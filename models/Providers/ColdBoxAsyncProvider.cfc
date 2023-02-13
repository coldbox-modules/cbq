component accessors="true" extends="AbstractQueueProvider" {

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
				sleep( delay * 1000 );
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
		arguments.pool.incrementCurrentExecutorCount();
		if ( arguments.pool.getCurrentExecutorCount() > 1 ) {
			var increasedPoolSize = javacast( "int", arguments.pool.getCurrentExecutorCount() );
			arguments.pool
				.getExecutor()
				.getNative()
				.setMaximumPoolSize( increasedPoolSize );
			arguments.pool
				.getExecutor()
				.getNative()
				.setCorePoolSize( increasedPoolSize );
		}

		return function() {
			pool.decrementCurrentExecutorCount();
			var current = pool.getExecutor().getCorePoolSize();
			var decreasedPoolSize = javacast( "int", current - 1 );
			if ( current > 1 ) {
				pool.getExecutor()
					.getNative()
					.setCorePoolSize( decreasedPoolSize );
				pool.getExecutor()
					.getNative()
					.setMaximumPoolSize( decreasedPoolSize );
			}
		};
	}

	public any function listen( required WorkerPool pool ) {
		return this;
	}

}
