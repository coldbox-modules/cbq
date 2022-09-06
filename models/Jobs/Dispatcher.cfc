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
				"job": arguments.job,
				"connection": connection
			}
		);

		connection.push(
			queueName = queueName,
			payload = serializeJSON( arguments.job.getMemento() ),
			delay = delay,
			attempts = 1
		);

		return this;
	}

}
