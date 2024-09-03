component {

    property name="settings" inject="coldbox:moduleSettings:cbq";
    property name="log" inject="logbox:logger:{this}";

    function configure() {
        registerScaleWorkerPoolsTask();

        param variables.settings.defaultWorkerShutdownTimeout = 60;
        param variables.settings.logFailedJobsProperties = {};
        param variables.settings.logFailedJobsProperties.cleanup = {};
        param variables.settings.logFailedJobsProperties.cleanup.enabled = false;
        if ( variables.settings.logFailedJobsProperties.cleanup.enabled ) {
            registerCleanupFailedJobLogTask();
        } else {
			if ( log.canDebug() ) {
				log.debug( "Cleanup task disabled for failed job log." );
			}
		}

        param variables.settings.batchRepositoryProperties = {};
        param variables.settings.batchRepositoryProperties.cleanup = {};
        param variables.settings.batchRepositoryProperties.cleanup.enabled = false;
        if ( variables.settings.batchRepositoryProperties.cleanup.enabled ) {
            registerCleanupBatchJobsTask();
        } else {
			if ( log.canDebug() ) {
				log.debug( "Cleanup task disabled for completed and cancelled batches." );
			}
		}
    }

    private any function registerScaleWorkerPoolsTask() {
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

    private any function registerCleanupFailedJobLogTask() {
		var cleanupCriteria = function( q, currentUnixTimestamp ) {
			q.where( "failedDate", "<=", currentUnixTimestamp - ( 60 * 60 * 24 * 30 ) ); // 30 days
		};
		param variables.settings.logFailedJobsProperties.cleanup.criteria = cleanupCriteria;

        param variables.settings.logFailedJobsProperties.tableName = "cbq_failed_jobs";

        var options = {};
		param variables.settings.logFailedJobsProperties.queryOptions = {};
		structAppend( options, variables.settings.logFailedJobsProperties.queryOptions );
		if (
			variables.settings.logFailedJobsProperties.keyExists( "datasource" ) && (
				!isSimpleValue( variables.settings.logFailedJobsProperties.datasource ) || variables.settings.logFailedJobsProperties.datasource != ""
			)
		) {
			options[ "datasource" ] = variables.settings.logFailedJobsProperties.datasource;
		}

		variables.log.debug( "Registering DB Task for cleaning up the failed job log" );

		var cleanupTask = task( "cbq:db-cleanup-failed-job-log" )
			.call( () => {
				var deleteQuery = newQuery().table( variables.settings.logFailedJobsProperties.tableName );
                variables.settings.logFailedJobsProperties.cleanup.criteria( deleteQuery, getCurrentUnixTimestamp() );
				return deleteQuery.delete( options = options ).result.recordCount;
			} )
			.before( function() {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Starting to clean up the failed job log." );
				}
			} )
			.onSuccess( function( task, deletedCount ) {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Finished cleaning up the failed job log. Total jobs deleted: #deletedCount.orElse( 0 )#" );
				}
			} )
			.onFailure( function( task, exception ) {
				if ( variables.log.canError() ) {
					variables.log.error(
						"Exception when cleaning up the failed job log: #exception.message#",
						{
							"exception" : arguments.exception
						}
					);
				}
			} );

		var cleanupFrequency = function( task ) { task.everyDay(); };
		param variables.settings.logFailedJobsProperties.cleanup.frequency = cleanupFrequency;
		variables.settings.logFailedJobsProperties.cleanup.frequency( cleanupTask );
    }

    private any function registerCleanupBatchJobsTask() {
		var cleanupCriteria = function( q, currentUnixTimestamp ) {
			q.where( ( q3 ) => {
                q3.where( "cancelledDate", "<=", currentUnixTimestamp - ( 60 * 60 * 24 * 30 ) ); // 30 days
                q3.orWhere( "completedDate", "<=", currentUnixTimestamp - ( 60 * 60 * 24 * 30 ) ); // 30 week
            } );
		};
		param variables.settings.batchRepositoryProperties.cleanup.criteria = cleanupCriteria;
        param variables.settings.batchRepositoryProperties.tableName = "cbq_batches";

        var options = {};
		param variables.settings.batchRepositoryProperties.queryOptions = {};
		structAppend( options, variables.settings.batchRepositoryProperties.queryOptions );
		if (
			variables.settings.batchRepositoryProperties.keyExists( "datasource" ) && (
				!isSimpleValue( variables.settings.batchRepositoryProperties.datasource ) || variables.settings.batchRepositoryProperties.datasource != ""
			)
		) {
			options[ "datasource" ] = variables.settings.batchRepositoryProperties.datasource;
		}

		variables.log.debug( "Registering DB Task for cleaning up completed or cancelled batches" );

		var cleanupTask = task( "cbq:db-cleanup-batches" )
			.call( () => {
				var deleteQuery = newQuery()
                variables.settings.batchRepositoryProperties.cleanup.criteria( deleteQuery, getCurrentUnixTimestamp() );
				// These restrictions are added after to prevent any mistakes from the user erasing them.
				deleteQuery.table( variables.settings.batchRepositoryProperties.tableName )
                    .where( ( q2 ) => {
                        q2.whereNotNull( "cancelledDate" );
                        q2.orWhereNotNull( "completedDate" );
                    } );
				return deleteQuery.delete( options = options ).result.recordCount;
			} )
			.before( function() {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Starting to clean up completed or cancelled batches." );
				}
			} )
			.onSuccess( function( task, deletedCount ) {
				if ( variables.log.canDebug() ) {
					variables.log.debug( "Finished cleaning up completed or cancelled batches. Total jobs deleted: #deletedCount.orElse( 0 )#" );
				}
			} )
			.onFailure( function( task, exception ) {
				if ( variables.log.canError() ) {
					variables.log.error(
						"Exception when cleaning up completed or cancelled batches: #exception.message#",
						{
							"exception" : arguments.exception
						}
					);
				}
			} );

        var cleanupFrequency = function( task ) { task.everyDay(); };
		param variables.settings.batchRepositoryProperties.cleanup.frequency = cleanupFrequency;
		variables.settings.batchRepositoryProperties.cleanup.frequency( cleanupTask );
    }

	function onShutdown( boolean force = false, numeric timeout = variables.settings.defaultWorkerShutdownTimeout ) {
		var stdout = createObject( "java", "java.lang.System" ).out;
		stdout.println( "Shutting down cbq scheduler" );
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

    /**
	 * Get the "available at" UNIX timestamp.
	 *
	 * @delay  The delay, in seconds, to add to the current timestamp
	 * @return int
	 */
	public numeric function getCurrentUnixTimestamp( numeric delay = 0 ) {
		return createObject( "java", "java.time.Instant" ).now().getEpochSecond() + arguments.delay;
	}

	public QueryBuilder function newQuery() provider="QueryBuilder@qb" {
	}

}