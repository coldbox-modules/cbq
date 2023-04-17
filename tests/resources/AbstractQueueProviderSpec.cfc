component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

    function run() {
        describe( "queue provider - #getProviderMapping()#", function() {
            it( "can manually release a job back on to a queue with a given delay", function() {
                var provider = getProvider();
                $spy( provider, "releaseJob" );
                var workerPool = makeWorkerPool( provider );
                var job = getInstance( "ReleaseTestJob" )
                    .setCurrentAttempt( 1 )
                    .setId( randRange( 1, 1000 ) )
                    .setMaxAttempts( 2 );

                // work the job
                var jobFuture = provider.marshalJob( job, workerPool );
                // if it is an async operation, wait for it to finish
                if ( !isNull( jobFuture ) ) {
                    jobFuture.get();
                }

                // inspect the spy
                expect( provider.$once( "releaseJob" ) ).toBeTrue( "releaseJob should have been called on the provider" );
                var callLog = provider.$callLog()[ "releaseJob" ][ 1 ];
                expect( provider.getBackoffForJob( callLog[ 1 ], callLog[ 2 ] ) ).toBe( 2, "The delay [2] should have been passed to the provider" );
            } );

            it( "does not manually release a job back on to a queue if the maximum attempts have been reached", function() {
                var provider = getProvider();
                $spy( provider, "releaseJob" );
                var workerPool = makeWorkerPool( provider );
                var job = getInstance( "ReleaseTestJob" )
                    .setCurrentAttempt( 1 )
                    .setId( randRange( 1, 1000 ) )
                    .setMaxAttempts( 1 );

                // work the job
                try {
                    var jobFuture = provider.marshalJob( job, workerPool );
                    // if it is an async operation, wait for it to finish
                    if ( !isNull( jobFuture ) ) {
                        jobFuture.get();
                    }
                } catch ( cbq.MaxAttemptsReached e ) {
                    // ignore
                } catch ( any e ) {
                    fail( "Unexpected exception: #e.message#", e.detail );
                }

                // if it is an async operation, wait for it to finish
                if ( !isNull( jobFuture ) ) {
                    jobFuture.get();
                }

                // inspect the spy
                expect( provider.$never( "releaseJob" ) ).toBeTrue( "releaseJob should not have been called on the provider since the job was at its max attempts." );
                expect( job ).toHaveKey( "onFailureCalled" );
                expect( job.onFailureCalled ).toBeTrue( "onFailure should have been called on the job" );
            } );

            it( "will always release a job with a maxAttempts of 0 regardless of the currentAttempt count", function() {
                var provider = getProvider();
                $spy( provider, "releaseJob" );
                var workerPool = makeWorkerPool( provider );
                var job = getInstance( "ReleaseTestJob" )
                    .setCurrentAttempt( 1000000 ) // one million
                    .setId( randRange( 1, 1000 ) )
                    .setMaxAttempts( 0 );

                // work the job
                var jobFuture = provider.marshalJob( job, workerPool );
                // if it is an async operation, wait for it to finish
                if ( !isNull( jobFuture ) ) {
                    jobFuture.get();
                }

                // inspect the spy
                expect( provider.$once( "releaseJob" ) ).toBeTrue( "releaseJob should have been called on the provider" );
                var callLog = provider.$callLog()[ "releaseJob" ][ 1 ];
                expect( provider.getBackoffForJob( callLog[ 1 ], callLog[ 2 ] ) ).toBe( 2, "The delay [2] should have been passed to the provider" );
            } );
        } );
    }

    function getProvider() {
        return duplicate( getWireBox().getInstance( getProviderMapping() ) );
    }

    function getProviderMapping() {
        throw(
            type = "MissingAbstractMethod",
            message = "This is an abstract method and must be implemented in a subclass."
        );
    }

    function makeWorkerPool(
        any provider = getProvider(),
        string connectionName = "TestConnection",
        string workerPoolName = ""
    ) {
        var connection = getInstance( "QueueConnection@cbq" )
            .setName( arguments.connectionName )
            .setProvider( arguments.provider );

        return getInstance( "WorkerPool@cbq" )
            .setName( arguments.workerPoolName )
            .setConnection( connection )
            .setConnectionName( connection.getName() )
            .startWorkers();
    }

}