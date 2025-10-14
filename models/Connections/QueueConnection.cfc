component accessors="true" {

	property name="name";
	property name="provider";
	property name="defaultQueue" default="default";

	public QueueConnection function push(
		required string queueName,
		required AbstractJob job,
		numeric delay = 0,
		numeric attempts = 0
	) {
		getProvider().push( argumentCollection = arguments );
		return this;
	}

	public struct function getMemento() {
		return {
			"name" : variables.name,
			"provider" : variables.provider.getMemento(),
			"defaultQueue" : variables.defaultQueue
		};
	}

	public void function shutdown( boolean force = false, numeric timeout = 60 ) {
		getProvider().shutdown( arguments.force, arguments.timeout );
		return;
	}

}
