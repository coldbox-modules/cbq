component {

	// Configure ColdBox Application
	function configure() {
		// coldbox directives
		coldbox = {
			// Application Setup
			appName : "Your app name here",
			eventName : "event",
			// Development Settings
			reinitPassword : "",
			handlersIndexAutoReload : true,
			// Implicit Events
			requestStartHandler : "Main.onRequestStart",
			applicationStartHandler : "Main.onAppInit",
			applicationHelper : "includes/helpers/ApplicationHelper.cfm",
			modulesExternalLocation : [ "modules_app" ],
			exceptionHandler : "main.onException",
			customErrorTemplate : "/coldbox/system/exceptions/Whoops.cfm"
		};

		// custom settings
		settings = {};

		// environment settings, create a detectEnvironment() method to detect it yourself.
		// create a function with the name of the environment so it can be executed if that environment is detected
		// the value of the environment is a list of regex patterns to match the cgi.http_host.
		environments = { development : "localhost,^127\.0\.0\.1" };

		// Module Directives
		moduleSettings = {
			"cbq" : {
				"configPath" : "app.config.cbq",
				"scaleInterval" : 3
			}
		};

		// LogBox DSL
		logBox = {
			// Define Appenders
			appenders : { coldboxTracer : { class : "coldbox.system.logging.appenders.ConsoleAppender" } },
			// Root Logger
			root : { levelmax : "INFO", appenders : "*" },
			// Implicit Level Categories
			info : [ "coldbox.system" ]
		};
	}

	/**
	 * Development environment
	 */
	function development() {
		coldbox.customErrorTemplate = "/coldbox/system/exceptions/BugReport.cfm";
	}

}
