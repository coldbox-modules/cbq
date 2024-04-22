component {

    function up( schema ) {
        schema.create( "cbq_jobs", function ( t ) {
            t.bigIncrements( "id" );
            t.string( "queue" );
            t.longText( "payload" );
            t.unsignedTinyInteger( "attempts" );
            t.unsignedBigInteger( "reservedDate" ).nullable();
            t.unsignedBigInteger( "availableDate" );
            t.unsignedBigInteger( "createdDate" );

			t.index( "queue" );
        } );
    }

    function down( schema ) {
        schema.dropIfExists( "cbq_jobs" );
    }

}