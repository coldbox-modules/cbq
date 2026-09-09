/** Unlimited retries and releases still count every execution. */
component {

	function up( schema ) {
		schema.alter( "cbq_jobs", function( t ) {
			t.modifyColumn( "attempts", t.unsignedBigInteger( "attempts" ) );
		} );
	}

	function down( schema, qb ) {
		if (
			qb.newQuery()
				.from( "cbq_jobs" )
				.where( "attempts", ">", 255 )
				.count() > 0
		) {
			throw( "Cannot narrow cbq job attempts while retained counts exceed 255." );
		}
		schema.alter( "cbq_jobs", function( t ) {
			t.modifyColumn( "attempts", t.unsignedTinyInteger( "attempts" ) );
		} );
	}

}
