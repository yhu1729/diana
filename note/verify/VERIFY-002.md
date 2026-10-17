---
id: VERIFY-002
title: Stage order of script/dev.sh verify
kind: fact
path:
  - script/dev.sh
related: [VERIFY-003, VST-003, WP-008, GATE-007]
---
`script/dev.sh verify` first requires `.venv` (from `script/dev.sh config`), then runs:

1. The Clight check (VST-003). It also stops `verify` when CompCert is missing from the switch.
2. Four stages at once: the compiler comparison (`script/compare_compiler.sh`, which skips
   itself without `ccomp`), the Lean build (`lake exe cache get && lake build`), the Rocq build
   (`make -C verification/rocq` with `-j`, PROVER-008) and the WP rows
   (`script/verify_frama_c.sh`, WP-008). It waits for all four, prints their logs, and fails if
   any failed; the spec gate then does not run.
3. The spec gate, `script/check_spec.py --run --strict`, last because it reads the Lean and Rocq
   builds: it writes the check files, runs `lake env lean CheckSpec.lean` and `make -s check`,
   and rewrites `doc/verification/report.md` (GATE-006).

`make check` is not a stage of its own; the gate runs it. Commit the rewritten report.
`DIANA_JOB=1` runs step 2 one stage after another in the order above, on the terminal, and stops
at the first failure (VERIFY-003).
