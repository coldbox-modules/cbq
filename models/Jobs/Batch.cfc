component accessors="true" {

	property name="dispatcher" inject="provider:Dispatcher@cbq";
	property name="wirebox" inject="wirebox";
	property name="repository";

	property name="id" type="string";
	property name="name" type="string";
	property name="totalJobs" type="numeric";
	property name="pendingJobs" type="numeric";
	property name="failedJobs" type="numeric";
	property name="failedJobIds" type="array";
	property name="options" type="struct";
	property name="createdDate" type="numeric";
	property name="cancelledDate" type="numeric";
	property name="completedDate" type="numeric";

	/**
	 * Add additional jobs to the batch.
	 */
	public Batch function add( required array jobs ) {
		var count = 0;
		for ( var job in arguments.jobs ) {
			job.withBatchId( variables.id );
			count++;
		}

		transaction {
			getRepository().incrementTotalJobs( variables.id, count );
			getDispatcher().bulkDispatch(
				connectionName = getConnectionName(),
				queueName = getQueueName(),
				jobs = jobs
			);
		}

		return getRepository().find( variables.id );
	}

	public void function recordSuccessfulJob( required string jobId ) {
		var counts = getRepository().decrementPendingJobs( variables.id, arguments.jobId );

		if ( counts.pendingJobs != 0 ) {
			return;
		}

		getRepository().markAsFinished( variables.id );
		dispatchThenJobIfNeeded();

		if ( counts.allJobsHaveRanExactlyOnce ) {
			dispatchFinallyJobIfNeeded();
		}
	}

	public void function recordFailedJob( required string jobId, required any error ) {
		var counts = getRepository().incrementFailedJobs( variables.id, arguments.jobId );

		if ( counts.failedJobs == 1 ) {
			if ( !allowsFailures() ) {
				cancel();
			}

			dispatchCatchJobIfNeeded( arguments.error );
		}

		if ( counts.allJobsHaveRanExactlyOnce ) {
			dispatchFinallyJobIfNeeded();
		}
	}

	public void function cancel() {
		getRepository().cancel( variables.id );
	}

	private void function dispatchThenJobIfNeeded() {
		if ( !hasThenJob() ) {
			return;
		}

		var thenJobConfig = variables.options.thenJob;
		var thenJob = variables.wirebox.getInstance( thenJobConfig.mapping );
		param thenJobConfig.properties = {};

		thenJob.setBackoff( isNull( thenJobConfig.backoff ) ? javacast( "null", "" ) : thenJobConfig.backoff );
		thenJob.setTimeout( isNull( thenJobConfig.timeout ) ? javacast( "null", "" ) : thenJobConfig.timeout );
		thenJob.setProperties( thenJobConfig.properties );
		thenJob.setMaxAttempts(
			isNull( thenJobConfig.maxAttempts ) ? javacast( "null", "" ) : thenJobConfig.maxAttempts
		);
		thenJob.setChained( isNull( thenJobConfig.chained ) ? javacast( "null", "" ) : thenJobConfig.chained );
		thenJob.withBatchId( variables.id );
		thenJob.setIsLifecycleJob( true );

		thenJob.dispatch();
	}

	private boolean function hasThenJob() {
		if ( !variables.options.keyExists( "thenJob" ) ) {
			return false;
		}

		if ( isNull( variables.options.thenJob ) ) {
			return false;
		}

		if ( isSimpleValue( variables.options.thenJob ) ) {
			return false;
		}

		return true;
	}

	private void function dispatchCatchJobIfNeeded( required any error ) {
		if ( !hasCatchJob() ) {
			return;
		}

		var catchJobConfig = variables.options.catchJob;
		var catchJob = variables.wirebox.getInstance( catchJobConfig.mapping );
		param catchJobConfig.properties = {};

		catchJob.setBackoff( isNull( catchJobConfig.backoff ) ? javacast( "null", "" ) : catchJobConfig.backoff );
		catchJob.setTimeout( isNull( catchJobConfig.timeout ) ? javacast( "null", "" ) : catchJobConfig.timeout );
		catchJob.setProperties( catchJobConfig.properties );
		catchJob.setMaxAttempts(
			isNull( catchJobConfig.maxAttempts ) ? javacast( "null", "" ) : catchJobConfig.maxAttempts
		);
		catchJob.setChained( isNull( catchJobConfig.chained ) ? javacast( "null", "" ) : catchJobConfig.chained );
		catchJob.withBatchId( variables.id );
		catchJob.setIsLifecycleJob( true );
		catchJob.setError( arguments.error );

		catchJob.dispatch();
	}

	private boolean function hasCatchJob() {
		if ( !variables.options.keyExists( "catchJob" ) ) {
			return false;
		}

		if ( isNull( variables.options.catchJob ) ) {
			return false;
		}

		if ( isSimpleValue( variables.options.catchJob ) ) {
			return false;
		}

		return true;
	}

	private void function dispatchFinallyJobIfNeeded() {
		if ( !hasFinallyJob() ) {
			return;
		}

		var finallyJobConfig = variables.options.finallyJob;
		var finallyJob = variables.wirebox.getInstance( finallyJobConfig.mapping );
		param finallyJobConfig.properties = {};

		finallyJob.setBackoff( isNull( finallyJobConfig.backoff ) ? javacast( "null", "" ) : finallyJobConfig.backoff );
		finallyJob.setTimeout( isNull( finallyJobConfig.timeout ) ? javacast( "null", "" ) : finallyJobConfig.timeout );
		finallyJob.setProperties( finallyJobConfig.properties );
		finallyJob.setMaxAttempts(
			isNull( finallyJobConfig.maxAttempts ) ? javacast( "null", "" ) : finallyJobConfig.maxAttempts
		);
		finallyJob.setChained( isNull( finallyJobConfig.chained ) ? javacast( "null", "" ) : finallyJobConfig.chained );
		finallyJob.withBatchId( variables.id );
		finallyJob.setIsLifecycleJob( true );

		finallyJob.dispatch();
	}

	private boolean function hasFinallyJob() {
		if ( !variables.options.keyExists( "finallyJob" ) ) {
			return false;
		}

		if ( isNull( variables.options.finallyJob ) ) {
			return false;
		}

		if ( isSimpleValue( variables.options.finallyJob ) ) {
			return false;
		}

		return true;
	}

	private any function getConnectionName() {
		if ( !variables.options.keyExists( "connection" ) ) {
			return javacast( "null", "" );
		}

		if ( isNull( variables.options.connection ) ) {
			return javacast( "null", "" );
		}

		if ( variables.options.connection == "" ) {
			return javacast( "null", "" );
		}

		return variables.options.connection;
	}

	private any function getQueueName() {
		if ( !variables.options.keyExists( "queue" ) ) {
			return javacast( "null", "" );
		}

		if ( isNull( variables.options.queue ) ) {
			return javacast( "null", "" );
		}

		if ( variables.options.queue == "" ) {
			return javacast( "null", "" );
		}

		return variables.options.queue;
	}

	public boolean function allowsFailures() {
		if ( !variables.options.keyExists( "allowFailures" ) ) {
			return false;
		}

		if ( isNull( variables.options.allowFailures ) ) {
			return false;
		}

		if ( variables.options.allowFailures == "" ) {
			return false;
		}

		return variables.options.allowFailures;
	}

}
