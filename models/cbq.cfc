component singleton accessors="true" {

	property name="wirebox" inject="wirebox";

	public AbstractJob function dispatch(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
		numeric backoff,
		numeric timeout,
		numeric maxAttempts
	) {
		var newJob = isArray( arguments.job ) ? variables.chain( arguments.job ) : variables.job(
			argumentCollection = arguments
		);
		newJob.dispatch();
		return newJob;
	}

	public AbstractJob function job(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
		string connection,
		numeric backoff,
		numeric timeout,
		numeric maxAttempts
	) {
		// make sure we have a job instance
		if ( isSimpleValue( arguments.job ) ) {
			if ( variables.wirebox.containsInstance( arguments.job ) ) {
				arguments.job = variables.wirebox.getInstance( arguments.job );
			} else {
				var mapping = arguments.job;
				arguments.job = variables.wirebox.getInstance( "NonExecutableJob@cbq" );
				arguments.job.setMapping( mapping );
			}
		}

		return arguments.job.applyMemento( arguments );
	}

	public AbstractJob function chain( required array jobs ) {
		if ( arguments.jobs.isEmpty() ) {
			throw( "At least one job must be passed to chain" );
		}

		var firstJob = arguments.jobs[ 1 ];

		if ( arguments.jobs.len() >= 2 ) {
			firstJob.chain( arguments.jobs.slice( 2 ) );
		}

		return firstJob;
	}

	public PendingBatch function batch( required array jobs ) {
		var batch = variables.wirebox.getInstance( "PendingBatch@cbq" );
		batch.add( jobs );
		return batch;
	}

}
