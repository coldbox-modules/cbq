component {

	this.name = "cbq";
	this.author = "Eric Peterson";
	this.webUrl = "https://github.com/coldbox-modules/cbq";
	this.cfmapping = "cbq";

	function configure() {
		settings = {
			"configPath" : "config.cbq",
			"registerWorkers" : getSystemSetting( "CBQ_REGISTER_WORKERS", true ),
			"scaleInterval" : 0,
			"defaultWorkerBackoff" : 0,
			"defaultWorkerTimeout" : 60,
			"defaultWorkerMaxAttempts" : 1,
			"batchRepositoryProperties" : {
				"tableName" : "cbq_batches",
				"queryOptions" : {}
			}
		};
	}

	function onLoad() {
		var configName = "Config@cbq";
		variables.wirebox
			.registerNewInstance( name = configName, instancePath = settings.configPath )
			.setVirtualInheritance( "BaseConfig@cbq" )
			.setThreadSafe( true )
			.setScope( variables.wirebox.getBinder().SCOPES.SINGLETON );

		var config = variables.wirebox.getInstance( configName );

		config.configure();

		// Get ColdBox environment settings and if same convention of 'environment'() found, execute it.
		var environment = variables.controller.getSetting( "ENVIRONMENT" );
		if ( structKeyExists( config, environment ) ) {
			invoke( config, environment );
		}

		config.registerConnections();
		if ( settings.registerWorkers ) {
			config.registerWorkerPools();
		}
	}

}
