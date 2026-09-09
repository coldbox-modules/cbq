component {
	function up( schema ) {
		schema.alter( "cbq_batches", ( t ) => {
			t.addColumn( t.longText( "processedJobIds" ).nullable() );
		} );
	}
	function down( schema ) {
		schema.alter( "cbq_batches", ( t ) => {
			t.dropColumn( "processedJobIds" );
		} );
	}
}
