component {

    function up( schema, qb ) {
        schema.alter( "cbq_failed_jobs", ( t ) => {
            t.addColumn( t.unsignedBigInteger( "originalId" ).nullable() );
			t.addConstraint( t.foreignKey( "originalId", "fk_cbq_jobs_originalId" ).references( "id" ).onTable( "cbq_jobs" ).onDelete( "NO ACTION" ) );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "cbq_failed_jobs", ( t ) => {
			t.dropForeignKey( "fk_cbq_jobs_originalId" );
            t.dropColumn( "originalId" );
        } );
    }

}