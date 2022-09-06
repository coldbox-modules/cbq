component accessors="true" {

	property name="name";
	property name="provider";
	property name="defaultQueue" default="default";

	public QueueConnection function push(
		required string queueName,
		required string payload,
		numeric delay = 0,
		numeric attempts = 0
	) {
		getProvider().push( argumentCollection = arguments );
		return this;
	}

}
