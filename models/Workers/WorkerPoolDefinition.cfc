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
	 * The queue name this Worker Pool will work
	 * The default queue name is `default`.
	 */
	property
		name="queue"
		type="any"
		default="default";

	/**
	 * The time to wait between retrying jobs, in seconds.
	 */
	property name="backoff" inject="coldbox:moduleSettings:cbq:defaultWorkerBackoff";

	/**
	 * The maximum amount of time a job can run before a TimeoutException is thrown, in seconds.
	 */
	property name="timeout" inject="coldbox:moduleSettings:cbq:defaultWorkerTimeout";

	/**
	 * The maximum amount of time to wait for jobs to complete when requesting a shutdown, like for a ColdBox reinit, in seconds.
	 */
	property name="shutdownTimeout" inject="coldbox:moduleSettings:cbq:defaultWorkerShutdownTimeout";

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
	 * The name of a queue to work.
	 *
	 * @queue The name of a queue to work.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function onQueue( required any queue ) {
		setQueue( arguments.queue );
		return this;
	}

	/**
	 * Sets the backoff time amount, in seconds.
	 *
	 * @amount The backoff time amount, in seconds.
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
	 * @amount The timeout time amount, in seconds.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function timeout( required numeric amount ) {
		setTimeout( arguments.amount );
		return this;
	}

	/**
	 * Sets the shutdown timeout time amount, in seconds.
	 *
	 * @amount The shutdown timeout time amount, in seconds.
	 *
	 * @returns The current WorkerPoolDefinition.
	 */
	public WorkerPoolDefinition function shutdownTimeout( required numeric amount ) {
		setShutdownTimeout( arguments.amount );
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
