component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "Batch Job", function() {
			it( "uses default connections and queues for lifecycle jobs", function() {
                var cbq = getInstance( "cbq@cbq" );

                var pendingBatch = cbq.batch( [] )
                    .then( cbq.job( "LifecycleSuccessJob" ) )
                    .catch( cbq.job( "LifecycleFailureJob" ) )
                    .finally( cbq.job( "LifecycleCompleteJob" ) );

				var options = pendingBatch.getOptions();
                debug( var = options );

                expect( options.thenJob?.connection ).notToBeNull();
                expect( options.thenJob?.queue ).notToBeNull();
                expect( options.catchJob?.connection ).notToBeNull();
                expect( options.catchJob?.queue ).notToBeNull();
                expect( options.finallyJob?.connection ).notToBeNull();
                expect( options.finallyJob?.queue ).notToBeNull();
			} );
		} );
	}

}
