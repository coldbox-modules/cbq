component singleton accessors="true" {

	property name="javaInstant" inject="java:java.time.Instant";
	property name="qb" inject="provider:QueryBuilder@qb";

	property
		name="properties"
		type="struct"
		inject="coldbox:moduleSettings:cbq:batchRepositoryProperties";
	property name="defaultQueryOptions" type="struct";
	property name="batchTableName" default="cbq_batches";

	public DBBatchRepository function init() {
		variables.timeBasedUUIDGenerator = createObject( "java", "com.fasterxml.uuid.Generators" ).timeBasedGenerator();
		variables.defaultQueryOptions = {};
		return this;
	}

	function onDIComplete() {
		setProperties( variables.properties );
	}

	public DBBatchRepository function setProperties( required struct properties ) {
		variables.properties = arguments.properties;
		variables.batchTableName = variables.properties.keyExists( "tableName" ) ? variables.properties.tableName : "cbq_batches";
		variables.defaultQueryOptions = variables.properties.keyExists( "queryOptions" ) ? variables.properties.queryOptions : {};
		if ( variables.properties.keyExists( "datasource" ) ) {
			variables.defaultQueryOptions[ "datasource" ] = variables.properties.datasource;
		}
		return this;
	}

	public Batch function find( required string id ) {
		var data = qb
			.from( variables.batchTableName )
			.where( "id", arguments.id )
			.first( options = variables.defaultQueryOptions )

		if ( structIsEmpty( data ) ) {
			throw( type = "cbq.BatchNotFound", message = "No batch found for id [#arguments.id#]" );
		}

		return toBatch( data );
	}

	public Batch function store( required PendingBatch batch ) {
		var id = variables.timeBasedUUIDGenerator.generate().toString();

		qb.table( variables.batchTableName )
			.insert(
				values = {
					"id" : id,
					"name" : arguments.batch.getName(),
					"totalJobs" : 0,
					"pendingJobs" : 0,
					"failedJobs" : 0,
					"failedJobIds" : "[]",
					"options" : serializeJSON( arguments.batch.getOptions() ),
					"createdDate" : variables.getCurrentUnixTimestamp()
				},
				options = variables.defaultQueryOptions
			);

		return variables.find( id );
	}

	public void function delete( required string id ) {
		qb.table( variables.batchTableName )
			.where( "id", arguments.id )
			.delete();
	}

	public void function incrementTotalJobs( required string id, required numeric count ) {
		qb.table( variables.batchTableName )
			.where( "id", arguments.id )
			.update( {
				"totalJobs" : qb.raw( "totalJobs + #count#" ),
				"pendingJobs" : qb.raw( "pendingJobs + #count#" ),
				"completedDate" : { "value" : 0, "null" : true }
			} );
	}

	public struct function decrementPendingJobs( required string batchId, required any jobId ) {
		transaction {
			var data = qb
				.from( variables.batchTableName )
				.where( "id", arguments.batchId )
				.lockForUpdate()
				.first( options = variables.defaultQueryOptions );

			if ( structIsEmpty( data ) ) {
				throw( type = "cbq.BatchNotFound", message = "No batch found for id [#arguments.batchId#]" );
			}

			qb.table( variables.batchTableName )
				.where( "id", arguments.batchId )
				.update( {
					"pendingJobs" : data.pendingJobs - 1,
					"failedJobs" : data.failedJobs,
					"failedJobIds" : serializeJSON(
						deserializeJSON( data.failedJobIds ).filter( ( failedJobId ) => failedJobId != jobId )
					)
				} );

			return {
				"pendingJobs" : data.pendingJobs - 1,
				"failedJobs" : data.failedJobs,
				"allJobsHaveRanExactlyOnce" : ( data.pendingJobs - 1 ) - data.failedJobs == 0
			};
		}
	}

	public struct function incrementFailedJobs( required string batchId, required any jobId ) {
		transaction {
			var data = qb
				.from( variables.batchTableName )
				.where( "id", arguments.batchId )
				.lockForUpdate()
				.first( options = variables.defaultQueryOptions );

			if ( structIsEmpty( data ) ) {
				throw( type = "cbq.BatchNotFound", message = "No batch found for id [#arguments.batchId#]" );
			}

			qb.table( variables.batchTableName )
				.where( "id", arguments.batchId )
				.update( {
					"pendingJobs" : data.pendingJobs,
					"failedJobs" : data.failedJobs + 1,
					"failedJobIds" : serializeJSON( deserializeJSON( data.failedJobIds ).append( arguments.jobId ) )
				} );

			return {
				"pendingJobs" : data.pendingJobs,
				"failedJobs" : data.failedJobs + 1,
				"allJobsHaveRanExactlyOnce" : data.pendingJobs - ( data.failedJobs + 1 ) == 0
			};
		}
	}

	public void function markAsFinished( required string id ) {
		qb.table( variables.batchTableName )
			.where( "id", arguments.id )
			.update( { "completedDate" : getCurrentUnixTimestamp() } );
	}

	public void function cancel( required string id ) {
		qb.table( variables.batchTableName )
			.where( "id", arguments.id )
			.update( {
				"cancelledDate" : getCurrentUnixTimestamp(),
				"completedDate" : getCurrentUnixTimestamp()
			} );
	}

	public Batch function toBatch( required struct data ) {
		var batch = newBatch();
		batch.setRepository( this );
		batch.setId( data.id );
		batch.setName( data.name );
		batch.setTotalJobs( data.totalJobs );
		batch.setPendingJobs( data.pendingJobs );
		batch.setFailedJobs( data.failedJobs );
		batch.setFailedJobIds( deserializeJSON( data.failedJobIds ) );
		batch.setOptions( deserializeJSON( data.options ) );
		batch.setCreatedDate( data.createdDate );
		batch.setCancelledDate( data.cancelledDate != "" ? data.cancelledDate : javacast( "null", "" ) );
		batch.setCompletedDate( data.completedDate != "" ? data.completedDate : javacast( "null", "" ) );
		return batch;
	}

	/**
	 * Get the "available at" UNIX timestamp.
	 *
	 * @delay  The delay, in seconds, to add to the current timestamp
	 * @return int
	 */
	public numeric function getCurrentUnixTimestamp( numeric delay = 0 ) {
		return variables.javaInstant.now().getEpochSecond() + arguments.delay;
	}

	public Batch function newBatch() provider="Batch@cbq" {
	}

}
