component {

    function up( schema, qb ) {
        schema.alter( "cbq_jobs", ( t ) => {
            t.addColumn( t.unsignedBigInteger( "completedDate" ).nullable() );
            t.addColumn( t.unsignedBigInteger( "lastReleasedDate" ).nullable() );
            t.addColumn( t.unsignedBigInteger( "failedDate" ).nullable() );
			t.addIndex( t.index( [ "completedDate", "failedDate" ] ) );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "cbq_jobs", ( t ) => {
			t.dropIndex( t.index( [ "completedDate", "failedDate" ] ) );
            t.dropColumn( "failedDate" );
            t.dropColumn( "lastReleasedDate" );
            t.dropColumn( "completedDate" );
        } );
    }

}