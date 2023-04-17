component extends="coldbox.system.testing.BaseTestCase" {

    this.unloadColdBox = false;

    function beforeAll() {
        super.beforeAll();

        getController().getModuleService()
            .registerAndActivateModule( "cbq", "testingModuleRoot" );
        getController().getInterceptorService().announce( "afterAspectsLoad" );

        param request.reloadDatabase = false;
        if ( !request.reloadDatabase ) {
            refreshDatabase();
            request.reloadDatabase = true;
        }
    }

    /**
    * @beforeEach
    */
    function setupIntegrationTest() {
        setup();
    }

    private void function refreshDatabase() {
        getController().getModuleService()
            .registerAndActivateModule( "cfmigrations", "testingModuleRoot" );
        var migrationManager = getWireBox().getInstance( "QBMigrationManager@cfmigrations" );
        var migrationService = application.wirebox.getInstance( "MigrationService@cfmigrations" );
		migrationService.setMigrationsDirectory( "/cbq/resources/database/migrations" );
		migrationService.setSeedsDirectory( "/cbq/resources/database/seeds" );
		migrationService.setSeedEnvironments( [ "development", "testing" ] );
		migrationService.setManager(
			migrationManager
				.setDefaultGrammar( "MySQLGrammar@qb" )
				.setDatasource( "cbq" )
				.setSchema( "cbq" )
		);
		migrationService.install();
        migrationService.reset();
        migrationService.runAllMigrations( "up" );
    }

    public any function $spy( required any object, required string method ) {
        return prepareMock( arguments.object ).$(
            method = arguments.method,
            callback = arguments.object[ arguments.method ]
        );

    }

}
