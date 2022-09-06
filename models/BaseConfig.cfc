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

	public QueueConnectionDefinition function newConnection( required string name ) {
		var connectionDefinition = newQueueConnectionDefinitionInstance();
		connectionDefinition.setName( arguments.name );
		variables.connectionDefinitions[ arguments.name ] = connectionDefinition;
		return connectionDefinition;
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
		required string connectionName,
		numeric quantity = 1,
		string queue = "default"
	) {
		var workerPoolDefinition = newWorkerPoolDefinitionInstance();
		workerPoolDefinition.setConnectionName( arguments.connectionName );
		workerPoolDefinition.setQuantity( arguments.quantity );
		workerPoolDefinition.setQueue( arguments.queue );
		variables.workerPoolDefinitions[ arguments.connectionName ] = workerPoolDefinition;
		return workerPoolDefinition;
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
			connectionName = arguments.definition.getConnectionName(),
			quantity = arguments.definition.getQuantity(),
			queue = arguments.definition.getQueue(),
			backoff = arguments.definition.getBackoff(),
			timeout = arguments.definition.getTimeout(),
			maxAttempts = arguments.definition.getMaxAttempts()
		);
	}

	public WorkerPool function registerWorkerPool(
		required string connectionName,
		numeric quantity = 1,
		string queue = "default",
		numeric backoff = 0,
		numeric timeout = 60,
		numeric maxAttempts = 1
	) {
		var connection = getConnection( arguments.connectionName );

		var instance = newWorkerPoolInstance();
		instance.setConnectionName( arguments.connectionName );
		instance.setConnection( connection );

		instance.setQuantity( arguments.quantity );
		instance.setQueue( arguments.queue );
		instance.setBackoff( arguments.backoff );
		instance.setTimeout( arguments.timeout );
		instance.setMaxAttempts( arguments.maxAttempts );

		if ( structKeyExists( variables.workerPools, arguments.connectionName ) ) {
			variables.workerPools[ arguments.connectionName ].shutdown();
		}

		variables.workerPools[ arguments.connectionName ] = instance;
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
