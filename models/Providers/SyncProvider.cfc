component accessors="true" extends="AbstractQueueProvider" {

	public any function push(
		required string queueName,
		required string payload,
		numeric delay = 0,
		numeric attempts = 0
	) {
		if ( isNull( variables.pool ) ) {
			if ( variables.log.canWarn() ) {
				variables.log.warn( "No workers have been defined so this job will not be executed." );
			}
			return;
		}

		sleep( arguments.delay ); // TODO: do we want to respect delay in the sync driver?
		marshalJob( deserializeJob( arguments.payload, createUUID(), arguments.attempts ) );
		return this;
	}

	public function function startWorker( required WorkerPool pool ) {
		variables.pool = arguments.pool;
		return function() {
		};
	}

	private void function marshalJob( required AbstractJob job ) {
		try {
			if ( variables.log.canDebug() ) {
				variables.log.debug( "Marshaling job ###job.getId()#", job.getMemento() );
			}

			beforeJobRun( job );

			variables.interceptorService.announce( "onCBQJobMarshalled", { "job": job } );

			if ( variables.log.canDebug() ) {
				variables.log.debug( "Running job ###job.getId()#", job.getMemento() );
			}

			var result = job.handle();

			if ( variables.log.canDebug() ) {
				variables.log.debug( "Job ###job.getId()# completed successfully." );
			}

			variables.interceptorService.announce(
				"onCBQJobComplete",
				{
					"job": job,
					"result": isNull( result ) ? javacast( "null", "" ) : result
				}
			);

			afterJobRun( job );

			return isNull( result ) ? javacast( "null", "" ) : result;
		} catch ( any e ) {
			// log failed job
			if ( "java.util.concurrent.CompletionException" == e.getClass().getName() ) {
				e = e.getCause();
			}

			if ( log.canError() ) {
				log.error( "Exception when running job #job.getId()#:", serializeJSON( e ) );
			}

			variables.interceptorService.announce(
				"onCBQJobException",
				{
					"job": job,
					"exception": e
				}
			);

			if ( job.getCurrentAttempt() < getMaxAttemptsForJob( job ) ) {
				variables.log.debug( "Releasing job ###job.getId()#" );
				releaseJob( job );
				variables.log.debug( "Released job ###job.getId()#" );
			} else {
				variables.log.debug( "Maximum attempts reached. Deleting job ###job.getId()#" );

				variables.interceptorService.announce(
					"onCBQJobFailed",
					{
						"job": job,
						"exception": e
					}
				);

				afterJobFailed( job );

				variables.log.debug( "Deleted job ###job.getId()# after maximum failed attempts." );
			}
		}
	}

	private string function getMaxAttemptsForJob( required AbstractJob job ) {
		if ( !isNull( arguments.job.getMaxAttempts() ) ) {
			return arguments.job.getMaxAttempts();
		}

		if ( !isNull( variables.pool ) ) {
			return variables.pool.getMaxAttempts();
		}

		return 1;
	}

}
