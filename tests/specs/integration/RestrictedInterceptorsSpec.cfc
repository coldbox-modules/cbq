component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function beforeAll() {
		super.beforeAll();
		controller
			.getInterceptorService()
			.registerInterceptor( interceptorObject = this, interceptorName = "RestrictedInterceptorsSpec" );
		setUpAOPListeners();
	}

	function run() {
		describe( "interceptors", () => {
			beforeEach( function() {
				structDelete( application, "onCBQJobMarshalledRestricted" );
				structDelete( application, "onCBQJobCompleteRestricted" );
				structDelete( application, "onCBQJobExceptionRestricted" );
				structDelete( application, "onCBQJobFailedRestricted" );
			} );
			it( "can listen to custom interception points", () => {
				var provider = getWireBox().getInstance( "SyncProvider@cbq" );
				var workerPool = makeWorkerPool( provider );
				var job = getInstance( "SendWelcomeEmailJob" );

				param application.onCBQJobMarshalledRestricted = false;
				param application.onCBQJobCompleteRestricted = false;
				param application.onCBQJobExceptionRestricted = false;
				param application.onCBQJobFailedRestricted = false;

				expect( application.onCBQJobMarshalledRestricted ).toBeFalse();
				expect( application.onCBQJobCompleteRestricted ).toBeFalse();
				expect( application.onCBQJobExceptionRestricted ).toBeFalse();
				expect( application.onCBQJobFailedRestricted ).toBeFalse();

				// work the job
				var jobFuture = provider.marshalJob( job, workerPool );
				// if it is an async operation, wait for it to finish
				if ( !isNull( jobFuture ) ) {
					jobFuture.get();
				}

				expect( application.onCBQJobMarshalledRestricted ).toBeFalse( "The onCBQJobMarshalledRestricted interceptor should not have been called since the jobPattern does not match." );
				expect( application.onCBQJobCompleteRestricted ).toBeTrue( "The onCBQJobCompleteRestricted interceptor should have been called." );
				expect( application.onCBQJobExceptionRestricted ).toBeFalse();
				expect( application.onCBQJobFailedRestricted ).toBeFalse();
			} );
		} );
	}

	function onCBQJobMarshalled( event, data ) jobPattern="ReleaseTestJob" {
		application.onCBQJobMarshalledRestricted = true;
	}

	function onCBQJobComplete( event, data ) jobPattern=".*Job" {
		application.onCBQJobCompleteRestricted = true;
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

	private void function setUpAOPListeners() {
		var binder = controller.getWireBox().getBinder();
		if ( !binder.getListeners().some( ( listener ) => listener.class.contains( "aop.Mixer" ) ) ) {
			binder.listener(
				class = "coldbox.system.aop.Mixer",
				properties = {},
				register = true
			);
		}
		binder.mapAspect( "CBQJobInterceptorRestriction" ).to( "cbq.models.JobInterceptorRestriction" );
		binder.bindAspect(
			binder.match().any(),
			binder
				.match()
				.methods( "onCBQJobAdded,onCBQJobMarshalled,onCBQJobComplete,onCBQJobException,onCBQJobFailed" )
				.annotatedWith( "jobPattern" ),
			"CBQJobInterceptorRestriction"
		);
		controller.getWireBox().autowire( this );
	}

}
