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

		marshalJob(
			deserializeJob(
				arguments.payload,
				createUUID(),
				arguments.attempts
			),
			variables.pool
		);
		return this;
	}

	public function function startWorker( required WorkerPool pool ) {
		variables.pool = arguments.pool;
		return function() {
		};
	}

	public any function listen( required WorkerPool pool ) {
		return this;
	}

	private void function marshalJob( required AbstractJob job, required WorkerPool pool ) {
		try {
			if ( variables.log.canDebug() ) {
				variables.log.debug( "Marshaling job ###job.getId()#", job.getMemento() );
			}

			beforeJobRun( job );

			variables.interceptorService.announce( "onCBQJobMarshalled", { "job" : job } );

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
					"job" : job,
					"result" : isNull( result ) ? javacast( "null", "" ) : result
				}
			);

			afterJobRun( job );

			var chain = job.getChained();
			if ( chain.isEmpty() ) {
				return;
			}

			var nextJobConfig = chain[ 1 ];
			var nextJob = variables.cbq.job( nextJobConfig.mapping );
			nextJob.applyMemento( nextJobConfig );

			if ( chain.len() >= 2 ) {
				nextJob.setChained( chain.slice( 2 ) );
			}

			nextJob.dispatch();
		} catch ( any e ) {
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

			if ( job.getCurrentAttempt() < getMaxAttemptsForJob( job ) ) {
				variables.log.debug( "Releasing job ###job.getId()#" );
				releaseJob( job );
				variables.log.debug( "Released job ###job.getId()#" );
			} else {
				variables.log.debug( "Maximum attempts reached. Deleting job ###job.getId()#" );

				variables.interceptorService.announce( "onCBQJobFailed", { "job" : job, "exception" : e } );

				afterJobFailed( job.getId(), job );

				variables.log.debug( "Deleted job ###job.getId()# after maximum failed attempts." );

				throw( e );
			}
		}
	}

}
