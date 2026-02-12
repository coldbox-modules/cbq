component {

	function up( schema ) {
		schema.alter( "cbq_batches", ( t ) => {
			t.addColumn( t.unsignedInteger( "successfulJobs" ).default( 0 ) );
		} );
	}

	function down( schema ) {
		schema.alter( "cbq_batches", ( t ) => {
			t.dropColumn( "successfulJobs" );
		} );
	}

}
