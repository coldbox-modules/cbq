component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBProvider attempt ownership", function() {
			beforeEach( function() {
				variables.provider = getWireBox()
					.buildInstance( getWireBox().getBinder().getMapping( "DBProvider@cbq" ) )
					.setProperties( {} );
				getWireBox().autowire(
					target = variables.provider,
					mapping = getWireBox().getBinder().getMapping( "DBProvider@cbq" )
				);
				for (
					var method in [
						"afterJobRun",
						"afterJobFailed",
						"processLockedRecord"
					]
				) {
					makePublic( variables.provider, method );
				}
				variables.pool = getInstance( "WorkerPool@cbq" ).setName( "Ownership-#createUUID()#" );
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.delete();
			} );
			afterEach( function() {
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.delete();
			} );

			[
				"complete",
				"release",
				"fail",
				"force-fail"
			].each( function( operation ) {
				it( "ignores stale #operation# after the same pool starts a newer attempt", function() {
					assertCallback( operation, "running" );
				} );
				it( "ignores stale #operation# while the same pool has reclaimed but not started", function() {
					assertCallback( operation, "pending" );
				} );
				it( "allows #operation# for the current execution", function() {
					assertCallback( operation, "current" );
				} );
			} );

			it( "does not marshal a stale fetched record when its reservation update loses", function() {
				var job = getInstance( "SendWelcomeEmailJob" ).setMaxAttempts( 5 );
				variables.provider.push( "default", job );
				var record = variables.provider
					.newQuery()
					.from( "cbq_jobs" )
					.first();
				variables.provider
					.newQuery()
					.table( "cbq_jobs" )
					.where( "id", record.id )
					.update( {
						"attempts" : 2,
						"reservedBy" : variables.pool.getUniqueId(),
						"reservedDate" : variables.provider.getCurrentUnixTimestamp()
					} );
				prepareMock( variables.provider ).$( "marshalJob" );
				variables.provider.processLockedRecord( record, variables.pool );
				expect( variables.provider.$never( "marshalJob" ) ).toBeTrue();
				expect(
					variables.provider
						.newQuery()
						.from( "cbq_jobs" )
						.where( "id", record.id )
						.value( "attempts" )
				).toBe( 2 );
			} );
		} );
	}

	private void function assertCallback( required string operation, required string state ) {
		var job = getInstance( "SendWelcomeEmailJob" );
		variables.provider.push( "default", job );
		var row = variables.provider
			.newQuery()
			.from( "cbq_jobs" )
			.first();
		job.setId( row.id ).setCurrentAttempt( 1 );
		variables.provider
			.newQuery()
			.table( "cbq_jobs" )
			.where( "id", row.id )
			.update( {
				"attempts" : arguments.state == "running" ? 2 : 1,
				"reservedBy" : variables.pool.getUniqueId(),
				"reservedDate" : arguments.state == "pending" ? {
					"value" : "",
					"null" : true,
					"nulls" : true,
					"cfsqltype" : "cf_sql_bigint"
				} : variables.provider.getCurrentUnixTimestamp()
			} );
		var before = variables.provider
			.newQuery()
			.from( "cbq_jobs" )
			.where( "id", row.id )
			.first();
		switch ( arguments.operation ) {
			case "complete":
				variables.provider.afterJobRun( job, variables.pool );
				break;
			case "release":
				variables.provider.releaseJob( job, variables.pool );
				break;
			case "fail":
				variables.provider.afterJobFailed(
					id = row.id,
					job = job,
					pool = variables.pool
				);
				break;
			case "force-fail":
				variables.provider.forceFailJob(
					id = row.id,
					pool = variables.pool,
					job = job
				);
				break;
		}
		var after = variables.provider
			.newQuery()
			.from( "cbq_jobs" )
			.where( "id", row.id )
			.first();
		if ( arguments.state != "current" ) {
			expect( after ).toBe( before, "The newer reservation must remain unchanged" );
		} else if ( arguments.operation == "complete" ) {
			expect( after.completedDate ?: "" ).notToBe( "" );
		} else if ( arguments.operation == "release" ) {
			expect( after.reservedBy ?: "" ).toBe( "" );
			expect( after.lastReleasedDate ?: "" ).notToBe( "" );
		} else {
			expect( after.failedDate ?: "" ).notToBe( "" );
		}
	}

}
