interface displayname="IDispatchableJob" {

	public void function handle();

	public IDispatchableJob function dispatch();

	public any function getId();

	public string function getMapping();

	public struct function getMemento();

	public struct function getProperties();
	public IDispatchableJob function setProperties( required struct props );

	public string function getConnection();
	public IDispatchableJob function setConnection( required string connection );

	public string function getQueue();
	public IDispatchableJob function setQueue( string queueName );

	public numeric function getBackoff();
	public IDispatchableJob function setBackoff( numeric backoff );

	public numeric function getTimeout();
	public IDispatchableJob function setTimeout( numeric timeout );

	public numeric function getMaxAttempts();
	public IDispatchableJob function setMaxAttempts( numeric maxAttempts );

	public numeric function getCurrentAttempts();
	public IDispatchableJob function setCurrentAttempts( numeric currentAttempts );

}
