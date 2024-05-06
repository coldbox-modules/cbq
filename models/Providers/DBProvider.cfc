component accessors="true" extends="AbstractQueueProvider" {

	property name="schedulerService" inject="coldbox:schedulerService";
	property name="async" inject="coldbox:asyncManager";
	property name="log" inject="logbox:logger:{this}";
	property name="workerQueue";
	property name="properties";
	property name="executor";

	variables.uniqueID = createUUID();
	variables.currentExecutorCount = 0;

	function onDIComplete() {
		variables.log.debug( "Creating new DB Provider for cbq: #variables.uniqueID#" );
	}

	public DBProvider function setProperties( required struct properties ) {
		variables.properties = arguments.properties;
		variables.tableName = variables.properties.keyExists( "tableName" ) ? variables.properties.tableName : "cbq_jobs";
		variables.defaultQueryOptions = variables.properties.keyExists( "queryOptions" ) ? variables.properties.queryOptions : {};
		if ( variables.properties.keyExists( "datasource" ) ) {
			variables.defaultQueryOptions[ "datasource" ] = variables.properties.datasource;
		}
		return this;
	}

	public any function listen( required WorkerPool pool ) {
		registerWorkerTask( arguments.pool );

		param variables.settings.cleanup = {};
		param variables.settings.cleanup.enabled = false;
		if ( variables.settings.cleanup.enabled ) {
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
					var jobCFC = variables.deserializeJob( job.payload, job.id, job.attempts );
					incrementJobAttempts( jobCFC, pool );
					application.cbController.getModuleService().loadMappings();
					variables.marshalJob(
						job = jobCFC,
						pool = pool,
						afterJobHook = () => {
							// variables.log.debug( "Job finished. Immediately running the scheduled task again." );
							// forceRun = true;
							// task.run();
						}
					);
				}

				return lockedRecords.len();
			} )
			.spacedDelay( 5, "seconds" )
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
		if ( isNull( variables.settings.cleanup.criteria ) ) {
			variables.settings.cleanup.criteria = function( q, currentUnixTimestamp ) {
				q.where( function( q ) {
					q3.where(
						"completedDate",
						"<=",
						currentUnixTimestamp - ( 60 * 60 * 24 * 7 )
					); // one week
					q3.orWhere(
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
				var deleteQuery = newQuery()
					.table( variables.tableName )
					.where( function( q ) {
						q2.whereNotNull( "completedDate" );
						q2.orWhereNotNull( "failedDate" );
					} );

				variables.settings.cleanup.criteria( deleteQuery, getCurrentUnixTimestamp() );

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

		if ( isNull( variables.settings.cleanup.frequency ) ) {
			variables.settings.cleanup.frequency = function( task ) {
				task.everyDay();
			};
		}
		variables.settings.cleanup.frequency( cleanupTask );

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
		required string payload,
		numeric delay = 0,
		numeric attempts = 0
	) {
		var jobPayload = {
			"queue" : arguments.queueName,
			"attempts" : arguments.attempts,
			"availableDate" : getCurrentUnixTimestamp( arguments.delay ),
			"createdDate" : getCurrentUnixTimestamp(),
			"payload" : arguments.payload
		};

		if ( variables.log.canDebug() ) {
			variables.log.debug( "Pushing job to #arguments.queueName# queue.", jobPayload );
		}

		newQuery().table( variables.tableName ).insert( jobPayload, variables.defaultQueryOptions );
		return this;
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

	private void function incrementJobAttempts( required AbstractJob job, required WorkerPool pool ) {
		if ( log.canDebug() ) {
			log.debug( "Reserving job ###arguments.job.getId()#" );
		}
		newQuery()
			.table( variables.tableName )
			.where( "id", arguments.job.getId() )
			.where( "reservedBy", arguments.pool.getUniqueId() )
			.whereNull( "reservedDate" )
			.update(
				values = {
					"reservedDate" : getCurrentUnixTimestamp(),
					"attempts" : arguments.job.getCurrentAttempt() + 1
				},
				options = variables.defaultQueryOptions
			);
		if ( log.canDebug() ) {
			log.debug( "Reserved job ###arguments.job.getId()#" );
		}
	}

	private void function afterJobRun( required AbstractJob job, required WorkerPool pool ) {
		markJobAsCompletedById( arguments.job.getId(), arguments.pool );
		// deleteJobById( arguments.job.getId() );
	}

	private void function afterJobFailed(
		required any id,
		AbstractJob job,
		WorkerPool pool
	) {
		markJobAsFailedById( arguments.id, isNull( arguments.pool ) ? javacast( "null", "" ) : arguments.pool );
		// deleteJobById( arguments.id );
	}

	private void function markJobAsCompletedById( required numeric id, required WorkerPool pool ) {
		newQuery()
			.table( variables.tableName )
			.where( "id", arguments.id )
			.where( "reservedBy", arguments.pool.getUniqueId() )
			.where( ( q ) => {
				q.whereNull( "completedDate" );
				q.whereNull( "failedDate" );
			} )
			.update( values = { "completedDate" : getCurrentUnixTimestamp() }, options = variables.defaultQueryOptions );
	}

	private void function markJobAsFailedById( required numeric id, WorkerPool pool ) {
		newQuery()
			.table( variables.tableName )
			.where( "id", arguments.id )
			.when( !isNull( arguments.pool ), ( q ) => {
				q.where( "reservedBy", pool.getUniqueId() );
			} )
			.where( "reservedBy", arguments.pool.getUniqueId() )
			.where( ( q ) => {
				q.whereNull( "completedDate" );
				q.whereNull( "failedDate" );
			} )
			.update( values = { "failedDate" : getCurrentUnixTimestamp() }, options = variables.defaultQueryOptions );
	}

	public void function releaseJob( required AbstractJob job, required WorkerPool pool ) {
		arguments.job.setCurrentAttempt( arguments.job.getCurrentAttempt() + 1 );
		newQuery()
			.table( variables.tableName )
			.where( "id", arguments.job.getId() )
			.where( "reservedBy", arguments.pool.getUniqueId() )
			.where( ( q ) => {
				q.whereNull( "completedDate" );
				q.whereNull( "failedDate" );
			} )
			.update(
				values = {
					"queue" : getQueueForJob( arguments.job, arguments.pool ),
					"payload" : serializeJSON( job.getMemento() ),
					"attempts" : arguments.job.getCurrentAttempt(),
					"reservedBy" : {
						"value" : "",
						"null" : true,
						"nulls" : true
					},
					"availableDate" : getCurrentUnixTimestamp( getBackoffForJob( arguments.job, arguments.pool ) ),
					"reservedDate" : {
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

		var ids = newQuery()
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
				// is reserved but expired
				q1.orWhere( ( q4 ) => {
					q4.where(
						"reservedDate",
						"<=",
						variables.getCurrentUnixTimestamp() - pool.getTimeout()
					);
				} );
			} )
			.orderByRaw( "CASE WHEN reservedBy = ? THEN 1 ELSE 2 END ASC", [ arguments.pool.getUniqueId() ] )
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
					.orWhere(
						"reservedDate",
						"<=",
						variables.getCurrentUnixTimestamp() - pool.getTimeout()
					);
			} )
			.update(
				values = {
					"reservedBy" : arguments.pool.getUniqueId(),
					"reservedDate" : {
						"value" : "",
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
