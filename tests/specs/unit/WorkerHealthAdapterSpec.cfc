component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "worker health snapshot adapter", function() {
			it( "requires an explicit worker pool and never treats the metric name as a default", function() {
				var adapter = new cbq.models.Telemetry.WorkerHealthAdapter();
				for (
					var options in [
						{},
						{ workerPool : "" },
						{ workerPool : [] }
					]
				) {
					expect( function() {
						adapter.sample( { name : "default", options : options } );
					} ).toThrow( "cbq.Telemetry.InvalidQueueHealthSelection" );
				}
				expect( function() {
					adapter.sample( { name : "default" } );
				} ).toThrow( "cbq.Telemetry.InvalidQueueHealthSelection" );
			} );
			it( "resolves the configured pool freshly for every snapshot without exposing options", function() {
				var calls = 0;
				var quantity = 2;
				var adapter = prepareMock( new cbq.models.Telemetry.WorkerHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getWorkerPool : function( pool ) {
							expect( pool ).toBe( "outbound" );
							calls++;
							return {
								getQuantity : function() {
									return quantity;
								}
							};
						}
					}
				);
				var context = {
					name : "mail",
					options : {
						workerPool : "outbound",
						secret : "PRIVATE"
					}
				};
				expect( adapter.sample( context ).configuredWorkers ).toBe( 2 );
				quantity = 4;
				expect( adapter.sample( context ).configuredWorkers ).toBe( 4 );
				expect( calls ).toBe( 2 );
				expect( serializeJSON( adapter.sample( context ) ) ).notToInclude( "PRIVATE" );
			} );
			it( "reports measured activity rather than executor capacity", function() {
				var adapter = new cbq.models.Telemetry.WorkerHealthAdapter();
				var snapshot = adapter.samplePool( {
					getQuantity : function() {
						return 4;
					},
					getCurrentExecutorCount : function() {
						return 4;
					},
					getExecutor : function() {
						return {
							getStats : function() {
								return {
									features : { taskMethods : true },
									activeCount : 1
								};
							}
						};
					}
				} );
				expect( snapshot.configuredWorkers ).toBe( 4 );
				expect( snapshot.activeExecutions ).toBe( 1 );
				expect( snapshot ).notToHaveKey( "activeWorkers" );
				expect( snapshot ).notToHaveKey( "lastHeartbeatAt" );
			} );
			it( "omits unsupported or unavailable activity instead of reporting zero", function() {
				var adapter = new cbq.models.Telemetry.WorkerHealthAdapter();
				for (
					var stats in [
						{},
						{ activeCount : 0 },
						{
							features : { taskMethods : false },
							activeCount : 0
						}
					]
				) {
					var snapshot = adapter.samplePool( {
						getQuantity : function() {
							return 4;
						},
						getExecutor : function() {
							return {
								getStats : function() {
									return stats;
								}
							};
						}
					} );
					expect( snapshot ).toBe( { configuredWorkers : 4 } );
				}
				expect(
					adapter.samplePool( {
						getQuantity : function() {
							return 4;
						}
					} )
				).toBe( { configuredWorkers : 4 } );
			} );
			it( "preserves missing pool errors rather than inventing a snapshot", function() {
				var adapter = prepareMock( new cbq.models.Telemetry.WorkerHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getWorkerPool : function() {
							throw( type = "cbq.MissingWorkerPool" );
						}
					}
				);
				expect( function() {
					adapter.sample( { options : { workerPool : "missing" } } );
				} ).toThrow( "cbq.MissingWorkerPool" );
			} );
			it( "reads supported activity from an actual ColdBox executor", function() {
				var native = createObject( "java", "java.util.concurrent.Executors" ).newFixedThreadPool(
					javacast( "int", 1 )
				);
				try {
					var executor = new coldbox.system.async.executors.Executor( "health-adapter", native );
					var adapter = new cbq.models.Telemetry.WorkerHealthAdapter();
					var snapshot = adapter.samplePool( {
						getQuantity : function() {
							return 1;
						},
						getExecutor : function() {
							return executor;
						}
					} );
					var stats = executor.getStats();
					if (
						stats.keyExists( "features" ) && stats.features.keyExists( "taskMethods" ) && stats.features.taskMethods
					) {
						expect( snapshot.activeExecutions ).toBe( 0 );
					} else {
						expect( snapshot ).notToHaveKey( "activeExecutions" );
					}
				} finally {
					native.shutdownNow();
				}
			} );
		} );
	}

}
