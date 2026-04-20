component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "SyncProvider onFailure exception argument", function() {
			beforeEach( function() {
				structDelete( application, "onFailureExceptionReceived" );
				structDelete( application, "onFailureExceptionHasExcpetionKey" );
			} );

			it( "passes the exception as 'exception' (not 'excpetion') to the onFailure handler", function() {
				var provider = getWireBox().getInstance( "SyncProvider@cbq" ).setProperties( {} );
				var pool = makeWorkerPool( provider );
				var job = getInstance( "OnFailureCapturingJob" )
					.setId( createUUID() )
					.setCurrentAttempt( 1 )
					.setMaxAttempts( 1 );

				param application.onFailureExceptionReceived = false;
				param application.onFailureExceptionHasExcpetionKey = true;

				expect( () => provider.marshalJob( job, pool ) ).toThrow();

				expect( application.onFailureExceptionReceived ).toBeTrue(
					"onFailure should receive the exception under the key 'exception'"
				);
				expect( application.onFailureExceptionHasExcpetionKey ).toBeFalse(
					"onFailure should NOT receive the exception under the misspelled key 'excpetion'"
				);
			} );
		} );
	}

	private any function makeWorkerPool( required any provider ) {
		var connection = getInstance( "QueueConnection@cbq" )
			.setName( "TestOnFailureConnection" )
			.setProvider( arguments.provider );

		return getInstance( "WorkerPool@cbq" )
			.setName( "TestOnFailurePool" )
			.setConnection( connection )
			.setConnectionName( connection.getName() )
			.startWorkers();
	}

}
