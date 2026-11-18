component extends="tests.resources.ModuleIntegrationSpec" appMapping="/app" {

	function run() {
		describe( "concurrent database watchers", function() {
			it( "finishes another pool's poll while the first is resolving a reserved job", function() {
				var provider = getInstance( "DBProvider@cbq" ).setProperties( {} );
				var scheduler = getInstance( "coldbox:schedulerService" ).getSchedulers()[ "cbScheduler@cbq" ];
				var connection = getInstance( "QueueConnection@cbq" ).setName( "db" ).setProvider( provider );
				var proofKey = "cbqPoll" & createUUID();
				var proof = {
					"entered" : newLatch(),
					"releaseSlow" : newLatch(),
					"releaseJob" : newLatch(),
					"jobPath" : expandPath( "/app/models/Jobs/ConcurrentPollJob.cfc" ),
					"seconds" : createObject( "java", "java.util.concurrent.TimeUnit" ).SECONDS,
					"slow" : createObject( "java", "java.util.concurrent.atomic.AtomicInteger" ).init( 0 ),
					"fast" : createObject( "java", "java.util.concurrent.atomic.AtomicInteger" ).init( 0 )
				};
				application[ proofKey ] = proof;
				var pools = {};
				var tasks = {};
				var lanes = [ "slow", "fast" ];
				try {
					for ( var lane in lanes ) {
						var queue = lane & proofKey;
						pools[ lane ] = getInstance( "WorkerPool@cbq" )
							.setConnection( connection )
							.setConnectionName( connection.getName() )
							.setName( queue )
							.setQueue( queue )
							.startWorkers();
						tasks[ lane ] = scheduler.getTaskRecord( "cbq:db-watcher:" & pools[ lane ].getUniqueId() ).task;
						provider.push(
							queue,
							getInstance( "ConcurrentPollJob" )
								.onQueue( queue )
								.setProperties( { "proofKey" : proofKey, "lane" : lane } )
						);
					}

					var slow = submitWatcher( tasks.slow );
					expect( proof.entered.await( javacast( "long", 10 ), proof.seconds ) ).toBeTrue();
					var fast = submitWatcher( tasks.fast );
					fast.get( javacast( "long", 10 ), proof.seconds );
					expect( tasks.fast.getStats().lastResult.get() ).toBe( 1 );
					proof.releaseJob.countDown();
					assertOutcome( provider, pools.fast, "failedDate" );
					proof.releaseSlow.countDown();
					slow.get( javacast( "long", 10 ), proof.seconds );
					expect( tasks.slow.getStats().lastResult.get() ).toBe( 1 );
					assertOutcome(
						provider,
						pools.slow,
						"completedDate"
					);
					for ( var lane in lanes ) {
						submitWatcher( tasks[ lane ] ).get( javacast( "long", 10 ), proof.seconds );
						expect( tasks[ lane ].getStats().lastResult.get() ).toBe( 0 );
						expect( proof[ lane ].get() ).toBe( 1 );
					}
					expect( request ).notToHaveKey( "cbqPollLane" );
				} finally {
					proof.releaseJob.countDown();
					proof.releaseSlow.countDown();
					stopPools( pools, scheduler );
					structDelete( application, proofKey );
				}
			} );
		} );
	}

	private any function newLatch() {
		return createObject( "java", "java.util.concurrent.CountDownLatch" ).init( 1 );
	}

	private void function stopPools( required struct pools, required any scheduler ) {
		for ( var lane in pools ) {
			scheduler.removeTask( "cbq:db-watcher:" & pools[ lane ].getUniqueId() );
			pools[ lane ].shutdown();
			getController().getAsyncManager().deleteExecutor( pools[ lane ].getExecutor().getName() );
			var provider = pools[ lane ].getConnection().getProvider();
			provider
				.newQuery()
				.from( "cbq_failed_jobs" )
				.where( "queue", pools[ lane ].getQueue() )
				.delete();
			provider
				.newQuery()
				.from( "cbq_jobs" )
				.where( "queue", pools[ lane ].getQueue() )
				.delete();
		}
	}

	private any function submitWatcher( required any watcher ) {
		return watcher
			.getScheduler()
			.getExecutor()
			.submit( watcher )
			.getNative();
	}

	private void function assertOutcome(
		required any provider,
		required any pool,
		required string column
	) {
		var deadline = getTickCount() + 10000;
		do {
			var row = provider
				.newQuery()
				.from( "cbq_jobs" )
				.where( "queue", pool.getQueue() )
				.first();
			if ( len( row[ column ] ?: "" ) ) {
				break;
			}
			sleep( 20 );
		} while ( getTickCount() < deadline );
		expect( row[ column ] ?: "" ).notToBeEmpty();
		expect( row.reservedBy ).toBe( pool.getUniqueId() );
		expect( row.attempts ).toBe( 1 );
	}

}
