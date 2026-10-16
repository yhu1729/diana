# Newton test values

Expected values in `test/c/test_newton.c` and `test/python/test_newton.py`:

- `x² − 2` from `x₀ = 2` with `tol = 1e-12`: `f″ = 2` and `f′ = 2x ≥ 2√2` on `[√2, 2]`, so
  NEWTON-A1 bounds each error by `K e²` with `K = 2/(4√2) = 0.354` while the iterate stays above
  the root; the tests allow `0.36` for the first five steps. The iterates are `1.5`,
  `1.4166666666666667`, `1.4142156862745099`, `1.4142135623746899`, `1.4142135623730951` (the
  correctly rounded `√2`, error 0) and then `1.414213562373095`: the computed `f` at the rounded
  root is `2⁻⁵¹`, not 0, so step 6 moves one ulp down with `dx = 1.57e-16 ≤ 1e-12` and stops. Six
  steps, and the result is within one ulp of `√2`.
- With `tol = 0` the same iteration never stops by itself: from step 5 on, `x` alternates between
  `1.4142135623730951` and `1.414213562373095`, a two-cycle, until the step limit; the tests pin
  `DIANA_ERR_MAXITER` at `max_iter = 100` with the iterate on the lower neighbour. This is why
  `tol` has no default in Python.
- `x − 1/2` from 0: the first step lands exactly on the root and the second sees `f = 0`, so the
  run takes two steps and ends with `dx = 0`. An exact `f(x) = 0` converges whatever `f′(x)` is,
  even 0, because the kernel tests it before dividing.
- Stagnation with `tol = 0`: a correction of `1e-300` from `x = 1` does not change `x`, nor does
  one that underflows to 0 (`DBL_TRUE_MIN / 4`). `1 − (−2⁻⁵³) = 1 + 2⁻⁵³` is a tie that rounds to
  even, back to 1, so the step stops with `dx = −2⁻⁵³`; the spacing below 1 is `2⁻⁵³`, so the
  correction `+2⁻⁵³` does move `x`, to `1 − 2⁻⁵³`, and the iteration continues. NEWTON-B3 is the
  general statement: a step that leaves `x` unchanged has `|dx| ≤ ulp(x)/2`.
- `x²` from 1 has a double root, so Newton's method converges linearly: `x` halves at each step,
  `|dx| = x/2`, and `|dx| ≤ 1e-6` first holds at step 20, where `x = dx = 2⁻²⁰`.
- `max_iter = 3` on `x² − 2` from 2 stops with `DIANA_ERR_MAXITER` at the third iterate
  `1.4142156862745099`, which `diana_newton_result` and `MaxIterError.estimate` report.
- The cube root of 10 from `x₀ = 2` takes five steps to the correctly rounded `2.154434690031884`;
  `cos x − x` from 1 reaches `0.7390851332151607` in five steps, where `cos x == x` holds exactly
  in binary64, so the last step sees `f = 0`.
- Argument errors: a NaN or infinite `fx` or `dfx`, a zero or negative-zero `dfx` with a non-zero
  `fx` (the correction is infinite), `fx = DBL_MAX` with `dfx = 1/2` (the correction overflows),
  and `x = −DBL_MAX` with `dx = DBL_MAX` (the iterate overflows) are each `DIANA_ERR_ARG` with the
  state unchanged, as are the rejected `init` arguments; a rejected reinitialization keeps the
  state. `−DBL_MAX + DBL_MAX/2` is finite, so that step continues.
- The callback wrapper evaluates `f` once per step (`n == iter`), reports the estimate on
  `DIANA_ERR_MAXITER`, and leaves `*root` untouched when `init` rejects the arguments, when the
  derivative is zero or never written by the callback (`*dfx` is reset to 0 before each call), or
  when the callback returns a non-finite value, in which case `*iter` counts the completed steps.
