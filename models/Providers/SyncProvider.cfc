component accessors="true" extends="AbstractQueueProvider" {

	public any function push(
		required string queueName,
		required string payload,
		numeric delay = 0,
		numeric attempts = 0
	) {
		if ( isNull( variables.pool ) ) {
			if ( variables.log.canWarn() ) {
				variables.log.warn( "No worker pools have been defined so this job will not be executed." );
			}
			return;
		}

		var firstJob = deserializeJob(
			arguments.payload,
			createUUID(),
			arguments.attempts
		);

		var chain = firstJob.getChained();
		var firstJobPayload = firstJob.getMemento();
		firstJobPayload.chained = [];
		arrayPrepend( chain, firstJobPayload );
		chain = chain.map( ( payload, i, arr ) => {
			payload.chained = arr.len() >= i + 1 ? arr.slice( i + 1 ) : [];
			payload.chained = payload.chained.map( ( p ) => {
				p.chained = [];
				return p;
			} );
			return deserializeJob(
				serializeJSON( payload ),
				createUUID(),
				1
			);
		} );

		for ( var job in chain ) {
			marshalJob( job, variables.pool );
		}
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

	public void function marshalJob( required AbstractJob job, required WorkerPool pool ) {
		try {
			if ( variables.log.canDebug() ) {
				// variables.log.debug( "Marshaling job ###arguments.job.getId()#", arguments.job.getMemento() );
			}

			beforeJobRun( arguments.job );
			if ( structKeyExists( job, "before" ) ) {
				job.before();
			}

			variables.interceptorService.announce( "onCBQJobMarshalled", { "job" : arguments.job } );

			if ( variables.log.canDebug() ) {
				variables.log.debug( "Running job ###arguments.job.getId()#", arguments.job.getMemento() );
			}

			var result = arguments.job.handle();

			if ( job.getIsReleased() ) {
				variables.log.debug( "Job [#job.getId()#] requested manual release." );

				var jobMaxAttempts = getMaxAttemptsForJob( job, arguments.pool );
				if ( jobMaxAttempts != 0 && job.getCurrentAttempt() >= getMaxAttemptsForJob( job, pool ) ) {
					throw(
						type = "cbq.MaxAttemptsReached",
						message = "Job [#job.getId()#] requested manual release, but has reached its maximum attempts [#job.getCurrentAttempt()#]."
					);
				}

				if ( jobMaxAttempts == 0 ) {
					variables.log.debug( "Job ###job.getId()# has a maxAttempts of 0 and will always be released." );
				}

				variables.log.debug( "Releasing job ###job.getId()#" );
				releaseJob( job, pool );
				variables.log.debug( "Released job ###job.getId()#" );
				return;
			}

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

			if ( structKeyExists( job, "after" ) ) {
				job.after();
			}
			afterJobRun( job, pool );

			ensureSuccessfulBatchJobIsRecorded( job, pool );
		} catch ( any e ) {
			// log failed job
			if ( log.canError() ) {
				log.error( "Exception when running job: #e.message#" );
			}

			variables.interceptorService.announce( "onCBQJobException", { "job" : job, "exception" : e } );

			var jobMaxAttempts = getMaxAttemptsForJob( job, arguments.pool );
			if ( jobMaxAttempts == 0 || job.getCurrentAttempt() < jobMaxAttempts ) {
				if ( jobMaxAttempts == 0 ) {
					variables.log.debug( "Job ###job.getId()# has a maxAttempts of 0 and will always be released." );
				}
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

				rethrow;
			}
		}
	}

}
