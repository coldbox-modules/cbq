/** Diagnostics must never replace the queue outcome they are reporting. */
component {

	public void function report(
		required string stage,
		required any exception,
		any logger
	) {
		try {
			arguments.logger.warn( "cbq diagnostic failure at [#arguments.stage#]", arguments.exception );
		} catch ( any loggingFailure ) {
			// Do not include job payloads or exception messages in the fallback.
			createObject( "java", "java.lang.System" ).err.println(
				"cbq: [#arguments.stage#] failed; LogBox reporting also failed [#loggingFailure.type#]."
			);
		} finally {
			// Even an unavailable stderr must not alter persistence, retries or cleanup.
			return;
		}
	}

}
