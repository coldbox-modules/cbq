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
		string queueName,
		numeric batchSize = 1
	) {
		if ( !isValid( "integer", arguments.batchSize ) || arguments.batchSize < 1 || arguments.batchSize > 100 ) {
			throw( type = "cbq.InvalidDispatchBatchSize", message = "batchSize must be an integer between 1 and 100." );
		}
		param arguments.connectionName = variables.config.getDefaultConnectionName();
		var connection = variables.config.getConnection( connectionName );

		var pending = [];
		for ( var job in arguments.jobs ) {
			variables.interceptorService.announce(
				"onCBQJobAdded",
				{
					"job" : job,
					"connection" : connection
				}
			);

			job.setCurrentAttempt( 0 );
			var entry = {
				"queueName" : arguments.queueName ?: job.getQueue() ?: connection.getDefaultQueue(),
				"job" : job,
				"attempts" : 0
			};
			if ( arguments.batchSize == 1 ) {
				connection.push( argumentCollection = entry );
			} else {
				pending.append( entry );
				if ( pending.len() == arguments.batchSize ) {
					connection.pushMany( pending );
					pending = [];
				}
			}
		}

		if ( pending.len() ) {
			connection.pushMany( pending );
		}

		return this;
	}

}
