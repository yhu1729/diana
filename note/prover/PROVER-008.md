---
id: PROVER-008
title: Rocq parallel build and its memory cap in dev.sh verify
kind: fact
path:
  - script/dev.sh
  - verification/rocq/Makefile
related: [PROVER-007, VERIFY-003, VERIFY-004]
---
`script/dev.sh verify` runs the Rocq build as `make -C verification/rocq -j <n>`, where `<n>` is
`DIANA_JOB` capped at one job per 2 GiB of physical memory; with `DIANA_JOB=1` it runs a plain,
sequential `make`.

- Memory is `sysctl -n hw.memsize` on macOS or `MemTotal` of `/proc/meminfo` on Linux; the cap is
  `memory / 2147483648`, at least 1. When neither can be read, `DIANA_JOB` is used as given.
- 2 GiB is the recorded peak resident set of one `rocq compile` on a `theory/VST` file, rounded
  up: 1.13 GB for `BisectionInit.v` and under 1.05 GB for every other file (`/usr/bin/time -l`,
  Rocq 9.2.0, VST 2.17, Apple M4). The rounding leaves room for the stages running beside it.
- Files build in parallel as far as their imports allow. On the 24 GB M4 the cap is 12, so
  `DIANA_JOB=10` gives 10 jobs; the cold Rocq build went from 187 s sequential to 73 s
  (VERIFY-004).
- `make real` and `make float` pass `-j N` on to the generated makefile in the same way; CI runs
  `make float` without it (PROVER-007, CI-013).
