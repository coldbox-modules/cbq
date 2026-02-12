component {

	function up( schema ) {
		schema.alter( "cbq_batches", ( t ) => {
			t.unsignedInteger( "successfulJobs" ).default( 0 );
		} );
	}

	function down( schema ) {
		schema.alter( "cbq_batches", ( t ) => {
			t.dropColumn( "successfulJobs" );
		} );
	}

}
