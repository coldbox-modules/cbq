component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "smoke test", function() {
			it( "can load the module", function() {
				expect( getController().getModuleService().isModuleActive( "cbq" ) ).toBeTrue();
			} );
		} );
	}

}
