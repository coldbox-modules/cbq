component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBProvider bulk persistence", function() {
			beforeEach( function() {
				var mapping = getWireBox().getBinder().getMapping( "DBProvider@cbq" );
				variables.provider = getWireBox().buildInstance( mapping );
				getWireBox().autowire( target = variables.provider, mapping = mapping );
				variables.provider.setProperties( {} );
				variables.queue = "bulk-" & createUUID();
			} );
			it( "persists independent long-text jobs across the 100-row boundary with native dates and bigint attempts", function() {
				transaction {
					try {
						var entries = makeEntries( 205 );
						var before = variables.provider.getCurrentUnixTimestamp();
						variables.provider.pushMany( entries );
						var after = variables.provider.getCurrentUnixTimestamp();
						var rows = queryRows();
						expect( rows.len() ).toBe( 205 );
						var seen = {};
						for ( var row in rows ) {
							var payload = deserializeJSON( row.payload );
							var ordinal = payload.properties.ordinal;
							expect( seen ).notToHaveKey( ordinal );
							seen[ ordinal ] = true;
							expect( payload.properties.text ).toBe( entries[ ordinal ].job.getProperties().text );
							expect( row.attempts ).toBe( 2147483648 );
							expect( row.createdDate >= before && row.createdDate <= after ).toBeTrue();
							expect( row.availableDate >= before + 17 && row.availableDate <= after + 17 ).toBeTrue();
						}
					} finally {
						transaction action="rollback";
					}
				}
				expect( queryRows() ).toBeEmpty();
			} );
			it( "lets a caller roll back earlier chunks when later job serialization fails", function() {
				var failed = false;
				var partialCount = 0;
				try {
					transaction {
						var entries = makeEntries( 101 );
						entries[ 101 ].job = "invalid job";
						try {
							variables.provider.pushMany( entries );
						} catch ( any e ) {
							partialCount = queryRows().len();
							rethrow;
						}
					}
				} catch ( any e ) {
					failed = true;
				}
				expect( failed ).toBeTrue();
				expect( partialCount ).toBe( 100 );
				expect( queryRows() ).toBeEmpty();
			} );
			it( "does not insert an empty input", function() {
				variables.provider.pushMany( [] );
				expect( queryRows() ).toBeEmpty();
			} );
		} );
	}
	private array function makeEntries( required numeric count ) {
		var result = [];
		for ( var i = 1; i <= arguments.count; i++ ) {
			result.append( {
				"queueName" : variables.queue,
				"job" : getInstance( "SendWelcomeEmailJob" ).setProperties( {
					"ordinal" : i,
					"text" : repeatString( "José 00123 " & chr( 34 ) & chr( 92 ) & chr( 10 ), 1000 )
				} ),
				"delay" : 17,
				"attempts" : 2147483648
			} );
		}
		return result;
	}
	private array function queryRows() {
		return variables.provider
			.newQuery()
			.from( "cbq_jobs" )
			.where( "queue", variables.queue )
			.orderBy( "id" )
			.get();
	}

}
