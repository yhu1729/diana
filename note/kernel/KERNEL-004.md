---
id: KERNEL-004
title: Callback wrappers live in src/<method>.c and are not verified
kind: fact
path:
  - src/bisection.c
  - src/euler.c
  - src/newton.c
  - src/rk4.c
  - include/diana/ode.h
  - include/diana/scalar.h
related: [KERNEL-001, KERNEL-003, API-001]
---
The callback convenience functions `diana_bisection`, `diana_newton`, `diana_euler` and
`diana_rk4` are ordinary C in `src/bisection.c`, `src/newton.c`, `src/euler.c` and `src/rk4.c`,
declared in their method's public header. They have no ACSL contract, no Frama-C expectation
row, no Clight AST and no VST proof.

- Callback types: `diana_scalar_fn` in `diana/scalar.h` (included by `diana/bisection.h`),
  `diana_newton_fn` in `diana/newton.h`, and `diana_ode_fn`, shared by Euler and RK4, in
  `diana/ode.h`.
- Each loops over checked verified kernels only: `init` / `step` / `result` for bisection and
  Newton, `diana_euler_step`, and `diana_rk4_stage` (stages 2 to 4) with `diana_rk4_step`; never
  an `_unchecked` variant. A kernel's error status is returned unchanged.
- The ODE wrappers take a caller-owned `work` buffer and its length `lwork` (at least `2·d`
  doubles for Euler, `5·d` for RK4), copy the new state into `y` only after the kernel call
  succeeds, and stop with `DIANA_ERR_CALLBACK` when the `int`-returning `diana_ode_fn` returns
  non-zero.
- The callback is a trust boundary: nothing checks what it does, including whether it preserves
  the floating-point environment (API-001).

The wrappers are still compiled with the strict flags, tested in `test/c/`, and part of the
`ccomp` comparison, which builds every `src/*.c` (`script/compare_compiler.sh`).
