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
		variables.executor = variables.async.newExecutor(
			"cbq:DBProvider:#variables.uniqueID#",
			"fixed",
			1
		);
		registerDBTask();
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

	private void function registerDBTask() {
		variables.log.debug( "Registering DB Task for cbq" );
		variables.schedulerService.getSchedulers()[ "cbScheduler@cbq" ]
			.task( "cbq:db-watcher:#variables.uniqueID#" )
			.call( this, "fetchJobs" )
			.spacedDelay( 5, "seconds" )
			.before( function() {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Starting to fetch jobs from the db" );
				}
			} )
			.onSuccess( function( task, jobCount ) {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Finished fetching jobs from the db.  Total jobs retrieved: #jobCount#" );
				}
			} )
			.onFailure( function( task, exception ) {
				if ( variables.log.canError() ) {
					variables.log.error( "Exception when fetching database jobs", serializeJSON( arguments.exception ) );
				}
			} )
			.when( function() {
				return variables.currentExecutorCount > 0;
			} );
		variables.log.debug( "Starting DB Task for cbq" );
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
		variables.pool = arguments.pool;
		variables.workerQueue = variables.pool.getQueue();

		if ( variables.currentExecutorCount == 0 ) {
			variables.log.debug( "Enabling the DB Task." );
		}

		variables.currentExecutorCount++;
		var increasedPoolSize = javacast( "int", variables.currentExecutorCount );
		variables.executor.getNative().setMaximumPoolSize( increasedPoolSize );
		variables.executor.getNative().setCorePoolSize( increasedPoolSize );
		variables.log.debug( "New DB worker count is #increasedPoolSize#." );

		return function() {
			variables.log.debug( "Disabling a DB worker." );
			variables.currentExecutorCount--;
			var current = variables.executor.getCorePoolSize();
			var decreasedPoolSize = javacast( "int", current - 1 );
			if ( current > 1 ) {
				variables.executor.getNative().setCorePoolSize( decreasedPoolSize );
				variables.executor.getNative().setMaximumPoolSize( decreasedPoolSize );
			}
			if ( variables.currentExecutorCount == 0 ) {
				variables.log.debug( "All DB workers stopped. Disabling the DB Task." );
			}
			variables.log.debug( "New DB worker count is #decreasedPoolSize#." );
		};
	}

	public any function fetchJobs() {
		var jobRecords = newQuery()
			.from( variables.tableName )
			.lockForUpdate( skipLocked = true )
			.where( "queue", variables.workerQueue )
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
						variables.getCurrentUnixTimestamp() - variables.pool.getTimeout()
					);
				} );
			} )
			.orderByAsc( "id" )
			.limit( variables.currentExecutorCount )
			.get( options = variables.defaultQueryOptions );

		for ( var job in jobRecords ) {
			variables.marshalJob( variables.deserializeJob( job.payload, job.id, job.attempts ) );
		}

		return jobRecords.len();
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
