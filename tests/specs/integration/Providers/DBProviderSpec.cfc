component extends="tests.resources.AbstractQueueProviderSpec" {

	function getProvider() {
		return getWireBox().getInstance( getProviderMapping() ).setProperties( {} );
	}

	function getProviderMapping() {
		return "DBProvider@cbq";
	}

}
