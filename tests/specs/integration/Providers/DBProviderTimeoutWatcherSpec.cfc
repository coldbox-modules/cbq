component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBProvider timeout watcher", function() {
			beforeEach( function() {
				variables.provider = getWireBox().getInstance( "DBProvider@cbq" ).setProperties( {} );
				makePublic( variables.provider, "fetchPotentiallyOpenRecords" );
				variables.pool = makeWorkerPool( variables.provider );
				// clean up any leftover test records
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

			it( "does not re-grab a reserved job that is still within its job-specific timeout", function() {
				var job = getWireBox().getInstance( "SendWelcomeEmailJob" );
				variables.provider.push( "default", job );

				// Simulate the job being reserved by another worker with a 300s job timeout
				var otherWorkerUUID = createUUID();
				var now = javacast( "long", getTickCount() / 1000 );
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"reservedBy" : otherWorkerUUID,
						"reservedDate" : now,
						"availableDate" : now + 300
					} );

				var ids = variables.provider.fetchPotentiallyOpenRecords( capacity = 10, pool = variables.pool );

				expect( ids ).toBeEmpty( "A reserved job still within its job-specific timeout should not be re-grabbed" );
			} );

			it( "re-grabs a reserved job whose job-specific timeout has expired", function() {
				var job = getWireBox().getInstance( "SendWelcomeEmailJob" );
				variables.provider.push( "default", job );

				// Simulate the job being reserved 310s ago with a 300s job timeout (availableDate now in the past)
				var otherWorkerUUID = createUUID();
				var now = javacast( "long", getTickCount() / 1000 );
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"reservedBy" : otherWorkerUUID,
						"reservedDate" : now - 310,
						"availableDate" : now - 10
					} );

				var ids = variables.provider.fetchPotentiallyOpenRecords( capacity = 10, pool = variables.pool );

				expect( ids ).toHaveLength(
					1,
					"A reserved job whose job-specific timeout has expired should be re-grabbed"
				);
			} );

			it( "does not re-grab a job using the pool timeout when the job-specific timeout is longer", function() {
				// Core bug fix: pool timeout is 60s, job timeout is 300s.
				// After 65s (past pool timeout, within job timeout), job should NOT be re-grabbed.
				var job = getWireBox().getInstance( "SendWelcomeEmailJob" );
				variables.provider.push( "default", job );

				var otherWorkerUUID = createUUID();
				var now = javacast( "long", getTickCount() / 1000 );
				// Reserved 65s ago, job timeout is 300s, so availableDate is still 235s in the future
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"reservedBy" : otherWorkerUUID,
						"reservedDate" : now - 65,
						"availableDate" : now + 235
					} );

				var ids = variables.provider.fetchPotentiallyOpenRecords( capacity = 10, pool = variables.pool );

				expect( ids ).toBeEmpty(
					"A job past the pool timeout but still within its job-specific timeout should not be re-grabbed"
				);
			} );
		} );
	}

	private any function makeWorkerPool( required any provider ) {
		var connection = getInstance( "QueueConnection@cbq" )
			.setName( "TestTimeoutWatcherConnection" )
			.setProvider( arguments.provider );

		return getInstance( "WorkerPool@cbq" )
			.setName( "TestTimeoutWatcherPool" )
			.setConnection( connection )
			.setConnectionName( connection.getName() )
			.startWorkers();
	}

}
