component {

	this.name = "cbq";
	this.author = "Eric Peterson";
	this.webUrl = "https://github.com/coldbox-modules/cbq";
	this.cfmapping = "cbq";

	variables.customInterceptionPointMethodNames = "onCBQJobAdded,onCBQJobMarshalled,onCBQJobComplete,onCBQJobException,onCBQJobFailed";

	function configure() {
		settings = {
			// The path the custom config file to register connections and worker pools
			"configPath" : "config.cbq",
			// Flag if workers should be registered.
			// If your application only pushes to the queues, you can set this to `false`.
			"registerWorkers" : getSystemSetting( "CBQ_REGISTER_WORKERS", true ),
			// The interval to poll for changes to the worker pool scaling.
			// Defaults to 0 which turns off the scheduled scaling feature.
			"scaleInterval" : 0,
			// The default amount of time, in seconds, to delay a job.
			// Used if the connection and job doesn't define their own.
			"defaultWorkerBackoff" : 0,
			// The default amount of time, in seconds, to wait before timing out a job.
			// Used if the connection and job doesn't define their own.
			"defaultWorkerTimeout" : 60,
			// The default amount of time, in seconds, to wait for a connection to shutdown before killing it when requesting a shutdown.
			"defaultConnectionShutdownTimeout" : 60,
			// The default amount of time, in seconds, to wait for tasks to complete before killing them when requesting a shutdown.
			"defaultWorkerShutdownTimeout" : 60,
			// The default amount of attempts to try before failing a job.
			// Used if the connection and job doesn't define their own.
			"defaultWorkerMaxAttempts" : 1,
			// Datasource information for tracking batches.
			"batchRepositoryProperties" : {
				"tableName" : "cbq_batches",
				"datasource" : "", // `datasource` can also be a struct
				"queryOptions" : {}, // The sibling `datasource` property overrides any defined datasource in queryOptions.
				"cleanup" : {
					"enabled" : false,
					"frequency" : ( task ) => {
						task.everyDay();
					},
					"criteria" : ( qb, currentUnixTimestamp ) => {
						qb.where( ( q ) => {
							q.where(
								"cancelledDate",
								"<=",
								currentUnixTimestamp - ( 60 * 60 * 24 * 30 )
							); // 30 days
							q.orWhere(
								"completedDate",
								"<=",
								currentUnixTimestamp - ( 60 * 60 * 24 * 30 )
							); // 30 week
						} );
					}
				}
			},
			// Flag to turn on logging failed jobs to a database table.
			"logFailedJobs" : false,
			// Datasource information for logging failed jobs.
			"logFailedJobsProperties" : {
				"tableName" : "cbq_failed_jobs",
				"datasource" : "", // `datasource` can also be a struct.
				"queryOptions" : {}, // The sibling `datasource` property overrides any defined datasource in `queryOptions`.
				"cleanup" : {
					"enabled" : false,
					"frequency" : ( task ) => {
						task.everyDay();
					},
					"criteria" : ( q, currentUnixTimestamp ) => {
						q.where(
							"failedDate",
							"<=",
							currentUnixTimestamp - ( 60 * 60 * 24 * 30 )
						); // 30 days
					}
				}
			},
			// Flag to allow restricting Job interceptor execution using a `jobPattern` annotation.
			"registerJobInterceptorRestrictionAspect" : false
		};

		interceptorSettings = { "customInterceptionPoints" : variables.customInterceptionPointMethodNames };
		interceptors = [ { "class" : "#moduleMapping#.interceptors.LogFailedJobsInterceptor" } ];
	}

	function afterConfigurationLoad() {
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

		if ( settings.registerJobInterceptorRestrictionAspect ) {
			if ( !binder.getListeners().some( ( listener ) => listener.class.contains( "aop.Mixer" ) ) ) {
				binder.listener(
					class = "coldbox.system.aop.Mixer",
					properties = {},
					register = true
				);
			}
			binder.mapAspect( "CBQJobInterceptorRestriction" ).to( "#moduleMapping#.models.JobInterceptorRestriction" );
			binder.bindAspect(
				binder.match().any(),
				binder
					.match()
					.methods( variables.customInterceptionPointMethodNames )
					.annotatedWith( "jobPattern" ),
				"CBQJobInterceptorRestriction"
			);
		}
	}

	function onUnload() {
		for ( var pool in config.getWorkerPools() ) {
			pool.shutdown();
		}

		for ( var conn in config.getConnections() ) {
			conn.shutdown( force = false, timeout = settings.defaultConnectionShutdownTimeout );
		}
	}

}
