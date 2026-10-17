---
id: COMPILER-004
title: The comparison runs only locally, inside script/dev.sh verify
kind: fact
path:
  - script/compare_compiler.sh
  - script/dev.sh
  - .gitlab-ci.yml
related: [COMPILER-001, COMPILER-010, VERIFY-001, VERIFY-002]
---
No CI job runs `script/compare_compiler.sh`: CompCert is under a non-commercial license and is in
no CI image, only in local opam switches. Locally, `script/dev.sh verify` runs it through
`opam exec` (with `--switch=$DIANA_OPAM_SWITCH` when that is set).

- With `DIANA_JOB=1` it runs in the foreground right after the Clight check, before the Lean,
  Rocq and Frama-C steps; otherwise it is the `compiler` stage, run after the Clight check at the
  same time as the Lean, Rocq and Frama-C stages, with its output in
  `<build>/verify/compiler.log` and its exit status and seconds in `compiler.status`. A failure
  fails `verify`.
- Without `ccomp` on `PATH` the script prints
  `compiler: ccomp not found; differential test skipped (...)` and exits 0. Inside
  `script/dev.sh verify` this path is rarely reached: the Clight check that runs before it fails
  when the opam switch has no `compcert.config`, so `verify` stops before the comparison on a
  machine without CompCert.
- To run it alone: `opam exec -- script/compare_compiler.sh` (outside the opam environment
  `ccomp` is usually not on `PATH` and the script skips).
- In CI and every ctest run, the driver is only executed, not compared (COMPILER-010).
