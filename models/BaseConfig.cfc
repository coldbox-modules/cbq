component singleton accessors="true" {

	property name="wirebox" inject="wirebox";

	property name="connectionDefinitions";
	property name="connections";

	property name="workerPoolDefinitions";
	property name="workerPools";

	property name="defaultConnectionName";

	public any function init() {
		reset();
		return this;
	}

	public any function reset() {
		// TODO: shutdown existing workers?
		variables.connectionDefinitions = {};
		variables.connections = {};
		variables.workerPoolDefinitions = {};
		variables.workerPools = {};
		variables.defaultConnectionName = "default";
		return this;
	}

	public QueueConnection function getConnection( required string name ) {
		if ( !structKeyExists( variables.connections, arguments.name ) ) {
			throw(
				type = "cbq.MissingQueueConnection",
				message = "The [#arguments.name#] connection has not yet been registered."
			);
		}

		return variables.connections[ arguments.name ];
	}

	/**
	 * Creates a new QueueConnectionDefinition component to configure a new Queue Connection.
	 *
	 * @name The unique name for the new Queue Connection.
	 */
	public QueueConnectionDefinition function newConnection( required string name ) {
		var connectionDefinition = newQueueConnectionDefinitionInstance();
		connectionDefinition.setName( arguments.name );
		variables.connectionDefinitions[ arguments.name ] = connectionDefinition;
		return connectionDefinition;
	}

	public QueueConnectionDefinition function withConnection( required string name ) {
		if ( !variables.connectionDefinitions.keyExists( arguments.name ) ) {
			throw(
				type = "cbq.MissingQueueConnection",
				message = "No queue connection definition found for [#arguments.name#]. Did you mean to create a `newConnection`?"
			);
		}

		return variables.connectionDefinitions[ arguments.name ];
	}

	public any function registerConnections() {
		for ( var name in variables.connectionDefinitions ) {
			if ( structKeyExists( variables.connections, name ) ) {
				continue;
			}

			registerConnectionFromDefinition( variables.connectionDefinitions[ name ] );
		}
		return this;
	}

	public QueueConnection function registerConnectionFromDefinition( required QueueConnectionDefinition definition ) {
		var connection = registerConnection(
			name = arguments.definition.getName(),
			provider = arguments.definition.getProvider(),
			properties = arguments.definition.getProperties(),
			defaultQueue = arguments.definition.getDefaultQueue()
		);
		if ( arguments.definition.getMakeDefault() ) {
			variables.defaultConnectionName = arguments.definition.getName();
		}
		return connection;
	}

	public QueueConnection function registerConnection(
		required string name,
		required any provider,
		struct properties = {},
		string defaultQueue = "default"
	) {
		if ( isSimpleValue( arguments.provider ) ) {
			var providerInstance = variables.wirebox.getInstance( arguments.provider );
			providerInstance.setName( arguments.provider );
			providerInstance.setProperties( arguments.properties );
			arguments.provider = providerInstance;
		}

		var newConnection = newQueueConnectionInstance();
		newConnection.setName( arguments.name );
		newConnection.setProvider( arguments.provider );
		newConnection.setDefaultQueue( arguments.defaultQueue );

		variables.connections[ arguments.name ] = newConnection;

		return newConnection;
	}

	public QueueConnectionDefinition function newQueueConnectionDefinitionInstance()
		provider="QueueConnectionDefinition@cbq"
	{
	}

	public QueueConnection function newQueueConnectionInstance() provider="QueueConnection@cbq" {
	}

	public WorkerPool function getWorkerPool( required string connectionName ) {
		if ( !structKeyExists( variables.workerPools, arguments.connectionName ) ) {
			throw(
				type = "cbq.MissingWorkerPool",
				message = "The worker pool for the [#arguments.connectionName#] connection has not yet been registered."
			);
		}

		return variables.workerPools[ arguments.connectionName ];
	}

	public WorkerPoolDefinition function newWorkerPool(
		required string name,
		string connectionName,
		numeric quantity = 1,
		array queues = [ "*" ],
		boolean force = false
	) {
		var workerPoolDefinition = newWorkerPoolDefinitionInstance();
		workerPoolDefinition.setName( arguments.name );
		if ( !isNull( arguments.connectionName ) ) {
			workerPoolDefinition.setConnectionName( arguments.connectionName );
		}
		workerPoolDefinition.setQuantity( arguments.quantity );
		workerPoolDefinition.setQueues( arguments.queues );
		if ( variables.workerPoolDefinitions.keyExists( workerPoolDefinition.getName() ) && !arguments.force ) {
			throw( "Duplicate Worker Pool name: [#workerPoolDefinition.getName()#]. Either use a different name or pass the `force` parameter to overwrite the existing Worker Pool." );
		}
		variables.workerPoolDefinitions[ workerPoolDefinition.getName() ] = workerPoolDefinition;
		return workerPoolDefinition;
	}

	public WorkerPoolDefinition function withWorkerPool( required string name ) {
		if ( !variables.workerPoolDefinitions.keyExists( arguments.name ) ) {
			throw(
				type = "cbq.MissingWorkerPool",
				message = "No worker pool definition found for [#arguments.name#]. Did you mean to create a `newWorkerPool`?"
			);
		}

		return variables.workerPoolDefinitions[ arguments.name ];
	}

	public any function registerWorkerPools() {
		for ( var name in variables.workerPoolDefinitions ) {
			if ( structKeyExists( variables.workerPools, name ) ) {
				continue;
			}

			registerWorkerPoolFromDefinition( variables.workerPoolDefinitions[ name ] );
		}
		return this;
	}

	public WorkerPool function registerWorkerPoolFromDefinition( required WorkerPoolDefinition definition ) {
		return registerWorkerPool(
			name = arguments.definition.getName(),
			connectionName = arguments.definition.getConnectionName(),
			quantity = arguments.definition.getQuantity(),
			queues = arguments.definition.getQueues(),
			backoff = arguments.definition.getBackoff(),
			timeout = arguments.definition.getTimeout(),
			maxAttempts = arguments.definition.getMaxAttempts()
		);
	}

	public WorkerPool function registerWorkerPool(
		required string name,
		required string connectionName,
		numeric quantity = 1,
		array queues = [ "*" ],
		numeric backoff = 0,
		numeric timeout = 60,
		numeric maxAttempts = 1
	) {
		var instance = newWorkerPoolInstance();
		instance.setName( arguments.name );
		instance.setConnectionName( arguments.connectionName );
		instance.setConnection( getConnection( arguments.connectionName ) );
		instance.setQuantity( arguments.quantity );
		instance.setQueues( arguments.queues );
		instance.setBackoff( arguments.backoff );
		instance.setTimeout( arguments.timeout );
		instance.setMaxAttempts( arguments.maxAttempts );

		if ( structKeyExists( variables.workerPools, arguments.name ) ) {
			variables.workerPools[ arguments.name ].shutdown();
		}

		variables.workerPools[ arguments.name ] = instance;
		instance.startWorkers();
		return instance;
	}

	public WorkerPoolDefinition function newWorkerPoolDefinitionInstance() provider="WorkerPoolDefinition@cbq" {
	}

	public WorkerPool function newWorkerPoolInstance() provider="WorkerPool@cbq" {
	}

	public numeric function getScaleInterval() {
		return 60;
	}

}
