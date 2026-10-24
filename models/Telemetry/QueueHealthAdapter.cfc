/** Provider-owned queue snapshots. Uses sample(context) without requiring Sentry. */
component {

	property name="config" inject="Config@cbq";

	struct function sample( required struct context ) {
		if (
			!arguments.context.keyExists( "options" ) || !isStruct( arguments.context.options ) ||
			!arguments.context.options.keyExists( "pool" ) || isNull( arguments.context.options.pool ) || !isSimpleValue(
				arguments.context.options.pool
			) ||
			!len( trim( arguments.context.options.pool ) )
		) {
			throw(
				type = "cbq.Telemetry.MissingWorkerPool",
				message = "Configure options.pool explicitly for the worker health adapter."
			);
		}
		var pool = variables.config.getWorkerPool( arguments.context.options.pool );
		var snapshot = samplePool( pool );
		if ( !structKeyExists( pool, "getConnection" ) ) return snapshot;
		var provider = pool.getConnection().getProvider();
		if ( !structKeyExists( provider, "getQueueHealth" ) ) return snapshot;
		var queueSelection = arguments.context.options.keyExists( "queue" ) ? arguments.context.options.queue : pool.getQueue();
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
