# cbq

### A protocol-based queueing system for ColdBox

## Requirements

Adobe 2018+ or Lucee 5+
ColdBox 6+

## Definitions

### Queue Connection
A queue connection defines how to connect to a backed service like Redis, RabbitMQ, or even a database.
Any given queue connection can have multiple "queues" which are named stacks of queued jobs or messages to be delivered.

### Queue
A named stack of jobs or messages to be delivered. A queue connection must have at least one queue which is usually "default".  A queue connection can have as many queues as desired.  This is mostly used later when defining queue workers to scale different queues at different priorities.

### Queue Provider
A queue provider is how a queue connection connects to a backend service like Redis, RabbitMQ, or a database.  It implements the necessary interface to send the jobs and to work the queues.  A queue provider can be used multiple times in a single application to define multiple queue connections with different configuration options.

A queue provider **must** extend the `AbstractQueueProvider` and implement the required abstract methods:

+ `public any function push( required string queue, required string payload, numeric delay, numeric attempt )`
+ `public function function startWorker( required WorkerPool pool )`

Additionally, the Queue Provider can use the following hooks to do additional processing or cleanup:

+ `private void function beforeJobRun( required AbstractJob job )`
+ `private void function afterJobRun( required AbstractJob job )`
+ `private void function afterJobFailed( required AbstractJob job )`

### Job
A job is a CFC that follows the `IDispatchableJob` interface (easily done by extending the `AbstractJob` component). It defines how to serialize the job using a memento pattern and deserialize the job from the queue.  It also holds the data needed to execute the job and a `handle` method that is called when working the job from the queue.  Job components exist in the context of your application so you have access to all the models, services, and helpers you have already written.  (Raw string messages can also be dispatched via cbq.  The message will need to be handled directly by your queue worker.)

```cfc
component extends="cbq.models.Jobs.AbstractJob" {

    function handle() {
        sleep( 1000 ); // do some processing work
        log.info( "sending email - #this.getBody()#" );
    }

}
```

## Providers

cbq provides the following providers out of the box:

+ SyncProvider
+ ColdBoxAsyncProvider
+ DatabaseProvider

Future planned providers include:
+ Mock (for testing)
+ RabbitMQ
+ Redis
+ Couchbase

(See the [ROADMAP](ROADMAP.md) for other planned protocols.)

Each of the providers takes different configuration when creating a connection.
Refer to the specific provider documentation for details.

## Installation and Setup

To install cbq, install it from ForgeBox:
```sh
box install cbq
```

You can configure cbq in you `moduleSettings` inside `config/ColdBox.cfc` as follows:
```cfc
moduleSettings = {
    "cbq" : {
        // The path the custom config file to register connections and worker pools
        "configPath" : "config.cbq",
        // Flag if workers should be registered.  If your application only pushes to the queues, you can set this to false.
        "registerWorkers" : getSystemSetting( "CBQ_REGISTER_WORKERS", true ),
        // The interval to poll for changes to the worker pool scaling.  Defaults to 0 which turns off the scheduled scaling feature.
        "scaleInterval" : 0
    }
};
```

Most of the configuration for cbq happens inside the cbq config file, located at `config/cbq.cfc` by convention.

```cfc
component {

    function configure() {
        newConnection( "default" )
            .setProvider( "SyncProvider@cbq" );
    }

    function work() {
        newWorkerPool( "default" );
    }

}
```

In `configure` you define one or more `Connection`s.  You must have at least one `Connection` called `default`.

New `Connection`s are created using the `newConnection` function. It is a builder pattern object. Only a `provider`
must be set. The other setters are optional.

```cfc
newConnection( connectionName )
    .setProvider( providerMapping )
    .onQueue( queueName = "default" )
    .markAsDefault( /* true / false */ );    .
```

In the `work` function you define worker pools to work on `queue`s for a given `Connection` that you defined above.

New `Worker Pool`s are created using the `newWorkerPool` function. It is a builder pattern object.
All of the setters are optional.

```cfc
newWorkerPool( connectionName )
    .quantity( numberOfWorkers )
    .onQueue( queueName = "default" )
    .backoff( backoffTimeInSeconds )
    .timeout( timeoutTimeInSeconds )
    .maxAttempts( maxNumberOfAttempts );
```

## Usage

### Job Components

`Job`s are CFCs that extend `cbq.models.Jobs.AbstractJob`. You need to define a `handle`
method that is ran when the `Job` is processed.

```cfc
// GreetingJob.cfc
component extends="cbq.models.Jobs.AbstractJob" {

    function handle() {
        // this is ran when the job is processed
        log.debug( "Hello world!" );
    }

}
```

To dispatch a job to a queue to be worked, call the `dispatch` method on a `Job` instance.
Dispatching a job serializes it and sends it to the configured connection.  It will
later be picked up by a worker and processed.

```cfc
getInstance( "GreetingJob" ).dispatch();
```

A `Job` is sent to the queue with any of its properties serialized.
You can set the properties of a job by calling the `setProperties`
method and passing a struct of properties.

```cfc
getInstance( "GreetingJob" )
    .setProperties( { "greeting": "Hello" } )
    .dispatch();
```

Additional Job-level properties can be set before dispatching to
override Worker Pool defaults on a per-Job basis.

```cfc
getInstance( "GreetingJob" )
    .setProperties( { "greeting": "Hello" } )
    .setDelay( 10 ) // delay processing this job for 10 seconds
    .dispatch();
```