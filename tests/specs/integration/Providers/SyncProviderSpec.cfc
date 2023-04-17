component extends="tests.resources.AbstractQueueProviderSpec" {

	function getProviderMapping() {
		return "SyncProvider@cbq";
	}

}
