component {

    function up( schema ) {
        schema.alter( "cbq_jobs", ( t ) => {
            t.addColumn( t.string( "reservedBy" ).nullable() );
			t.addIndex( t.index( "reservedBy" ) );
        } );
    }

    function down( schema ) {
        schema.alter( "cbq_jobs", ( t ) => {
			t.dropIndex( t.index( "reservedBy" ) );
            t.dropColumn( "reservedBy" );
        } );
    }

}