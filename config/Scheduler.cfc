component {

    property name="settings" inject="coldbox:moduleSettings:cbq";
    property name="log" inject="logbox:logger:{this}";

    function configure() {
        task( "cbq:scale-worker-pools" )
            .call( function() {
                var config = variables.wirebox.getInstance( "Config@cbq" );
                if ( structKeyExists( config, "scale" ) ) {
                    return config.scale();
                }
            } )
            .delay( variables.settings.scaleInterval, "seconds" )
            .every( variables.settings.scaleInterval, "seconds" )
            .setDisabled( variables.settings.scaleInterval <= 0 );
    }


	function onShutdown( boolean force = false, numeric timeout = variables.shutdownTimeout ) {
		systemOutput( "Shutting down cbq scheduler", true );
		if ( variables.log.canDebug() ) {
			variables.log.debug( "Shutting down cbq scheduler", {
				"force": force,
				"timeout": timeout
			} );
		}

		var config = variables.wirebox.getInstance( "Config@cbq" );
		var workerPoolMap = config.getWorkerPools();
		for ( var workerPoolName in workerPoolMap ) {
			var workerPool = workerPoolMap[ workerPoolName ];
			workerPool.shutdown( argumentCollection = arguments );
		}

		if ( variables.log.canDebug() ) {
			variables.log.debug( "Finished shutting down cbq scheduler", {
				"force": force,
				"timeout": timeout
			} );
		}
	}

    function beforeAnyTask( task ) {
        if ( variables.log.canDebug() ) {
            variables.log.debug( "[#arguments.task.getName()#] starting on #getThreadName()#..." );
        }
    }

    function onAnyTaskSuccess( task, result ) {
        if ( variables.log.canDebug() ) {
            variables.log.debug( "[#arguments.task.getName()#] complete." );
        }
    }

    function onAnyTaskError( task, exception ) {
        if ( variables.log.canError() ) {
            var message = structKeyExists( arguments.exception, "getMessage" ) ? arguments.exception.getMessage() : arguments.exception.message;
            variables.log.error(
                "Exception when running task [#arguments.task.getName()#]: #message#",
                {
                    "task": getTaskMemento( task ),
                    "exception": exception
                }
            );
        }
    }

    private struct function getTaskMemento( task ) {
        return {
            "delay": task.getDelay(),
            "period": task.getPeriod(),
            "spacedDelay": task.getSpacedDelay(),
            "timeunit": task.getTimeunit(),
            "name": task.getName(),
            "disabled": task.getDisabled(),
            "timezone": task.getTimezone(),
            "stats": task.getStats(),
            "dayOfTheMonth": task.getDayOfTheMonth(),
            "dayOfTheWeek": task.getDayOfTheWeek(),
            "weekends": task.getWeekends(),
            "weekdays": task.getWeekdays(),
            "lastBusinessDay": task.getLastBusinessDay(),
            "noOverlaps": task.getNoOverlaps()
        };
    }

}