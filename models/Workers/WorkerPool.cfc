component accessors="true" {

	property name="async" inject="coldbox:asyncManager";

	property name="id" type="string";
	property name="name" type="string";
	property name="quantity" default="1";
	property
		name="queue"
		type="any"
		default="default";
	property name="backoff" default="0";
	property name="timeout" default="60";
	property name="maxAttempts" default="1";

	property name="connectionName";
	property name="connection";

	property name="workerHooks";
	property name="executor";
	property name="currentExecutorCount";


	public WorkerPool function init() {
		variables.id = createUUID();
		variables.workerHooks = [];
		variables.currentExecutorCount = 0;
		return this;
	}

	public string function getUniqueId() {
		return variables.name & "/" & variables.id;
	}

	public WorkerPool function setQueue( required any queue ) {
		if ( !isSimpleValue( arguments.queue ) && !getConnection().getProvider().supportsMultipleQueues() ) {
			throw(
				type = "cbq.WorkerPool.MultipleQueuesNotSupported",
				message = "This connection does not support multiple queues.",
				extendedinfo = serializeJSON( {
					"queue" : arguments.queue,
					"connection" : getConnection().getMemento()
				} )
			);
		}

		variables.queue = arguments.queue;
		return this;
	}

	public WorkerPool function scale( required numeric amount ) {
		var currentQuantity = getQuantity();
		var difference = arguments.amount - currentQuantity;
		if ( difference > 0 ) {
			for ( var i = currentQuantity; i < arguments.amount; i++ ) {
				var stopWorkerFn = getConnection().getProvider().startWorker( this );
				variables.workerHooks.append( stopWorkerFn );
			}
		} else if ( difference < 0 ) {
			for ( var i = currentQuantity; i > arguments.amount; i-- ) {
				var stopWorkerFn = variables.workerHooks[ i ];
				stopWorkerFn();
				arrayDeleteAt( variables.workerHooks, i );
			}
		}
		setQuantity( arguments.amount );
		return this;
	}

	public WorkerPool function startWorkers() {
		variables.executor = variables.async.newExecutor(
			"cbq:WorkerPool:#getConnectionName()#:#getName()#",
			"fixed",
			1
		);

		for ( var i = 1; i <= getQuantity(); i++ ) {
			var stopWorkerFn = getConnection().getProvider().startWorker( this );
			variables.workerHooks.append( stopWorkerFn );
		}
		getConnection().getProvider().listen( this );
		return this;
	}

	public WorkerPool function incrementCurrentExecutorCount() {
		variables.currentExecutorCount++;
		return this
	}

	public WorkerPool function decrementCurrentExecutorCount() {
		variables.currentExecutorCount--;
		return this
	}

	public WorkerPool function shutdown() {
		for ( var i = variables.workerHooks.len(); i >= 1; i-- ) {
			var stopWorkerFn = variables.workerHooks[ i ];
			stopWorkerFn();
			arrayDeleteAt( variables.workerHooks, i );
		}
		setQuantity( 0 );
		return this;
	}

	public struct function getMemento() {
		return {
			"id" : variables.id,
			"name" : variables.name,
			"uniqueId" : getUniqueId(),
			"quantity" : variables.quantity,
			"queue" : variables.queue,
			"backoff" : variables.backoff,
			"timeout" : variables.timeout,
			"maxAttempts" : variables.maxAttempts,
			"connectionName" : variables.connectionName,
			"currentExecutorCount" : variables.currentExecutorCount
		};
	}

}
