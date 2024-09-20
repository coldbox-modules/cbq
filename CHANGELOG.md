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


