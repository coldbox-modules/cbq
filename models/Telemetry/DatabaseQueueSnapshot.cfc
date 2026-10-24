/** Read-only cbq database queue snapshot using the provider's availability and lease fields. */
component {

	function init(
		required function queryFactory,
		string table = "cbq_jobs",
		struct queryOptions = {}
	) {
		variables.queryFactory = arguments.queryFactory;
		variables.table = arguments.table;
		variables.queryOptions = duplicate( arguments.queryOptions );
		return this;
	}
	function snapshot( required any queue ) {
		var builder = variables.queryFactory();
		var grammar = builder.getGrammar();
		var available = grammar.wrapValue( "availableDate" );
		var reserved = grammar.wrapValue( "reservedDate" );
		var owner = grammar.wrapValue( "reservedBy" );
		var created = grammar.wrapValue( "createdDate" );
		var unclaimed = reserved & " IS NULL AND " & owner & " IS NULL";
		var claimed = "(" & reserved & " IS NOT NULL OR " & owner & " IS NOT NULL)";
		var now = int( createObject( "java", "java.lang.System" ).currentTimeMillis() / 1000 );
		var queues = isArray( arguments.queue ) ? arguments.queue : [ arguments.queue ];
		if ( !queues.len() ) throw( type = "cbq.Telemetry.InvalidQueueSelection" );
		for ( var queueName in queues ) {
			if ( isNull( queueName ) || !isSimpleValue( queueName ) )
				throw( type = "cbq.Telemetry.InvalidQueueSelection" );
		}
		builder.from( variables.table );
		if ( !arrayFind( queues, "*" ) ) builder.whereIn( "queue", queues );
		var rows = builder
			.whereNull( "completedDate" )
			.whereNull( "failedDate" )
			.selectRaw(
				"COALESCE(SUM(CASE WHEN " & unclaimed & " AND " & available & " <= ? THEN 1 ELSE 0 END),0) AS " & grammar.wrapValue( "runnable" ),
				[ now ]
			)
			.selectRaw(
				"COALESCE(SUM(CASE WHEN " & unclaimed & " AND " & available & " > ? THEN 1 ELSE 0 END),0) AS " & grammar.wrapValue( "delayed" ),
				[ now ]
			)
			.selectRaw( "COALESCE(SUM(CASE WHEN " & claimed & " THEN 1 ELSE 0 END),0) AS " & grammar.wrapValue( "reserved" ) )
			.selectRaw(
				"COALESCE(SUM(CASE WHEN " & claimed & " AND " & available & " <= ? THEN 1 ELSE 0 END),0) AS " & grammar.wrapValue( "staleReservations" ),
				[ now ]
			)
			.selectRaw( "MIN(CASE WHEN " & unclaimed & " THEN " & created & " ELSE NULL END) AS " & grammar.wrapValue( "oldestCreatedAt" ) )
			.get( options = variables.queryOptions );
		if ( !isArray( rows ) || rows.len() != 1 ) throw( type = "cbq.Telemetry.InvalidQueueHealthResult" );
		var snapshot = rows[ 1 ];
		snapshot[ "depth" ] = snapshot.runnable + snapshot.delayed;
		snapshot[ "oldestAgeSeconds" ] = snapshot.depth > 0 && snapshot.keyExists( "oldestCreatedAt" ) && !isNull(
			snapshot.oldestCreatedAt
		) && isNumeric( snapshot.oldestCreatedAt ) ? max( 0, now - snapshot.oldestCreatedAt ) : 0;
		snapshot.delete( "oldestCreatedAt" );
		return snapshot;
	}

}
