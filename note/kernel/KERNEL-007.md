---
id: KERNEL-007
title: Shared ACSL predicates live in a private header per method
kind: fact
path:
  - src/bisection_acsl.h
  - src/newton_acsl.h
related: [KERNEL-005, WP-001]
---
ACSL predicates used by more than one function of a method are defined once, in a private header
`src/<method>_acsl.h` that the method's sources include.

- `src/bisection_acsl.h`: `bisection_next` (finite `x` strictly inside `(a, b)`),
  `bisection_bracket(s, m)` (finite endpoints and values, `a <= b`, both within `±m`, a strict
  sign change or a collapsed root with `fa == fb == 0`, `tol >= 0`) and
  `bisection_unchanged{L1, L2}` (every state field equal at both labels). Included by
  `src/bisection_init.c`, `src/bisection_step.c` and `src/bisection_result.c`.
- `src/newton_acsl.h`: `newton_state` (valid pointer, finite `x`, `dx` and `tol`, `tol >= 0`) and
  `newton_unchanged{L1, L2}`. Included by `src/newton_init.c` and `src/newton_step.c`.

The headers hold only `/*@ ... */` annotations and an include of the method's public header, so
they change no Clight AST. No source file defines a predicate of its own.
