# Worker health snapshot adapter

`WorkerHealthAdapter@cbq` provides read-only snapshots of a registered cbq worker pool. It does not start workers, poll the queue provider, publish metrics or depend on Sentry. Each call resolves the pool again, so it follows the current registered pool rather than caching a stale instance.

For Sentry automatic collection, select the adapter explicitly:

```cfml
moduleSettings.sentry.automaticCollectors = {
    enabled: true,
    queueWorkers: [ {
        // Fixed metric label; this does not choose a pool.
        name: "mail",
        // Provider-owned snapshot implementation; other queue providers use their own adapters.
        adapter: "WorkerHealthAdapter@cbq",
        // Explicit cbq pool selection. No default pool is assumed.
        options: { pool: "outbound" }
    } ]
};
```

Sentry also needs its existing valid DSN and `enableMetrics:true` settings. No Sentry setting or dependency is needed to use the snapshot directly:

```cfml
snapshot = wirebox.getInstance( "WorkerHealthAdapter@cbq" )
    .sample( { options: { pool: "outbound" } } );
// Or samplePool(workerPool) when the caller already has the pool instance.
```

The adapter follows the optional `ISnapshotAdapter.sample(context)` contract structurally; it does not import Sentry's interface. `options.pool` must be supplied explicitly. Missing configuration or an unregistered pool throws an error so the caller can record a failed sample rather than a false zero.

Snapshots contain `configuredWorkers` from pool quantity and `activeExecutions` only when the executor advertises `features.taskMethods` and reports `activeCount`. Configured concurrency and current executor capacity are not active worker counts. ColdBox versions or executor types without supported activity statistics omit `activeExecutions`; an unstarted executor also leaves it absent. A measured idle executor can report zero. The snapshot does not manufacture a worker heartbeat, retry totals, queue backlog, job identifiers or payload data.

Local verification and release requirements are recorded with the companion Sentry change. This adapter must be present in the installed cbq version before configuring its mapping in Sentry; it is not included in older cbq releases.

Local checks passed on prepared Lucee 5.4.8.2, BoxLang 1.18.0+66 and Adobe 2023 update 25 runtimes (Java 21): 6/6 adapter specs and 134/134 companion Sentry specs per engine, with zero failures/errors/skips. The latter includes ten PostgreSQL 18.1 cases with actual cbq workers, including automatic WireBox resolution of this adapter and idle/busy worker activity. cbq source was `next` base `fad884a` plus this adapter; qb 14.1.0, ColdBox 7.5.2 and TestBox 3.2 were supplied by the isolated Sentry harness. The complete cbq suite was not run locally. This does not qualify crash recovery, actual worker heartbeats, other queue providers or real Sentry delivery/indexing.
