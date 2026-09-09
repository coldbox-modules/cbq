component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "reported configuration regressions", function() {
			it( "stores batches with no optional lifecycle jobs", function() {
				var batch = getInstance( "@cbq" ).batch( [] );
				var options = batch.getOptions();
				expect( isNull( options.thenJob ) ).toBeTrue();
				expect( isNull( options.catchJob ) ).toBeTrue();
				expect( isNull( options.finallyJob ) ).toBeTrue();
				var stored = getInstance( "DBBatchRepository@cbq" ).store( batch );
				expect( stored.getId() ).notToBeEmpty();
			} );
			it( "dispatches to the explicitly named database connection and queue", function() {
				var queue = "issue5-#createUUID()#";
				var cbq = getInstance( "@cbq" );
				cbq.job(
						job = "SendWelcomeEmailJob",
						properties = { "jobToken" : "token" },
						chain = [],
						queue = queue,
						connection = "db"
					)
					.dispatch();
				var row = getInstance( "QueryBuilder@qb" )
					.from( "cbq_jobs" )
					.where( "queue", queue )
					.first();
				expect( row ).notToBeEmpty();
				var payload = deserializeJSON( row.payload );
				expect( payload.connection ).toBe( "db" );
				expect( payload.properties.jobToken ).toBe( "token" );
			} );
			it( "keeps datasource settings isolated between database connections", function() {
				var config = getInstance( "Config@cbq" );
				config.registerConnection(
					"issue5-first",
					"DBProvider@cbq",
					{
						"datasource" : "cbq",
						"tableName" : "cbq_jobs"
					}
				);
				config.registerConnection(
					"issue5-second",
					"DBProvider@cbq",
					{ "datasource" : "must-not-be-used-second" }
				);
				config.registerConnection(
					"issue5-third",
					"DBProvider@cbq",
					{ "datasource" : "must-not-be-used-third" }
				);
				var queue = "isolated-#createUUID()#";
				getInstance( "@cbq" )
					.job(
						job = "SendWelcomeEmailJob",
						queue = queue,
						connection = "issue5-first"
					)
					.dispatch();
				expect(
					getInstance( "QueryBuilder@qb" )
						.from( "cbq_jobs" )
						.where( "queue", queue )
						.count()
				).toBe( 1 );
				expect(
					config
						.getConnection( "issue5-first" )
						.getProvider()
						.getProperties()
						.datasource
				).toBe( "cbq" );
				expect(
					config
						.getConnection( "issue5-second" )
						.getProvider()
						.getProperties()
						.datasource
				).toBe( "must-not-be-used-second" );
			} );

			it( "releases an unknown mapping for another worker without consuming an attempt", function() {
				var provider = getInstance( "DBProvider@cbq" ).setProperties( {} );
				makePublic( provider, "processLockedRecord" );
				var pool = getInstance( "WorkerPool@cbq" ).setName( "UnknownMapping" );
				var queue = "unknown-#createUUID()#";
				provider.push( queue, getInstance( "@cbq" ).job( "MissingOnThisWorker" ) );
				var row = provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "queue", queue )
					.first();
				provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "id", row.id )
					.update( { "reservedBy" : pool.getUniqueId() } );
				provider.processLockedRecord( row, pool );
				var after = provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "id", row.id )
					.first();
				expect( after.reservedBy ?: "" ).toBe( "" );
				expect( after.failedDate ?: "" ).toBe( "" );
				expect( after.attempts ).toBe( 0 );
				expect( after.payload ).toBe( row.payload );
				// A late callback must not release a reservation now owned by another pool.
				provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "id", row.id )
					.update( { "reservedBy" : "another-pool" } );
				provider.processLockedRecord( row, pool );
				expect(
					provider
						.newQuery()
						.from( "cbq_jobs" )
						.where( "id", row.id )
						.value( "reservedBy" )
				).toBe( "another-pool" );
			} );

			it( "leaves unknown job mappings available without recording failure", function() {
				var provider = getInstance( "DBProvider@cbq" ).setProperties( {} );
				var queue = "issue6-#createUUID()#";
				provider.push( queue, getInstance( "@cbq" ).job( "MissingOnThisWorker" ) );
				var row = provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "queue", queue )
					.first();
				expect( () => provider.deserializeJob( row.payload, row.id, row.attempts ) ).toThrow();
				var after = provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "id", row.id )
					.first();
				expect( after.failedDate ?: "" ).toBe( "" );
				expect( after.completedDate ?: "" ).toBe( "" );
				expect( after.attempts ).toBe( 0 );
			} );
		} );
	}

}
