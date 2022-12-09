component extends="AbstractJob" accessors="true" {

	property name="batchId" type="string";
	property
		name="isLifecycleJob"
		type="boolean"
		default="false";

	public BatchableJob function withBatchId( required string id ) {
		variables.batchId = arguments.id;
		return this;
	}

	public Batch function getBatch() {
		return getRepository().find( variables.batchId );
	}

	public cbq function getRepository() provider="DBBatchRepository@cbq" {
	}

	public struct function getMemento() {
		return {
			"id" : this.getId(),
			"connection": this.getConnection(),
			"queue": this.getQueue(),
			"mapping" : this.getMapping(),
			"properties" : this.getProperties(),
			"backoff" : this.getBackoff(),
			"timeout" : this.getTimeout(),
			"maxAttempts" : this.getMaxAttempts(),
			"currentAttempt" : this.getCurrentAttempt(),
			"chained" : this.getChained(),
			"batchId" : isNull( this.getBatchId() ) ? javacast( "null", "" ) : this.getBatchId(),
			"isLifecycleJob" : this.getIsLifecycleJob()
		};
	}

}
