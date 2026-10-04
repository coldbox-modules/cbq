component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "observational queue boundaries", function() {
			it( "brackets synchronous worker execution and preserves the result when observers fail", function() {
				var states = [];
				var diagnostics = [];
				var result = 0;
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
						},
						warn : function( message, extraInfo ) {
							diagnostics.append( {
								message  : message,
								exception  : extraInfo
							} );
						}
					}
				);
				provider.$property(
					"interceptorService",
					"variables",
					{
						announce : function( state, data ) {
							states.append( {
								state  : state,
								id  : data.executionId ?: ""
							} );
							if ( state == "onCBQJobComplete" ) {
								result = data.result;
							}
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
				expect( result ).toBe( 42 );
				expect( diagnostics.len() ).toBe( 1 );
				expect( diagnostics[ 1 ].message ).toInclude( "onCBQJobExecutionStarted" );
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
						warn : () => {
							throw( type = "DiagnosticFailure" );
						},
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
								throw( type = "ObserverFailure" );
							}
							if ( state == "onCBQJobExecutionExited" ) {
								exited.countDown();
								throw( type = "ObserverFailure" );
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
				var diagnostics = [];
				dispatcher.$property(
					"log",
					"variables",
					{
						warn : function( message, exception ) {
							diagnostics.append( exception );
							throw( type = "DiagnosticFailure" );
						}
					}
				);
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
				expect( diagnostics.len() ).toBe( 2 );
				expect( states ).toBe( [
					"onCBQJobAdded",
					"onCBQJobAdded",
					"onCBQJobPublishException",
					"onCBQJobPublishException"
				] );
			} );
			it( "preserves successful publication when both its observer and diagnostic logger fail", function() {
				var pushed = 0;
				var dispatcher = createMock( "cbq.models.Jobs.Dispatcher" );
				dispatcher.$property(
					"log",
					"variables",
					{
						warn : () => {
							throw( type = "DiagnosticFailure" );
						}
					}
				);
				var connection = {
					getDefaultQueue : () => "synthetic",
					pushMany : function( entries ) {
						pushed += entries.len();
					}
				};
				dispatcher.$property(
					"config",
					"variables",
					{
						getDefaultConnectionName : () => "synthetic",
						getConnection : () => connection
					}
				);
				dispatcher.$property(
					"interceptorService",
					"variables",
					{
						announce : function( state, data ) {
							if ( state == "onCBQJobPublished" ) {
								throw( type = "ObserverFailure" );
							}
						}
					}
				);
				var jobs = [
					createMock( "cbq.models.Jobs.AbstractJob" ).init(),
					createMock( "cbq.models.Jobs.AbstractJob" ).init()
				];
				expect( dispatcher.bulkDispatch( jobs = jobs, batchSize = 2 ) ).toBe( dispatcher );
				expect( pushed ).toBe( 2 );
			} );
			it( "preserves the original synchronous job failure and worker exit despite failed observation diagnostics", function() {
				var provider = createMock( "cbq.models.Providers.SyncProvider" );
				var exited = false;
				provider.$property(
					"log",
					"variables",
					{
						canDebug : () => false,
						canError : () => false,
						debug : () => {
						},
						warn : () => {
							throw( type = "DiagnosticFailure" );
						}
					}
				);
				provider.$property(
					"interceptorService",
					"variables",
					{
						announce : function( state, data ) {
							if ( state == "onCBQJobExecutionExited" ) {
								exited = true;
							}
							if (
								state == "onCBQJobExecutionStarted" || state == "onCBQJobAttemptFinished" || state == "onCBQJobExecutionExited"
							) {
								throw( type = "ObserverFailure" );
							}
						}
					}
				);
				var job = createMock( "cbq.models.Jobs.AbstractJob" )
					.init()
					.setId( "synthetic" )
					.setCurrentAttempt( 1 )
					.setMaxAttempts( 1 )
					.setMapping( "Synthetic" );
				job.$( "handle" )
					.$callback( () => {
						throw( type = "OriginalJobFailure", message = "original synthetic job failure" );
					} );
				job.$( "isBatchJob", false );
				var pool = createMock( "cbq.models.Workers.WorkerPool" ).init().setMaxAttempts( 1 );
				expect( () => provider.marshalJob( job, pool ) ).toThrow( "OriginalJobFailure" );
				expect( exited ).toBeTrue();
			} );
			it( "reports broken recovery diagnostics and terminal fallback without skipping the completion hook", function() {
				var async = new coldbox.system.async.AsyncManager();
				var executor = async.newExecutor(
					"recovery-diagnostics-" & createUUID(),
					"single",
					1
				);
				var diagnostics = createObject( "java", "java.util.concurrent.ConcurrentLinkedQueue" ).init();
				var forced = createObject( "java", "java.util.concurrent.atomic.AtomicBoolean" ).init( false );
				var hookRan = createObject( "java", "java.util.concurrent.atomic.AtomicBoolean" ).init( false );
				var provider = createMock( "cbq.models.Providers.AbstractQueueProvider" );
				provider.$property( "async", "variables", async );
				provider.$property(
					"log",
					"variables",
					{
						canDebug : () => false,
						canError : () => true,
						debug : () => {
						},
						error : () => {
							throw( type = "DiagnosticFailure" );
						},
						warn : function( message, exception ) {
							diagnostics.add( message );
						}
					}
				);
				provider.$property(
					"interceptorService",
					"variables",
					{
						announce : () => {
						}
					}
				);
				provider
					.$( method = "forceFailJob", preserveReturnType = false )
					.$callback( ( id, pool, job ) => {
						forced.set( true );
						throw( type = "TerminalPersistenceFailure" );
					} );
				var job = createMock( "cbq.models.Jobs.AbstractJob" )
					.init()
					.setId( "synthetic" )
					.setMapping( "Synthetic" )
					.setTimeout( 2 );
				job.$( "handle" )
					.$callback( () => {
						throw( type = "OriginalJobFailure" );
					} );
				job.$( "isBatchJob", false );
				var pool = createMock( "cbq.models.Workers.WorkerPool" )
					.init()
					.setExecutor( executor )
					.setMaxAttempts( 1 );
				try {
					provider
						.marshalJob(
							job,
							pool,
							( completedJob, completedPool ) => hookRan.set( true )
						)
						.get( 2500 );
					var messages = [];
					for ( var message in diagnostics.toArray() ) {
						messages.append( message );
					}
					expect( forced.get() ).toBeTrue();
					expect( hookRan.get() ).toBeTrue();
					expect( messages.len() ).toBe( 2 );
					expect( messages[ 1 ] ).toInclude( "onException handler diagnostic" );
					expect( messages[ 2 ] ).toInclude( "forceFailJob fallback" );
				} finally {
					executor.shutdownNow();
				}
			} );
		} );
	}

}
