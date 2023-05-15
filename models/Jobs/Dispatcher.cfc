component singleton accessors="true" {

	property name="interceptorService" inject="box:interceptorService";
	property name="config" inject="Config@cbq";

	public Dispatcher function dispatch( required any job ) {
		var connectionName = arguments.job.getConnection();
		param connectionName = variables.config.getDefaultConnectionName();
		var connection = variables.config.getConnection( connectionName );
		var queueName = arguments.job.getQueue();
		param queueName = connection.getDefaultQueue();

		var delay = arguments.job.getBackoff();
		param delay = 0;

		variables.interceptorService.announce(
			"onCBQJobAdded",
			{
				"job" : arguments.job,
				"connection" : connection
			}
		);

		connection.push(
			queueName = queueName,
			payload = serializeJSON( arguments.job.getMemento() ),
			delay = delay,
			attempts = 1 // TODO: shouldn't this be 0?
		);

		return this;
	}

	public Dispatcher function bulkDispatch(
		required array jobs,
		string connectionName,
		string queueName
	) {
		param arguments.connectionName = variables.config.getDefaultConnectionName();
		var connection = variables.config.getConnection( connectionName );

		param queueName = connection.getDefaultQueue();

		for ( var job in arguments.jobs ) {
			variables.interceptorService.announce(
				"onCBQJobAdded",
				{
					"job" : job,
					"connection" : connection
				}
			);

			connection.push(
				queueName = queueName,
				payload = serializeJSON( job.getMemento() ),
				attempts = 1
			);
		}

		return this;
	}

}
