component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "opt-in bulk dispatch", function() {
			beforeEach( function() {
				variables.events = [];
				variables.writes = [];
				variables.provider = {
					"push" : function(
						queueName,
						job,
						delay = 0,
						attempts = 0
					) {
						variables.events.append( "push:" & job.getProperties().ordinal );
						variables.writes.append( [
							{
								"queueName" : queueName,
								"job" : job,
								"attempts" : attempts
							}
						] );
					},
					"pushMany" : function( entries ) {
						variables.events.append( "many:" & entries.len() );
						variables.writes.append( entries );
					}
				};
				variables.connection = new cbq.models.Connections.QueueConnection()
					.setProvider( variables.provider )
					.setDefaultQueue( "fallback" );
				variables.dispatcher = new cbq.models.Jobs.Dispatcher()
					.setConfig( {
						"getDefaultConnectionName" : function() {
							return "default";
						},
						"getConnection" : function( name ) {
							return variables.connection;
						}
					} )
					.setInterceptorService( {
						"announce" : function( name, data ) {
							expect( name ).toBe( "onCBQJobAdded" );
							variables.events.append( "event:" & data.job.getProperties().ordinal );
							data.job.getProperties().announced = true;
						}
					} );
			} );
			it( "retains event then insert ordering by default", function() {
				variables.dispatcher.bulkDispatch( jobs( 3 ) );
				expect( variables.events ).toBe( [
					"event:1",
					"push:1",
					"event:2",
					"push:2",
					"event:3",
					"push:3"
				] );
			} );
			it( "batches mixed queues with per-job events, reset attempts and a final partial batch", function() {
				variables.dispatcher.bulkDispatch( jobs = jobs( 5 ), batchSize = 2 );
				expect( variables.events ).toBe( [
					"event:1",
					"event:2",
					"many:2",
					"event:3",
					"event:4",
					"many:2",
					"event:5",
					"many:1"
				] );
				var ordinal = 0;
				for ( var batch in variables.writes ) {
					for ( var entry in batch ) {
						ordinal++;
						expect( entry.queueName ).toBe( "queue-" & ordinal );
						expect( entry.job.getProperties().ordinal ).toBe( ordinal );
						expect( entry.job.getProperties().announced ).toBeTrue();
						expect( entry.job.getCurrentAttempt() ).toBe( 0 );
						expect( entry.attempts ).toBe( 0 );
					}
				}
				expect( ordinal ).toBe( 5 );
			} );
			it( "honors an explicit queue and providers that only implement push", function() {
				structDelete( variables.provider, "pushMany" );
				variables.dispatcher.bulkDispatch(
					jobs = jobs( 3 ),
					queueName = "000123",
					batchSize = 2
				);
				expect( variables.writes.len() ).toBe( 3 );
				for ( var batch in variables.writes ) {
					expect( compare( batch[ 1 ].queueName, "000123" ) ).toBe( 0 );
				}
			} );
			it( "does no work for an empty batch", function() {
				variables.dispatcher.bulkDispatch( jobs = [], batchSize = 100 );
				expect( variables.events ).toBeEmpty();
			} );
			it( "rejects invalid batch sizes before announcing or pushing jobs", function() {
				for ( var size in [ 0, -1, 1.5, 101 ] ) {
					expect( function() {
						variables.dispatcher.bulkDispatch( jobs = jobs( 1 ), batchSize = size );
					} ).toThrow( "cbq.InvalidDispatchBatchSize" );
				}
				expect( variables.events ).toBeEmpty();
			} );
		} );
	}
	private array function jobs( required numeric count ) {
		var result = [];
		for ( var i = 1; i <= arguments.count; i++ ) {
			result.append(
				new cbq.models.Jobs.AbstractJob()
					.setProperties( { "ordinal" : i } )
					.setQueue( "queue-" & i )
					.setCurrentAttempt( 9 )
			);
		}
		return result;
	}

}
