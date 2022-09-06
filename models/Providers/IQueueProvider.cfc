interface displayname="IQueueProvider" {

	public IQueueProvider function push( required string queue, required string payload );
	public IWorker function startWorker( required WorkerPool pool );

}
