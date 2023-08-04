component {

    function up( schema ) {
        schema.create( "cbq_jobs", function ( t ) {
            t.bigIncrements( "id" );
            t.string( "queue" );
            t.longText( "payload" );
            t.unsignedInteger( "attempts" );
            t.unsignedInteger( "reservedDate" ).nullable();
            t.unsignedInteger( "availableDate" );
            t.unsignedInteger( "createdDate" );

			t.index( "queue" );
        } );
    }

    function down( schema ) {
        schema.dropIfExists( "cbq_jobs" );
    }

}
