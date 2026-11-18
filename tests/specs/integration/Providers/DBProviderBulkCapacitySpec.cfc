/** Run against a migrated disposable PostgreSQL database; other grammars keep their existing limits. */
component extends="testbox.system.BaseSpec" {

	function run() {
		cfdbinfo( type = "Version", name = "local.databaseInfo" );
		describe(
			title = "PostgreSQL explicit native bulk capacity",
			body = function() {
				beforeEach( function() {
					variables.queue = "bulk-capacity-" & createUUID();
					variables.counter = {
						"rows" : [],
						"bindings" : [],
						"json" : []
					};
					variables.grammar = new qb.models.Grammars.PostgresGrammar().setInterceptorService(
						new tests.resources.BulkInsertObserver().setCounter( variables.counter )
					);
					variables.provider = freshProvider();
					var formatter = new qb.models.Query.QueryBuilder().getColumnFormatter();
					variables.recordset = !isClosure( formatter ) && compareNoCase(
						getMetadata( formatter ).name ?: "",
						"identityColumnFormatter"
					) == 0;
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
						variables.counter.bindings = [];
						variables.counter.json = [];
						var entries = makeEntries( total );
						var before = variables.provider.getCurrentUnixTimestamp();
						variables.provider.pushMany( entries );
						var after = variables.provider.getCurrentUnixTimestamp();
						expect( variables.counter.rows ).toBe( total == 1001 ? [ 1000, 1 ] : [ 1000, 1000, 5 ] );
						expect( variables.counter.bindings ).toBe(
							variables.recordset ? ( total == 1001 ? [ 1, 1 ] : [ 1, 1, 1 ] ) : (
								total == 1001 ? [ 5000, 5 ] : [ 5000, 5000, 25 ]
							)
						);
						expect( variables.counter.json.every( ( value ) => value == variables.recordset ) ).toBeTrue();
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
					expect( variables.counter.bindings ).toBe( [ 500, 500, 25 ] );
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
				it( "retains native typed inserts for a custom builder, utilities, or formatter", function() {
					for ( var custom in [ "builder", "utils", "formatter" ] ) {
						variables.counter.rows = [];
						variables.counter.bindings = [];
						variables.counter.json = [];
						variables.provider
							.$( "newQuery" )
							.$callback( function() {
								var query = custom == "builder" ? new tests.resources.BulkCustomQueryBuilder(
									grammar = variables.grammar
								) : new qb.models.Query.QueryBuilder( grammar = variables.grammar );
								if ( custom == "utils" ) {
									query.setUtils( new tests.resources.BulkCustomQueryUtils() );
								}
								if ( custom == "formatter" ) {
									query.setColumnFormatter( ( column ) => column );
								}
								return query;
							} );
						variables.provider.pushMany( makeEntries( 2 ) );
						expect( variables.counter.bindings ).toBe( [ 10 ] );
						expect( variables.counter.json ).toBe( [ false ] );
					}
				} );
				it( "rejects a same-named private custom formatter from the stock shortcut", function() {
					variables.provider
						.$( "newQuery" )
						.$callback( function() {
							return new qb.models.Query.QueryBuilder( grammar = variables.grammar ).setColumnFormatter(
								new tests.resources.BulkSpoofFormatter().formatter()
							);
						} );
					expect( queryRows() ).toBeEmpty();
					transaction action="setsavepoint" savepoint="spoof_formatter";
					var failed = false;
					try {
						variables.provider.pushMany( makeEntries( 2 ) );
					} catch ( any failure ) {
						failed = true;
						transaction action="rollback" savepoint="spoof_formatter";
					}
					expect( failed ).toBeTrue();
					expect( variables.counter.json ).toBe( [ false ] );
					expect( variables.counter.bindings ).toBe( [ 10 ] );
					expect( queryRows() ).toBeEmpty();
				} );
				it( "preserves scalar JDBC coercion for fractional attempts and delays", function() {
					variables.provider
						.$( "getCurrentUnixTimestamp" )
						.$callback( function( delay = 0 ) {
							return 1700000000 + delay;
						} );
					var entries = makeEntries( 1 );
					entries[ 1 ].attempts = 1.5;
					entries[ 1 ].delay = 17.5;
					expect( queryRows() ).toBeEmpty();
					transaction action="setsavepoint" savepoint="fractional_native";
					var scalarError = "";
					var bulkError = "";
					try {
						variables.provider.push( argumentCollection = entries[ 1 ] );
					} catch ( any failure ) {
						scalarError = failure.type & ":" & failure.message;
						transaction action="rollback" savepoint="fractional_native";
					}
					try {
						variables.provider.pushMany( entries );
					} catch ( any failure ) {
						bulkError = failure.type & ":" & failure.message;
						transaction action="rollback" savepoint="fractional_native";
					}
					expect( bulkError ).toBe( scalarError );
					var rows = queryRows();
					if ( len( scalarError ) ) {
						expect( rows ).toBeEmpty();
					} else {
						expect( rows.len() ).toBe( 2 );
						for (
							var field in [
								"attempts",
								"createdDate",
								"availableDate",
								"payload"
							]
						) {
							expect( rows[ 2 ][ field ] ).toBe( rows[ 1 ][ field ] );
						}
					}
					expect( variables.counter.json ).toBe( [ false, false ] );
					expect( variables.counter.bindings ).toBe( [ 5, 5 ] );
				} );
				it( "falls back for SQL nulls and JSON batches above the 8MiB UTF8 bound", function() {
					makePublic( variables.provider, "insertBulkRows" );
					var large = repeatString( "é", 2200000 );
					var entries = makeEntries( 2 );
					for ( var entry in entries ) {
						entry.job.setProperties( { "text" : large } );
					}
					variables.provider.pushMany( entries );
					expect( queryRows().len() ).toBe( 2 );
					expect( variables.counter.json ).toBe( [ false ] );
					expect( variables.counter.bindings ).toBe( [ 10 ] );
					var failed = false;
					transaction action="setsavepoint" savepoint="null_binding";
					try {
						variables.provider.insertBulkRows( [
							{
								"queue" : {
									"value" : "",
									"cfsqltype" : "varchar",
									"null" : true
								},
								"payload" : {
									"value" : "{}",
									"cfsqltype" : "varchar"
								},
								"attempts" : { "value" : 0, "cfsqltype" : "bigint" },
								"createdDate" : 1700000000,
								"availableDate" : 1700000000
							}
						] );
					} catch ( any failure ) {
						failed = true;
						transaction action="rollback" savepoint="null_binding";
					}
					expect( failed ).toBeTrue();
					expect( variables.counter.json ).toBe( [ false, false ] );
					expect( queryRows().len() ).toBe( 2 );
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
