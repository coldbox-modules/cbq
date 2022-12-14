component extends="coldbox.system.testing.BaseTestCase" {

    this.unloadColdBox = false;

    function beforeAll() {
        super.beforeAll();

        getController().getModuleService()
            .registerAndActivateModule( "cbq", "testingModuleRoot" );
        getController().getInterceptorService().announce( "afterAspectsLoad" );
    }

    /**
    * @beforeEach
    */
    function setupIntegrationTest() {
        setup();
    }

}
