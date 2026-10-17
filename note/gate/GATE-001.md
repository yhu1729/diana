---
id: GATE-001
title: Front matter fields of spec/<method>.md that the spec gate reads
kind: rule
path:
  - spec/*.md
  - script/check_spec.py
related: [GATE-002, GATE-003, KERNEL-006]
---
Each `spec/<method>.md` starts with YAML front matter that `script/check_spec.py` validates:

- `method`: equal to the file stem (`bisection` in `spec/bisection.md`).
- `kernel`: one source path or a non-empty list of them, each an existing file
  (`[src/bisection_mid.c, src/bisection_init.c, src/bisection_step.c, src/bisection_result.c]`).
- `theorem`: a list of entries with
  - `id`: the theorem ID (GATE-002), unique over all spec files;
  - `layer`: `A`, `B` or `C`, equal to the letter in the ID;
  - `informal`: the statement in words, required; it is the report's Statement column;
  - `lean`, `rocq`: fully qualified constant names; layer A needs both, layer B needs `rocq`,
    layer C needs `rocq` (a VST or model theorem) or `acsl`;
  - `acsl`: `<file>` or `<file>:<function>`; the file must exist and a given function must occur
    in it followed by `(`. Every current entry names only the file.
- `model` and `hypothesis` appear in every spec; the gate does not read them.

A Lean name `Diana.Real.Bisection.bracket_width` must be declared in
`verification/lean/Diana/Real/Bisection.lean`; a Rocq name
`Diana.Float.Bisection.mid_in_bracket` in `verification/rocq/theory/Float/Bisection.v` (the
leading `Diana` is `theory/`). A structural error makes the gate exit 1 before it writes
anything.
