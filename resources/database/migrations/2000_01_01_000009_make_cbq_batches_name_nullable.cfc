component {

	function up( schema, qb ) {
		schema.alter( "cbq_batches", ( t ) => {
			t.modifyColumn( "name", t.string( "name" ).nullable() );
		} );
	}

	function down( schema, qb ) {
		schema.alter( "cbq_batches", ( t ) => {
			t.modifyColumn( "name", t.string( "name" ) );
		} );
	}

}
