component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "observational queue boundaries", function() {
			it( "brackets synchronous worker execution and preserves the result when observers fail", function() {
				var states = [];
				var provider = createMock( "cbq.models.Providers.SyncProvider" );
				provider.$property(
					"log",
					"variables",
					{
						canDebug : function() {
							return false;
						},
						canError : function() {
							return false;
						}
					}
				);
				provider.$property(
					"interceptorService",
					"variables",
					{
						announce : function( state, data ) {
							states.append( {
								state      : state,
								id      : data.executionId ?: ""
							} );
							if ( state == "onCBQJobExecutionStarted" ) {
								throw( "ObserverFailure" );
							}
						}
					}
				);
				var job = createMock( "cbq.models.Jobs.AbstractJob" ).init();
				job.setId( "synthetic" )
					.setCurrentAttempt( 1 )
					.setMapping( "Synthetic" );
				job.$( "handle" )
					.$callback( function() {
						return 42;
					} );
				job.$( "isBatchJob", false );
				var pool = createMock( "cbq.models.Workers.WorkerPool" ).init();
				provider.marshalJob( job, pool );
				expect( states.map( ( entry ) => entry.state ) ).toBe( [
					"onCBQJobAttemptScheduled",
					"onCBQJobExecutionStarted",
					"onCBQJobMarshalled",
					"onCBQJobAttemptFinished",
					"onCBQJobComplete",
					"onCBQJobExecutionExited"
				] );
				expect( states[ 1 ].id ).toBe( states[ 6 ].id );
			} );
			it( "finishes a real asynchronous timeout before the worker exits and keeps a stable execution ID", function() {
				var async = new coldbox.system.async.AsyncManager();
				var executor = async.newExecutor(
					"observation-test-" & createUUID(),
					"single",
					1
				);
				var states = createObject( "java", "java.util.concurrent.ConcurrentLinkedQueue" ).init();
				var started = createObject( "java", "java.util.concurrent.CountDownLatch" ).init( 1 );
				var exited = createObject( "java", "java.util.concurrent.CountDownLatch" ).init( 1 );
				var provider = createMock( "cbq.models.Providers.AbstractQueueProvider" );
				provider.$property( "async", "variables", async );
				provider.$property(
					"log",
					"variables",
					{
						canDebug : () => false,
						canError : () => false,
						debug : () => {
						}
					}
				);
				provider.$( "releaseJob", () => {
				} );
				provider.$property(
					"interceptorService",
					"variables",
					{
						announce : function( state, data ) {
							if ( data.keyExists( "executionId" ) ) {
								states.add( {
									"state" : state,
									"id" : data.executionId,
									"status" : data.status ?: ""
								} );
							}
							if ( state == "onCBQJobExecutionStarted" ) {
								started.countDown();
							}
							if ( state == "onCBQJobExecutionExited" ) {
								exited.countDown();
							}
						}
					}
				);
				var job = createMock( "cbq.models.Jobs.AbstractJob" )
					.init()
					.setId( "synthetic" )
					.setMapping( "Synthetic" )
					.setTimeout( 1 )
					.setMaxAttempts( 2 );
				job.$( "handle" )
					.$callback( () => {
						sleep( 4000 );
						return 42;
					} );
				job.$( "isBatchJob", false );
				var pool = createMock( "cbq.models.Workers.WorkerPool" )
					.init()
					.setExecutor( executor )
					.setMaxAttempts( 2 );
				try {
					provider.marshalJob( job, pool ).get( 6500 );
					expect( started.getCount() ).toBe( 0 );

					expect(
						exited.await(
							javacast( "long", 6 ),
							createObject( "java", "java.util.concurrent.TimeUnit" ).SECONDS
						)
					).toBeTrue();
					var observations = states.toArray();
					expect( observations.map( ( entry ) => entry.state ).find( "onCBQJobAttemptFinished" ) ).toBeLT(
						observations.map( ( entry ) => entry.state ).find( "onCBQJobExecutionExited" )
					);
					var finished = observations.filter( ( entry ) => entry.state == "onCBQJobAttemptFinished" );
					expect( finished.len() ).toBe( 1 );
					expect( finished[ 1 ].status ).toBe( "deadline_exceeded" );
					for ( var entry in observations ) {
						expect( entry.id ).toBe( observations[ 1 ].id );
					}
				} finally {
					executor.shutdownNow();
				}
			} );
			it( "reports bulk publish rejection without replacing the provider failure", function() {
				var states = [];
				var dispatcher = createMock( "cbq.models.Jobs.Dispatcher" );
				var connection = {
					getDefaultQueue : function() {
						return "synthetic";
					},
					pushMany : function() {
						throw( type = "EnqueueFailure", message = "original enqueue failure" );
					}
				};
				dispatcher.$property(
					"config",
					"variables",
					{
						getDefaultConnectionName : function() {
							return "synthetic";
						},
						getConnection : function() {
							return connection;
						}
					}
				);
				dispatcher.$property(
					"interceptorService",
					"variables",
					{
						announce : function( state, data ) {
							states.append( state );
							if ( state == "onCBQJobPublishException" ) {
								throw( "ObserverFailure" );
							}
						}
					}
				);
				var jobs = [
					createMock( "cbq.models.Jobs.AbstractJob" ).init(),
					createMock( "cbq.models.Jobs.AbstractJob" ).init()
				];
				expect( () => dispatcher.bulkDispatch( jobs = jobs, batchSize = 2 ) ).toThrow( "EnqueueFailure" );
				expect( states ).toBe( [
					"onCBQJobAdded",
					"onCBQJobAdded",
					"onCBQJobPublishException",
					"onCBQJobPublishException"
				] );
			} );
		} );
	}

}
