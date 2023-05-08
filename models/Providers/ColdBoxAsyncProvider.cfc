component accessors="true" extends="AbstractQueueProvider" {

	property name="executor";

	variables.currentExecutorCount = 0;
	variables.blockingQueues = {};

	this.$timeUnit = new coldbox.system.async.time.TimeUnit();

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
		log.debug( "Pushing job to queue: #queueName#" );
		if ( !variables.blockingQueues.keyExists( queueName ) ) {
			log.debug( "Creating BlockingQueue for: #queueName#" );
			variables.blockingQueues[ queueName ] = createObject( "java", "java.util.concurrent.LinkedBlockingQueue" ).init();
		}
		variables.async
			.newFuture( function() {
				sleep( delay * 1000 );
				return true;
			} )
			.then( function() {
				log.debug( "Adding job to BlockingQueue for #queueName#", payload );
				variables.blockingQueues[ queueName ].put( payload );
			} );
		return this;
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

		// queue the jobs according to their specified queue
		// have the worker pools listening to the queues; they check their queues in order.
		// the wildcard queue checks all the types of queues
		// TODO: how to disconnect
		log.debug( "Starting listener for #arguments.pool.getName()#" );
		var future = variables.async.newFuture( function() {
			while ( true ) {
				for ( var queueName in pool.getQueues() ) {
					while ( true ) {
						var payload = javacast( "null", "" );
						if ( queueName == "*" ) {
							for ( var queueToCheck in variables.blockingQueues ) {
								payload = variables.blockingQueues[ queueToCheck ].poll(
									javacast( "long", 1 ),
									this.$timeUnit.get( "seconds" )
								);

								if ( !isNull( payload ) ) {
									break;
								}
							}
						} else if ( variables.blockingQueues.keyExists( queueName ) ) {
							payload = variables.blockingQueues[ queueName ].poll(
								javacast( "long", 1 ),
								this.$timeUnit.get( "seconds" )
							);
						}

						if ( isNull( payload ) ) {
							break;
						}

						var job = deserializeJob( payload, createUUID() );
						variables.async
							.newFuture( function() {
								log.debug( "Starting job ###job.getId()# on #pool.getName()#" );
								return marshalJob( job, pool );
							}, pool.getExecutor() )
							.onException( function( e ) {
								// log failed job
								if ( "java.util.concurrent.CompletionException" == e.getClass().getName() ) {
									e = e.getCause();
								}

								if ( log.canError() ) {
									log.error(
										"Exception when running job: #e.message#",
										{
											"job" : job.getMemento(),
											"exception" : e
										}
									);
								}
							} );

						break;
					}
				}
			}
		} );

		return function() {
			future.cancel();
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
