---
id: GATE-004
title: How the gate reads the provers' axiom output
kind: fact
path:
  - script/check_spec.py
related: [GATE-003, GATE-005, GATE-007]
---
With `--run`, the gate runs `lake env lean CheckSpec.lean` in `verification/lean` and
`make -s check` in `verification/rocq`, and gives each listed constant a status per prover.

- A prover command that cannot start or exits non-zero sets every pending constant of that prover
  to `check failed`, and its output goes to stderr.
- Lean: stdout and stderr are searched for `'N' depends on axioms: [a, b]` and
  `'N' does not depend on any axioms`.
- Rocq: only stdout is parsed (Rocq writes its warnings to stderr). `Print Assumptions` does not
  echo the constant, so the output is split into blocks starting with
  `Closed under the global context` or `Axioms:`, matched to the constants by position. In an
  `Axioms:` block a line starting in column 0 is an axiom (`name` or `name : type`); indented
  lines continue a type.
- Because the match is positional, a block count different from the number of constants, text
  after a `Closed under ...` line, an empty `Axioms:` block, or an unindented line that is not an
  axiom is an error, and every pending Rocq constant reads `check failed`.
- A constant absent from the output reads `missing`; one depending on an axiom outside
  `script/axiom_allow.yaml` reads `axiom: <names>`; otherwise `ok`.
- A Lean `sorry` (`sorryAx`) or a Rocq `Admitted` lemma (which `Print Assumptions` lists as an
  axiom) is therefore caught as a disallowed axiom.
