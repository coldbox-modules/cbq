component accessors="true" {

	property name="dispatcher" inject="provider:Dispatcher@cbq";
	property name="mapping" inject="wirebox:targetID";
	property name="log" inject="logbox:logger:{this}";
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

	public struct function getMemento() {
		return {
			"id" : this.getId(),
			"mapping" : this.getMapping(),
			"properties" : this.getProperties(),
			"backoff" : this.getBackoff(),
			"timeout" : this.getTimeout(),
			"maxAttempts" : this.getMaxAttempts(),
			"currentAttempt" : this.getCurrentAttempt(),
			"chained" : this.getChained()
		};
	}

}
