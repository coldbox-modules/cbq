component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function beforeAll() {
		super.beforeAll();
		controller
			.getWireBox()
			.getBinder()
			.unMap( "CBQJobInterceptorRestriction" );
		controller
			.getInterceptorService()
			.registerInterceptor( interceptorObject = this, interceptorName = "InterceptorsSpec" );
	}

	function run() {
		describe( "interceptors", () => {
			beforeEach( function() {
				structDelete( application, "onCBQJobMarshalled" );
				structDelete( application, "onCBQJobComplete" );
				structDelete( application, "onCBQJobException" );
				structDelete( application, "onCBQJobFailed" );
			} );

			it( "can listen to custom interception points", () => {
				var provider = getWireBox().getInstance( "SyncProvider@cbq" );
				var workerPool = makeWorkerPool( provider );
				var job = getInstance( "SendWelcomeEmailJob" );

				param application.onCBQJobMarshalled = false;
				param application.onCBQJobComplete = false;
				param application.onCBQJobException = false;
				param application.onCBQJobFailed = false;

				expect( application.onCBQJobMarshalled ).toBeFalse();
				expect( application.onCBQJobComplete ).toBeFalse();
				expect( application.onCBQJobException ).toBeFalse();
				expect( application.onCBQJobFailed ).toBeFalse();

				// work the job
				var jobFuture = provider.marshalJob( job, workerPool );
				// if it is an async operation, wait for it to finish
				if ( !isNull( jobFuture ) ) {
					jobFuture.get();
				}

				expect( application.onCBQJobMarshalled ).toBeTrue( "The onCBQJobMarshalled interceptor should have been called." );
				expect( application.onCBQJobComplete ).toBeTrue( "The onCBQJobComplete interceptor should have been called." );
				expect( application.onCBQJobException ).toBeFalse();
				expect( application.onCBQJobFailed ).toBeFalse();
			} );
		} );
	}

	function onCBQJobMarshalled( event, data ) {
		application.onCBQJobMarshalled = true;
	}

	function onCBQJobComplete( event, data ) {
		application.onCBQJobComplete = true;
	}

	private function makeWorkerPool(
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
