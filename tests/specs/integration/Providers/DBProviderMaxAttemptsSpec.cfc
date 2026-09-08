component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBProvider maxAttempts safeguards", function() {
			beforeEach( function() {
				variables.workerPools = [];
				variables.provider = getWireBox()
					.buildInstance( getWireBox().getBinder().getMapping( "DBProvider@cbq" ) )
					.setProperties( {} );
				getWireBox().autowire(
					target = variables.provider,
					mapping = getWireBox().getBinder().getMapping( "DBProvider@cbq" )
				);
				makePublic( variables.provider, "processLockedRecord" );
				variables.pool = makeWorkerPool( variables.provider );
				variables.cbqSettings = getController().getModuleSettings( "cbq" );
				variables.originalLogFailedJobs = variables.cbqSettings.logFailedJobs;
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.delete();
				variables.provider
					.newQuery()
					.table( "cbq_failed_jobs" )
					.delete();
			} );

			afterEach( function() {
				for ( var pool in variables.workerPools ) {
					pool.shutdown( force = true, timeout = 1 );
				}
				variables.cbqSettings.logFailedJobs = variables.originalLogFailedJobs;
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.delete();
				variables.provider
					.newQuery()
					.table( "cbq_failed_jobs" )
					.delete();
			} );

			it( "counts each failed execution once through the configured maximum", function() {
				assertExecutionAttempts( "AlwaysErrorJob" );
			} );

			it( "counts each manual release once through the configured maximum", function() {
				assertExecutionAttempts( "ReleaseTestJob" );
			} );

			for ( var counterBoundary in [ 255, 32767, 2147483647 ] ) {
				it(
					title = "reserves an unlimited job beyond execution count " & counterBoundary,
					data = { "boundary" : counterBoundary },
					body = function( data ) {
						var job = getWireBox().getInstance( "SendWelcomeEmailJob" ).setMaxAttempts( 0 );
						variables.provider.push( "default", job );
						variables.provider
							.newQuery()
							.table( "cbq_jobs" )
							.update( {
								"attempts" : data.boundary,
								"reservedBy" : variables.pool.getUniqueId(),
								"reservedDate" : {
									"value" : "",
									"null" : true,
									"nulls" : true,
									"cfsqltype" : "cf_sql_bigint"
								}
							} );
						var record = variables.provider
							.newQuery()
							.from( "cbq_jobs" )
							.first();
						// Keep the real deserialization/reservation update; stop only
						// the asynchronous dispatch after the persisted increment.
						prepareMock( variables.provider ).$( "marshalJob" );
						variables.provider.processLockedRecord( record, variables.pool );
						var row = variables.provider
							.newQuery()
							.from( "cbq_jobs" )
							.where( "id", record.id )
							.first();
						expect( row.attempts ).toBe( data.boundary + 1 );
						expect( row.reservedBy ).toBe( variables.pool.getUniqueId() );
						expect( row.reservedDate ?: "" ).notToBe( "" );
						expect( row.completedDate ?: "" ).toBe( "" );
						expect( row.failedDate ?: "" ).toBe( "" );
						expect( variables.provider.$once( "marshalJob" ) ).toBeTrue();
					}
				);
			}

			it( "forceFailJob sets failedDate and preserves the reservation", function() {
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
				expect( row.reservedBy ?: "" ).toBe( variables.pool.getUniqueId(), "reservedBy should be preserved" );
				expect( row.reservedDate ).toBe( now, "reservedDate should be preserved" );
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
				variables.provider.$( "incrementJobAttempts", true );
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
				expect( row.reservedBy ?: "" ).toBe(
					variables.pool.getUniqueId(),
					"reservedBy should be preserved after terminal failure"
				);
				expect( row.reservedDate ?: "" ).toBe(
					"",
					"reservedDate should remain unchanged after terminal failure"
				);
			} );

			it( "logs a failed job when a timeout retry already meets maxAttempts before dispatch", function() {
				variables.cbqSettings.logFailedJobs = true;
				var job = getWireBox().getInstance( "AlwaysErrorJob" ).setMaxAttempts( 3 );
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
						"attempts" : 3
					} );

				var record = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.first();

				variables.provider.processLockedRecord( record, variables.pool );

				var failedLog = variables.provider
					.newQuery()
					.from( "cbq_failed_jobs" )
					.first();

				expect( failedLog ).notToBeNull(
					"terminal maxAttempts failures discovered by the timeout watcher should be visible in the failed jobs log"
				);
				expect( failedLog.originalId ).toBe( record.id );
				expect( failedLog.exceptionType ).toBe( "cbq.MaxAttemptsReached" );
				expect( failedLog.exceptionMessage ).toInclude( "exceeded maximum attempts" );
			} );

			it( "persists the terminal attempt before failing a job that reaches maxAttempts during execution", function() {
				var job = getWireBox().getInstance( "AlwaysErrorJob" ).setMaxAttempts( 3 );
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
						"attempts" : 2
					} );

				var record = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.first();

				variables.provider.processLockedRecord( record, variables.pool );
				var row = waitForFailedJobRow( record.id );

				expect( row.failedDate ).notToBeNull( "the third failed run should mark the row failed" );
				expect( row.attempts ).toBe( 3, "the terminal third run should be reflected in the attempts column" );
				expect( row.reservedBy ?: "" ).toBe(
					variables.pool.getUniqueId(),
					"reservedBy should be preserved after terminal failure"
				);
				expect( row.reservedDate ?: "" ).notToBe(
					"",
					"reservedDate should be preserved after terminal failure"
				);
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
				variables.provider.$( "incrementJobAttempts", true );
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
						"availableDate" : now + 60,
						// marshalJob below begins execution one; mirror its persisted reservation.
						"attempts" : 1
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

	private void function assertExecutionAttempts( required string mapping ) {
		var job = getWireBox().getInstance( arguments.mapping ).setMaxAttempts( 3 );
		variables.provider.push( "default", job );
		var jobId = variables.provider
			.newQuery()
			.from( "cbq_jobs" )
			.value( "id" );
		for ( var attempt = 1; attempt <= 3; attempt++ ) {
			// Drive successive reservations directly, without a timer/backoff wait.
			// processLockedRecord still executes the actual job and lifecycle future.
			variables.provider
				.newQuery()
				.table( "cbq_jobs" )
				.where( "id", jobId )
				.update( {
					"reservedBy" : variables.pool.getUniqueId(),
					"reservedDate" : {
						"value" : "",
						"null" : true,
						"nulls" : true,
						"cfsqltype" : "cf_sql_bigint"
					}
				} );
			var record = variables.provider
				.newQuery()
				.from( "cbq_jobs" )
				.where( "id", jobId )
				.first();
			variables.provider.processLockedRecord( record, variables.pool );
			var row = {};
			var settled = false;
			for ( var poll = 1; poll <= 100; poll++ ) {
				row = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "id", jobId )
					.first();
				if ( ( row.reservedBy ?: "" ) == "" || ( row.failedDate ?: "" ) != "" ) {
					settled = true;
					break;
				}
				sleep( 50 );
			}
			expect( settled ).toBeTrue( "The execution must release or fail before checking its count" );
			expect( row.attempts ).toBe( attempt, "Releasing a job must not consume another execution attempt" );
			if ( attempt < 3 ) {
				expect( row.failedDate ?: "" ).toBe( "", "The configured budget must allow another execution" );
				expect( deserializeJSON( row.payload ).currentAttempt ).toBe( attempt );
			} else {
				expect( row.failedDate ?: "" ).notToBe( "", "The third execution must exhaust the budget" );
			}
		}
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

	private struct function waitForFailedJobRow( required numeric id ) {
		for ( var i = 1; i <= 20; i++ ) {
			var row = variables.provider
				.newQuery()
				.from( "cbq_jobs" )
				.where( "id", arguments.id )
				.first();
			if ( !isNull( row.failedDate ) && row.attempts == 3 ) {
				return row;
			}
			sleep( 100 );
		}

		return variables.provider
			.newQuery()
			.from( "cbq_jobs" )
			.where( "id", arguments.id )
			.first();
	}

	private any function makeWorkerPool( required any provider ) {
		var uniqueName = createUUID();
		var connection = getInstance( "QueueConnection@cbq" )
			.setName( "TestMaxAttemptsConnection-#uniqueName#" )
			.setProvider( arguments.provider );

		var pool = getInstance( "WorkerPool@cbq" )
			.setName( "TestMaxAttemptsPool-#uniqueName#" )
			.setConnection( connection )
			.setConnectionName( connection.getName() )
			.startWorkers();
		variables.workerPools.append( pool );
		return pool;
	}

}
