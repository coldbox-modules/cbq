# Queue health snapshot adapter

`QueueHealthAdapter@cbq` reads queue backlog through an explicit connection, or combines worker and queue measurements through an explicit worker pool. It does not start workers, reserve jobs, publish metrics or depend on Sentry. Each call resolves the current connection or worker pool and its provider.

```cfml
moduleSettings.sentry.automaticCollectors = {
    // Start Sentry's periodic sampler.
    enabled: true,
    // One provider-neutral list for queue and worker measurements.
    queues: [ {
        // Fixed logical metric label; independent of cbq worker-pool and queue identifiers.
        name: "mail",
        // Explicit provider-owned implementation. Other queue systems use their own adapters.
        adapter: "QueueHealthAdapter@cbq",
        // Select worker activity plus backlog from this cbq worker pool.
        options: {
            // Its connection chooses the provider; its queue selection chooses the queues.
            workerPool: "outbound"
        }
    } ]
};
```

Sentry also needs its existing valid DSN and `enableMetrics:true`. Its `queues` collector handles worker activity and backlog together; separate worker/database collector definitions are not needed. All measurements use the configured logical queue label. `options.queue` can override the selected queue(s); otherwise the worker pool's string/array/wildcard queue selection applies.

For backlog without local workers, select a connection instead:

```cfml
// Choose queue backlog without collecting shared worker activity.
moduleSettings.sentry.automaticCollectors.queues = [ {
    // Fixed logical metric label.
    name: "mail",
    // Provider-owned adapter; no worker pool is required.
    adapter: "QueueHealthAdapter@cbq",
    // Explicit source and optional queue selection.
    options: {
        // Registered cbq connection; its provider owns storage and database configuration.
        connection: "database",
        // Optional queue name, array or wildcard. Omit to use the connection's default queue.
        queue: "mail"
    }
} ];
```

Configure exactly one of `options.workerPool` or `options.connection`. Missing, empty, nonsimple, ambiguous or legacy `options.pool` selection raises `cbq.Telemetry.InvalidQueueHealthSelection`; no source is inferred from a metric label. Missing registered connections/worker pools and provider sampling failures retain their original errors.

The adapter follows `sample(context)` structurally without importing Sentry's interface. It can be used directly without Sentry:

```cfml
snapshot = wirebox.getInstance( "QueueHealthAdapter@cbq" )
    .sample( { options: { workerPool: "outbound" } } );
```

Worker-pool selection returns `configuredWorkers` and supported `activeExecutions`. If the connection's provider exposes `getQueueHealth(queue)`, either selection includes supported `depth`, `oldestAgeSeconds`, `runnable`, `delayed`, `reserved`, `staleReservations`, `retries` and `exhausted` fields. Connection-only snapshots contain no worker fields. Providers own their snapshot logic; cbq's database provider uses its configured table, query options and datasource. Database counts exclude completed/failed jobs; unclaimed work is runnable or delayed, claimed work is reserved, and expired claims are stale. Queue selections are bound query parameters; `*` selects all queues. No database configuration or cbq schema knowledge is required in Sentry.

Missing capabilities stay absent. A connection-only provider without queue health support returns an empty snapshot, not zero backlog or worker activity. An unstarted executor does not imply zero activity; supported idle executors can report zero. Queue/database sampling errors propagate to the caller's failure diagnostics, rather than pretending a backlog is zero. There are no fabricated worker heartbeats, job IDs, payloads or raw exceptions in successful snapshots.

`WorkerHealthAdapter@cbq` remains an alias, and `samplePool(workerPool)` remains available for earlier manual worker integrations. The adapter must be present in the installed cbq release before selecting its mapping in Sentry. Neither package acquires a dependency on the other.

Earlier local verification of the worker-only implementation and the companion Sentry suite is recorded in the PR. The unified queue changes add combined/backlog-only snapshots, provider-owned table/datasource selection, multiple queues and wildcard/parameter binding coverage. Current local and hosted results are recorded on the draft PRs.

Worker measurements always describe the entire worker pool, even when `options.queue` narrows the backlog selection. Prefer one combined collector per worker pool; use connection-only snapshots for extra per-queue breakdowns so shared worker activity is not counted repeatedly.

Before the explicit connection/worker-pool selector correction, the unified implementation passed 9/9 adapter specs and 137/137 companion Sentry specs on each prepared Lucee 5, BoxLang and Adobe 2023 runtime, including eleven real PostgreSQL/cbq cases. MySQL integration specs exercise provider queue snapshots in cbq's hosted suite. Current selector coverage, hosted results and release prerequisites are recorded on the draft PRs. Formatting and whitespace checks pass; installed application modules were not modified.
