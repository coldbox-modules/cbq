component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "database provider queue health", function() {
			beforeEach( function() {
				variables.provider = getWireBox()
					.getInstance( "DBProvider@cbq" )
					.setProperties( { datasource : "cbq" } );
				variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.delete();
			} );
			afterEach( function() {
				variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.delete();
			} );
			it( "returns measured zeros for an empty queue", function() {
				var snapshot = variables.provider.getQueueHealth( "mail" );
				expect( snapshot.depth ).toBe( 0 );
				expect( snapshot.runnable ).toBe( 0 );
				expect( snapshot.reserved ).toBe( 0 );
				expect( snapshot.oldestAgeSeconds ).toBe( 0 );
			} );
			it( "reads selected queues without reserving jobs or mixing in other queues", function() {
				variables.provider.push( "mail", getWireBox().getInstance( "SendWelcomeEmailJob" ) );
				variables.provider.push( "pdf", getWireBox().getInstance( "SendWelcomeEmailJob" ) );
				variables.provider.push( "mail' OR 1=1 --", getWireBox().getInstance( "SendWelcomeEmailJob" ) );
				expect( variables.provider.getQueueHealth( [ "mail", "pdf" ] ).depth ).toBe( 2 );
				expect( variables.provider.getQueueHealth( "*" ).depth ).toBe( 3 );
				expect( variables.provider.getQueueHealth( [ "*" ] ).depth ).toBe( 3 );
				expect( variables.provider.getQueueHealth( "mail' OR 1=1 --" ).depth ).toBe( 1 );
				expect( variables.provider.getQueueHealth( "*" ).reserved ).toBe( 0 );
			} );
		} );
	}

}
