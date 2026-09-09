component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBBatchRepository counts", function() {
			it( "counts a repeated result only once while other jobs remain pending", function() {
				var repository = getWireBox().getInstance( "DBBatchRepository@cbq" );
				var batch = createTrackedBatch( repository, 2 );
				batch.recordSuccessfulJob( "first" );
				batch.recordSuccessfulJob( "first" );
				batch.recordFailedJob( "first", {} );
				var stored = repository.find( batch.getId() );
				expect( stored.getPendingJobs() ).toBe( 1 );
				expect( stored.getSuccessfulJobs() ).toBe( 1 );
				expect( stored.getFailedJobs() ).toBe( 0 );
				batch.recordFailedJob( "second", {} );
				batch.recordFailedJob( "second", {} );
				batch.recordSuccessfulJob( "second" );
				stored = repository.find( batch.getId() );
				expect( stored.getPendingJobs() ).toBe( 0 );
				expect( stored.getSuccessfulJobs() ).toBe( 1 );
				expect( stored.getFailedJobs() ).toBe( 1 );
				expect( stored.getFailedJobIds() ).toBe( [ "second" ] );
			} );

			it( "does not repeat lifecycle jobs or underflow a completed batch", function() {
				var repository = getWireBox().getInstance( "DBBatchRepository@cbq" );
				var batch = createTrackedBatch( repository, 1 );
				prepareMock( batch ).$( "dispatchThenJobIfNeeded" ).$( "dispatchFinallyJobIfNeeded" );
				batch.recordSuccessfulJob( "only" );
				batch.recordSuccessfulJob( "only" );
				batch.recordFailedJob( "only", {} );
				expect( repository.find( batch.getId() ).getPendingJobs() ).toBe( 0 );
				expect( batch.$once( "dispatchThenJobIfNeeded" ) ).toBeTrue();
				expect( batch.$once( "dispatchFinallyJobIfNeeded" ) ).toBeTrue();
			} );

			it( "serializes concurrent reports for the same job", function() {
				var repository = getWireBox().getInstance( "DBBatchRepository@cbq" );
				var batch = createTrackedBatch( repository, 2 );
				var batchId = batch.getId();
				var async = getInstance( "coldbox:asyncManager" );
				var first = async.newFuture( () => repository.decrementPendingJobs( batchId, "same" ) );
				var second = async.newFuture( () => repository.decrementPendingJobs( batchId, "same" ) );
				first.get();
				second.get();
				var stored = repository.find( batchId );
				expect( stored.getPendingJobs() ).toBe( 1 );
				expect( stored.getSuccessfulJobs() ).toBe( 1 );
			} );

			it( "preserves known failures on batches predating the processed IDs column", function() {
				var repository = getWireBox().getInstance( "DBBatchRepository@cbq" );
				var batch = createTrackedBatch( repository, 2 );
				getInstance( "QueryBuilder@qb" )
					.table( "cbq_batches" )
					.where( "id", batch.getId() )
					.update( {
						"pendingJobs" : 1,
						"failedJobs" : 1,
						"failedJobIds" : '["old-failure"]',
						"processedJobIds" : {
							"value" : "",
							"null" : true,
							"nulls" : true
						}
					} );
				batch.recordFailedJob( "old-failure", {} );
				batch.recordSuccessfulJob( "remaining" );
				var stored = repository.find( batch.getId() );
				expect( stored.getPendingJobs() ).toBe( 0 );
				expect( stored.getFailedJobs() ).toBe( 1 );
				expect( stored.getSuccessfulJobs() ).toBe( 1 );
			} );

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
