# Queue health snapshot adapter

`QueueHealthAdapter@cbq` combines supported worker and queue measurements in one read-only snapshot. It does not start workers, reserve jobs, publish metrics or depend on Sentry. Each call resolves the current pool and its provider.

```cfml
moduleSettings.sentry.automaticCollectors = {
    enabled: true,
    queues: [ {
        // Fixed logical metric label; independent of provider pool/queue identifiers.
        name: "mail",
        // Explicit provider-owned implementation. Other queue systems use their own adapters.
        adapter: "QueueHealthAdapter@cbq",
        // Required cbq pool. Its connection chooses the provider; its queue selection chooses the queues.
        options: { pool: "outbound" }
    } ]
};
```

Sentry also needs its existing valid DSN and `enableMetrics:true`. Its `queues` collector handles worker activity and backlog together; separate worker/database collector definitions are not needed. All measurements use the configured logical queue label. `options.queue` can override the selected queue(s); otherwise the pool's string/array/wildcard queue selection applies.

The adapter follows `sample(context)` structurally without importing Sentry's interface. It can be used directly without Sentry:

```cfml
snapshot = wirebox.getInstance( "QueueHealthAdapter@cbq" )
    .sample( { options: { pool: "outbound" } } );
```

It returns `configuredWorkers` and supported `activeExecutions`. If the pool's provider exposes `getQueueHealth(queue)`, it also includes supported `depth`, `oldestAgeSeconds`, `runnable`, `delayed`, `reserved`, `staleReservations`, `retries` and `exhausted` fields. Providers own their snapshot logic; cbq's database provider uses its configured table, query options and datasource. Database counts exclude completed/failed jobs; unclaimed work is runnable or delayed, claimed work is reserved, and expired claims are stale. Queue selections are bound query parameters; `*` selects all queues. No database configuration or cbq schema knowledge is required in Sentry.

Missing capabilities stay absent. An unstarted executor does not imply zero activity; supported idle executors can report zero. Queue/database sampling errors propagate to the caller's failure diagnostics, rather than pretending a backlog is zero. There are no fabricated worker heartbeats, job IDs, payloads or raw exceptions in successful snapshots.

`WorkerHealthAdapter@cbq` remains an alias, and `samplePool(workerPool)` remains available for earlier manual worker integrations. The adapter must be present in the installed cbq release before selecting its mapping in Sentry. Neither package acquires a dependency on the other.

Earlier local verification of the worker-only implementation and the companion Sentry suite is recorded in the PR. The unified queue changes add combined/backlog-only snapshots, provider-owned table/datasource selection, multiple queues and wildcard/parameter binding coverage. Current local and hosted results are recorded on the draft PRs.

Worker measurements always describe the entire pool, even when `options.queue` narrows the backlog selection. Prefer one combined collector per pool; use backlog-only snapshots for extra per-queue breakdowns so shared pool activity is not counted repeatedly.

The unified implementation passed 9/9 adapter specs and 137/137 companion Sentry specs on each prepared Lucee 5, BoxLang and Adobe 2023 runtime, including eleven real PostgreSQL/cbq cases. New MySQL integration specs exercise provider queue snapshots in cbq's hosted suite. Current hosted results and release prerequisites are recorded on the draft PRs. Formatting and whitespace checks pass; installed application modules were not modified.
