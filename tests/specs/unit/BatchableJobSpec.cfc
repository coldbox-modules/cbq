component extends="testbox.system.BaseSpec" {

	function run() {
		describe( "Batchable Job", function() {
			it( "knows if a job is a Batch job", function() {
				var job = new cbq.models.Jobs.AbstractJob();
				expect( job.isBatchJob() ).toBeFalse();
				job.withBatchId( 1 );
				expect( job.isBatchJob() ).toBeTrue();
			} );

			it( "throws an exception when trying to get the Batch for a non-Batch Job", function() {
				var job = new cbq.models.Jobs.AbstractJob();
				expect( function() {
					job.getBatch();
				} ).toThrow( "cbq.MissingBatchId" );
			} );
		} );
	}

}
