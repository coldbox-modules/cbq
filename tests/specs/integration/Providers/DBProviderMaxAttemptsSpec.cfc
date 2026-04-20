component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBProvider maxAttempts safeguards", function() {
			beforeEach( function() {
				variables.provider = getWireBox().getInstance( "DBProvider@cbq" ).setProperties( {} );
				makePublic( variables.provider, "processLockedRecord" );
				variables.pool = makeWorkerPool( variables.provider );
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.delete();
			} );

			afterEach( function() {
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.delete();
			} );

			it( "forceFailJob sets failedDate and clears the reservation", function() {
				var job = getWireBox().getInstance( "SendWelcomeEmailJob" ).setMaxAttempts( 3 );
				variables.provider.push( "default", job );

				var now = javacast( "long", getTickCount() / 1000 );
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"reservedBy" : variables.pool.getUniqueId(),
						"reservedDate" : now,
						"availableDate" : now + 60,
						"attempts" : 5
					} );

				var jobId = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.value( "id" );

				variables.provider.forceFailJob( jobId, variables.pool );

				var row = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "id", jobId )
					.first();

				expect( row.failedDate ).notToBeNull( "failedDate should be set" );
				expect( row.failedDate ).toBeGT( 0, "failedDate should be a unix timestamp" );
				expect( row.reservedBy ?: "" ).toBe( "", "reservedBy should be cleared" );
				expect( row.reservedDate ?: "" ).toBe( "", "reservedDate should be cleared" );
			} );

			it( "skips dispatch and marks the job failed when attempts already meets maxAttempts", function() {
				var job = getWireBox().getInstance( "AlwaysErrorJob" ).setMaxAttempts( 3 );
				variables.provider.push( "default", job );

				var now = javacast( "long", getTickCount() / 1000 );
				// Simulate the runaway state: 29 attempts in DB, payload still says maxAttempts=3,
				// reserved by this pool but reservedDate was never set (the symptom we observed).
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"reservedBy" : variables.pool.getUniqueId(),
						"reservedDate" : {
							"value" : "",
							"null" : true,
							"nulls" : true
						},
						"availableDate" : now - 1,
						"attempts" : 29
					} );

				var record = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.first();

				prepareMock( variables.provider );
				variables.provider.$( "incrementJobAttempts" );
				variables.provider.$( "marshalJob" );

				variables.provider.processLockedRecord( record, variables.pool );

				expect( variables.provider.$never( "incrementJobAttempts" ) ).toBeTrue(
					"incrementJobAttempts must not run once attempts >= maxAttempts"
				);
				expect( variables.provider.$never( "marshalJob" ) ).toBeTrue(
					"marshalJob must not run once attempts >= maxAttempts"
				);

				var row = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "id", record.id )
					.first();
				expect( row.failedDate ).notToBeNull( "the runaway job should be marked failed" );
			} );

			it( "still proceeds normally when attempts is below maxAttempts", function() {
				var job = getWireBox().getInstance( "SendWelcomeEmailJob" ).setMaxAttempts( 3 );
				variables.provider.push( "default", job );

				var now = javacast( "long", getTickCount() / 1000 );
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"reservedBy" : variables.pool.getUniqueId(),
						"reservedDate" : {
							"value" : "",
							"null" : true,
							"nulls" : true
						},
						"availableDate" : now - 1,
						"attempts" : 1
					} );

				var record = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.first();

				prepareMock( variables.provider );
				variables.provider.$( "incrementJobAttempts" );
				variables.provider.$( "marshalJob" );

				variables.provider.processLockedRecord( record, variables.pool );

				expect( variables.provider.$once( "incrementJobAttempts" ) ).toBeTrue(
					"incrementJobAttempts should run when attempts < maxAttempts"
				);
				expect( variables.provider.$once( "marshalJob" ) ).toBeTrue(
					"marshalJob should run when attempts < maxAttempts"
				);
			} );

			it( "still marks the row failed when releaseJob throws inside the exception handler", function() {
				// Regression: previously, if releaseJob threw inside .onException, the
				// future swallowed the secondary exception and the row stayed reserved,
				// causing unbounded timeout-based re-pickups.
				// We use a real subclass (FailingReleaseDBProvider) instead of MockBox so that
				// WireBox provider methods (newQuery) continue to work inside the async thread.
				var failingProvider = getWireBox().getInstance( "FailingReleaseDBProvider" ).setProperties( {} );
				var failingPool = makeWorkerPool( failingProvider );

				failingProvider
					.newQuery()
					.table( "cbq_jobs" )
					.delete();
				var job = getWireBox()
					.getInstance( "AlwaysErrorJob" )
					.setMaxAttempts( 5 )
					.setCurrentAttempt( 0 );

				failingProvider.push( "default", job );

				var now = javacast( "long", getTickCount() / 1000 );
				failingProvider
					.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"reservedBy" : failingPool.getUniqueId(),
						"reservedDate" : now,
						"availableDate" : now + 60
					} );

				var jobId = failingProvider
					.newQuery()
					.from( "cbq_jobs" )
					.value( "id" );

				job.setId( jobId );

				try {
					var jobFuture = failingProvider.marshalJob( job, failingPool );
					if ( !isNull( jobFuture ) ) {
						jobFuture.get();
					}
				} catch ( any e ) {
				}

				var row = failingProvider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "id", jobId )
					.first();

				expect( row.failedDate ?: "" ).notToBe(
					"",
					"the row must be marked failed even when releaseJob throws, otherwise the timeout watcher will retry it forever"
				);

				failingProvider
					.newQuery()
					.table( "cbq_jobs" )
					.delete();
			} );

			it( "falls back to forceFailJob when even afterJobFailed throws", function() {
				// Floor of the defense: if the proper failure-recording path is broken,
				// markJobFailed should escalate to forceFailJob to guarantee the row exits
				// the retry loop.
				var job = getWireBox()
					.getInstance( "AlwaysErrorJob" )
					.setMaxAttempts( 1 )
					.setCurrentAttempt( 0 )
					.setId( randRange( 1, 1000 ) );

				variables.provider.push( "default", job );
				var jobId = reserveJobForPool();
				job.setId( jobId );

				prepareMock( variables.provider );
				makePublic( variables.provider, "afterJobFailed" );
				variables.provider
					.$( "afterJobFailed" )
					.$throws( type = "TestSimulatedFailure", message = "simulated afterJobFailed failure" );
				variables.provider.$( "forceFailJob" );

				try {
					var jobFuture = variables.provider.marshalJob( job, variables.pool );
					if ( !isNull( jobFuture ) ) {
						jobFuture.get();
					}
				} catch ( any e ) {
				}

				expect( variables.provider.$atLeast( 1, "forceFailJob" ) ).toBeTrue(
					"forceFailJob must run when afterJobFailed throws"
				);
			} );
		} );
	}

	private numeric function reserveJobForPool() {
		var now = javacast( "long", getTickCount() / 1000 );
		variables.provider
			.newQuery()
			.table( "cbq_jobs" )
			.update( {
				"reservedBy" : variables.pool.getUniqueId(),
				"reservedDate" : now,
				"availableDate" : now + 60
			} );
		return variables.provider
			.newQuery()
			.from( "cbq_jobs" )
			.value( "id" );
	}

	private any function makeWorkerPool( required any provider ) {
		var connection = getInstance( "QueueConnection@cbq" )
			.setName( "TestMaxAttemptsConnection" )
			.setProvider( arguments.provider );

		return getInstance( "WorkerPool@cbq" )
			.setName( "TestMaxAttemptsPool" )
			.setConnection( connection )
			.setConnectionName( connection.getName() )
			.startWorkers();
	}

}
