component {

    function up( schema, qb ) {
        if ( qb.newQuery().table( "cbq_failed_jobs" ).count() > 0 ) {
            throw( "To run this migration, the cbq_failed_jobs table must be empty." );
        }

        schema.alter( "cbq_failed_jobs", ( t ) => {
            t.dropColumn( "failedDate" );
            t.addColumn( t.unsignedInteger( "failedDate" ) );
        } );
    }

    function down( schema, qb ) {
        if ( qb.newQuery().table( "cbq_failed_jobs" ).count() > 0 ) {
            throw( "To run this migration, the cbq_failed_jobs table must be empty." );
        }

        schema.alter( "cbq_failed_jobs", ( t ) => {
            t.dropColumn( "failedDate" );
            t.addColumn( t.timestamp( "failedDate" ).withCurrent() );
        } );
    }

}