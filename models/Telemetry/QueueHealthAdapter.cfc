/** Provider-owned queue snapshots. Uses sample(context) without requiring Sentry. */
component {

	property name="config" inject="Config@cbq";

	struct function sample( required struct context ) {
		if ( !arguments.context.keyExists( "options" ) || !isStruct( arguments.context.options ) ) {
			throw(
				type = "cbq.Telemetry.InvalidQueueHealthSelection",
				message = "Configure exactly one of options.workerPool or options.connection."
			);
		}
		var options = arguments.context.options;
		var hasWorkerPool = options.keyExists( "workerPool" );
		var hasConnection = options.keyExists( "connection" );
		if ( options.keyExists( "pool" ) || hasWorkerPool == hasConnection ) {
			throw(
				type = "cbq.Telemetry.InvalidQueueHealthSelection",
				message = "Configure exactly one of options.workerPool or options.connection; options.pool is not supported."
			);
		}
		var source = hasWorkerPool ? options.workerPool : options.connection;
		if ( isNull( source ) || !isSimpleValue( source ) || !len( trim( source ) ) ) {
			throw(
				type = "cbq.Telemetry.InvalidQueueHealthSelection",
				message = "The workerPool or connection selector must be a nonempty name."
			);
		}
		var snapshot = {};
		var connection = {};
		if ( hasWorkerPool ) {
			var pool = variables.config.getWorkerPool( source );
			snapshot = samplePool( pool );
			if ( !structKeyExists( pool, "getConnection" ) ) return snapshot;
			connection = pool.getConnection();
		} else {
			connection = variables.config.getConnection( source );
		}
		var provider = connection.getProvider();
		if ( !structKeyExists( provider, "getQueueHealth" ) ) return snapshot;
		var queueSelection = options.keyExists( "queue" ) ? options.queue : (
			hasWorkerPool ? pool.getQueue() : connection.getDefaultQueue()
		);
		var observed = provider.getQueueHealth( queueSelection );
		if ( !isStruct( observed ) ) throw( type = "cbq.Telemetry.InvalidQueueHealthResult" );
		for (
			var field in [
				"depth",
				"oldestAgeSeconds",
				"runnable",
				"delayed",
				"reserved",
				"staleReservations",
				"retries",
				"exhausted"
			]
		) {
			if (
				observed.keyExists( field ) && !isNull( observed[ field ] ) && isNumeric( observed[ field ] ) && observed[
					field
				] >= 0 && observed[ field ] <= 1.7976931348623157E308
			)
				snapshot[ field ] = observed[ field ];
		}
		return snapshot;
	}

	struct function samplePool( required any pool ) {
		var snapshot = { "configuredWorkers" : arguments.pool.getQuantity() };
		try {
			var stats = arguments.pool.getExecutor().getStats();
			// Some executors return a fallback zero when activity cannot be measured.
			if (
				stats.keyExists( "features" ) && stats.features.keyExists( "taskMethods" ) && stats.features.taskMethods &&
				stats.keyExists( "activeCount" )
			) {
				snapshot[ "activeExecutions" ] = stats.activeCount;
			}
		} catch ( any unavailable ) {
			// An unstarted/unsupported executor does not imply zero activity or a worker heartbeat.
		}
		return snapshot;
	}

}
