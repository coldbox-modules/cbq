component extends="cbq.models.Jobs.AbstractJob" {

	function handle() {
		throw(
			type = "cbq.tests.OnFailureCapturingJob",
			message = "This job always errors to test the onFailure exception argument."
		);
	}

	function onFailure() {
		application.onFailureExceptionReceived = !isNull( arguments.exception );
		application.onFailureExceptionIsExpcetion = structKeyExists( arguments, "excpetion" );
	}

}
