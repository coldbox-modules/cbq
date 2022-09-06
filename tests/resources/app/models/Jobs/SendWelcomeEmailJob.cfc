component extends="cbq.models.Jobs.AbstractJob" {

    property name="log" inject="logbox:logger:{this}";

    function handle() {
        log.info( "sending email" );
    }

}