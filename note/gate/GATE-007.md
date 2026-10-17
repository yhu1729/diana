---
id: GATE-007
title: Exit status of the spec gate with --strict and --prover
kind: fact
path:
  - script/check_spec.py
  - script/dev.sh
  - .gitlab-ci.yml
related: [GATE-004, GATE-006, WP-007, VERIFY-001]
---
`script/check_spec.py` exits 1 on a structural error or when no theorem is found. Otherwise:

- Without `--strict` it fails only when a constant reads `check failed` or `axiom: ...`;
  `missing`, `no project` (shown as `planned` in the report) and `not run` are printed but pass.
- With `--strict` it fails unless every constant of every selected prover reads `ok`, so
  `--strict` without `--run` always fails (every constant is `not run`).
- With `--strict` and no `--prover`, it also requires, for the `acsl` file of every theorem that
  has one, exactly one row with a positive count in `verification/frama-c/expectation.txt`.
  `script/verify_frama_c.sh` runs WP on exactly those rows, so an ACSL file cannot drop out of
  the WP run unnoticed; the count alone proves nothing.
- `--prover lean` or `--prover rocq` (repeatable) limits `--run` and `--strict` to those provers
  and drops the Frama-C requirement.

Invocations: `script/dev.sh verify` runs `--run --strict` (both provers, report rewritten). CI
`verify_lean` runs `--run --strict --prover lean --no-report`, so a missing Lean proof fails CI
without requiring the Rocq-only layers or Frama-C rows. CI `style_python` runs the structural,
non-strict check with `--no-report`. The Rocq axiom gate runs only locally (VERIFY-001).
