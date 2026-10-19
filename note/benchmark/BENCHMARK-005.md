---
id: BENCHMARK-005
title: Scalar, quadrature and ODE benchmark cases and their inputs
kind: fact
path:
  - benchmark/bisection.c
  - benchmark/newton.c
  - benchmark/trapezoidal.c
  - benchmark/simpson.c
  - benchmark/euler.c
  - benchmark/rk4.c
related: [BENCHMARK-004, BENCHMARK-006, API-019]
---
- `bisection_step`: one solve of `x² − 2 = 0` on `[0, 2]` with `tol = 0`, `max_iter = 200`:
  `init`, `step` until the status is not `DIANA_CONTINUE`, `result`; 53 steps, each a unit.
  `bisection`: the wrapper on the same problem, units `iter`.
- `newton_step`: one solve from `x₀ = 2` with `tol = 1e-12`, `max_iter = 100`, `f = x² − 2`,
  `f′ = 2x`; 6 steps. `newton`: the wrapper.
- `trapezoidal`, `simpson`: `n` samples, `h = 1e-3`; a unit is a sample.
- `euler_step`, `euler_step_unchecked`, `rk4_stage` (stage 2), `rk4_stage_unchecked`,
  `rk4_step`, `rk4_step_unchecked`: fixed `y` and `f` or `k1` to `k4` (seeds 1 to 5),
  `h = 0.01`, output into a separate buffer; a unit is a component.
- `euler_loop`, `rk4_loop` and their `_unchecked` variants: 8 steps of the loop a caller writes,
  the right-hand side `y′ = −y/2` then the step, swapping `y` and the output; RK4 evaluates the
  right-hand side four times with stages 2 to 4 written to a work vector. `h = 1e-9`, so the
  state decays by a negligible factor over a run and never underflows. Units `8·d`, one
  component of one step; the checked and unchecked rows differ only in the kernels called.
- `euler`, `rk4`: the callback wrappers `diana_euler` and `diana_rk4` on the same right-hand
  side, 8 steps per call in place, `work` of `2d` and `5d`; the difference to the `_loop` rows
  is the wrapper's own cost (the callback with its `t` and `ctx`, the status checks).
