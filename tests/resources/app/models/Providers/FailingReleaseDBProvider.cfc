/**
 * Test fixture: a DBProvider whose releaseJob always throws.
 * Used by DBProviderMaxAttemptsSpec to verify that the catch block
 * in marshalJob's .onException handler correctly falls back to
 * markJobFailed when releaseJob fails — without needing MockBox
 * (which interferes with WireBox provider methods in async threads).
 */
component extends="cbq.models.Providers.DBProvider" {

	public void function releaseJob( required any job, required any pool ) {
		throw(
			type = "FailingReleaseDBProvider.SimulatedFailure",
			message = "Simulated releaseJob failure for testing"
		);
	}

}
