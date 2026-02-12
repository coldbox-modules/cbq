component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBBatchRepository counts", function() {
			it( "initializes successfulJobs for newly stored batches", function() {
				var repository = getWireBox().getInstance( "DBBatchRepository@cbq" );
				var batch = repository.store(
					getWireBox()
						.getInstance( "@cbq" )
						.batch( [] )
						.allowFailures()
				);

				expect( batch.getSuccessfulJobs() ).toBe( 0 );
			} );

			it( "successful jobs increment successfulJobs and decrement pendingJobs", function() {
				var repository = getWireBox().getInstance( "DBBatchRepository@cbq" );
				var config = registerSyncConnectionAndWorkerPool();
				var batch = createTrackedBatch( repository, 1 );
				var provider = config.getConnection( "syncBatchCounts" ).getProvider();
				var pool = config.getWorkerPool( "syncBatchCounts" );

				var job = getWireBox()
					.getInstance( "@cbq" )
					.job( "SendWelcomeEmailJob" )
					.setId( createUUID() )
					.withBatchId( batch.getId() );

				provider.marshalJob( job, pool );

				var updatedBatch = repository.find( batch.getId() );

				expect( updatedBatch.getPendingJobs() ).toBe( 0 );
				expect( updatedBatch.getFailedJobs() ).toBe( 0 );
				expect( updatedBatch.getSuccessfulJobs() ).toBe( 1 );
			} );

			it( "retryable errors do not change pending, successful, or failed counts", function() {
				var repository = getWireBox().getInstance( "DBBatchRepository@cbq" );
				var config = registerSyncConnectionAndWorkerPool();
				var batch = createTrackedBatch( repository, 1 );
				var provider = config.getConnection( "syncBatchCounts" ).getProvider();
				var pool = config.getWorkerPool( "syncBatchCounts" );

				var job = getWireBox()
					.getInstance( "@cbq" )
					.job( "AlwaysErrorJob" )
					.setId( createUUID() )
					.withBatchId( batch.getId() )
					.setCurrentAttempt( 1 )
					.setMaxAttempts( 2 );

				expect( () => provider.marshalJob( job, pool ) ).toThrow( "cbq.SyncProviderJobFailed" );

				var updatedBatch = repository.find( batch.getId() );

				expect( updatedBatch.getPendingJobs() ).toBe( 1 );
				expect( updatedBatch.getSuccessfulJobs() ).toBe( 0 );
				expect( updatedBatch.getFailedJobs() ).toBe( 0 );
				expect( updatedBatch.getFailedJobIds() ).toBeEmpty();
			} );

			it( "failed jobs increment failedJobs, append failedJobIds, and decrement pendingJobs", function() {
				var repository = getWireBox().getInstance( "DBBatchRepository@cbq" );
				var config = registerSyncConnectionAndWorkerPool();
				var batch = createTrackedBatch( repository, 1 );
				var provider = config.getConnection( "syncBatchCounts" ).getProvider();
				var pool = config.getWorkerPool( "syncBatchCounts" );
				var failedJobId = createUUID();

				var job = getWireBox()
					.getInstance( "@cbq" )
					.job( "AlwaysErrorJob" )
					.setId( failedJobId )
					.withBatchId( batch.getId() )
					.setCurrentAttempt( 1 )
					.setMaxAttempts( 1 );

				expect( () => provider.marshalJob( job, pool ) ).toThrow();

				var updatedBatch = repository.find( batch.getId() );

				expect( updatedBatch.getPendingJobs() ).toBe( 0 );
				expect( updatedBatch.getSuccessfulJobs() ).toBe( 0 );
				expect( updatedBatch.getFailedJobs() ).toBe( 1 );
				expect( updatedBatch.getFailedJobIds() ).toHaveLength( 1 );
				expect( updatedBatch.getFailedJobIds()[ 1 ] ).toBe( failedJobId );
			} );
		} );
	}

	private any function registerSyncConnectionAndWorkerPool() {
		var config = getWireBox().getInstance( "Config@cbq" );

		if ( !config.getConnections().keyExists( "syncBatchCounts" ) ) {
			config.registerConnection(
				name = "syncBatchCounts",
				provider = getWireBox().getInstance( "SyncProvider@cbq" ).setProperties( {} )
			);
		}

		if ( !config.getWorkerPools().keyExists( "syncBatchCounts" ) ) {
			config.registerWorkerPool(
				name = "syncBatchCounts",
				connectionName = "syncBatchCounts",
				maxAttempts = 2
			);
		}

		return config;
	}

	private any function createTrackedBatch( required any repository, required numeric totalJobs ) {
		var pendingBatch = getWireBox()
			.getInstance( "@cbq" )
			.batch( [] )
			.allowFailures();
		var batch = arguments.repository.store( pendingBatch );
		arguments.repository.incrementTotalJobs( batch.getId(), arguments.totalJobs );
		return arguments.repository.find( batch.getId() );
	}

}
