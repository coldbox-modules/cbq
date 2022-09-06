component accessors="true" {

	property name="quantity" default="1";
	property name="queue" default="default";
	property name="backoff" default="0";
	property name="timeout" default="60";
	property name="maxAttempts" default="1";

	property name="connectionName";
	property name="connection";

	property name="workerHooks";

	public WorkerPool function init() {
		variables.workerHooks = [];
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
		for ( var i = 1; i <= getQuantity(); i++ ) {
			var stopWorkerFn = getConnection().getProvider().startWorker( this );
			variables.workerHooks.append( stopWorkerFn );
		}
		return this;
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
