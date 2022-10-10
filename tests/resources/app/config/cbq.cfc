component accessors="true" {

	function configure() {
		this.scaleCalled = false;
		newConnection( "default" ).setProvider( "ColdBoxAsyncProvider@cbq" ).setProperties( {} );

		newWorkerPool( "default" );
	}

	function testing() {
		param request.cbq = {};
		request.cbq.testingCalled = true;
	}

	function scale() {
		this.scaleCalled = true;
	}

	function getScaleInterval() {
		return 1;
	}

}
