component accessors="true" {

	property name="async" inject="coldbox:asyncManager";

	property name="name" type="string";
	property name="quantity" default="1";
	property name="queues" type="array";
	property name="backoff" default="0";
	property name="timeout" default="60";
	property name="maxAttempts" default="1";

	property
		name="_shouldWorkAllQueues"
		type="boolean"
		default="true"
		accessors="false";
	property name="connectionName";
	property name="connection";

	property name="workerHooks";
	property name="executor";
	property name="currentExecutorCount";


	public WorkerPool function init() {
		variables.workerHooks = [];
		variables.queues = [ "*" ];
		variables.currentExecutorCount = 0;
		return this;
	}

	public WorkerPool function setQueues( required array queues ) {
		variables.queues = arguments.queues;
		variables._shouldWorkAllQueues = variables.queues.filter( ( queue ) => queue == "*" ).len() > 0;
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

	public boolean function shouldWorkAllQueues() {
		return variables._shouldWorkAllQueues;
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

}
