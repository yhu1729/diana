---
id: PROVER-003
title: Rocq stays at 9.2 and dev.sh runs the opam tools through opam exec
kind: rule
path:
  - script/dev.sh
  - CONTRIBUTING.md
related: [PROVER-001, PROVER-002]
---
Use Rocq 9.2 (`rocq-core.9.2.0`), not 9.3: the `coq-compcert.3.18` opam package requires
`coq {>= "8.15.0" & < "9.3~"}`, so CompCert, and with it `clightgen` and the VST proofs about its
ASTs, does not install next to Rocq 9.3. A Homebrew `rocq` 9.3 on `PATH` is not used.

`script/dev.sh` keeps such a binary out by running the opam tools through its `opam_run`: with
`DIANA_OPAM_SWITCH` set, `opam exec --switch=$DIANA_OPAM_SWITCH --`, otherwise `opam exec --` in
the current switch. In `verify` that covers `opam var lib` and `clightgen` of the Clight check,
the compiler comparison, the Rocq `make`, the WP rows and the spec gate (whose `make -s check`
therefore uses the switch's `rocq`). The Lean build is not wrapped; `lake` comes from elan.

Run a step by hand the same way, for example `opam exec -- make -C verification/rocq`.
