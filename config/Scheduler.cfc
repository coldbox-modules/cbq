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
                exception
            );
        }
    }

}