component extends="cbq.models.Jobs.AbstractJob" {

	function handle() {
		throw( type = "cbq.tests.AlwaysErrorJob", message = "This job always errors for testing." );
	}

}
