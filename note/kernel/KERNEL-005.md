---
id: KERNEL-005
title: A helper several files call is an external function with a private header
kind: rule
path:
  - src/bisection_mid.c
  - src/bisection_mid.h
  - src/fp.h
related: [KERNEL-001, FP-002, STYLE-002, WP-003, VST-005]
---
Code that several kernel files share is an external `diana_` function in a source file of its
own, with its ACSL contract on the declaration in a private header under `src/`. Today this is
only `diana_bisection_mid` (`src/bisection_mid.c`, `src/bisection_mid.h`), which
`diana_bisection_init`, `diana_bisection_step` and `diana_bisection_result` call.

- Not `static inline`: `clightgen` emits a `static inline` function into the AST of every source
  that includes it, and each copy needs its own listed VST theorem (for the `src/fp.h` helpers
  BISECTION-C5/C6/C13, NEWTON-C8 to C10, EULER-C3, RK4-C7/C8, TRAPEZOIDAL-C3, SIMPSON-C3). An
  external function is proved once (BISECTION-C1) and its callers import that funspec
  (`Diana.VST.BisectionMid.mid_spec`).
- `src/fp.h` remains the only header with `static inline` helpers (FP-002).
- A float contract WP cannot prove puts the helper in `SKIP` of `script/run_frama_c.sh`, with a
  layer-B theorem that discharges it (`diana_bisection_mid`: BISECTION-B1); a skipped helper has
  no expectation row of its own (WP-003).
- The header lives in `src/`, not `include/`, so the helper is not public API, although it is an
  external symbol of the library.
