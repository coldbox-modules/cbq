component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "Pending Batch", function() {
			it( "should have no jobs when instantiated", function() {
				var pendingBatch = new cbq.models.Jobs.PendingBatch();
				expect( pendingBatch.getjobs() ).toBe( [] );
			} );
			it( "should support finally for backwards compatibility", function() {
				var pendingBatch = new cbq.models.Jobs.PendingBatch();
				pendingBatch.finally( mockJob() );
				expect( pendingBatch.getFinallyJob() ).toBeInstanceOf( "AbstractJob" );
			} );
			it( "should support onComplete as an alias for finally", function() {
				var pendingBatch = new cbq.models.Jobs.PendingBatch();
				pendingBatch.onComplete( mockJob() );
				expect( pendingBatch.getFinallyJob() ).toBeInstanceOf( "AbstractJob" );
			} );
			it( "should support catch for backwards compatibility", function() {
				var pendingBatch = new cbq.models.Jobs.PendingBatch();
				pendingBatch.catch( mockJob() );
				expect( pendingBatch.getCatchJob() ).toBeInstanceOf( "AbstractJob" );
			} );
			it( "should support onFailure as an alias for catch", function() {
				var pendingBatch = new cbq.models.Jobs.PendingBatch();
				pendingBatch.onFailure( mockJob() );
				expect( pendingBatch.getCatchJob() ).toBeInstanceOf( "AbstractJob" );
			} );
		} );
	}

	private function mockJob() {
		return createMock( "models.Jobs.AbstractJob" );
	}

}
