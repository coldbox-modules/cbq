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

		arguments.job.setCurrentAttempt( 0 );
		connection.push(
			queueName = queueName,
			job = arguments.job,
			delay = delay,
			attempts = 0
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

		for ( var job in arguments.jobs ) {
			variables.interceptorService.announce(
				"onCBQJobAdded",
				{
					"job" : job,
					"connection" : connection
				}
			);

			job.setCurrentAttempt( 0 );
			connection.push(
				queueName = arguments.queueName ?: job.getQueue() ?: connection.getDefaultQueue(),
				job = job,
				attempts = 0
			);
		}

		return this;
	}

}
