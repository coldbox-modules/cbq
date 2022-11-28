component {

    function up( schema ) {
        schema.create( "cbq_batches", function ( t ) {
            t.string( "id" ).primaryKey();
            t.string( "name" );
            t.unsignedInteger( "totalJobs" );
            t.unsignedInteger( "pendingJobs" );
            t.unsignedInteger( "failedJobs" );
            t.text( "failedJobIds" );
            t.text( "options" ).nullable();
            t.unsignedInteger( "createdDate" );
            t.unsignedInteger( "cancelledDate" ).nullable();
            t.unsignedInteger( "completedDate" ).nullable();
        } );
    }

    function down( schema ) {
        schema.dropIfExists( "cbq_batches" );
    }

}