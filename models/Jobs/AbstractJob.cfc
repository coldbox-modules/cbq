component accessors="true" {

	property name="dispatcher" inject="provider:Dispatcher@cbq";
	property name="mapping" inject="wirebox:targetID";
	property name="log" inject="logbox:logger:{this}";
	property name="cbq" inject="provider:cbq@cbq";
	property name="wirebox" inject="wirebox";
	property name="str" inject="Str@Str";

	property name="id";
	property name="connection";
	property name="queue";
	property name="backoff";
	property name="timeout";
	property name="maxAttempts";
	property name="currentAttempt";
	property name="chained" type="array";
	property name="batchId" type="string";
	property
		name="isReleased"
		type="boolean"
		default="false";
	property
		name="isLifecycleJob"
		type="boolean"
		default="false";

	property name="properties";

	function init() {
		variables.properties = {};
		variables.chained = [];
		return this;
	}

	function handle() {
		throw(
			type = "MissingAbstractMethod",
			message = "This is an abstract method and must be implemented in a subclass."
		);
	}

	public any function setProperties( required struct properties ) {
		variables.properties = arguments.properties;
		for ( var key in arguments.properties ) {
			if ( structKeyExists( variables, "set#key#" ) ) {
				invoke(
					this,
					"set#key#",
					{ "1" : arguments.properties[ key ] }
				);
			}
		}
		return this;
	}

	public AbstractJob function onConnection( required string name ) {
		setConnection( arguments.name );
		return this;
	}

	public AbstractJob function onQueue( required string name ) {
		setQueue( arguments.name );
		return this;
	}

	public AbstractJob function dispatch() {
		getDispatcher().dispatch( this );
		return this;
	}

	public AbstractJob function release( numeric backoff = 0 ) {
		variables.isReleased = true;
		setBackoff( arguments.backoff );
		return this;
	}

	public any function getInstance() {
		return variables.wirebox.getInstance( argumentCollection = arguments );
	}

	public AbstractJob function setDelay( required numeric delay ) {
		variables.backoff = arguments.delay;
		return this;
	}

	public AbstractJob function chain( required array jobs ) {
		variables.chained = arguments.jobs.map( function( job ) {
			return isObject( job ) ? job.getMemento() : job;
		} );
		return this;
	}

	public any function onMissingMethod( required string missingMethodName, struct missingMethodArguments = {} ) {
		if ( variables.str.startsWith( arguments.missingMethodName, "get" ) ) {
			var propertyName = variables.str.slice( arguments.missingMethodName, 4 );
			return variables.properties[ propertyName ];
		}

		if ( variables.str.startsWith( arguments.missingMethodName, "set" ) ) {
			var propertyName = variables.str.slice( arguments.missingMethodName, 4 );
			var firstKey = structKeyArray( arguments.missingMethodArguments )[ 1 ];
			var value = arguments.missingMethodArguments[ firstKey ];
			variables.properties[ propertyName ] = value;
			return this;
		}

		throw( "No method [#missingMethodName#] found on [#variables.mapping#]" );
	}

	public boolean function isBatchJob() {
		return !isNull( variables.batchId );
	}

	public AbstractJob function withBatchId( required string id ) {
		variables.batchId = arguments.id;
		return this;
	}

	public Batch function getBatch() {
		if ( !isBatchJob() ) {
			throw(
				type = "cbq.MissingBatchId",
				message = "Cannot fetch a Batch without a batchId. If needed, you can check if a job is a Batch job using the `isBatchJob()` method."
			);
		}

		return getRepository().find( variables.batchId );
	}

	public any function getRepository() provider="DBBatchRepository@cbq" {
	}

	public struct function getMemento() {
		return {
			"id" : this.getId(),
			"connection" : this.getConnection(),
			"queue" : this.getQueue(),
			"mapping" : this.getMapping(),
			"properties" : this.getProperties(),
			"backoff" : this.getBackoff(),
			"timeout" : this.getTimeout(),
			"maxAttempts" : this.getMaxAttempts(),
			"currentAttempt" : this.getCurrentAttempt(),
			"chained" : this.getChained(),
			"batchId" : isBatchJob() ? this.getBatchId() : javacast( "null", "" ),
			"isLifecycleJob" : this.getIsLifecycleJob()
		};
	}

	public AbstractJob function applyMemento( required struct memento ) {
		param arguments.memento.properties = {};

		if ( !isNull( arguments.memento.queue ) ) {
			this.setQueue( arguments.memento.queue );
		}

		if ( !isNull( arguments.memento.connection ) ) {
			this.setConnection( arguments.memento.connection );
		}

		if ( !isNull( arguments.memento.timeout ) ) {
			this.setTimeout( arguments.memento.timeout );
		}

		if ( !isNull( arguments.memento.backoff ) ) {
			this.setBackoff( arguments.memento.backoff );
		}

		if ( !isNull( arguments.memento.maxAttempts ) ) {
			this.setMaxAttempts( arguments.memento.maxAttempts );
		}

		if ( !isNull( arguments.memento.currentAttempt ) ) {
			this.setCurrentAttempt( arguments.memento.currentAttempt );
		}

		if ( !isNull( arguments.memento.chained ) ) {
			this.setChained( arguments.memento.chained );
		}

		this.setProperties( arguments.memento.properties );

		return this;
	}

	private boolean function checkInterrupted() {
		var thisThread = createObject( "java", "java.lang.Thread" ).currentThread();
		// Has the user tried to interrupt this thread?
		return thisThread.interrupted();
	}

}
