component extends="cbq.models.Jobs.AbstractJob" {

	function applyMemento( required struct memento ) {
		super.applyMemento( arguments.memento );
		var proof = application[ getProperties().proofKey ];
		var lane = getProperties().lane;
		if ( structKeyExists( server, "boxlang" ) ) {
			request.cbqPollLane = lane;
		}
		if ( lane == "slow" ) {
			proof.entered.countDown();
			if ( !proof.releaseSlow.await( javacast( "long", 20 ), proof.seconds ) ) {
				throw( message = "Timed out waiting for the other watcher" );
			}
		}
		if ( structKeyExists( server, "boxlang" ) && request.cbqPollLane != lane ) {
			throw( message = "Overlapping polls shared a request" );
		}
		return this;
	}

	function handle() {
		var proof = application[ getProperties().proofKey ];
		var lane = getProperties().lane;
		if ( expandPath( "/app/models/Jobs/ConcurrentPollJob.cfc" ) != proof.jobPath ) {
			throw( message = "Worker resolved the wrong application mapping" );
		}
		proof[ lane ].incrementAndGet();
		if ( lane == "fast" ) {
			if ( !proof.releaseJob.await( javacast( "long", 20 ), proof.seconds ) ) {
				throw( message = "Job dispatch blocked the poll" );
			}
			throw( type = "cbq.tests.ConcurrentPollFailure", message = "Expected job failure" );
		}
	}

}
