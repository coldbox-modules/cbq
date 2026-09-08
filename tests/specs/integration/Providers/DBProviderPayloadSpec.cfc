component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBProvider text payload persistence", function() {
			beforeEach( function() {
				variables.provider = getWireBox()
					.buildInstance( getWireBox().getBinder().getMapping( "DBProvider@cbq" ) )
					.setProperties( {} );
				getWireBox().autowire(
					target = variables.provider,
					mapping = getWireBox().getBinder().getMapping( "DBProvider@cbq" )
				);
				variables.queue = "payload-#createUUID()#";
			} );
			afterEach( function() {
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.where( "queue", variables.queue )
					.delete();
			} );
			it( "round trips long JSON text, literal escapes and nested values with bigint attempts", function() {
				var properties = {
					"text" : repeatString( "José with quotes, dates 2026-09-08 and 00123. ", 1000 ),
					"quote" : chr( 34 ),
					"slash" : chr( 92 ),
					"line" : chr( 10 ),
					"nested" : {
						"empty" : "",
						"values" : [ true, false, 1, "00123" ]
					}
				};
				var job = getInstance( "SendWelcomeEmailJob" ).setProperties( properties );
				var before = variables.provider.getCurrentUnixTimestamp();
				variables.provider.push(
					queueName = variables.queue,
					job = job,
					delay = 17,
					attempts = 2147483648
				);
				var after = variables.provider.getCurrentUnixTimestamp();
				var row = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "queue", variables.queue )
					.first();
				expect( compare( row.queue, variables.queue ) ).toBe( 0 );
				expect( row.attempts ).toBe( 2147483648 );
				expect( row.createdDate >= before && row.createdDate <= after ).toBeTrue();
				expect( row.availableDate >= before + 17 && row.availableDate <= after + 17 ).toBeTrue();
				expect( deserializeJSON( row.payload ).properties ).toBe( properties );
			} );
			it( "preserves a numeric-looking queue name without normalizing its leading zeros", function() {
				variables.queue = "000" & randRange( 100000000, 999999999 );
				variables.provider.push(
					variables.queue,
					getInstance( "SendWelcomeEmailJob" ),
					17
				);
				var row = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.where( "queue", variables.queue )
					.first();
				expect( compare( row.queue, variables.queue ) ).toBe( 0 );
			} );
		} );
	}

}
