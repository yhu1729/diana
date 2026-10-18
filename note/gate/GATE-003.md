---
id: GATE-003
title: The gate writes CheckSpec.lean and CheckSpec.v, leaving out missing names
kind: fact
path:
  - script/check_spec.py
  - verification/lean/Diana.lean
  - verification/rocq/_CoqProject
  - verification/rocq/Makefile
related: [GATE-004, PROVER-007, VERIFY-005]
---
Every run of `script/check_spec.py` that passes the structural check writes two git-ignored
check files, with or without `--run`:

- `verification/lean/CheckSpec.lean`: `import Diana`, then `#print axioms <name>` per Lean
  constant;
- `verification/rocq/CheckSpec.v`: `From <Diana.Dir> Require Import <Module>.` per module, then
  `Print Assumptions <name>.` per Rocq constant.

With `--layer` both files hold only the theorems of the selected layers (GATE-007), so a
`CheckSpec.v` written without layer C imports no `Diana.VST` module and builds without VST.

Before writing, each name is looked up in its module file with a regular expression for a
declaration (Lean `theorem`, `lemma`, `def`, `abbrev`, `instance`, with optional attributes and
modifiers; Rocq `Theorem`, `Lemma`, `Corollary`, `Proposition`, `Definition`, `Fixpoint`,
`Instance`). A name not declared there is marked `missing` and left out of the file, so one
absent constant does not break the prover run for the others; the prover run decides the rest.

Consequences:

- `CheckSpec.lean` imports only the root module, so a Lean module must be imported by
  `verification/lean/Diana.lean`; otherwise `lake build` does not build it and the Lean run
  fails on the unknown name, marking every Lean constant `check failed` (GATE-004).
- `make check` (and `check_real`, `check_float`) builds files of `verification/rocq/_CoqProject`
  before `CheckSpec.v`, so a Rocq file must be listed there (PROVER-007).
- On a fresh clone neither file exists until the gate has run once (VERIFY-005).
