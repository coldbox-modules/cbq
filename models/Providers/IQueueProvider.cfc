interface displayname="IQueueProvider" {

	public IQueueProvider function push(
		required string queue,
		required AbstractJob job,
		numeric delay,
		numeric attempts
	);
	public IWorker function startWorker( required WorkerPool pool );

}
