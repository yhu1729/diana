---
id: KERNEL-007
title: Shared ACSL predicates live in a private header per method
kind: fact
path:
  - src/bisection_acsl.h
  - src/newton_acsl.h
  - src/substitution_acsl.h
related: [KERNEL-005, WP-001]
---
ACSL predicates and lemmas used by more than one function of a method are defined once, in a
private header `src/<method>_acsl.h` that the method's sources include.

- `src/bisection_acsl.h`: `bisection_next` (finite `x` strictly inside `(a, b)`),
  `bisection_bracket(s, m)` (finite endpoints and values, `a <= b`, both within `±m`, a strict
  sign change or a collapsed root with `fa == fb == 0`, `tol >= 0`) and
  `bisection_unchanged{L1, L2}` (every state field, `status` included, equal at both labels).
  Included by `src/bisection_init.c`, `src/bisection_step.c` and `src/bisection_result.c`.
- `src/newton_acsl.h`: `newton_state` (valid pointer, finite `x`, `dx` and `tol`, `tol >= 0`) and
  `newton_unchanged{L1, L2}` (every field, `status` included). Included by `src/newton_init.c`
  and `src/newton_step.c`.
- `src/substitution_acsl.h`: the lemma `column_end` (WP-011) and `substitution_valid(l, n, b, x)`
  (`l[0 .. n*n-1]` and `b[0 .. n-1]` readable, `x[0 .. n-1]` writable and separate from both).
  Included by `src/forward_substitution.c` and `src/back_substitution.c`. ACSL rejects `const` in
  a predicate's parameter types, so the parameters are `double *`.

The headers hold only `/*@ ... */` annotations and an include of the method's public header, so
they change no Clight AST. A method of one source file keeps its annotations there:
`src/cholesky.c` declares its own copy of `column_end`, `src/lu.c` its own `column_end` and
the predicate `lu_valid(a, n, lu, piv)` (readable `a`, writable `lu` and `piv`, all three
separate), and `src/lu_solve.c` its own `column_end` and `lu_solve_valid(lu, piv, n, b, x)`
(readable `lu`, `piv` and `b`, writable `x` separate from all three).
