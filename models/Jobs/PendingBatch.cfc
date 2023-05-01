component accessors="true" extends="AbstractJob" {

	property name="name" default="";
	property name="jobs" type="array";
	property name="thenJob";
	property name="catchJob";
	property name="finallyJob";
	property name="allowFailures" default="false";

	public PendingBatch function init() {
		variables.jobs = [];
		return this;
	}

	public PendingBatch function allowFailures( boolean allow = true ) {
		variables.allowFailures = arguments.allow;
		return this;
	}

	/**
	 * Adds a single Job or an array of Jobs to a PendingBatch.
	 *
	 * @job         The Job WireBox id, Job instance, or array of Job instances to add to the PendingBatch.
	 * @properties  A struct of properties for the Job instance. (Only used when providing a Job WireBox id.)
	 * @chain       An array of Jobs to chain after this Job. (Only used when providing a Job WireBox id.)
	 * @queue       The queue the Job belongs to. (Only used when providing a Job WireBox id.)
	 * @connection  The Connection to dispatch the Job on. (Only used when providing a Job WireBox id.)
	 * @backoff     The amount of time, in seconds, to wait between attempting Jobs. (Only used when providing a Job WireBox id.)
	 * @timeout     The amount of time, in seconds, to wait before treating a Job as erroring. (Only used when providing a Job WireBox id.)
	 * @maxAttempts The maximum amount of attempts of a Job before treating the Job as failed. (Only used when providing a Job WireBox id.)
	 *
	 * @return      The PendingBatch instance.
	 */
	public PendingBatch function add(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
		string connection,
		numeric backoff,
		numeric timeout,
		numeric maxAttempts
	) {
		if ( !isArray( arguments.job ) ) {
			if ( isSimpleValue( arguments.job ) ) {
				arguments.job = getCBQ().job( argumentCollection = arguments );
			}
			arguments.job = [ arguments.job ];
		}

		variables.jobs.append( arguments.job, true );
		return this;
	}

	/**
	 * Defines a Job to be dispatched when all the jobs in the batch finishes successfully.
	 *
	 * @job         The Job WireBox id or Job instance to execute if all the jobs in the Batch complete successfully.
	 * @properties  A struct of properties for the Job instance. (Only used when providing a Job WireBox id.)
	 * @chain       An array of Jobs to chain after this Job. (Only used when providing a Job WireBox id.)
	 * @queue       The queue the Job belongs to. (Only used when providing a Job WireBox id.)
	 * @connection  The Connection to dispatch the Job on. (Only used when providing a Job WireBox id.)
	 * @backoff     The amount of time, in seconds, to wait between attempting Jobs. (Only used when providing a Job WireBox id.)
	 * @timeout     The amount of time, in seconds, to wait before treating a Job as erroring. (Only used when providing a Job WireBox id.)
	 * @maxAttempts The maximum amount of attempts of a Job before treating the Job as failed. (Only used when providing a Job WireBox id.)
	 *
	 * @return      The PendingBatch instance.
	 */
	public PendingBatch function then(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
		string connection,
		numeric backoff,
		numeric timeout,
		numeric maxAttempts
	) {
		if ( isSimpleValue( arguments.job ) ) {
			arguments.job = getCBQ().job( argumentCollection = arguments );
		}

		variables.thenJob = arguments.job;
		return this;
	}

	/**
	 * Defines a Job to be dispatched the first time a job in the Batch fails.
	 *
	 * @job         The Job WireBox id or Job instance to execute the first time a job in the Batch fails.
	 * @properties  A struct of properties for the Job instance. (Only used when providing a Job WireBox id.)
	 * @chain       An array of Jobs to chain after this Job. (Only used when providing a Job WireBox id.)
	 * @queue       The queue the Job belongs to. (Only used when providing a Job WireBox id.)
	 * @connection  The Connection to dispatch the Job on. (Only used when providing a Job WireBox id.)
	 * @backoff     The amount of time, in seconds, to wait between attempting Jobs. (Only used when providing a Job WireBox id.)
	 * @timeout     The amount of time, in seconds, to wait before treating a Job as erroring. (Only used when providing a Job WireBox id.)
	 * @maxAttempts The maximum amount of attempts of a Job before treating the Job as failed. (Only used when providing a Job WireBox id.)
	 *
	 * @return      The PendingBatch instance.
	 */
	public PendingBatch function catch(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
		string connection,
		numeric backoff,
		numeric timeout,
		numeric maxAttempts
	) {
		if ( isSimpleValue( arguments.job ) ) {
			arguments.job = getCBQ().job( argumentCollection = arguments );
		}

		variables.catchJob = arguments.job;
		return this;
	}

	/**
	 * Defines a Job to be dispatched after all the jobs in the Batch have executed successfully or failed.
	 *
	 * @job         The Job WireBox id or Job instance to execute after all the jobs in the Batch have executed successfully or failed.
	 * @properties  A struct of properties for the Job instance. (Only used when providing a Job WireBox id.)
	 * @chain       An array of Jobs to chain after this Job. (Only used when providing a Job WireBox id.)
	 * @queue       The queue the Job belongs to. (Only used when providing a Job WireBox id.)
	 * @connection  The Connection to dispatch the Job on. (Only used when providing a Job WireBox id.)
	 * @backoff     The amount of time, in seconds, to wait between attempting Jobs. (Only used when providing a Job WireBox id.)
	 * @timeout     The amount of time, in seconds, to wait before treating a Job as erroring. (Only used when providing a Job WireBox id.)
	 * @maxAttempts The maximum amount of attempts of a Job before treating the Job as failed. (Only used when providing a Job WireBox id.)
	 *
	 * @return      The PendingBatch instance.
	 */
	public PendingBatch function finally(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
		string connection,
		numeric backoff,
		numeric timeout,
		numeric maxAttempts
	) {
		if ( isSimpleValue( arguments.job ) ) {
			arguments.job = getCBQ().job( argumentCollection = arguments );
		}

		variables.finallyJob = arguments.job;
		return this;
	}

	/**
	 * Dispatches a PendingBatch and all the Jobs it contains.
	 *
	 * @return A Batch instance created from this PendingBatch.
	 */
	public Batch function dispatch() {
		try {
			var batch = getRepository().store( this );
			batch.add( variables.jobs );
			return batch;
		} catch ( any e ) {
			if ( !isNull( batch ) ) {
				getRepository().delete( batch.getId() );
			}
			rethrow;
		}
	}

	public struct function getOptions() {
		return {
			"thenJob" : getThenJob()?.getMemento() ?: javacast( "null", "" ),
			"catchJob" : getCatchJob()?.getMemento() ?: javacast( "null", "" ),
			"finallyJob" : getFinallyJob()?.getMemento() ?: javacast( "null", "" ),
			"allowFailures" : getAllowFailures(),
			"connection" : getConnection(),
			"queue" : getQueue()
		};
	}

	public cbq function getCBQ() provider="cbq@cbq" {
	}
	public cbq function getRepository() provider="DBBatchRepository@cbq" {
	}

}
