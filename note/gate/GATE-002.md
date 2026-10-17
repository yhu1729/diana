---
id: GATE-002
title: Theorem ID format and layer letter
kind: rule
path:
  - script/check_spec.py
  - spec/*.md
related: [GATE-001]
---
A theorem ID is `<METHOD>-<layer><number>`: the spec file stem in capitals with `_` written as
`-`, then `A`, `B` or `C`, then a number (`BISECTION-A1` in `spec/bisection.md`,
`EULER-UNCHECKED-C1` in `spec/euler_unchecked.md`). `script/check_spec.py` rejects an entry
unless:

- the ID matches `^[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-[ABC]\d+$`;
- everything before its last `-` equals the prefix derived from the file stem;
- the letter after its last `-` equals the entry's `layer`;
- no other entry in any spec file has the same ID.

Layers: A is the real-number model (Lean and Rocq), B the binary64 model (Flocq), C the code
(VST against the Clight AST, a C-order model theorem, or an ACSL contract proved by WP). Numbers
count per method and layer.
