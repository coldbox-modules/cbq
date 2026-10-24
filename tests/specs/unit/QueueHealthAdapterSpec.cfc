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
				var snapshot = adapter.sample( { options : { pool : "outbound" } } );
				expect( snapshot.configuredWorkers ).toBe( 2 );
				expect( snapshot.depth ).toBe( 4 );
				expect( selections[ 1 ] ).toBe( [ "mail", "pdf" ] );
				expect( serializeJSON( snapshot ) ).notToInclude( "PRIVATE" );
				adapter.sample( { options : { pool : "outbound", queue : "mail" } } );
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
				expect( adapter.sample( { options : { pool : "outbound" } } ) ).toBe( { configuredWorkers : 3 } );
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
					adapter.sample( { options : { pool : "outbound" } } );
				} ).toThrow( "SnapshotFailed" );
			} );
		} );
	}

}
