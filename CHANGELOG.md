# v5.0.2
## 13 Oct 2025 — 19:31:41 UTC

### fix

+ __ModuleConfig:__ Add missing `config` variable in ModuleConfig
 ([1cff751](https://github.com/coldbox-modules/cbq/commit/1cff751c7f88988304ead62b2e8a25fd2c02a18c))


# v5.0.1
## 10 Oct 2025 — 17:13:35 UTC

### fix

+ __QueueProvider:__ Add exception to the `afterJobException` and `afterJobFailed` lifecycle methods
 ([d263896](https://github.com/coldbox-modules/cbq/commit/d263896718cdcfe9a4b54c3bb13d1c62ac1102e2))


# v5.0.0
## 10 Oct 2025 — 16:37:07 UTC

### BREAKING

+ __AbstractQueueProvider:__ Pass in the full job object to `push` ([dcd077f](https://github.com/coldbox-modules/cbq/commit/dcd077fe6d822ad7ede0fa2cd32ead4371483efc))

### chore

+ __CI:__ Update CI matrix
 ([ace3afa](https://github.com/coldbox-modules/cbq/commit/ace3afa8e23ff15637f1e9fbb6a487fbaba25618))

### feat

+ __AbstractJob:__ Allow Jobs to be cancelled, preventing further retries
 ([5ece4df](https://github.com/coldbox-modules/cbq/commit/5ece4df2616f10a43b5ca5002887e6b081506504))
+ __AbstractQueueProvider:__ Add a `afterJobExpection` provider-level method
 ([1262a67](https://github.com/coldbox-modules/cbq/commit/1262a670b6e56828a9f0ae608ccf64e8d532c7c4))
+ __AbstractJob:__ Add a `providerContext` field on the job ([dae0d8e](https://github.com/coldbox-modules/cbq/commit/dae0d8efac1ab545402a54d9ecf4b473041e3035))
+ __lifecycle:__ Call `shutdown` on connections and workers on `onUnload` ([fb7d808](https://github.com/coldbox-modules/cbq/commit/fb7d808bfed9102ae7370f1d6a9b47c78950f042))

### fix

+ __ModuleConfig:__ Use `afterConfigurationLoad` to let all other modules load ([1791bb9](https://github.com/coldbox-modules/cbq/commit/1791bb99c256bcfcec36b5bdfc93aaf85300f4f2))


# v4.0.0
## 31 Jan 2025 — 17:41:44 UTC

### BREAKING

+ __Batch:__ ACF currently errors when compiling PendingBatch.cfc ([78c0c39](https://github.com/coldbox-modules/cbq/commit/78c0c39042538112e5fb2bcfe96ec873fc1d0ee5))
+ __FailedJobs:__ Use a unix timestamp as the failed job log failedDate column type ([0f36ad8](https://github.com/coldbox-modules/cbq/commit/0f36ad88caac3ce4f19cf76c498642933389ec7a))
+ __DBProvider:__ Better locking to avoid duplicate runs of the same job ([eed4c61](https://github.com/coldbox-modules/cbq/commit/eed4c6184745e53a59a1b51b66c02657e11834ef))
+ __Config:__ Worker Pools can only define a single queue to work. (#15) ([a417b09](https://github.com/coldbox-modules/cbq/commit/a417b09e66d805f33870bf4607f1262754a98a15))
+ __Config:__ Remove work method in favor of configure ([eb94b08](https://github.com/coldbox-modules/cbq/commit/eb94b0808172259b0bf94d3ae868e0d800292f41))

### chore

+ __DBProvider:__ Remove `lockForUpdate` flag and add debug logging
 ([413760f](https://github.com/coldbox-modules/cbq/commit/413760f93f3ffb5e3b5fb8609f3a309afe74d0ab))

### feat

+ __WorkerPool:__ Make shutdown timeout configurable
 ([575651c](https://github.com/coldbox-modules/cbq/commit/575651c916d8fbb94619f6468e9fdade94cf923e))
+ __DBProvider:__ Add back ability to work on multiple queues ([364b9ca](https://github.com/coldbox-modules/cbq/commit/364b9ca4b1d0d138877ed148774301985203c27b))
+ __Interceptors:__ Add ability to restrict interceptor execution with `jobPattern` ([552e8ae](https://github.com/coldbox-modules/cbq/commit/552e8ae1edc9b7ad8db575d4c15b250b1d86a5ad))
+ __Job:__ Add support for `before` and `after` lifecycle methods ([8cf8390](https://github.com/coldbox-modules/cbq/commit/8cf839098f3571dfe37f385bcb39a1c24deef115))
+ __Config:__ Add environment detection for config file ([7004069](https://github.com/coldbox-modules/cbq/commit/700406998b67a46028230f90c3459450b8acb5e6))

### fix

+ __Batch:__ Don't override Batch job queues unless one is specifically requested
 ([6926067](https://github.com/coldbox-modules/cbq/commit/6926067c3a28655a80ab967a92cfdd64e1af23c3))
+ __SyncProvider:__ Fix stack overflow when releasing a job too many times ([5997087](https://github.com/coldbox-modules/cbq/commit/599708759cbb1f90e30a2f21e3e3ab2d8a1cca1d))
+ __SyncProvider:__ Add chained jobs to the Sync job memento. ([b1af5aa](https://github.com/coldbox-modules/cbq/commit/b1af5aae205b06e3c749be26b200670f416c90e6))
+ __SyncProvider:__ Un-nest chains to prevent stack overflows
 ([b89c81a](https://github.com/coldbox-modules/cbq/commit/b89c81a5c47f6d353a0d46110eba5739bb16e4c6))
+ __FailedJobs:__ Fix variable name
 ([b6e5f40](https://github.com/coldbox-modules/cbq/commit/b6e5f40dc993db45e7efdf311fa24152a65a712c))
+ __FailedJobs:__ Inject logbox into the interceptor
 ([f759d4f](https://github.com/coldbox-modules/cbq/commit/f759d4ffa50af9a1f4f07bb9a20b15fbb0039de4))
+ __FailedJobs:__ Use CF_SQL_VARCHAR as the SQL type for `originalId`
 ([041f34b](https://github.com/coldbox-modules/cbq/commit/041f34bcdada079647c226f2bc812293b4c44564))
+ __FailedJobs:__ Make originalId able to track all provider ids
 ([ecbade0](https://github.com/coldbox-modules/cbq/commit/ecbade0102f93d27fd2096e392f0dbe9371b27fb))
+ __FailedJobs:__ Log errors logging failed jobs
 ([fd4bffa](https://github.com/coldbox-modules/cbq/commit/fd4bffab61a5046b8baf263e37666292e0cdd760))
+ __DBProvider:__ Fix releasing job timeouts using the wrong value
 ([276a473](https://github.com/coldbox-modules/cbq/commit/276a473879cb3a354fed911094aa59ad046a2b10))
+ __DBProvider:__ Allow picking up of jobs that were previously reserved but not released correctly
 ([67c3659](https://github.com/coldbox-modules/cbq/commit/67c365927f27eafc85c727b972465249912805c3))
+ __DBProvider:__ When claiming a job, the DBProvider should extend the availableDate by the job timeout, not backoff.
 ([bb0b0e2](https://github.com/coldbox-modules/cbq/commit/bb0b0e20487255ecf99c6d4abf10b3de99e4b6ee))
+ __WorkerPool:__ Correctly shutdown worker pools
 ([fcaee85](https://github.com/coldbox-modules/cbq/commit/fcaee854ba4fd7340b0d2ced25008b49c46f4165))
+ __DBProvider:__ Fix for unwrapping an Optional in a log message
 ([9025919](https://github.com/coldbox-modules/cbq/commit/90259191841ef00073bfc4dab188cc02916a8b35))
+ __DBProvider:__ Disable forceRun until we figure out why it's losing mappings
 ([4418d4c](https://github.com/coldbox-modules/cbq/commit/4418d4c67428144eb77827fb34338c46e9df5f49))
+ __SyncProvider:__ Add pool to releaseJob call
 ([0430bcd](https://github.com/coldbox-modules/cbq/commit/0430bcda975a373532fed2770cf654f209ea53ff))
+ __ColdBoxAsyncProvider:__ Respect WorkerPools in ColdBoxAsyncProvider
 ([a5011f3](https://github.com/coldbox-modules/cbq/commit/a5011f3459d13d4804848700a7c9ca89afab21e7))
+ __ColdBoxAsyncProvider:__ Fix unbound thread CPU usage in ColdBoxAsyncProvider ([54ae0bf](https://github.com/coldbox-modules/cbq/commit/54ae0bfefaaa968c7b1588773acdbe0cd5fdc98d))
+ __box.json:__ Upgrade to qb v9 ([08b9e2e](https://github.com/coldbox-modules/cbq/commit/08b9e2e69131e4b0ac9e50b9b9902f723c64a2fd))
+ __DBProvider:__ Fix duplicate job runs ([5736613](https://github.com/coldbox-modules/cbq/commit/5736613863219c1986fa52de8a0cff647f00df3a))
+ __DBProvider:__ Missing Parameter to releaseJob ([6b079d8](https://github.com/coldbox-modules/cbq/commit/6b079d8fb1d2cb052676916931708090aecd1a6a))
+ __SyncProvider:__ Pass the pool to getMaxAttemptsForJob ([d5d6742](https://github.com/coldbox-modules/cbq/commit/d5d6742cfbf37639e31387ddd1895c8a600a917e))
+ __Scheduler:__ Fix onAnyTaskError exception logging
 ([43e56c2](https://github.com/coldbox-modules/cbq/commit/43e56c2050ca31d69d5c393570f3c84cc864b203))

### other

+ __\*:__ ci: Adds Coldbox 7 Tests and Experimental Matrix (#18) ([1eb27a3](https://github.com/coldbox-modules/cbq/commit/1eb27a3145f02d7a8877845c4d089b5a9032b373))
+ __\*:__ fix: Replace typo excpetion with exception ([56cdd07](https://github.com/coldbox-modules/cbq/commit/56cdd07d12d59080f554e818a35ecae422ec2f26))
+ __\*:__ fix: Update syntax for Lucee 6.1 and ACF ([a4f4502](https://github.com/coldbox-modules/cbq/commit/a4f4502e443a14cad93d13259a96f4a52681a865))
+ __\*:__ Fix missing shutdownTimeout variable
 ([9bb553c](https://github.com/coldbox-modules/cbq/commit/9bb553c8b7ce7e0d1217e0578469928363557dab))
+ __\*:__ feat: Add clean-up tasks for completed or failed jobs, failed job logs, and completed or cancelled batches.
 ([80ee9e9](https://github.com/coldbox-modules/cbq/commit/80ee9e9afc271df06e86fe86fd19dffb3b5e9bb6))
+ __\*:__ v3.0.0-beta.1
 ([139302b](https://github.com/coldbox-modules/cbq/commit/139302b807ae44b124219adbb64a974797d120dc))
+ __\*:__ fix: reload module mappings in an attempt to work around ColdBox Async losing them
 ([152e282](https://github.com/coldbox-modules/cbq/commit/152e28275a04cdd6d01be380d05759c11af8b368))
+ __\*:__ fix: Fix moduleSettings missing a queryOptions key for failed jobs
 ([f47402d](https://github.com/coldbox-modules/cbq/commit/f47402dc5d93bbaf54e14ecb28a9e1ed03406be7))
+ __\*:__ v1.0.0 ([d4196ed](https://github.com/coldbox-modules/cbq/commit/d4196edcc9120ad90a80129a0f969ef07a0b2221))
+ __\*:__ fix: Adjust moduleSettings to be more internally consistent.
 ([1898ebd](https://github.com/coldbox-modules/cbq/commit/1898ebd4d0241b958c49e55e1ce01569d7300510))
+ __\*:__ chore: code cleanup
 ([3e4baae](https://github.com/coldbox-modules/cbq/commit/3e4baae7c98e6e4f20b85c48d8c2b87203be8b28))
+ __\*:__ fix: Update ColdBoxAsyncProvider for named worker pools
 ([bb169c3](https://github.com/coldbox-modules/cbq/commit/bb169c3d4743b9218c2068f145cd02c7d3b3429d))
+ __\*:__ feat: Add failed jobs table and interceptor
 ([edc7952](https://github.com/coldbox-modules/cbq/commit/edc795227fa8006e58f9ad95d5d8e0a0c9c8a3e4))
+ __\*:__ fix: Ensure batch jobs are recorded from SyncProvider
 ([c3161f8](https://github.com/coldbox-modules/cbq/commit/c3161f862eda5d00f408b0fa47a110fdbc2668be))
+ __\*:__ feat: Allow setting connections on Batches
 ([a612729](https://github.com/coldbox-modules/cbq/commit/a612729e1b7d59c5331a38ece226bc8073021f4a))
+ __\*:__ feat: Allow for infinite attempts when setting maxAttempts to 0
 ([3467e26](https://github.com/coldbox-modules/cbq/commit/3467e261be864dfe5f1f20f6ae124c9d5d946467))
+ __\*:__ tests: Temporarily only test on Lucee 5
 ([84b200f](https://github.com/coldbox-modules/cbq/commit/84b200f361ced5ceafa827f07a390844f724be73))
+ __\*:__ tests: ACF-specific fixes
 ([7328566](https://github.com/coldbox-modules/cbq/commit/73285668fdcf90c07c23c663adcbc95a4194807b))
+ __\*:__ tests: Fix for ACF and MockBox
 ([d85e869](https://github.com/coldbox-modules/cbq/commit/d85e869b734a50d4cc57a9c9203b0c3946852337))
+ __\*:__ tests: Install cfconfig in pipelines
 ([e3b58dd](https://github.com/coldbox-modules/cbq/commit/e3b58dd4ba4eebc99574a7a620438b93a3d35400))
+ __\*:__ tests: Add CFMigrations dependency
 ([d49d906](https://github.com/coldbox-modules/cbq/commit/d49d90689c4017659372380ce538c92ed1241151))
+ __\*:__ tests: Add database for DBProvider tests
 ([0cee608](https://github.com/coldbox-modules/cbq/commit/0cee60879965e751ff959d0974fe79267889e3a3))
+ __\*:__ docs: Add docblocks to PendingBatch
 ([20ecb08](https://github.com/coldbox-modules/cbq/commit/20ecb08e4849324c9c232881fd179cf4815c6b8f))
+ __\*:__ feat: Manually `release` a job inside the `handle` method. ([451b616](https://github.com/coldbox-modules/cbq/commit/451b6169cd3c25feb6a27913cb7a225b1eed6a01))
+ __\*:__ feat: BatchableJob is no longer needed; it all goes through AbstractJob
 ([751e138](https://github.com/coldbox-modules/cbq/commit/751e1380a8038c3093c52f09174be2913bef5df5))
+ __\*:__ fix: Avoid calling getMemento() on null jobs in PendingBatch ([01d8591](https://github.com/coldbox-modules/cbq/commit/01d85912f95fc236cf082f5074136b670ca37e77))
+ __\*:__ chore: Update README newWorkerPool function ([077772d](https://github.com/coldbox-modules/cbq/commit/077772d4e84a2ef5e81f3cb8818167887d22df36))
+ __\*:__ fix: incorrect throw that causing raw HTML as the exception message ([c8ae745](https://github.com/coldbox-modules/cbq/commit/c8ae74532ddf5632db559eb65251250cfb44894f))
+ __\*:__ feat: Provide cbq helper to jobs by default
 ([dd0d5eb](https://github.com/coldbox-modules/cbq/commit/dd0d5eb5445d92fe99c094c070a9c4f5282e5bc8))
+ __\*:__ fix: Add missing queryOptions to qb calls
 ([767c4f7](https://github.com/coldbox-modules/cbq/commit/767c4f748907a942e666668df67e2cd2fa650b3d))
+ __\*:__ feat: if a job defines an `onFailure` method, call it when the job fails
 ([6b091f7](https://github.com/coldbox-modules/cbq/commit/6b091f7ab0955218234b7ef989532716a737102b))
+ __\*:__ fix: Allow for setting different datasources for Batches
 ([4f54b79](https://github.com/coldbox-modules/cbq/commit/4f54b79263defcec0ec5f07c527da4a224035714))
+ __\*:__ feat: Use module defaults for worker pool settings
 ([81b3484](https://github.com/coldbox-modules/cbq/commit/81b3484016e360a100b25dd7cbb081bd96782692))
+ __\*:__ chore: Clean up LogBox logs for better error grouping in StacheBox
 ([ca4f738](https://github.com/coldbox-modules/cbq/commit/ca4f738973fec7d367a228d199544f7086509e89))
+ __\*:__ feat: Docblocks, listen block for Sync Provider, remove onQueue from QueueConnectionDefinition
 ([750a166](https://github.com/coldbox-modules/cbq/commit/750a1667e908cdd4775d8d2170b11c73d73441dd))
+ __\*:__ feat: Enable multiple worker pools per connection and queue priority order
 ([56f0456](https://github.com/coldbox-modules/cbq/commit/56f04564bfdd37576708d418478075153993a686))
+ __\*:__ fix: Fix issues where config properties were not correctly applied
 ([ab78ce6](https://github.com/coldbox-modules/cbq/commit/ab78ce62b2f1c6c882a522a78b5c4477a3789c01))
+ __\*:__ fix: use `cbq.job` in case the job is not defined on this server
 ([14a6dfd](https://github.com/coldbox-modules/cbq/commit/14a6dfd82b3957ce83d66b2a5f3ac43485d5b2bc))
+ __\*:__ fix: Use job queue if present in chained jobs ([a78dbbb](https://github.com/coldbox-modules/cbq/commit/a78dbbb0203f4cad073129745518d0cf77e1b20c))
+ __\*:__ fix: Allow for chains longer than 2
 ([aeb9229](https://github.com/coldbox-modules/cbq/commit/aeb9229e25ad078c6bd4b22d56c2a6fd5578fd03))
+ __\*:__ feat: Add connection and queue to mementos
 ([a45ae5a](https://github.com/coldbox-modules/cbq/commit/a45ae5ae7cf93abc1f9bf32b03678e6602d075d6))
+ __\*:__ feat: Add support for batched jobs
 ([4f80090](https://github.com/coldbox-modules/cbq/commit/4f80090b390bac84d2d815d6736aa0031a09f6b2))
+ __\*:__ docs: fix typo ([61d09a1](https://github.com/coldbox-modules/cbq/commit/61d09a1d679e0dd344812214a28dce6e4b81cde4))
+ __\*:__ docs: Fixed onQueue argument name in README ([4b0d24c](https://github.com/coldbox-modules/cbq/commit/4b0d24cac6c2485e05a6f2dce973c0d0d1f6829b))
+ __\*:__ Merge pull request #1 from Daemach/main ([cab3958](https://github.com/coldbox-modules/cbq/commit/cab3958525ade2219490cf5687b5cf4591f87b52))
+ __\*:__ Typo fix
 ([c59afd8](https://github.com/coldbox-modules/cbq/commit/c59afd8ee7445d60f0ea0d16f2b0972d96f73dba))
+ __\*:__ fix: Temporarily disable scale spec ([1e40d8e](https://github.com/coldbox-modules/cbq/commit/1e40d8e84166e8cc396393c036f4dffba6c1a591))
+ __\*:__ 0.1.4 ([af7bfe9](https://github.com/coldbox-modules/cbq/commit/af7bfe9413282f9aa3bdb0493198c48df43c37c4))
+ __\*:__ fix: Don't do timeout or backoff in SyncProvider
 ([a0a5e21](https://github.com/coldbox-modules/cbq/commit/a0a5e216fbf3ddc309efe3535799bbd52bb72bf0))
+ __\*:__ 0.1.3 ([ccd684b](https://github.com/coldbox-modules/cbq/commit/ccd684b69762779bb60f3f4c8f2bc33a5e61fe00))
+ __\*:__ fix: Standardize on seconds for timeout and backoff
 ([39d1107](https://github.com/coldbox-modules/cbq/commit/39d1107dd3b84f3f457d1a8f8a4f01ba92f32e81))
+ __\*:__ 0.1.2 ([7037c29](https://github.com/coldbox-modules/cbq/commit/7037c299753f9cafc021b7aea22398c065fd3e61))
+ __\*:__ v0.1.1
 ([6cb9053](https://github.com/coldbox-modules/cbq/commit/6cb90536df5490521ed576452fa33227140d0095))
+ __\*:__ feat: Add chained jobs and job helpers in cbq model
 ([350047c](https://github.com/coldbox-modules/cbq/commit/350047cdd5627ae3bccd6188ddaa9b9c52b1b13a))
+ __\*:__ v0.1.0
 ([65ebb72](https://github.com/coldbox-modules/cbq/commit/65ebb72b87cbcc9737bdfaa46b8d23d426e4dfdc))
+ __\*:__ Initial commit
 ([d601988](https://github.com/coldbox-modules/cbq/commit/d601988acaae92f063ae9d8074fcbed3decbedc6))

### perf

+ __DBProvider:__ Increase throughput for DBProvider ([6fb8fd3](https://github.com/coldbox-modules/cbq/commit/6fb8fd3e098589d9d9135d56c1f6058fee99782b))


# v3.0.13
## 20 Sep 2024 — 15:39:44 UTC

### other

+ __\*:__ fix: Replace typo excpetion with exception ([56cdd07](https://github.com/coldbox-modules/cbq/commit/56cdd07d12d59080f554e818a35ecae422ec2f26))


# v3.0.12
## 03 Sep 2024 — 15:53:21 UTC

### other

+ __\*:__ fix: Update syntax for Lucee 6.1 and ACF ([a4f4502](https://github.com/coldbox-modules/cbq/commit/a4f4502e443a14cad93d13259a96f4a52681a865))


# v3.0.11
## 07 Aug 2024 — 18:40:35 UTC

### other

+ __\*:__ Fix missing shutdownTimeout variable
 ([9bb553c](https://github.com/coldbox-modules/cbq/commit/9bb553c8b7ce7e0d1217e0578469928363557dab))


# v3.0.10
## 07 Aug 2024 — 16:37:29 UTC

### fix

+ __Batch:__ Don't override Batch job queues unless one is specifically requested
 ([6926067](https://github.com/coldbox-modules/cbq/commit/6926067c3a28655a80ab967a92cfdd64e1af23c3))


# v3.0.9
## 25 Jun 2024 — 16:46:56 UTC

### fix

+ __SyncProvider:__ Fix stack overflow when releasing a job too many times ([5997087](https://github.com/coldbox-modules/cbq/commit/599708759cbb1f90e30a2f21e3e3ab2d8a1cca1d))


# v3.0.8
## 12 Jun 2024 — 17:21:18 UTC

### fix

+ __SyncProvider:__ Add chained jobs to the Sync job memento. ([b1af5aa](https://github.com/coldbox-modules/cbq/commit/b1af5aae205b06e3c749be26b200670f416c90e6))


# v3.0.7
## 23 May 2024 — 21:34:49 UTC

### fix

+ __SyncProvider:__ Un-nest chains to prevent stack overflows
 ([b89c81a](https://github.com/coldbox-modules/cbq/commit/b89c81a5c47f6d353a0d46110eba5739bb16e4c6))


# v3.0.6
## 23 May 2024 — 17:07:59 UTC

### fix

+ __FailedJobs:__ Fix variable name
 ([b6e5f40](https://github.com/coldbox-modules/cbq/commit/b6e5f40dc993db45e7efdf311fa24152a65a712c))


# v3.0.5
## 23 May 2024 — 17:03:25 UTC

### fix

+ __FailedJobs:__ Inject logbox into the interceptor
 ([f759d4f](https://github.com/coldbox-modules/cbq/commit/f759d4ffa50af9a1f4f07bb9a20b15fbb0039de4))


# v3.0.4
## 23 May 2024 — 16:58:00 UTC

### fix

+ __FailedJobs:__ Use CF_SQL_VARCHAR as the SQL type for `originalId`
 ([041f34b](https://github.com/coldbox-modules/cbq/commit/041f34bcdada079647c226f2bc812293b4c44564))


# v3.0.3
## 23 May 2024 — 16:40:10 UTC

### fix

+ __FailedJobs:__ Make originalId able to track all provider ids
 ([ecbade0](https://github.com/coldbox-modules/cbq/commit/ecbade0102f93d27fd2096e392f0dbe9371b27fb))


# v3.0.2
## 21 May 2024 — 14:01:55 UTC

### fix

+ __FailedJobs:__ Log errors logging failed jobs
 ([fd4bffa](https://github.com/coldbox-modules/cbq/commit/fd4bffab61a5046b8baf263e37666292e0cdd760))


# v3.0.1
## 16 May 2024 — 15:48:35 UTC

### fix

+ __DBProvider:__ Fix releasing job timeouts using the wrong value
 ([276a473](https://github.com/coldbox-modules/cbq/commit/276a473879cb3a354fed911094aa59ad046a2b10))


# v3.0.0
## 16 May 2024 — 14:58:33 UTC

### BREAKING

+ __FailedJobs:__ Use a unix timestamp as the failed job log failedDate column type ([0f36ad8](https://github.com/coldbox-modules/cbq/commit/0f36ad88caac3ce4f19cf76c498642933389ec7a))
+ __DBProvider:__ Better locking to avoid duplicate runs of the same job ([eed4c61](https://github.com/coldbox-modules/cbq/commit/eed4c6184745e53a59a1b51b66c02657e11834ef))

### chore

+ __DBProvider:__ Remove `lockForUpdate` flag and add debug logging
 ([413760f](https://github.com/coldbox-modules/cbq/commit/413760f93f3ffb5e3b5fb8609f3a309afe74d0ab))

### feat

+ __WorkerPool:__ Make shutdown timeout configurable
 ([575651c](https://github.com/coldbox-modules/cbq/commit/575651c916d8fbb94619f6468e9fdade94cf923e))

### fix

+ __DBProvider:__ Allow picking up of jobs that were previously reserved but not released correctly
 ([67c3659](https://github.com/coldbox-modules/cbq/commit/67c365927f27eafc85c727b972465249912805c3))
+ __DBProvider:__ When claiming a job, the DBProvider should extend the availableDate by the job timeout, not backoff.
 ([bb0b0e2](https://github.com/coldbox-modules/cbq/commit/bb0b0e20487255ecf99c6d4abf10b3de99e4b6ee))
+ __WorkerPool:__ Correctly shutdown worker pools
 ([fcaee85](https://github.com/coldbox-modules/cbq/commit/fcaee854ba4fd7340b0d2ced25008b49c46f4165))
+ __DBProvider:__ Fix for unwrapping an Optional in a log message
 ([9025919](https://github.com/coldbox-modules/cbq/commit/90259191841ef00073bfc4dab188cc02916a8b35))

### other

+ __\*:__ feat: Add clean-up tasks for completed or failed jobs, failed job logs, and completed or cancelled batches.
 ([80ee9e9](https://github.com/coldbox-modules/cbq/commit/80ee9e9afc271df06e86fe86fd19dffb3b5e9bb6))
+ __\*:__ v3.0.0-beta.1
 ([139302b](https://github.com/coldbox-modules/cbq/commit/139302b807ae44b124219adbb64a974797d120dc))


# v2.1.0
## 13 Feb 2024 — 23:42:12 UTC

### feat

+ __DBProvider:__ Add back ability to work on multiple queues ([364b9ca](https://github.com/coldbox-modules/cbq/commit/364b9ca4b1d0d138877ed148774301985203c27b))
+ __Interceptors:__ Add ability to restrict interceptor execution with `jobPattern` ([552e8ae](https://github.com/coldbox-modules/cbq/commit/552e8ae1edc9b7ad8db575d4c15b250b1d86a5ad))
+ __Job:__ Add support for `before` and `after` lifecycle methods ([8cf8390](https://github.com/coldbox-modules/cbq/commit/8cf839098f3571dfe37f385bcb39a1c24deef115))


# v2.0.5
## 09 Nov 2023 — 16:58:45 UTC

### fix

+ __DBProvider:__ Disable forceRun until we figure out why it's losing mappings
 ([4418d4c](https://github.com/coldbox-modules/cbq/commit/4418d4c67428144eb77827fb34338c46e9df5f49))


# v2.0.4
## 06 Nov 2023 — 19:33:46 UTC

### other

+ __\*:__ fix: reload module mappings in an attempt to work around ColdBox Async losing them
 ([152e282](https://github.com/coldbox-modules/cbq/commit/152e28275a04cdd6d01be380d05759c11af8b368))


