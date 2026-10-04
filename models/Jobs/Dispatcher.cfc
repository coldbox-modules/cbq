component singleton accessors="true" {

	property name="interceptorService" inject="box:interceptorService";
	property name="config" inject="Config@cbq";
	property name="log" inject="logbox:logger:{this}";

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
		try {
			connection.push(
				queueName = queueName,
				job = arguments.job,
				delay = delay,
				attempts = 0
			);
		} catch ( any failure ) {
			announcePublishResult(
				"onCBQJobPublishException",
				arguments.job,
				connection,
				failure
			);
			rethrow;
		}
		announcePublishResult(
			"onCBQJobPublished",
			arguments.job,
			connection
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
				publishMany( connection, [ entry ] );
			} else {
				pending.append( entry );
				if ( pending.len() == arguments.batchSize ) {
					publishMany( connection, pending );
					pending = [];
				}
			}
		}

		if ( pending.len() ) {
			publishMany( connection, pending );
		}

		return this;
	}

	private function publishMany( required any connection, required array entries ) {
		try {
			if ( arguments.entries.len() == 1 ) {
				arguments.connection.push( argumentCollection = arguments.entries[ 1 ] );
			} else {
				arguments.connection.pushMany( arguments.entries );
			}
		} catch ( any failure ) {
			for ( var entry in arguments.entries ) {
				announcePublishResult(
					"onCBQJobPublishException",
					entry.job,
					arguments.connection,
					failure
				);
			}
			rethrow;
		}
		for ( var entry in arguments.entries ) {
			announcePublishResult(
				"onCBQJobPublished",
				entry.job,
				arguments.connection
			);
		}
	}

	private function announcePublishResult(
		required string state,
		required any job,
		required any connection,
		any exception
	) {
		try {
			variables.interceptorService.announce(
				arguments.state,
				{
					"job" : arguments.job,
					"connection" : arguments.connection,
					"exception" : arguments.exception ?: javacast( "null", "" )
				}
			);
		} catch ( any observerFailure ) {
			new cbq.models.Support.FailureDiagnostics().report(
				arguments.state,
				observerFailure,
				variables.log ?: javacast( "null", "" )
			);
		}
	}

}
