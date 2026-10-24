/** Read-only worker snapshots. Compatible with Sentry's sample(context) contract; Sentry is not required. */
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
		return samplePool( variables.config.getWorkerPool( arguments.context.options.pool ) );
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
