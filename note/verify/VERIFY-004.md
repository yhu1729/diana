---
id: VERIFY-004
title: Recorded timing of script/dev.sh verify
kind: fact
path:
  - script/dev.sh
related: [VERIFY-002, VERIFY-003, PROVER-008]
---
`time script/dev.sh verify` on an Apple M4 (10 cores, 24 GB) with Rocq 9.2.0, Frama-C 32.1,
Alt-Ergo 2.6.4 and Lean 4.35.0, Mathlib cache present; seconds. Cold: after `make clean` in
`verification/rocq`, with `verification/frama-c/cache` and the Lean `.lake/build` of the Diana
modules removed. Warm: a second run with nothing changed.

| Stage | Sequential, cold | Sequential, warm | `DIANA_JOB=10`, cold | `DIANA_JOB=10`, warm |
|---|---|---|---|---|
| Clight check | 2 | 2 | 2 | 2 |
| Compiler comparison | 49 | 51 | 99 | 52 |
| Lean build | 133 | 116 | 203 | 89 |
| Rocq build | 187 | 0 | 73 | 0 |
| WP rows | 85 | 89 | 80 | 27 |
| Spec gate | 132 | 148 | 122 | 161 |
| Total | 588 | 406 | 327 | 252 |

The sequential columns time each stage on its own. Each `DIANA_JOB=10` column is one run: the
total is wall-clock time, the middle stages are their `build/verify/*.status` times under
contention, and the spec gate is the remainder. The Lean build is the longest middle stage in both
parallel runs and so sets the total. In parallel, the cold Rocq build drops from 187 to 73 s and
the warm WP rows from 89 to 27 s; the spec gate, which rebuilds both check files, is the largest
single cost. The same warm state with `DIANA_JOB=1` took 360 s, and every run left the report
unchanged. Rerun and replace these figures after a change to the stages.
