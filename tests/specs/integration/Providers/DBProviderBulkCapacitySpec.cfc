/** Run against a migrated disposable PostgreSQL database; other grammars keep their existing limits. */
component extends="testbox.system.BaseSpec" {

	function run() {
		cfdbinfo( type = "Version", name = "local.databaseInfo" );
		describe(
			title = "PostgreSQL explicit native bulk capacity",
			body = function() {
				beforeEach( function() {
					variables.queue = "bulk-capacity-" & createUUID();
					variables.counter = { "rows" : [] };
					variables.grammar = new qb.models.Grammars.PostgresGrammar().setInterceptorService(
						new tests.resources.BulkInsertObserver().setCounter( variables.counter )
					);
					variables.provider = freshProvider();
				} );
				aroundEach( function( spec ) {
					transaction {
						try {
							spec.body();
						} finally {
							transaction action="rollback";
						}
					}
				} );
				it( "persists 1001 and 2005 ordered independent native jobs in 2 and 3 inserts", function() {
					for ( var total in [ 1001, 2005 ] ) {
						variables.queue = "bulk-capacity-" & createUUID();
						variables.counter.rows = [];
						var entries = makeEntries( total );
						var before = variables.provider.getCurrentUnixTimestamp();
						variables.provider.pushMany( entries );
						var after = variables.provider.getCurrentUnixTimestamp();
						expect( variables.counter.rows ).toBe( total == 1001 ? [ 1000, 1 ] : [ 1000, 1000, 5 ] );
						var rows = queryRows();
						expect( rows.len() ).toBe( total );
						for ( var index = 1; index <= total; index++ ) {
							var payload = deserializeJSON( rows[ index ].payload );
							expect( payload.properties.ordinal ).toBe( index );
							expect( payload.properties.text ).toBe( entries[ index ].job.getProperties().text );
							expect( payload.mapping ).toBe( "BulkCapacityFixtureJob" );
							expect( rows[ index ].attempts ).toBe( 2147483648 );
							expect( rows[ index ].createdDate >= before && rows[ index ].createdDate <= after ).toBeTrue();
							expect(
								rows[ index ].availableDate >= before + 17 && rows[ index ].availableDate <= after + 17
							).toBeTrue();
						}
					}
				} );
				it( "rolls back an already persisted 1000-row chunk when serialization of job 1001 fails", function() {
					var entries = makeEntries( 1001 );
					entries[ 1001 ].job = "invalid job";
					var observed = 0;
					var failed = false;
					expect( queryRows() ).toBeEmpty();
					transaction action="setsavepoint" savepoint="bulk_capacity";
					try {
						variables.provider.pushMany( entries );
					} catch ( any failure ) {
						failed = true;
						observed = queryRows().len();
						transaction action="rollback" savepoint="bulk_capacity";
					}
					expect( failed ).toBeTrue();
					expect( observed ).toBe( 1000 );
					expect( variables.counter.rows ).toBe( [ 1000 ] );
					expect( queryRows() ).toBeEmpty();
					variables.provider.pushMany( makeEntries( 1001 ) );
					expect( queryRows().len() ).toBe( 1001 );
				} );
				it( "retains 100-row defaults and resets a prior PostgreSQL opt-in when reconfigured", function() {
					expect( variables.provider.getMaxBulkDispatchBatchSize() ).toBe( 1000 );
					variables.provider.setProperties( {} );
					expect( variables.provider.getMaxBulkDispatchBatchSize() ).toBe( 100 );
					variables.provider.pushMany( makeEntries( 205 ) );
					expect( variables.counter.rows ).toBe( [ 100, 100, 5 ] );
					expect( queryRows().len() ).toBe( 205 );
				} );
				it( "validates once per configuration and retains inherited capability for custom watchers", function() {
					variables.queryCalls = 0;
					variables.provider = freshProvider( "tests.resources.ListenOnlyDBProvider" );
					expect( variables.provider.getMaxBulkDispatchBatchSize() ).toBe( 1000 );
					expect( variables.provider.getMaxBulkDispatchBatchSize() ).toBe( 1000 );
					expect( variables.queryCalls ).toBe( 1 );
					variables.provider.setProperties( { "bulkInsertBatchSize" : 1000 } );
					expect( variables.provider.getMaxBulkDispatchBatchSize() ).toBe( 1000 );
					expect( variables.queryCalls ).toBe( 2 );
				} );
			},
			skip = databaseInfo.DATABASE_PRODUCTNAME[ 1 ] != "PostgreSQL"
		);
	}

	private any function freshProvider( string mapping = "cbq.models.Providers.DBProvider" ) {
		var provider = createMock( arguments.mapping )
			.setJavaInstant( createObject( "java", "java.time.Instant" ) )
			.setLog( {
				"canDebug" : function() {
					return false;
				}
			} )
			.setProperties( { "bulkInsertBatchSize" : 1000 } );
		provider
			.$( "newQuery" )
			.$callback( function() {
				variables.queryCalls = ( variables.queryCalls ?: 0 ) + 1;
				return new qb.models.Query.QueryBuilder( grammar = variables.grammar );
			} );
		return provider;
	}

	private array function makeEntries( required numeric count ) {
		var entries = [];
		for ( var index = 1; index <= arguments.count; index++ ) {
			entries.append( {
				"queueName" : variables.queue,
				"job" : new cbq.models.Jobs.AbstractJob()
					.setMapping( "BulkCapacityFixtureJob" )
					.setProperties( {
						"ordinal" : index,
						"text" : repeatString( "José 00123 " & chr( 34 ) & chr( 92 ) & chr( 10 ), 30 )
					} ),
				"delay" : 17,
				"attempts" : 2147483648
			} );
		}
		return entries;
	}

	private array function queryRows() {
		return new qb.models.Query.QueryBuilder( grammar = variables.grammar )
			.from( "cbq_jobs" )
			.where( "queue", variables.queue )
			.orderBy( "id" )
			.get();
	}

}
