component extends="cbq.models.Jobs.AbstractJob" {

	function handle() {
		// do nothing
	}

	function before() {
		request.jobBeforeCalled = true;
	}

	function after() {
		request.jobAfterCalled = true;
	}

}
