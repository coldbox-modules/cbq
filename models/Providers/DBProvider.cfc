component accessors="true" extends="AbstractQueueProvider" {

	property name="schedulerService" inject="coldbox:schedulerService";
	property name="async" inject="coldbox:asyncManager";
	property name="log" inject="logbox:logger:{this}";
	property name="workerQueue";
	property name="properties";
	property name="executor";

	variables.uniqueID = createUUID();
	variables.currentExecutorCount = 0;
	variables.bulkInsertBatchSize = 100;
	variables.largeBulkValidated = false;

	function onDIComplete() {
		variables.log.debug( "Creating new DB Provider for cbq: #variables.uniqueID#" );
	}

	public DBProvider function setProperties( required struct properties ) {
		var bulkSize = arguments.properties.keyExists( "bulkInsertBatchSize" ) ? arguments.properties.bulkInsertBatchSize : 100;
		if ( !isSimpleValue( bulkSize ) || !isValid( "integer", bulkSize ) || bulkSize < 1 || bulkSize > 1000 ) {
			throw(
				type = "cbq.DBProvider.InvalidBulkInsertBatchSize",
				message = "bulkInsertBatchSize must be an integer between 1 and 1000."
			);
		}
		var pollInterval = arguments.properties.keyExists( "pollIntervalMilliseconds" ) ? arguments.properties.pollIntervalMilliseconds : 5000;
		if ( !isSimpleValue( pollInterval ) || !isValid( "integer", pollInterval ) || pollInterval <= 0 ) {
			throw(
				type = "cbq.DBProvider.InvalidPollInterval",
				message = "pollIntervalMilliseconds must be a positive integer."
			);
		}
		variables.pollIntervalMilliseconds = pollInterval;
		variables.bulkInsertBatchSize = bulkSize;
		variables.largeBulkValidated = false;
		variables.properties = arguments.properties;
		variables.tableName = variables.properties.keyExists( "tableName" ) ? variables.properties.tableName : "cbq_jobs";
		variables.defaultQueryOptions = variables.properties.keyExists( "queryOptions" ) ? variables.properties.queryOptions : {};
		if ( variables.properties.keyExists( "datasource" ) ) {
			variables.defaultQueryOptions[ "datasource" ] = variables.properties.datasource;
		}
		return this;
	}

	/** PostgreSQL opt-in; five parameters per row exceed other engines' safe limits. */
	public numeric function getMaxBulkDispatchBatchSize() {
		if ( variables.bulkInsertBatchSize > 100 && !variables.largeBulkValidated ) {
			var grammar = newQuery().getGrammar();
			if ( structKeyExists( grammar, "getResolvedGrammar" ) ) {
				grammar = grammar.getResolvedGrammar();
			}
			// BoxLang may load the same stock source through a physical module alias.
			var grammarMetadata = getMetadata( grammar );
			var sameSource = structKeyExists( grammarMetadata, "path" ) &&
			compare(
				createObject( "java", "java.io.File" ).init( grammarMetadata.path ).getCanonicalPath(),
				createObject( "java", "java.io.File" )
					.init( expandPath( "/qb/models/Grammars/PostgresGrammar.cfc" ) )
					.getCanonicalPath()
			) == 0;
			if ( !isInstanceOf( grammar, "qb.models.Grammars.PostgresGrammar" ) && !sameSource ) {
				throw(
					type = "cbq.DBProvider.UnsupportedBulkInsertBatchSize",
					message = "bulkInsertBatchSize above 100 requires PostgreSQL."
				);
			}
			if ( variables.defaultQueryOptions.keyExists( "datasource" ) ) {
				cfdbinfo(
					type = "Version",
					name = "local.databaseInfo",
					datasource = variables.defaultQueryOptions.datasource
				);
			} else {
				cfdbinfo( type = "Version", name = "local.databaseInfo" );
			}
			if ( databaseInfo.DATABASE_PRODUCTNAME[ 1 ] != "PostgreSQL" ) {
				throw(
					type = "cbq.DBProvider.UnsupportedBulkInsertBatchSize",
					message = "bulkInsertBatchSize above 100 requires a PostgreSQL datasource."
				);
			}
			variables.largeBulkValidated = true;
		}
		return variables.bulkInsertBatchSize;
	}

	public any function listen( required WorkerPool pool ) {
		registerWorkerTask( arguments.pool );

		param variables.properties.cleanup = {};
		param variables.properties.cleanup.enabled = false;
		if ( variables.properties.cleanup.enabled ) {
			registerCleanupTask( arguments.pool );
		}
	}

	private any function registerWorkerTask( required WorkerPool pool ) {
		variables.log.debug( "Registering DB Task for Worker Pool [#arguments.pool.getUniqueId()#]" );

		// var forceRun = false;
		var task = variables.schedulerService.getSchedulers()[ "cbScheduler@cbq" ]
			.task( "cbq:db-watcher:#arguments.pool.getUniqueId()#" )
			.call( () => {
				var capacity = pool.getCurrentExecutorCount() - pool.getExecutor().getActiveCount();
				// var capacity = pool.getCurrentExecutorCount() - pool.getExecutor().getActiveCount() + ( forceRun ? 1 : 0 );
				// if ( forceRun ) {
				// 	forceRun = false;
				// }

				transaction {
					var potentiallyOpenRecords = fetchPotentiallyOpenRecords( capacity, pool );
					if ( potentiallyOpenRecords.isEmpty() ) {
						return potentiallyOpenRecords.len();
					}
					tryToLockRecords( potentiallyOpenRecords, pool );
				}

				var lockedRecords = fetchLockedRecords( capacity, pool );

				for ( var job in lockedRecords ) {
					processLockedRecord( job, pool );
				}

				return lockedRecords.len();
			} )
			.spacedDelay( variables.pollIntervalMilliseconds, "milliseconds" )
			.before( function() {
				application.cbController.getModuleService().loadMappings();
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Starting to fetch jobs from the db for Worker Pool [#pool.getUniqueId()#]" );
				}
			} )
			.onSuccess( function( task, jobCount ) {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Finished fetching jobs from the db for Worker Pool [#pool.getUniqueId()#].  Total jobs retrieved: #jobCount.orElse( 0 )#" );
				}
			} )
			.onFailure( function( task, exception ) {
				if ( variables.log.canError() ) {
					variables.log.error(
						"Exception when fetching database jobs for Worker Pool [#pool.getUniqueId()#]: #exception.message#",
						{
							"pool" : pool.getMemento(),
							"exception" : arguments.exception
						}
					);
				}
			} )
			.when( function() {
				variables.log.debug(
					"Checking if we should fetch new database jobs for Worker Pool [#pool.getUniqueId()#].",
					{
						"currentExecutorCount" : pool.getCurrentExecutorCount(),
						"activeCount" : pool.getExecutor().getActiveCount(),
						"willRun" : pool.getCurrentExecutorCount() > 0 && pool.getExecutor().getActiveCount() < pool.getCurrentExecutorCount()
						// "forceRun" : forceRun
					}
				);

				// if ( forceRun ) {
				// 	variables.log.debug( "forceRun is true so we will fetch new database jobs and reset forceRun to false for Worker Pool [#pool.getUniqueId()#]." );
				// 	return true;
				// }

				return pool.getCurrentExecutorCount() > 0 &&
				pool.getExecutor().getActiveCount() < pool.getCurrentExecutorCount();
			} );

		variables.log.debug( "Starting DB Task for Worker Pool [#arguments.pool.getUniqueId()#]" );
	}

	private any function registerCleanupTask( required WorkerPool pool ) {
		if ( isNull( variables.properties.cleanup.criteria ) ) {
			variables.properties.cleanup.criteria = function( qb, currentUnixTimestamp ) {
				qb.where( function( q ) {
					q.where(
						"completedDate",
						"<=",
						currentUnixTimestamp - ( 60 * 60 * 24 * 7 )
					); // one week
					q.orWhere(
						"failedDate",
						"<=",
						currentUnixTimestamp - ( 60 * 60 * 24 * 7 )
					); // one week
				} );
			};
		}

		variables.log.debug( "Registering DB Task for cleaning up completed and failed worker pool jobs [#arguments.pool.getUniqueId()#]" );

		var cleanupTask = variables.schedulerService.getSchedulers()[ "cbScheduler@cbq" ]
			.task( "cbq:db-cleanup-watcher:#arguments.pool.getUniqueId()#" )
			.call( function() {
				var deleteQuery = newQuery();
				variables.properties.cleanup.criteria( deleteQuery, getCurrentUnixTimestamp() );
				// These restrictions are added after to prevent any mistakes from the user erasing them.
				deleteQuery
					.table( variables.tableName )
					.where( function( q ) {
						q.whereNotNull( "completedDate" );
						q.orWhereNotNull( "failedDate" );
					} );
				return deleteQuery.delete( options = variables.defaultQueryOptions ).result.recordCount;
			} )
			.before( function() {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Starting to clean up completed and failed jobs from the db for Worker Pool [#pool.getUniqueId()#]" );
				}
			} )
			.onSuccess( function( task, deletedCount ) {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Finished cleaning up completed and failed jobs from the db for Worker Pool [#pool.getUniqueId()#]. Total jobs deleted: #deletedCount.orElse( 0 )#" );
				}
			} )
			.onFailure( function( task, exception ) {
				if ( variables.log.canError() ) {
					variables.log.error(
						"Exception when cleaning up completed and failed database jobs for Worker Pool [#pool.getUniqueId()#]: #exception.message#",
						{
							"pool" : pool.getMemento(),
							"exception" : arguments.exception
						}
					);
				}
			} );

		if ( isNull( variables.properties.cleanup.frequency ) ) {
			variables.properties.cleanup.frequency = function( task ) {
				task.everyDay();
			};
		}
		variables.properties.cleanup.frequency( cleanupTask );

		variables.log.debug( "Starting DB Task for cleaning up completed and failed worker pool jobs [#arguments.pool.getUniqueId()#]" );
	}

	private boolean function worksMultipleQueues( required WorkerPool pool ) {
		return isArray( arguments.pool.getQueue() );
	}

	private boolean function shouldWorkAllQueues( required WorkerPool pool ) {
		var queues = arguments.pool.getQueue();
		if ( !isArray( queues ) ) {
			return queues == "*";
		}
		return queues.filter( ( queue ) => queue == "*" ).len() > 0;
	}

	private string function generateQueuePriorityOrderBy( required WorkerPool pool ) {
		var queues = arguments.pool.getQueue();
		if ( !isArray( queues ) ) {
			return;
		}

		var whenStatements = queues
			.filter( ( queue ) => queue != "*" )
			.map( ( queue, i, arr ) => "WHEN queue = '#queue#' THEN #arr.len() - i + 1#" );
		return "CASE #whenStatements.toList( " " )# ELSE 0 END DESC";
	}

	public any function push(
		required string queueName,
		required AbstractJob job,
		numeric delay = 0,
		numeric attempts = 0
	) {
		var jobPayload = buildJobPayload( argumentCollection = arguments );
		newQuery().table( variables.tableName ).insert( jobPayload, variables.defaultQueryOptions );
		return this;
	}

	/** Each job remains a separate row; the caller owns transaction boundaries. */
	public any function pushMany( required array entries ) {
		var batchSize = getMaxBulkDispatchBatchSize();
		var rows = [];
		for ( var entry in arguments.entries ) {
			rows.append( buildJobPayload( argumentCollection = entry ) );
			// The default stays below SQL Server/SQLite limits; larger batches require PostgreSQL.
			if ( rows.len() == batchSize ) {
				newQuery().table( variables.tableName ).insert( rows, variables.defaultQueryOptions );
				rows = [];
			}
		}
		if ( rows.len() ) {
			newQuery().table( variables.tableName ).insert( rows, variables.defaultQueryOptions );
		}
		return this;
	}

	private struct function buildJobPayload(
		required string queueName,
		required AbstractJob job,
		numeric delay = 0,
		numeric attempts = 0
	) {
		var jobPayload = {
			"queue" : {
				"value" : arguments.queueName,
				"cfsqltype" : "varchar"
			},
			"attempts" : {
				"value" : arguments.attempts,
				"cfsqltype" : "bigint"
			},
			"availableDate" : getCurrentUnixTimestamp( arguments.delay ),
			"createdDate" : getCurrentUnixTimestamp(),
			"payload" : {
				"value" : serializeJSON( arguments.job.getMemento() ),
				"cfsqltype" : "varchar"
			}
		};

		if ( variables.log.canDebug() ) {
			variables.log.debug( "Pushing job to #arguments.queueName# queue.", jobPayload );
		}
		return jobPayload;
	}

	public function function startWorker( required WorkerPool pool ) {
		variables.log.debug( "Starting DB worker." );

		if ( arguments.pool.getCurrentExecutorCount() == 0 ) {
			variables.log.debug( "Enabling the DB Task." );
		}

		arguments.pool.incrementCurrentExecutorCount();
		var increasedPoolSize = javacast( "int", arguments.pool.getCurrentExecutorCount() );
		arguments.pool
			.getExecutor()
			.getNative()
			.setMaximumPoolSize( increasedPoolSize );
		arguments.pool
			.getExecutor()
			.getNative()
			.setCorePoolSize( increasedPoolSize );
		variables.log.debug( "New DB worker count is #increasedPoolSize#." );

		return function() {
			variables.log.debug( "Disabling a DB worker." );
			pool.decrementCurrentExecutorCount();
			var current = pool.getExecutor().getCorePoolSize();
			var decreasedPoolSize = javacast( "int", current - 1 );
			if ( current > 1 ) {
				pool.getExecutor()
					.getNative()
					.setCorePoolSize( decreasedPoolSize );
				pool.getExecutor()
					.getNative()
					.setMaximumPoolSize( decreasedPoolSize );
			}
			variables.log.debug( "New DB worker count is #decreasedPoolSize#." );
			if ( pool.getCurrentExecutorCount() == 0 ) {
				variables.log.debug( "All DB workers stopped. Disabling the DB Task." );
			}
		};
	}

	public boolean function supportsMultipleQueues() {
		return true;
	}

	private void function processLockedRecord( required any record, required WorkerPool pool ) {
		try {
			var jobCFC = variables.deserializeJob(
				arguments.record.payload,
				arguments.record.id,
				arguments.record.attempts
			);
		} catch ( cbq.UnknownJobMapping e ) {
			// No execution has started. Release only this fetched reservation so
			// another worker can handle it, without consuming an attempt.
			newQuery()
				.table( variables.tableName )
				.where( "id", arguments.record.id )
				.where( "reservedBy", arguments.pool.getUniqueId() )
				.whereNull( "reservedDate" )
				.whereNull( "completedDate" )
				.whereNull( "failedDate" )
				.where(
					"attempts",
					{
						"value" : arguments.record.attempts,
						"sqltype" : "bigint"
					}
				)
				.update(
					values = {
						"reservedBy" : {
							"value" : "",
							"null" : true,
							"nulls" : true
						}
					},
					options = variables.defaultQueryOptions
				);
			log.warn(
				"Worker pool [#arguments.pool.getUniqueId()#] cannot handle job [#arguments.record.id#]: #e.message#",
				{
					"queue" : arguments.record.queue,
					"jobId" : arguments.record.id,
					"pool" : arguments.pool.getUniqueId()
				}
			);
			return;
		}

		jobCFC.setProviderContext( {
			"attempt" : arguments.record.attempts,
			"awaitingExecution" : true
		} );
		var jobMaxAttempts = getMaxAttemptsForJob( jobCFC, arguments.pool );
		if ( jobMaxAttempts != 0 && arguments.record.attempts >= jobMaxAttempts ) {
			if ( log.canWarn() ) {
				log.warn(
					"Job ###jobCFC.getId()# already has #arguments.record.attempts# attempts (max #jobMaxAttempts#). Marking as failed without further retry.",
					{ "job" : jobCFC.getMemento() }
				);
			}
			markJobFailed(
				jobCFC,
				arguments.pool,
				buildMaxAttemptsReachedException( jobCFC, jobMaxAttempts )
			);
			return;
		}

		if ( !incrementJobAttempts( jobCFC, arguments.pool ) ) {
			return;
		}
		jobCFC.setProviderContext( {
			"attempt" : arguments.record.attempts + 1,
			"awaitingExecution" : false
		} );
		application.cbController.getModuleService().loadMappings();
		variables.marshalJob(
			job = jobCFC,
			pool = arguments.pool,
			afterJobHook = () => {
			}
		);
	}

	private boolean function incrementJobAttempts( required AbstractJob job, required WorkerPool pool ) {
		if ( log.canDebug() ) {
			log.debug( "Reserving job ###arguments.job.getId()#" );
		}
		var reservation = newQuery()
			.table( variables.tableName )
			.where( "id", arguments.job.getId() )
			.where( "reservedBy", arguments.pool.getUniqueId() )
			.whereNull( "reservedDate" )
			.whereNull( "completedDate" )
			.whereNull( "failedDate" )
			.where(
				"attempts",
				{
					"value" : arguments.job.getCurrentAttempt(),
					"sqltype" : "bigint"
				}
			)
			.update(
				values = {
					"reservedDate" : getCurrentUnixTimestamp(),
					"availableDate" : getCurrentUnixTimestamp( getTimeoutForJob( arguments.job, arguments.pool ) ),
					"attempts" : {
						"value" : arguments.job.getCurrentAttempt() + 1,
						"sqltype" : "bigint"
					}
				},
				options = variables.defaultQueryOptions
			);
		if ( log.canDebug() ) {
			log.debug( "Reserved job ###arguments.job.getId()#" );
		}
		return reservation.result.recordCount == 1;
	}

	private void function afterJobRun( required AbstractJob job, required WorkerPool pool ) {
		ownedJobQuery(
			arguments.job.getId(),
			arguments.pool,
			arguments.job
		).update( values = { "completedDate" : getCurrentUnixTimestamp() }, options = variables.defaultQueryOptions );
	}

	private void function afterJobFailed(
		required any id,
		AbstractJob job,
		WorkerPool pool
	) {
		ownedJobQuery( argumentCollection = arguments ).update(
			values = { "failedDate" : getCurrentUnixTimestamp() },
			options = variables.defaultQueryOptions
		);
	}

	public void function forceFailJob(
		required any id,
		WorkerPool pool,
		AbstractJob job
	) {
		if ( !isNull( arguments.job ) ) {
			ownedJobQuery( argumentCollection = arguments ).update(
				values = { "failedDate" : getCurrentUnixTimestamp() },
				options = variables.defaultQueryOptions
			);
			return;
		}
		// Preserve the explicit ID-only administrative fallback contract.
		newQuery()
			.table( variables.tableName )
			.where( "id", arguments.id )
			.update( values = { "failedDate" : getCurrentUnixTimestamp() }, options = variables.defaultQueryOptions );
	}

	private any function ownedJobQuery(
		required any id,
		WorkerPool pool,
		AbstractJob job
	) {
		var query = newQuery()
			.table( variables.tableName )
			.where( "id", arguments.id )
			.whereNull( "completedDate" )
			.whereNull( "failedDate" );
		if ( !isNull( arguments.pool ) ) {
			query.where( "reservedBy", arguments.pool.getUniqueId() );
		}
		if ( !isNull( arguments.job ) ) {
			var context = arguments.job.getProviderContext() ?: {};
			query.where(
				"attempts",
				{
					"value" : context.keyExists( "attempt" ) ? context.attempt : arguments.job.getCurrentAttempt(),
					"sqltype" : "bigint"
				}
			);
			if ( context.awaitingExecution ?: false ) {
				query.whereNull( "reservedDate" );
			} else {
				// A reclaimed-but-not-started row still has the previous count.
				// Its cleared reservedDate fences callbacks from that execution.
				query.whereNotNull( "reservedDate" );
			}
		}
		return query;
	}

	private any function buildMaxAttemptsReachedException( required AbstractJob job, required numeric maxAttempts ) {
		try {
			throw(
				type = "cbq.MaxAttemptsReached",
				message = "Job ###arguments.job.getId()# exceeded maximum attempts (#arguments.maxAttempts#) before execution."
			);
		} catch ( any e ) {
			return e;
		}
	}

	public void function releaseJob( required AbstractJob job, required WorkerPool pool ) {
		// The current execution was already counted by processLockedRecord/marshalJob.
		ownedJobQuery(
			arguments.job.getId(),
			arguments.pool,
			arguments.job
		).update(
			values = {
				"queue" : getQueueForJob( arguments.job, arguments.pool ),
				"payload" : serializeJSON( job.getMemento() ),
				"attempts" : {
					"value" : arguments.job.getCurrentAttempt(),
					"sqltype" : "bigint"
				},
				"reservedBy" : {
					"value" : "",
					"null" : true,
					"nulls" : true
				},
				"availableDate" : getCurrentUnixTimestamp( getBackoffForJob( arguments.job, arguments.pool ) ),
				"reservedDate" : {
					"cfsqltype" : "cf_sql_bigint",
					"value" : "",
					"null" : true,
					"nulls" : true
				},
				"lastReleasedDate" : getCurrentUnixTimestamp()
			},
			options = variables.defaultQueryOptions
		);
	}

	private array function fetchPotentiallyOpenRecords( required numeric capacity, required WorkerPool pool ) {
		if ( log.canDebug() ) {
			log.debug( "Fetching up to #capacity# potentially open record(s) [Worker Pool #pool.getUniqueId()#]." );
		}

		var builder = newQuery();
		var ids = builder
			.from( variables.tableName )
			.limit( arguments.capacity )
			.lockForUpdate( skipLocked = true )
			.when( !shouldWorkAllQueues( arguments.pool ), ( q ) => q.whereIn( "queue", pool.getQueue() ) )
			.where( ( q ) => {
				q.whereNull( "completedDate" );
				q.whereNull( "failedDate" );
			} )
			.where( ( q1 ) => {
				// is available
				q1.where( ( q2 ) => {
					q2.whereNull( "reservedDate" )
						.whereNull( "reservedBy" )
						.where(
							"availableDate",
							"<=",
							variables.getCurrentUnixTimestamp()
						);
				} );
				// past the job's own timeout (availableDate was set to now + jobTimeout at reservation time)
				q1.orWhere( ( q2 ) => {
					q2.whereNotNull( "reservedDate" )
						.where(
							"availableDate",
							"<=",
							variables.getCurrentUnixTimestamp()
						);
				} );
				// reserved by a worker but never released
				q1.orWhere( ( q3 ) => {
					q3.whereNull( "reservedDate" )
						.whereNotNull( "reservedBy" )
						.where(
							"availableDate",
							"<=",
							variables.getCurrentUnixTimestamp()
						);
				} );
			} )
			.orderByRaw(
				"CASE WHEN #builder.getGrammar().wrapValue( "reservedBy" )# = ? THEN 1 ELSE 2 END ASC",
				[ arguments.pool.getUniqueId() ]
			)
			.when( worksMultipleQueues( arguments.pool ), ( q ) => {
				q.orderByRaw( generateQueuePriorityOrderBy( pool ) )
			} )
			.orderByAsc( "id" )
			.values( column = "id", options = variables.defaultQueryOptions );

		if ( log.canDebug() ) {
			log.debug(
				"Found #arrayLen( ids )# potentially open record(s) to lock [Worker Pool #pool.getUniqueId()#].",
				{ "ids" : ids }
			);
		}

		return ids;
	}

	private void function tryToLockRecords( required array ids, required WorkerPool pool ) {
		if ( log.canDebug() ) {
			log.debug(
				"Attempting to lock #arrayLen( ids )# record(s) for Worker Pool #pool.getUniqueId()#.",
				{ "ids" : ids }
			);
		}

		var result = newQuery()
			.table( variables.tableName )
			.whereIn( "id", arguments.ids )
			.where( ( q ) => {
				q.whereNull( "completedDate" );
				q.whereNull( "failedDate" );
			} )
			.where( ( q ) => {
				q.where( ( q2 ) => {
						q2.whereNull( "reservedBy" );
						q2.whereNull( "reservedDate" );
					} )
					.orWhere( ( q2 ) => {
						q2.whereNotNull( "reservedDate" )
							.where(
								"availableDate",
								"<=",
								variables.getCurrentUnixTimestamp()
							);
					} )
					.orWhere( ( q2 ) => {
						q2.whereNotNull( "reservedBy" )
							.whereNull( "reservedDate" )
							.where(
								"availableDate",
								"<=",
								variables.getCurrentUnixTimestamp()
							);
					} );
			} )
			.update(
				values = {
					"reservedBy" : arguments.pool.getUniqueId(),
					"reservedDate" : {
						"value" : "",
						"cfsqltype" : "cf_sql_bigint",
						"null" : true,
						"nulls" : true
					}
				},
				options = variables.defaultQueryOptions
			)
			.result;

		if ( log.canDebug() ) {
			log.debug(
				"Attempted to lock #arrayLen( ids )# record(s). Actually locked #result.recordCount# record(s).",
				{
					"attemptedIds" : ids,
					"workerPool" : pool.getUniqueId()
				}
			);
		}
	}

	private array function fetchLockedRecords( required numeric capacity, required WorkerPool pool ) {
		if ( log.canDebug() ) {
			log.debug( "Fetching up to #arguments.capacity# locked record(s) for Worker Pool #pool.getUniqueId()#." );
		}

		var records = newQuery()
			.from( variables.tableName )
			.limit( arguments.capacity )
			.when( !shouldWorkAllQueues( pool ), ( q ) => q.whereIn( "queue", pool.getQueue() ) )
			.where( ( q ) => {
				q.whereNull( "completedDate" );
				q.whereNull( "failedDate" );
			} )
			.where( "reservedBy", pool.getUniqueId() )
			.whereNull( "reservedDate" )
			.when( worksMultipleQueues( pool ), ( q ) => {
				q.orderByRaw( generateQueuePriorityOrderBy( pool ) )
			} )
			.orderByAsc( "id" )
			.get( options = variables.defaultQueryOptions );

		if ( log.canDebug() ) {
			log.debug(
				"Fetched #arrayLen( records )# locked record(s) for Worker Pool #pool.getUniqueId()#.",
				{ "records" : records }
			);
		}

		return records;
	}

	public QueryBuilder function newQuery() provider="QueryBuilder@qb" {
	}

}
