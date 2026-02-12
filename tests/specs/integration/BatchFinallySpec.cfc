component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "batch finally dispatching", function() {
			beforeEach( function() {
				structDelete( application, "jobBeforeCalled" );
				structDelete( application, "jobAfterCalled" );

				param application.jobBeforeCalled = false;
				param application.jobAfterCalled = false;
			} );

			it( "dispatches the finally job when the last job fails", function() {
				var cbq = getWireBox().getInstance( "@cbq" );
				registerSyncConnectionAndWorkerPool();

				var successJob = cbq.job( "SendWelcomeEmailJob" );
				var failingJob = cbq.job( job = "ReleaseTestJob", maxAttempts = 1 );

				var pendingBatch = cbq
					.batch( [ successJob, failingJob ] )
					.onConnection( "syncBatch" )
					.onComplete(
						job = "BeforeAndAfterJob",
						connection = "syncBatch"
					);

				try {
					pendingBatch.dispatch();
				} catch ( cbq.MaxAttemptsReached e ) {
					// The sync provider rethrows the terminal failure.
				}

				expect( application.jobAfterCalled ).toBeTrue(
					"The `finally` job should dispatch even when the last job fails."
				);
			} );

			it( "dispatches the finally job when all jobs succeed", function() {
				var cbq = getWireBox().getInstance( "@cbq" );
				registerSyncConnectionAndWorkerPool();

				var pendingBatch = cbq
					.batch( [ cbq.job( "SendWelcomeEmailJob" ), cbq.job( "SendWelcomeEmailJob" ) ] )
					.onConnection( "syncBatch" )
					.onComplete(
						job = "BeforeAndAfterJob",
						connection = "syncBatch"
					);

				pendingBatch.dispatch();

				expect( application.jobAfterCalled )
					.toBeTrue( "The `finally` job should dispatch when all batch jobs succeed." );
			} );
		} );
	}

	private void function registerSyncConnectionAndWorkerPool() {
		var config = getWireBox().getInstance( "Config@cbq" );

		if ( !config.getConnections().keyExists( "syncBatch" ) ) {
			config.registerConnection(
				name = "syncBatch",
				provider = getWireBox().getInstance( "SyncProvider@cbq" ).setProperties( {} )
			);
		}

		if ( !config.getWorkerPools().keyExists( "syncBatch" ) ) {
			config.registerWorkerPool(
				name = "syncBatch",
				connectionName = "syncBatch",
				maxAttempts = 1
			);
		}
	}

}
