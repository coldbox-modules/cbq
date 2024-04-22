component {

    function up( schema, qb ) {
		var grammarName = listLast( getMetadata( qb.getGrammar() ).name, "." );
		if ( grammarName == "AutoDiscover" ) {
			grammarName = listLast( getMetadata( qb.getGrammar().autoDiscoverGrammar() ).name, "." );
		}

		switch ( grammarName ) {
			case "MySqlGrammar":
			case "SqlServerGrammar":
			case "PostgresGrammar":
			case "OracleGrammar":
			case "SqliteGrammar":
				break;
			default:
				throw( "Unsupported grammar type: " & grammarName & ". You will need to edit the migration file to correctly migrate from unix timestamps to datetime columns manually." );
		}

        schema.alter( "cbq_jobs", ( t ) => {
			t.renameColumn( "createdDate", t.unsignedInteger( "createdDateUnix" ) );
			t.renameColumn( "availableDate", t.unsignedInteger( "availableDateUnix" ) );
			t.renameColumn( "reservedDate", t.unsignedInteger( "reservedDateUnix" ).nullable() );

            t.addColumn( t.datetime( "createdDate" ).nullable() );
            t.addColumn( t.datetime( "availableDate" ).nullable() );
            t.addColumn( t.datetime( "reservedDate" ).nullable() );
            t.addColumn( t.datetime( "completedDate" ).nullable() );
            t.addColumn( t.datetime( "releasedDate" ).nullable() );
            t.addColumn( t.datetime( "failedDate" ).nullable() );
			t.addConstraint( t.index( [ "completedDate", "releasedDate", "failedDate" ] ) );
        } );

		switch ( grammarName ) {
			case "MySqlGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDate": qb.raw( "FROM_UNIXTIME(createdDateUnix)" ),
						"availableDate": qb.raw( "FROM_UNIXTIME(availableDateUnix)" ),
						"reservedDate": qb.raw( "FROM_UNIXTIME(reservedDateUnix)" )
					} );
				break;
			case "SqlServerGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDate": qb.raw( "DATEADD(s, createdDateUnix, '1970-01-01 00:00:00')" ),
						"availableDate": qb.raw( "DATEADD(s, availableDateUnix, '1970-01-01 00:00:00')" ),
						"reservedDate": qb.raw( "DATEADD(s, reservedDateUnix, '1970-01-01 00:00:00')" )
					} );
				break;
			case "PostgresGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDate": qb.raw( "to_timestamp(createdDateUnix)" ),
						"availableDate": qb.raw( "to_timestamp(availableDateUnix)" ),
						"reservedDate": qb.raw( "to_timestamp(reservedDateUnix)" )
					} );
				break;
			case "OracleGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDate": qb.raw( "to_date('01-JAN-1970','dd-mon-yyyy')+(createdDateUnix/60/60/24)" ),
						"availableDate": qb.raw( "to_date('01-JAN-1970','dd-mon-yyyy')+(availableDateUnix/60/60/24)" ),
						"reservedDate": qb.raw( "to_date('01-JAN-1970','dd-mon-yyyy')+(reservedDateUnix/60/60/24)" )
					} );
				break;
			case "SqliteGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDate": qb.raw( "datetime(createdDateUnix, 'unixepoch')" ),
						"availableDate": qb.raw( "datetime(availableDateUnix, 'unixepoch')" ),
						"reservedDate": qb.raw( "datetime(reservedDateUnix, 'unixepoch')" )
					} );
				break;
			default:
				throw( "Unsupported grammar type: " & grammarName & ". You will need to edit the migration file to correctly migrate from unix timestamps to datetime columns manually." );
		}

		schema.alter( "cbq_jobs", ( t ) => {
			t.renameColumn( "createdDate", t.datetime( "createdDate" ) );
            t.renameColumn( "availableDate", t.datetime( "availableDate" ) );

			t.dropColumn( "createdDateUnix" );
			t.dropColumn( "availableDateUnix" );
			t.dropColumn( "reservedDateUnix" );
		} );
    }

    function down( schema, qb ) {
		var grammarName = listLast( getMetadata( qb.getGrammar() ).name, "." );
		if ( grammarName == "AutoDiscover" ) {
			grammarName = listLast( getMetadata( qb.getGrammar().autoDiscoverGrammar() ).name, "." );
		}

		switch ( grammarName ) {
			case "MySqlGrammar":
			case "SqlServerGrammar":
			case "PostgresGrammar":
			case "SqliteGrammar":
				break;
			default:
				throw( "Unsupported grammar type: " & grammarName & ". You will need to edit the migration file to correctly migrate back from datetime columns to unix timestamps manually." );
		}

		// add the unix columns back in
		schema.alter( "cbq_jobs", ( t ) => {
			t.addColumn( t.unsignedInteger( "createdDateUnix" ).nullable() );
			t.addColumn( t.unsignedInteger( "availableDateUnix" ).nullable() );
			t.addColumn( t.unsignedInteger( "reservedDateUnix" ).nullable() );
		} );

		// migrate the data
		switch ( grammarName ) {
			case "MySqlGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDateUnix": qb.raw( "UNIX_TIMESTAMP(createdDate)" ),
						"availableDateUnix": qb.raw( "UNIX_TIMESTAMP(availableDate)" ),
						"reservedDateUnix": qb.raw( "UNIX_TIMESTAMP(reservedDate)" )
					} );
				break;
			case "SqlServerGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDateUnix": qb.raw( "DATEDIFF(s, '1970-01-01 00:00:00', createdDate)" ),
						"availableDateUnix": qb.raw( "DATEDIFF(s, '1970-01-01 00:00:00', availableDate)" ),
						"reservedDateUnix": qb.raw( "DATEDIFF(s, '1970-01-01 00:00:00', reservedDate)" )
					} );
				break;
			case "PostgresGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDateUnix": qb.raw( "EXTRACT(EPOCH FROM TIMESTAMP createdDate" ),
						"availableDateUnix": qb.raw( "EXTRACT(EPOCH FROM TIMESTAMP availableDate" ),
						"reservedDateUnix": qb.raw( "EXTRACT(EPOCH FROM TIMESTAMP reservedDate" )
					} );
				break;
			case "SqliteGrammar":
				qb.newQuery()
					.table( "cbq_jobs" )
					.update( {
						"createdDateUnix": qb.raw( "strftime('%s', createdDate)" ),
						"availableDateUnix": qb.raw( "strftime('%s', availableDate)" ),
						"reservedDateUnix": qb.raw( "strftime('%s', reservedDate)" )
					} );
				break;
			default:
				throw( "Unsupported grammar type: " & grammarName & ". You will need to edit the migration file to correctly migrate from unix timestamps to datetime columns manually." );
		}

        schema.alter( "cbq_jobs", ( t ) => {
			t.dropConstraint( t.index( [ "completedDate", "releasedDate", "failedDate" ] ) );
            t.dropColumn( "failedDate" );
            t.dropColumn( "releasedDate" );
            t.dropColumn( "completedDate" );
            t.dropColumn( "reservedDate" );
            t.dropColumn( "availableDate" );
            t.dropColumn( "createdDate" );

			t.renameColumn( "reservedDateUnix", t.unsignedInteger( "reservedDate" ).nullable() );
			t.renameColumn( "availableDateUnix", t.unsignedInteger( "availableDate" ) );
			t.renameColumn( "createdDateUnix", t.unsignedInteger( "createdDate" ) );
        } );
    }

}