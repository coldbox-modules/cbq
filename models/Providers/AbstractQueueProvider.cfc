component accessors="true" {

	property name="interceptorService" inject="box:interceptorService";
	property name="javaInstant" inject="java:java.time.Instant";
	property name="async" inject="coldbox:asyncManager";
	property name="log" inject="logbox:logger:{this}";
	property name="wirebox" inject="wirebox";
	property name="cbq" inject="@cbq";

	property name="name";
	property name="properties";

	/**
	 * Persists a serialized job to the Queue Connection
	 *
	 * @queueName The queue name for the job.
	 * @payload   The serialized job string.
	 * @delay     The delay (in seconds) before working the job.
	 * @attempts  The current attempt number.
	 *
	 * @return    AbstractQueueProvider
	 */
	public any function push(
		required string queueName,
		required string payload,
		numeric delay = 0,
		numeric attempts = 0
	) {
		throw(
			type = "MissingAbstractMethod",
			message = "This is an abstract method and must be implemented in a subclass."
		);
	}

	/**
	 * Starts a worker for a Worker Pool on this Queue Connection.
	 *
	 * @pool    The Worker Pool that is working this Queue Connection.
	 *
	 * @return  A function that when called will stop this worker.
	 */
	public function function startWorker( required WorkerPool pool ) {
		throw(
			type = "MissingAbstractMethod",
			message = "This is an abstract method and must be implemented in a subclass."
		);
	}

	/**
	 * Starts any background processes needed for the Worker Pool.
	 *
	 * @pool    The Worker Pool that is working this Queue Connection.
	 *
	 * @return  AbstractQueueProvider
	 */
	public any function listen( required WorkerPool pool ) {
		throw(
			type = "MissingAbstractMethod",
			message = "This is an abstract method and must be implemented in a subclass."
		);
	}

	public any function deserializeJob(
		required string payload,
		required any jobId,
		required numeric currentAttempt
	) {
		var config = deserializeJSON( arguments.payload );

		if ( !variables.wirebox.containsInstance( config.mapping ) ) {
			afterJobFailed( arguments.jobId );
			throw( "Failed to find the [#config.mapping#] instance" );
		}

		var instance = variables.wirebox.getInstance( config.mapping );
		instance.applyMemento( config );
		instance.setId( arguments.jobId );
		instance.setCurrentAttempt( arguments.currentAttempt );

		if ( config.keyExists( "batchId" ) ) {
			instance.withBatchId( config.batchId );
			instance.setIsLifecycleJob( config.isLifecycleJob );
		}

		return instance;
	}

	/**
	 * Get the "available at" UNIX timestamp.
	 *
	 * @delay  The delay, in seconds, to add to the current timestamp
	 * @return int
	 */
	public numeric function getCurrentUnixTimestamp( numeric delay = 0 ) {
		return variables.javaInstant.now().getEpochSecond() + arguments.delay;
	}

	private void function marshalJob(
		required AbstractJob job,
		required WorkerPool pool,
		function afterJobHook
	) {
		variables.async
			.newFuture( function() {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Marshaling job ###job.getId()#", job.getMemento() );
				}

				beforeJobRun( job );

				variables.interceptorService.announce( "onCBQJobMarshalled", { "job" : job } );

				if ( variables.log.canDebug() ) {
					variables.log.debug( "Running job ###job.getId()#", job.getMemento() );
				}

				return job.handle();
			}, arguments.pool.getExecutor() )
			.orTimeout( getTimeoutForJob( arguments.job, arguments.pool ), "seconds" )
			.then( function( result ) {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Job ###job.getId()# completed successfully." );
				}

				variables.interceptorService.announce(
					"onCBQJobComplete",
					{
						"job" : job,
						"result" : isNull( result ) ? javacast( "null", "" ) : result
					}
				);

				afterJobRun( job );

				dispatchNextJobInChain( job );
				ensureSuccessfulBatchJobIsRecorded( job );

				if ( !isNull( afterJobHook ) && ( isCustomFunction( afterJobHook ) || isClosure( afterJobHook ) ) ) {
					afterJobHook( job );
				}
			} )
			.onException( function( e ) {
				// log failed job
				if ( "java.util.concurrent.CompletionException" == e.getClass().getName() ) {
					e = e.getCause();
				}

				if ( log.canError() ) {
					log.error(
						"Exception when running job: #e.message#",
						{
							"job" : job.getMemento(),
							"exception" : e
						}
					);
				}

				variables.interceptorService.announce( "onCBQJobException", { "job" : job, "exception" : e } );

				if ( job.getCurrentAttempt() < getMaxAttemptsForJob( job, pool ) ) {
					variables.log.debug( "Releasing job ###job.getId()#" );
					releaseJob( job, pool );
					variables.log.debug( "Released job ###job.getId()#" );
				} else {
					variables.log.debug( "Maximum attempts reached. Deleting job ###job.getId()#" );

					if ( structKeyExists( job, "onFailure" ) ) {
						invoke(
							job,
							"onFailure",
							{ "excpetion" : e }
						);
					}

					variables.interceptorService.announce( "onCBQJobFailed", { "job" : job, "exception" : e } );

					afterJobFailed( job.getId(), job );
					ensureFailedBatchJobIsRecorded( job, e );

					variables.log.debug( "Deleted job ###job.getId()# after maximum failed attempts." );
				}

				if ( !isNull( afterJobHook ) && ( isCustomFunction( afterJobHook ) || isClosure( afterJobHook ) ) ) {
					afterJobHook( job );
				}
			} );
	}

	private void function beforeJobRun( required AbstractJob job ) {
	}

	private void function afterJobRun( required AbstractJob job ) {
	}

	private void function afterJobFailed( required any id, AbstractJob job ) {
	}

	private void function releaseJob( required AbstractJob job, required WorkerPool pool ) {
		push(
			getQueueForJob( arguments.job, arguments.pool ),
			serializeJSON( job.getMemento() ),
			getBackoffForJob( arguments.job, arguments.pool ),
			arguments.job.getCurrentAttempt() + 1
		);
	}

	private string function getQueueForJob( required AbstractJob job, required WorkerPool pool ) {
		if ( !isNull( arguments.job.getQueue() ) ) {
			return arguments.job.getQueue();
		}

		if ( !isNull( arguments.pool ) ) {
			return arguments.pool.getQueues()[ 1 ];
		}

		return "default";
	}

	private numeric function getBackoffForJob( required AbstractJob job, required WorkerPool pool ) {
		if ( !isNull( arguments.job.getBackoff() ) ) {
			return arguments.job.getBackoff();
		}

		if ( !isNull( arguments.pool ) ) {
			return arguments.pool.getBackoff();
		}

		return 0;
	}

	private numeric function getTimeoutForJob( required AbstractJob job, required WorkerPool pool ) {
		if ( !isNull( arguments.job.getTimeout() ) ) {
			return arguments.job.getTimeout();
		}

		if ( !isNull( arguments.pool ) ) {
			return arguments.pool.getTimeout();
		}

		return 60;
	}

	private numeric function getMaxAttemptsForJob( required AbstractJob job, required WorkerPool pool ) {
		if ( !isNull( arguments.job.getMaxAttempts() ) ) {
			return arguments.job.getMaxAttempts();
		}

		if ( !isNull( arguments.pool ) ) {
			return arguments.pool.getMaxAttempts();
		}

		return 1;
	}

	private void function dispatchNextJobInChain( required AbstractJob job ) {
		var chain = arguments.job.getChained();
		if ( chain.isEmpty() ) {
			return;
		}

		var nextJobConfig = chain[ 1 ];
		var nextJob = variables.cbq.job( nextJobConfig.mapping );
		param nextJobConfig.properties = {};

		if ( !isNull( nextJobConfig.queue ) ) {
			nextJob.setQueue( nextJobConfig.queue );
		}

		if ( !isNull( nextJobConfig.connection ) ) {
			nextJob.setConnection( nextJobConfig.connection );
		}

		if ( !isNull( nextJobConfig.timeout ) ) {
			nextJob.setTimeout( nextJobConfig.timeout );
		}

		if ( !isNull( nextJobConfig.backoff ) ) {
			nextJob.setBackoff( nextJobConfig.backoff );
		}

		if ( !isNull( nextJobConfig.maxAttempts ) ) {
			nextJob.setMaxAttempts( nextJobConfig.maxAttempts );
		}

		nextJob.setProperties( nextJobConfig.properties );

		if ( chain.len() >= 2 ) {
			nextJob.setChained( chain.slice( 2 ) );
		}

		nextJob.dispatch();
	}

	private void function ensureSuccessfulBatchJobIsRecorded( required AbstractJob job ) {
		if ( !arguments.job.isBatchJob() ) {
			return;
		}

		if ( arguments.job.getIsLifecycleJob() ) {
			return;
		}

		arguments.job.getBatch().recordSuccessfulJob( arguments.job.getId() );
	}

	private void function ensureFailedBatchJobIsRecorded( required AbstractJob job, required any error ) {
		if ( !arguments.job.isBatchJob() ) {
			return;
		}

		if ( arguments.job.getIsLifecycleJob() ) {
			return;
		}

		arguments.job.getBatch().recordFailedJob( arguments.job.getId(), arguments.error );
	}

}
