component {

    function up( schema ) {
        schema.create( "cbq_failed_jobs", function ( t ) {
            t.bigIncrements( "id" );
            t.string( "connection" );
            t.string( "queue" );
            t.string( "mapping" );
            t.longText( "memento" );
            t.longText( "properties" );
            t.string( "exceptionType" ).nullable();
            t.string( "exceptionMessage" );
            t.string( "exceptionDetail" ).nullable();
            t.longText( "exceptionExtendedInfo" ).nullable();
            t.longText( "exceptionStackTrace" );
            t.longText( "exception" );
            t.timestamp( "failedDate" ).withCurrent();
        } );
    }

    function down( schema ) {
        schema.dropIfExists( "cbq_failed_jobs" );
    }

}