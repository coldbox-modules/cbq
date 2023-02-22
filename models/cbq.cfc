component singleton accessors="true" {

	property name="wirebox" inject="wirebox";

	/**
	 * Dispatches a job or chain of jobs.
	 *
	 * @job         A Job instance or a WireBox ID of a Job instance.
	 *              If the WireBox ID doesn't exist, a `NonExecutableJob` instance will be used instead.
	 *              This allows you to dispatch a Job from a server where that Job component is not defined.
	 *              If an array is passed, a Job Chain is created and dispatched.
	 * @properties  A struct of properties for the Job instance.
	 * @chain       An array of Jobs to chain after this Job.
	 * @queue       The queue the Job belongs to.
	 * @connection  The Connection to dispatch the Job on.
	 * @backoff     The amount of time, in seconds, to wait between attempting Jobs.
	 * @timeout     The amount of time, in seconds, to wait before treating a Job as erroring.
	 * @maxAttempts The maximum amount of attempts of a Job before treating the Job as failed.
	 *
	 * @return      The dispatched Job instance.
	 */
	public AbstractJob function dispatch(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
		string connection,
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

	/**
	 * Creates a job or chain of jobs without dispatching it.
	 *
	 * @job         A Job instance or a WireBox ID of a Job instance.
	 *              If the WireBox ID doesn't exist, a `NonExecutableJob` instance will be used instead.
	 *              This allows you to dispatch a Job from a server where that Job component is not defined.
	 *              If an array is passed, a Job Chain is created and dispatched.
	 * @properties  A struct of properties for the Job instance.
	 * @chain       An array of Jobs to chain after this Job.
	 * @queue       The queue the Job belongs to.
	 * @connection  The Connection to dispatch the Job on.
	 * @backoff     The amount of time, in seconds, to wait between attempting Jobs.
	 * @timeout     The amount of time, in seconds, to wait before treating a Job as erroring.
	 * @maxAttempts The maximum amount of attempts of a Job before treating the Job as failed.
	 *
	 * @return      The new Job instance.
	 */
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

	/**
	 * Creates a chain of jobs to be ran.
	 * Alias for calling `firstJob.chain( otherJobs )`.
	 *
	 * @jobs  The array of jobs to run in order in a chain.
	 *
	 * @return  The first job of the chain with the chained jobs configured to be dispatched.
	 */
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

	/**
	 * Creates a PendingBatch from the Jobs provided.
	 *
	 * @jobs    An array of jobs to batch together.
	 *
	 * @return  The PendingBatch to be dispatched.
	 */
	public PendingBatch function batch( required array jobs ) {
		var batch = variables.wirebox.getInstance( "PendingBatch@cbq" );
		batch.add( jobs );
		return batch;
	}

}
