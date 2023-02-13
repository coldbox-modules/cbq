component accessors="true" {

	property name="config" inject="provider:Config@cbq";

	property name="name" type="string";
	property name="connectionName";
	property name="quantity" default="1";
	property name="queues" type="array";
	property name="backoff" default="0";
	property name="timeout" default="60";
	property name="maxAttempts" default="1";

	public WorkerPoolDefinition function init() {
		variables.queues = [ "*" ];
		return this;
	}

	public WorkerPoolDefinition function forConnection( required string name ) {
		setConnectionName( arguments.name );
		return this;
	}

	public WorkerPoolDefinition function quantity( required numeric count ) {
		setQuantity( arguments.count );
		return this;
	}

	public WorkerPoolDefinition function onQueues( required any queues ) {
		if ( !isArray( arguments.queues ) ) {
			arguments.queues = arraySlice( arguments.queues.split( ",\s*" ), 1 );
		}
		setQueues( arguments.queues );
		return this;
	}

	public WorkerPoolDefinition function backoff( required numeric amount ) {
		setBackoff( arguments.amount );
		return this;
	}

	public WorkerPoolDefinition function timeout( required numeric amount ) {
		setTimeout( arguments.amount );
		return this;
	}

	public WorkerPoolDefinition function maxAttempts( required numeric amount ) {
		setMaxAttempts( arguments.amount );
		return this;
	}

	public WorkerPool function register() {
		return variables.config.registerWorkerPoolFromDefinition( this );
	}

}
