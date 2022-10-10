component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "config", function() {
			describe( "connections", function() {
				it( "can register a queue connection", function() {
					// this relies on the `configure` method in the app's cbq.cfc
					var config = getWireBox().getInstance( "Config@cbq" );
					var connections = config.getConnections();
					expect( connections ).toBeStruct();
					expect( connections ).toHaveLength( 1 );
					expect( connections ).toHaveKey( "default" );
					var defaultConnection = config.getConnection( "default" );
					expect( defaultConnection.getName() ).toBe( "default" );
					var defaultConnectionProvider = defaultConnection.getProvider();
					expect( defaultConnectionProvider.getName() ).toBe( "ColdBoxAsyncProvider@cbq" );
					expect( defaultConnectionProvider.getProperties() ).toBe( {} );
				} );

				it( "throws an exception when trying to get a queue connection that does not exist", function() {
					expect( function() {
						var config = getWireBox().getInstance( "Config@cbq" );
						config.getConnection( "does-not-exist" );
					} ).toThrow( type = "cbq.MissingQueueConnection" );
				} );

				it( "defaults the queue connection to default", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					expect( config.getDefaultConnectionName() ).toBe( "default" );
				} );

				it( "can set a new default connection via a connection definition", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					config
						.newConnection( "defaultTwo" )
						.markAsDefault()
						.provider( "ColdBoxAsyncProvider@cbq" )
						.setProperties( {} )
						.register();
					expect( config.getDefaultConnectionName() ).toBe( "defaultTwo" );
				} );

				it( "can set a new default connection via a method", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					config.setDefaultConnectionName( "newDefault" );
					expect( config.getDefaultConnectionName() ).toBe( "newDefault" );
				} );

				it( "calls methods corresponding to the environment", function() {
					expect( request ).toHaveKey( "cbq" );
					expect( request.cbq ).toHaveKey( "testingCalled" );
					expect( request.cbq.testingCalled ).toBeTrue();
				} );
			} );

			describe( "workers", function() {
				it( "can create a worker pool with default values", function() {
					// this relies on the `work` method in the app's cbq.cfc
					var config = getWireBox().getInstance( "Config@cbq" );
					var workerPools = config.getWorkerPools();
					expect( workerPools ).toBeStruct();
					expect( workerPools ).toHaveLength( 1 );
					expect( workerPools ).toHaveKey( "default" );
					var defaultWorkerPool = config.getWorkerPool( "default" );
					expect( defaultWorkerPool.getConnectionName() ).toBe( "default" );
					expect( defaultWorkerPool.getConnection().getName() ).toBe( "default" );
					expect( defaultWorkerPool.getQuantity() ).toBe( 1 );
					expect( defaultWorkerPool.getQueue() ).toBe( "default" );
					expect( defaultWorkerPool.getBackoff() ).toBe( 0 );
					expect( defaultWorkerPool.getTimeout() ).toBe( 60 );
					expect( defaultWorkerPool.getMaxAttempts() ).toBe( 1 );
				} );

				it( "throws an exception when the associated connection does not exist", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					var workerPoolDefinition = config.newWorkerPoolDefinitionInstance();
					workerPoolDefinition.setConnectionName( "does-not-exist" );
					expect( function() {
						workerPoolDefinition.register();
					} ).toThrow( type = "cbq.MissingQueueConnection" );
				} );

				it( "throws an exception when the worker queue does not exist", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					config.newConnection( "another" ).register();
					expect( function() {
						config.getWorkerPool( "register" );
					} ).toThrow( type = "cbq.MissingWorkerPool" );
				} );

				it( "can define a worker pool", function() {
					var config = getWireBox().getInstance( "Config@cbq" );

					var workerPoolDefinition = config.newWorkerPool( "default" );
					workerPoolDefinition.quantity( 4 );
					workerPoolDefinition.onQueue( "default" );
					workerPoolDefinition.backoff( 5 );
					workerPoolDefinition.timeout( 30 );
					workerPoolDefinition.maxAttempts( 3 );

					var workerPool = workerPoolDefinition.register();

					expect( workerPool.getConnectionName() ).toBe( "default" );
					expect( workerPool.getConnection().getName() ).toBe( "default" );
					expect( workerPool.getQuantity() ).toBe( 4 );
					expect( workerPool.getQueue() ).toBe( "default" );
					expect( workerPool.getBackoff() ).toBe( 5 );
					expect( workerPool.getTimeout() ).toBe( 30 );
					expect( workerPool.getMaxAttempts() ).toBe( 3 );
				} );
			} );

			describe( "scale", function() {
				beforeEach( function() {
					var config = getWireBox().getInstance( "Config@cbq" )
					config.reset();
					config.configure();
					config.registerConnections();
					config.registerWorkerPools();
				} );

				it( "automatically registers a scheduled task to scale when a scale method is present", function() {
					sleep( 3000 );
					var config = getWireBox().getInstance( "Config@cbq" );
					expect( config ).toHaveKey( "scaleCalled" );
					expect( config.scaleCalled ).toBeTrue();
				} );

				it( "can scale up a worker pool", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					config.reset();
					config.configure();
					config.registerConnections();

					var stopCalled = 0;
					var provider = config.getConnection( "default" ).getProvider();
					prepareMock( provider )
						.$( "startWorker" )
						.$results( function() {
							stopCalled++;
						} );
					expect( provider.$count( "startWorker" ) ).toBe( 0 );

					var workerPool = config.newWorkerPool( "default", 1 ).register();
					expect( workerPool.getQuantity() ).toBe( 1 );
					expect( workerPool.getWorkerHooks() ).toHaveLength( workerPool.getQuantity() );
					expect( provider.$count( "startWorker" ) ).toBe( 1 );
					expect( stopCalled ).toBe( 0 );

					workerPool.scale( 3 );

					expect( workerPool.getQuantity() ).toBe( 3 );
					expect( workerPool.getWorkerHooks() ).toHaveLength( workerPool.getQuantity() );
					expect( provider.$count( "startWorker" ) ).toBe( 3 );
					expect( stopCalled ).toBe( 0 );
				} );

				it( "can scale down a worker pool", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					config.reset();
					config.configure();
					config.registerConnections();

					var stopCalled = 0;
					var provider = config.getConnection( "default" ).getProvider();
					prepareMock( provider )
						.$( "startWorker" )
						.$results( function() {
							stopCalled++;
						} );
					expect( provider.$count( "startWorker" ) ).toBe( 0 );

					var workerPool = config.newWorkerPool( "default", 3 ).register();
					expect( workerPool.getQuantity() ).toBe( 3 );
					expect( workerPool.getWorkerHooks() ).toHaveLength( workerPool.getQuantity() );
					expect( provider.$count( "startWorker" ) ).toBe( 3 );
					expect( stopCalled ).toBe( 0 );

					workerPool.scale( 1 );

					expect( workerPool.getQuantity() ).toBe( 1 );
					expect( workerPool.getWorkerHooks() ).toHaveLength( workerPool.getQuantity() );
					expect( provider.$count( "startWorker" ) ).toBe( 3 );
					expect( stopCalled ).toBe( 2 );
				} );

				it( "does nothing if the configuration remains the same", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					config.reset();
					config.configure();
					config.registerConnections();

					var stopCalled = 0;
					var provider = config.getConnection( "default" ).getProvider();
					prepareMock( provider )
						.$( "startWorker" )
						.$results( function() {
							stopCalled++;
						} );
					expect( provider.$count( "startWorker" ) ).toBe( 0 );

					var workerPool = config.newWorkerPool( "default", 3 ).register();
					expect( workerPool.getQuantity() ).toBe( 3 );
					expect( workerPool.getWorkerHooks() ).toHaveLength( workerPool.getQuantity() );
					expect( provider.$count( "startWorker" ) ).toBe( 3 );
					expect( stopCalled ).toBe( 0 );

					workerPool.scale( 3 );

					expect( workerPool.getQuantity() ).toBe( 3 );
					expect( workerPool.getWorkerHooks() ).toHaveLength( workerPool.getQuantity() );
					expect( provider.$count( "startWorker" ) ).toBe( 3 );
					expect( stopCalled ).toBe( 0 );
				} );

				it( "automatically shuts down a worker pool if the worker pool for the queue connection is replaced", function() {
					var config = getWireBox().getInstance( "Config@cbq" );
					config.reset();
					config.configure();
					config.registerConnections();

					var stopCalled = 0;
					var provider = config.getConnection( "default" ).getProvider();
					prepareMock( provider )
						.$( "startWorker" )
						.$results( function() {
							stopCalled++;
						} );
					expect( provider.$count( "startWorker" ) ).toBe( 0 );

					var workerPool = config.newWorkerPool( "default", 1 ).register();
					expect( workerPool.getQuantity() ).toBe( 1 );
					expect( workerPool.getWorkerHooks() ).toHaveLength( workerPool.getQuantity() );
					expect( provider.$count( "startWorker" ) ).toBe( 1 );
					expect( stopCalled ).toBe( 0 );

					var workerPoolUpdated = config.newWorkerPool( "default", 3 ).register();

					expect( workerPoolUpdated.getQuantity() ).toBe( 3 );
					expect( workerPoolUpdated.getWorkerHooks() ).toHaveLength( workerPoolUpdated.getQuantity() );
					expect( provider.$count( "startWorker" ) ).toBe( 4 );

					expect( workerPool.getQuantity() ).toBe( 0 );
					expect( workerPool.getWorkerHooks() ).toHaveLength( workerPool.getQuantity() );
					expect( stopCalled ).toBe( 1 );
				} );
			} );
		} );
	}

}
