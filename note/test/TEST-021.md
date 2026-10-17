---
id: TEST-021
title: RK4 exact stage and step cases
kind: fact
path:
  - test/c/test_rk4.c
  - src/rk4_stage.c
  - src/rk4_step.c
related: [TEST-022, TEST-023, TEST-024]
---
`diana_rk4_stage` writes `y[i] + c * k[i]` with `c = 0.5 * h` for stages 2 and 3 and `c = h` for
stage 4; `diana_rk4_step` writes `y[i] + (h * s) / 6` with
`s = (k1[i] + k4[i]) + 2 * (k2[i] + k3[i])`. The exact cases use values with few significant bits
so the coefficient, every product and every sum are exact.

- Stage: `y = {1, -2, 1/2}`, `k = {3, 4, -8}`, `h = 1/2` give `{1.75, -1, -1.5}` at stages 2 and
  3 (`c = 1/4`) and `{2.5, 0, -3.5}` at stage 4 (`c = 1/2`, also with `d = 1`). The 100-component
  case `y = i - 50`, `k = 3 - i` gives `i/2 - 48.5` with `c = 1/2` twice: stage 2 with `h = 1`
  and stage 4 with `h = 1/2`.
- Step: with `h = 3/4`, `h s / 6 = s / 8` is exact for small integer `s`:
  `y = {1, 0, -2}` and slopes `k1 = {6, 0, 1}`, `k2 = {12, 3, 2}`, `k3 = {0, -3, 2}`,
  `k4 = {6, 6, 1}` give `{5.5, 0.75, -0.75}`. 100 components with `y = i - 50` and slopes
  `2i, -i, -i, 2i` give `y` (the sum cancels to 0); with `2i, 0, 0, 2i` they give `y + i/2`.
- Weights: unit slopes in separate components with `h = 6` give `{1, 2, 2, 1}`.
- `h = 0` keeps each `y[i]` with its sign of zero at stages 2 and 4 and in the step.
- Underflow is not an error: `h = DBL_TRUE_MIN` with `s = 1` makes `h s = 2^-1074`, and dividing
  by 6 rounds to `+0`.
- Every successful case runs the checked and the unchecked function (TEST-024).
