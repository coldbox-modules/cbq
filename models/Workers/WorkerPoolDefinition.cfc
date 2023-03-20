component accessors="true" {

	/**
	 * A reference to the current cbq config.
	 */
	property name="config" inject="provider:Config@cbq";

	/**
	 * The unique name for the Worker Pool.
	 */
	property name="name" type="string";

	/**
	 * The associated connection name for the Worker Pool.
	 * This must match an existing configured Connection.
	 */
	property name="connectionName";

	/**
	 * The number of workers for this Worker Pool.
	 */
	property name="quantity" default="1";

	/**
	 * An array of queues this Worker Pool will work, in order.
	 * An asterisk (`*`) signifies all queues.
	 */
	property name="queues" type="array";

	/**
	 * The time to wait between retrying jobs, in seconds.
	 */
	property name="backoff" inject="coldbox:moduleSettings:cbq:defaultWorkerBackoff";

	/**
	 * The maximum amount of time a job can run before a TimeoutException is thrown, in seconds.
	 */
	property name="timeout" inject="coldbox:moduleSettings:cbq:defaultWorkerTimeout";

	/**
	 * The maximum number of attempts made before a job is marked as failed.
	 */
	property name="maxAttempts" inject="coldbox:moduleSettings:cbq:defaultWorkerMaxAttempts";

	/**
	 * Creates a new WorkerPoolDefinition.
	 *
	 * @returns A new WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function init() {
		variables.queues = [ "*" ];
		return this;
	}

	/**
	 * Sets the associated connection name for this Worker Pool.
	 *
	 * @name The associated connection name.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function forConnection( required string name ) {
		setConnectionName( arguments.name );
		return this;
	}

	/**
	 * Sets the quantity of workers for this Worker Pool.
	 *
	 * @count The number of workers for this Worker Pool.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function quantity( required numeric count ) {
		setQuantity( arguments.count );
		return this;
	}

	/**
	 * An array or list of queues to work, in order.
	 * The asterisk (`*`) is a special symbol for all queues.
	 *
	 * @queues An array or list of queues to work, in order.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function onQueues( required any queues ) {
		if ( !isArray( arguments.queues ) ) {
			arguments.queues = arraySlice( arguments.queues.split( ",\s*" ), 1 );
		}
		setQueues( arguments.queues );
		return this;
	}

	/**
	 * Sets the backoff time amount, in seconds.
	 *
	 * @count The backoff time amount, in seconds.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function backoff( required numeric amount ) {
		setBackoff( arguments.amount );
		return this;
	}

	/**
	 * Sets the timeout time amount, in seconds.
	 *
	 * @count The timeout time amount, in seconds.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function timeout( required numeric amount ) {
		setTimeout( arguments.amount );
		return this;
	}

	/**
	 * Sets the max number of attempts.
	 *
	 * @count The max number of attempts.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function maxAttempts( required numeric amount ) {
		setMaxAttempts( arguments.amount );
		return this;
	}

	/**
	 * Registers this WorkerPoolDefinition as a WorkerPool instance.
	 *
	 * @returns A WorkerPool instance created from this definition.
	 */
	public WorkerPool function register() {
		return variables.config.registerWorkerPoolFromDefinition( this );
	}

}
