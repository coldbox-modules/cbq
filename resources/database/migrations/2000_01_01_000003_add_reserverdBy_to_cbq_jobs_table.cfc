component {

    function up( schema ) {
        schema.alter( "cbq_jobs", ( t ) => {
            t.addColumn( t.string( "reservedBy" ).nullable() );
			t.addConstraint( t.index( "reservedBy" ) );
        } );
    }

    function down( schema ) {
        schema.alter( "cbq_jobs", ( t ) => {
			t.dropConstraint( t.index( "reservedBy" ) );
            t.dropColumn( "reservedBy" );
        } );
    }

}