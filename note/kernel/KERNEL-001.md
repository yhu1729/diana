---
id: KERNEL-001
title: Verified kernel shape
kind: rule
path:
  - src/bisection_*.c
  - src/newton_*.c
  - src/euler_step*.c
  - src/rk4_st*.c
  - src/simpson.c
  - src/trapezoidal.c
  - src/cholesky.c
  - src/forward_substitution.c
  - src/back_substitution.c
  - src/lu.c
  - src/lu_solve.c
  - src/fp_sqrt.c
  - include/diana/*.h
related: [KERNEL-002, KERNEL-004, KERNEL-005, FP-001, STYLE-002]
---
A verified kernel is a reverse-communication state machine on a caller-owned struct (`init` / `step`
/ `result`: bisection, Newton) or one function over caller-supplied arrays (trapezoidal, Simpson,
Euler step, RK4 stage and step, Cholesky, forward and back substitution, LU, LU solve). It allocates
nothing, calls no libm function, neither takes nor calls a function pointer, and every public
function returns `diana_status`.

- Reverse communication: the state names the next point (`s->x`); the caller evaluates the
  function there and passes the value(s) to `step`, which returns `DIANA_CONTINUE` while it needs
  another. The function never enters the kernel, so no proof assumes anything about it.
- Memory: every input and output is a caller-owned struct or buffer passed by pointer with its
  extent (`n`, `d`); no `malloc`, and no static or global data anywhere in `src/`.
- Calls: only the `static inline` helpers of `src/fp.h` (FP-001, FP-002) and other verified
  Diana functions (`diana_bisection_mid`, `diana_fp_sqrt`, KERNEL-005). `diana_fp_sqrt` is the
  one function that calls a compiler builtin, `__builtin_sqrt` (FP-006).
- Interface: public names are prefixed `diana_` and declared in `include/diana/`. Every public
  function returns `diana_status` except the two string functions, `diana_status_str` and
  `diana_version`, which return a static `const char *`. The private helpers
  `diana_bisection_mid` and `diana_fp_sqrt` return `double`.
- Callback loops are convenience wrappers outside the verified core (KERNEL-004).

The provers enforce this, not a lint: `script/run_frama_c.sh` fails on a call to a function
without a body unless it is in `SKIP` (WP-003), and a VST proof needs a funspec for every callee.
