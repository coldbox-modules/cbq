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

	public PendingBatch function add(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
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

	public PendingBatch function then(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
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

	public PendingBatch function catch(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
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

	public PendingBatch function finally(
		required any job,
		struct properties = {},
		array chain = [],
		string queue,
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
			"thenJob" : getThenJob().getMemento() ?: javacast( "null", "" ),
			"catchJob" : getCatchJob().getMemento() ?: javacast( "null", "" ),
			"finallyJob" : getFinallyJob().getMemento() ?: javacast( "null", "" ),
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
