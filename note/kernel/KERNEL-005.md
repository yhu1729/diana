---
id: KERNEL-005
title: A helper several files call is an external function with a private header
kind: rule
path:
  - src/bisection_mid.c
  - src/bisection_mid.h
  - src/fp_sqrt.c
  - src/fp_sqrt.h
  - src/fp.h
related: [KERNEL-001, FP-002, STYLE-002, WP-003, VST-005]
---
Code that several kernel files share is an external `diana_` function in a source file of its
own, with its ACSL contract on the declaration in a private header under `src/`:
`diana_bisection_mid` (`src/bisection_mid.c`, `src/bisection_mid.h`), which
`diana_bisection_init`, `diana_bisection_step` and `diana_bisection_result` call, and
`diana_fp_sqrt` (`src/fp_sqrt.c`, `src/fp_sqrt.h`), which `diana_cholesky` and `diana_norm_2`
call; its call of `__builtin_sqrt` needs an assumed contract in WP and an assumed funspec in VST,
so it is isolated in a function of its own (FP-006).

- Not `static inline`: `clightgen` emits a `static inline` function into the AST of every source
  that includes it, and each copy needs its own listed VST theorem (for the `src/fp.h` helpers
  BISECTION-C5/C6/C13, NEWTON-C8 to C10, EULER-C3, RK4-C7/C8, TRAPEZOIDAL-C3, SIMPSON-C3,
  NORM-C7 to C12). An
  external function is proved once (BISECTION-C1) and its callers import that funspec
  (`Diana.VST.BisectionMid.mid_spec`).
- `src/fp.h` remains the only header with `static inline` helpers (FP-002).
- A float contract WP cannot prove puts the helper in `SKIP` of `script/run_frama_c.sh`, with a
  layer-B theorem that discharges it (`diana_bisection_mid`: BISECTION-B1; `diana_fp_sqrt`:
  CHOLESKY-B1); a skipped helper has no expectation row of its own (WP-003).
- The header lives in `src/`, not `include/`, so the helper is not public API, although it is an
  external symbol of the library.
