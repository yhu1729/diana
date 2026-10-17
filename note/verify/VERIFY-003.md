---
id: VERIFY-003
title: Parallel verify run, its logs, DIANA_JOB and the sequential mode
kind: fact
path:
  - script/dev.sh
  - script/job_count.sh
related: [VERIFY-002, WP-008, PROVER-008]
---
`DIANA_JOB` sets the parallelism of `script/dev.sh verify`. `script/job_count.sh` reads it (a
positive integer, else an error) or falls back to the CPU count (`nproc`, `sysctl -n hw.ncpu`,
`getconf _NPROCESSORS_ONLN`, else 1); `verify` exports the result, so both the WP rows in flight
and the Rocq job count (capped by memory) follow it.

- `DIANA_JOB` above 1: the four middle stages run as background jobs, each writing
  `$DIANA_BUILD_DIR/verify/<stage>.log` (default `build/verify/`; stages `compiler`, `lean`,
  `rocq`, `frama_c`) and `<stage>.status` with the exit status and the seconds taken. Old logs and
  statuses are removed first. A line `verify: <stage> passed (N s)` or `... FAILED ...` is
  printed as each ends, then the four logs in that fixed order under
  `==> <stage>: status S, N s <==`. An interrupt kills the stages.
- `DIANA_JOB=1`: the stages run one after another in the foreground, output on the terminal, WP
  rows in file order with `-wp-par 4`, Rocq `make` without `-j`; nothing goes to `build/verify/`.
- The stages share no files: the comparison builds in a temporary directory, Lean writes under
  `verification/lean/.lake/`, Rocq writes beside its sources in `verification/rocq/theory/` and
  `verification/clight/`, and WP writes under `verification/frama-c/` and a temporary directory.
