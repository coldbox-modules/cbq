component accessors="true" extends="AbstractQueueProvider" {

	property name="async" inject="coldbox:asyncManager";
	property name="executor";

	variables.currentExecutorCount = 0;

	function onDIComplete() {
		variables.executor = variables.async.newExecutor(
			"cbq:ColdBoxAsyncProvider",
			"fixed",
			1
		);
	}

	public any function push(
		required string queueName,
		required string payload,
		numeric delay = 0,
		numeric attempts = 0
	) {
		variables.async
			.newFuture( function() {
				sleep( delay );
				return true;
			}, variables.executor )
			.then( function() {
				return marshalJob( deserializeJob( payload, createUUID(), attempts ) );
			} )
			.onException( function( e ) {
				// log failed job
				if ( "java.util.concurrent.CompletionException" == e.getClass().getName() ) {
					e = e.getCause();
				}

				if ( log.canError() ) {
					log.error( "Exception when running job #job.getId()#:", serializeJSON( e ) );
				}
			} );
	}

	public function function startWorker( required WorkerPool pool ) {
		variables.pool = arguments.pool;
		variables.currentExecutorCount++;
		if ( variables.currentExecutorCount > 1 ) {
			var currentPoolSize = variables.executor.getCorePoolSize();
			var increasedPoolSize = javacast( "int", currentPoolSize + 1 );
			variables.executor.getNative().setMaximumPoolSize( increasedPoolSize );
			variables.executor.getNative().setCorePoolSize( increasedPoolSize );
		}

		return function() {
			variables.currentExecutorCount--;
			var current = variables.executor.getCorePoolSize();
			if ( current > 1 ) {
				var decreasedPoolSize = javacast( "int", current - 1 );
				variables.executor.getNative().setCorePoolSize( decreasedPoolSize );
				variables.executor.getNative().setMaximumPoolSize( decreasedPoolSize );
			}
		};
	}

}
