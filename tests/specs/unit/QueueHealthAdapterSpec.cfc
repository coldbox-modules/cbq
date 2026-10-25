component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "provider-owned queue health", function() {
			it( "combines worker activity with the provider's selected queue snapshot", function() {
				var selections = [];
				var provider = {
					getQueueHealth : function( queue ) {
						selections.append( queue );
						return {
							depth : 4,
							oldestAgeSeconds : 10,
							runnable : 3,
							delayed : 1,
							privatePayload : "PRIVATE"
						};
					}
				};
				var pool = {
					getQuantity : function() {
						return 2;
					},
					getQueue : function() {
						return [ "mail", "pdf" ];
					},
					getConnection : function() {
						return {
							getProvider : function() {
								return provider;
							}
						};
					}
				};
				var adapter = prepareMock( new cbq.models.Telemetry.QueueHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getWorkerPool : function() {
							return pool;
						}
					}
				);
				var snapshot = adapter.sample( { options : { workerPool : "outbound" } } );
				expect( snapshot.configuredWorkers ).toBe( 2 );
				expect( snapshot.depth ).toBe( 4 );
				expect( selections[ 1 ] ).toBe( [ "mail", "pdf" ] );
				expect( serializeJSON( snapshot ) ).notToInclude( "PRIVATE" );
				adapter.sample( {
					options : {
						workerPool : "outbound",
						queue : "mail"
					}
				} );
				expect( selections[ 2 ] ).toBe( "mail" );
			} );
			it( "omits backlog when a provider does not support a queue snapshot", function() {
				var adapter = prepareMock( new cbq.models.Telemetry.QueueHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getWorkerPool : function() {
							return {
								getQuantity : function() {
									return 3;
								},
								getConnection : function() {
									return {
										getProvider : function() {
											return {};
										}
									};
								}
							};
						}
					}
				);
				expect( adapter.sample( { options : { workerPool : "outbound" } } ) ).toBe( { configuredWorkers : 3 } );
			} );
			it( "propagates failed provider snapshots rather than pretending backlog is zero", function() {
				var adapter = prepareMock( new cbq.models.Telemetry.QueueHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getWorkerPool : function() {
							return {
								getQuantity : function() {
									return 3;
								},
								getQueue : function() {
									return "mail";
								},
								getConnection : function() {
									return {
										getProvider : function() {
											return {
												getQueueHealth : function() {
													throw( type = "SnapshotFailed" );
												}
											};
										}
									};
								}
							};
						}
					}
				);
				expect( function() {
					adapter.sample( { options : { workerPool : "outbound" } } );
				} ).toThrow( "SnapshotFailed" );
			} );
			it( "samples a connection without resolving workers and preserves queue selections", function() {
				var selections = [];
				var connections = 0;
				var adapter = prepareMock( new cbq.models.Telemetry.QueueHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getWorkerPool : function() {
							throw( type = "UnexpectedWorkerPoolResolution" );
						},
						getConnection : function( name ) {
							expect( name ).toBe( "database" );
							connections++;
							return {
								getDefaultQueue : function() {
									return "default-mail";
								},
								getProvider : function() {
									return {
										getQueueHealth : function( queue ) {
											selections.append( queue );
											return {
												depth : connections,
												privatePayload : "PRIVATE",
												configuredWorkers : 99
											};
										}
									};
								}
							};
						}
					}
				);
				expect( adapter.sample( { options : { connection : "database" } } ) ).toBe( { depth : 1 } );
				expect( selections[ 1 ] ).toBe( "default-mail" );
				for ( var queue in [ "mail", [ "mail", "pdf" ], "*" ] ) {
					var sample = adapter.sample( {
						options : {
							connection : "database",
							queue : queue
						}
					} );
					expect( sample ).toBe( { depth : selections.len() } );
					expect( selections[ selections.len() ] ).toBe( queue );
				}
				expect( connections ).toBe( 4 );
			} );
			it( "rejects ambiguous, legacy and invalid source selectors", function() {
				var adapter = new cbq.models.Telemetry.QueueHealthAdapter();
				for (
					var options in [
						{},
						{ pool : "outbound" },
						{ connection : "" },
						{ connection : [] },
						{ workerPool : " " },
						{ workerPool : [] },
						{
							workerPool : "outbound",
							connection : "database"
						},
						{
							pool : "old",
							workerPool : "outbound"
						},
						{
							pool : "old",
							connection : "database"
						}
					]
				) {
					expect( function() {
						adapter.sample( { name : "default", options : options } );
					} ).toThrow( "cbq.Telemetry.InvalidQueueHealthSelection" );
				}
				expect( function() {
					adapter.sample( {} );
				} ).toThrow( "cbq.Telemetry.InvalidQueueHealthSelection" );
				expect( function() {
					adapter.sample( { options : [] } );
				} ).toThrow( "cbq.Telemetry.InvalidQueueHealthSelection" );
			} );
			it( "omits unsupported connection-only backlog without inventing worker counts", function() {
				var adapter = prepareMock( new cbq.models.Telemetry.QueueHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getConnection : function() {
							return {
								getProvider : function() {
									return {};
								}
							};
						}
					}
				);
				expect( adapter.sample( { options : { connection : "custom" } } ) ).toBe( {} );
			} );
			it( "preserves missing connection errors", function() {
				var adapter = prepareMock( new cbq.models.Telemetry.QueueHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getConnection : function() {
							throw( type = "cbq.MissingQueueConnection" );
						}
					}
				);
				expect( function() {
					adapter.sample( { options : { connection : "missing" } } );
				} ).toThrow( "cbq.MissingQueueConnection" );
			} );
			it( "rejects invalid connection provider snapshots", function() {
				var adapter = prepareMock( new cbq.models.Telemetry.QueueHealthAdapter() ).$property(
					"config",
					"variables",
					{
						getConnection : function() {
							return {
								getProvider : function() {
									return {
										getQueueHealth : function() {
											return "unavailable";
										}
									};
								}
							};
						}
					}
				);
				expect( function() {
					adapter.sample( {
						options : {
							connection : "database",
							queue : "mail"
						}
					} );
				} ).toThrow( "cbq.Telemetry.InvalidQueueHealthResult" );
			} );
		} );
	}

}
