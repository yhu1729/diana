---
id: GATE-008
title: What the spec gate does not check
kind: fact
path:
  - script/check_spec.py
  - spec/*.md
related: [GATE-001, GATE-004, VST-003]
---
The gate checks that each listed constant exists and which axioms it depends on; it does not
compare the constant's type with its `informal` statement. A Rocq `Definition` or a Lean `def` of
a trivial proposition under the listed name passes, so whether a constant says what the spec
says is a matter of review.

It also does not:

- run WP or read its output: the Frama-C column and the strict ACSL requirement read only
  `verification/frama-c/expectation.txt`; the proof is `script/verify_frama_c.sh` (WP-008);
- check that a VST proof is about the current source; `script/dev.sh verify` compares the
  Clight ASTs (VST-003);
- read `model` or `hypothesis`, or check that `kernel` lists every source of the method;
- cover code no spec lists: the callback wrappers (`src/bisection.c`, `src/euler.c`,
  `src/newton.c`, `src/rk4.c`) and the Python package have no theorem.
