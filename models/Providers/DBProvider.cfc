component accessors="true" extends="AbstractQueueProvider" {

	property name="schedulerService" inject="coldbox:schedulerService";
	property name="async" inject="coldbox:asyncManager";
	property name="log" inject="logbox:logger:{this}";
	property name="workerQueue";
	property name="properties";
	property name="executor";

	variables.uniqueID = createUUID();
	variables.currentExecutorCount = 0;
	variables.reservationDurationInSeconds = 60;

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
		variables.log.debug( "Registering DB Task for Worker Pool [#arguments.pool.getName()#]" );
		variables.schedulerService.getSchedulers()[ "cbScheduler@cbq" ]
			.task( "cbq:db-watcher:#arguments.pool.getName()#" )
			.call( () => {
				var jobRecords = newQuery()
					.from( variables.tableName )
					.lockForUpdate( skipLocked = true )
					.when( !pool.shouldWorkAllQueues(), ( q ) => q.whereIn( "queue", pool.getQueues() ) )
					.where( function( q1 ) {
						// is available
						q1.where( function( q2 ) {
							q2.whereNull( "reservedDate" )
								.where(
									"availableDate",
									"<=",
									variables.getCurrentUnixTimestamp()
								);
						} );
						// is reserved but expired
						q1.orWhere( function( q3 ) {
							q3.where(
								"reservedDate",
								"<=",
								variables.getCurrentUnixTimestamp() - pool.getTimeout()
							);
						} );
					} )
					.orderByRaw( generateQueuePriorityOrderBy( pool ) )
					.orderByAsc( "id" )
					.get( options = variables.defaultQueryOptions );

				for ( var job in jobRecords ) {
					variables.marshalJob( variables.deserializeJob( job.payload, job.id, job.attempts ), pool );
				}

				return jobRecords.len();
			} )
			.spacedDelay( 5, "seconds" )
			.before( function() {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Starting to fetch jobs from the db for Worker Pool [#pool.getName()#]" );
				}
			} )
			.onSuccess( function( task, jobCount ) {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Finished fetching jobs from the db for Worker Pool [#pool.getName()#].  Total jobs retrieved: #jobCount#" );
				}
			} )
			.onFailure( function( task, exception ) {
				if ( variables.log.canError() ) {
					variables.log.error(
						"Exception when fetching database jobs for Worker Pool [#pool.getName()#]",
						serializeJSON( arguments.exception )
					);
				}
			} )
			.when( function() {
				return pool.getQuantity() > 0;
			} );
		variables.log.debug( "Starting DB Task for Worker Pool [#arguments.pool.getName()#]" );
	}

	private string function generateQueuePriorityOrderBy( required WorkerPool pool ) {
		var whenStatements = arguments.pool
			.getQueues()
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
			"attempts" : arguments.attempts, // TODO: attempts should probably be in the payload
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

	private void function beforeJobRun( required AbstractJob job ) {
		markJobAsReserved( arguments.job );
	}

	private void function markJobAsReserved( required AbstractJob job ) {
		if ( log.canDebug() ) {
			log.debug( "Reserving job ###arguments.job.getId()#" );
		}
		newQuery()
			.table( variables.tableName )
			.where( "id", arguments.job.getId() )
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

	private void function afterJobRun( required AbstractJob job ) {
		deleteJobById( arguments.job.getId() );
	}

	private void function afterJobFailed( required any id, AbstractJob job ) {
		deleteJobById( arguments.id );
	}

	private void function deleteJobById( required numeric id ) {
		transaction {
			if (
				!newQuery()
					.table( variables.tableName )
					.lockForUpdate()
					.find( id = arguments.id, options = variables.defaultQueryOptions )
					.isEmpty()
			) {
				newQuery()
					.table( variables.tableName )
					.where( "id", arguments.id )
					.delete( options = variables.defaultQueryOptions );
			}
		}
	}

	private void function releaseJob( required AbstractJob job ) {
		transaction {
			if (
				!newQuery()
					.table( variables.tableName )
					.lockForUpdate()
					.find( id = arguments.job.getId(), options = variables.defaultQueryOptions )
					.isEmpty()
			) {
				newQuery()
					.table( variables.tableName )
					.where( "id", arguments.job.getId() )
					.delete( options = variables.defaultQueryOptions );
			}

			super.releaseJob( arguments.job );
		}
	}

	public QueryBuilder function newQuery() provider="QueryBuilder@qb" {
	}

}
