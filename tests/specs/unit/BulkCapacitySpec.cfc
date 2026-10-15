component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "provider bulk capacity", function() {
			it( "keeps providers without a capability at 100, including push-only providers", function() {
				var connection = new cbq.models.Connections.QueueConnection().setProvider( {
					"push" : function() {
					}
				} );
				expect( connection.getMaxBulkDispatchBatchSize() ).toBe( 100 );
				expect( new cbq.models.Providers.DBProvider().setProperties( {} ).getMaxBulkDispatchBatchSize() ).toBe(
					100
				);
			} );
			it( "rejects invalid database caps without changing caller properties", function() {
				var provider = new cbq.models.Providers.DBProvider();
				for (
					var invalid in [
						0,
						-1,
						1.5,
						1001,
						"invalid",
						"",
						[],
						{}
					]
				) {
					expect( function() {
						provider.setProperties( { "bulkInsertBatchSize" : invalid } );
					} ).toThrow( "cbq.DBProvider.InvalidBulkInsertBatchSize" );
				}
				var properties = {};
				provider.setProperties( properties );
				expect( properties ).toBe( {} );
			} );
			it( "rejects larger batches for SQL Server, SQLite, and unrecognized grammars before hooks or writes", function() {
				for (
					var grammar in [
						new qb.models.Grammars.SQLServerGrammar(),
						new qb.models.Grammars.SQLiteGrammar(),
						new qb.models.Grammars.BaseGrammar()
					]
				) {
					var provider = createMock( "cbq.models.Providers.DBProvider" ).setProperties( { "bulkInsertBatchSize" : 1000 } );
					provider.$( "newQuery", new qb.models.Query.QueryBuilder( grammar = grammar ) );
					var calls = [];
					var connection = new cbq.models.Connections.QueueConnection().setProvider( provider );
					var dispatcher = dispatcherFor( connection, calls );
					expect( function() {
						dispatcher.bulkDispatch( jobs = jobs( 1 ), batchSize = 1000 );
					} ).toThrow( "cbq.DBProvider.UnsupportedBulkInsertBatchSize" );
					expect( calls ).toBeEmpty();
				}
			} );
			it( "validates declared capacity before calling any hooks on custom providers", function() {
				for ( var cap in [ 100, 0, 1001, 2.5 ] ) {
					var calls = [];
					var provider = {
						"getMaxBulkDispatchBatchSize" : function() {
							return cap;
						},
						"pushMany" : function() {
							calls.append( "write" );
						}
					};
					var connection = new cbq.models.Connections.QueueConnection().setProvider( provider );
					var dispatcher = dispatcherFor( connection, calls );
					expect( function() {
						dispatcher.bulkDispatch( jobs = jobs( 1 ), batchSize = 1000 );
					} ).toThrow( "cbq.InvalidDispatchBatchSize" );
					expect( calls ).toBeEmpty();
				}
			} );
			it( "preserves every native hook and ordinal over 1001 and 2005 jobs", function() {
				for ( var total in [ 1001, 2005 ] ) {
					var calls = [];
					var batches = [];
					var provider = {
						"getMaxBulkDispatchBatchSize" : function() {
							return 1000;
						},
						"pushMany" : function( entries ) {
							batches.append( entries );
							calls.append( "write:" & entries.len() );
						}
					};
					var connection = new cbq.models.Connections.QueueConnection().setProvider( provider );
					dispatcherFor( connection, calls ).bulkDispatch( jobs = jobs( total ), batchSize = 1000 );
					expect( batches.map( ( entries ) => entries.len() ) ).toBe(
						total == 1001 ? [ 1000, 1 ] : [ 1000, 1000, 5 ]
					);
					var ordinal = 0;
					var cursor = 0;
					for ( var batch in batches ) {
						for ( var entry in batch ) {
							ordinal++;
							expect( entry.job.getProperties().ordinal ).toBe( ordinal );
							expect( entry.job.getCurrentAttempt() ).toBe( 0 );
							expect( entry.attempts ).toBe( 0 );
							expect( calls[ ++cursor ] ).toBe( "onCBQJobAdded:" & ordinal );
						}
						expect( calls[ ++cursor ] ).toBe( "write:" & batch.len() );
						for ( var entry in batch ) {
							expect( calls[ ++cursor ] ).toBe( "onCBQJobPublished:" & entry.job.getProperties().ordinal );
						}
					}
					expect( ordinal ).toBe( total );
					expect( cursor ).toBe( calls.len() );
				}
			} );
			it( "announces failure for the failed chunk without publishing its tail", function() {
				var calls = [];
				var writes = 0;
				var provider = {
					"getMaxBulkDispatchBatchSize" : function() {
						return 1000;
					},
					"pushMany" : function( entries ) {
						if ( ++writes == 2 ) {
							throw( type = "FixtureWriteFailure" );
						}
					}
				};
				var connection = new cbq.models.Connections.QueueConnection().setProvider( provider );
				var dispatcher = dispatcherFor( connection, calls );
				expect( function() {
					dispatcher.bulkDispatch( jobs = jobs( 2005 ), batchSize = 1000 );
				} ).toThrow( "FixtureWriteFailure" );
				expect( calls.filter( ( value ) => value.left( 14 ) == "onCBQJobAdded:" ).len() ).toBe( 2000 );
				expect( calls.filter( ( value ) => value.find( "onCBQJobPublished:" ) == 1 ).len() ).toBe( 1000 );
				expect( calls.filter( ( value ) => value.find( "onCBQJobPublishException:" ) == 1 ).len() ).toBe( 1000 );
			} );
		} );
	}

	private any function dispatcherFor( required any connection, required array calls ) {
		var capturedConnection = arguments.connection;
		var capturedCalls = arguments.calls;
		return new cbq.models.Jobs.Dispatcher()
			.setConfig( {
				"getDefaultConnectionName" : function() {
					return "default";
				},
				"getConnection" : function( name ) {
					return capturedConnection;
				}
			} )
			.setInterceptorService( {
				"announce" : function( state, data ) {
					capturedCalls.append( state & ":" & data.job.getProperties().ordinal );
				}
			} );
	}

	private array function jobs( required numeric count ) {
		var result = [];
		for ( var i = 1; i <= arguments.count; i++ ) {
			result.append(
				new cbq.models.Jobs.AbstractJob()
					.setMapping( "FixtureJob" )
					.setProperties( { "ordinal" : i } )
					.setCurrentAttempt( 9 )
			);
		}
		return result;
	}

}
