component extends="AbstractJob" {

	function handle() {
		throw( type = "cbq.NonExecutableJob", message = "Tried to handle a non-executable job" );
	}

}
