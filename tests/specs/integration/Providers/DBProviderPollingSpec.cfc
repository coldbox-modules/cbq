component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "DBProvider polling configuration", function() {
			beforeEach( function() {
				variables.provider = freshProvider();
				variables.scheduler = getWireBox().getInstance( "coldbox:schedulerService" ).getSchedulers()[
					"cbScheduler@cbq"
				];
				variables.taskNames = [];
			} );

			afterEach( function() {
				for ( var name in variables.taskNames ) {
					variables.scheduler.removeTask( name );
				}
			} );

			it( "keeps the five-second default without adding caller properties", function() {
				var properties = {};
				variables.provider.setProperties( properties );
				expect( variables.provider.getProperties() ).toBe( {} );
				var task = watcher();
				expect( task.getSpacedDelay() ).toBe( 5000 );
				expect( task.getTimeUnit() ).toBe( "milliseconds" );
			} );

			it( "applies subsecond polling to the actual native watcher", function() {
				variables.provider.setProperties( { "pollIntervalMilliseconds" : 250 } );
				var task = watcher();
				expect( task.getSpacedDelay() ).toBe( 250 );
				expect( task.getTimeUnit() ).toBe( "milliseconds" );
			} );

			it( "uses each connection's own polling interval", function() {
				variables.provider.setProperties( { "pollIntervalMilliseconds" : 100 } );
				var first = watcher();
				variables.provider = freshProvider();
				variables.provider.setProperties( { "pollIntervalMilliseconds" : 7000 } );
				var second = watcher();
				expect( first.getSpacedDelay() ).toBe( 100 );
				expect( second.getSpacedDelay() ).toBe( 7000 );
			} );

			it( "rejects zero, negative, fractional, nonnumeric and complex intervals", function() {
				for ( var invalid in [ 0, -1, 0.5, "invalid", "", [], {} ] ) {
					expect( function() {
						variables.provider.setProperties( { "pollIntervalMilliseconds" : invalid } );
					} ).toThrow( "cbq.DBProvider.InvalidPollInterval" );
				}
			} );
		} );
	}

	private any function freshProvider() {
		var mapping = getWireBox().getBinder().getMapping( "DBProvider@cbq" );
		var provider = getWireBox().buildInstance( mapping );
		getWireBox().autowire( target = provider, mapping = mapping );
		return provider;
	}

	private any function watcher() {
		var connection = getWireBox()
			.getInstance( "QueueConnection@cbq" )
			.setName( "PollingTest-" & createUUID() )
			.setProvider( variables.provider );
		var pool = getWireBox()
			.getInstance( "WorkerPool@cbq" )
			.setName( "PollingTest-" & createUUID() )
			.setConnection( connection )
			.setConnectionName( connection.getName() );
		variables.provider.listen( pool );
		var name = "cbq:db-watcher:" & pool.getUniqueId();
		variables.taskNames.append( name );
		return variables.scheduler.getTaskRecord( name ).task;
	}

}
