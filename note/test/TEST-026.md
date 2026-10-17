---
id: TEST-026
title: RK4 Python property, rounding, agreement, convergence and out tests
kind: fact
path:
  - test/python/test_rk4.py
related: [TEST-020, TEST-025, API-004]
---
`test/python/test_rk4.py` checks the stage and step against Python floats, the RK4-B2/B3/B5 bounds
in exact arithmetic, the driver against hand-written stages, fourth-order convergence, and the
extension's own `out` checks.

- Property (Hypothesis, 500 derandomized examples each): vectors of equal length 1 to 20 of any
  floats. The stage must equal `y[i] + c*k[i]` (`c = 0.5*h`, or `h` at stage 4) and the step
  `y[i] + h*((k1[i] + k4[i]) + 2.0*(k2[i] + k3[i]))/6.0` in Python floats bit for bit, with
  `ValueError` exactly when a component is not finite.
- Rounding (seed 1729): 500 components per case with magnitudes `2^k`, `k` in `[-40, 40]` or
  `[-1074, -1000]`. The stage (stages 2 and 4) is checked against RK4-B2/B3 for a random `h` and
  for `h = 3 * 2^-1074` and `-7 * 2^-1074`, where `h/2` rounds (`|fl(c) - c| <= eta` is asserted);
  the step against RK4-B5 with `gamma_4`, for a random `h`.
- Agreement: `diana.rk4` on a non-autonomous, nonlinear `f` over three steps equals the same steps
  written out with `rk4_stage` and `rk4_step`.
- Convergence: the rotation `y' = (y2, -y1)` from `(0, 1)` to `t = 1` with `n = 8, ..., 128`
  steps; each halving of `h` must divide the error by 16 within `0.7`. The error is about
  `0.007 h^4`; measured ratios are 15.38, 15.71, 15.86, 15.93 (and 14.57 from `n = 4` to 8, which
  the test omits). Rounding, about `n u`, is far below the smallest error, about `2.6e-11`.
- `diana._diana.rk4_stage` and `rk4_step` with an explicit `out`: read-only `out` is
  `BufferError`; empty or wrong-length `out`, or `out` equal to or overlapping `y` or any slope,
  is `ValueError` ("out must not overlap y or a slope" for the step); a valid call returns `None`.
