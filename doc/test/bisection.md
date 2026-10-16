# Bisection test values

Expected values in `test/c/test_bisection.c`:

- The state-machine test checks the bracket invariant after every step. The width halves each step,
  so `(b - a) / 2^n <= tol` holds at `n = ceil(log2((b - a) / tol))`: 41 steps for `[0, 2]` and
  `tol = 1e-12`.
- With `tol = 0` the final bracket is a pair of adjacent doubles, so the estimate is within 1 ulp of
  the root, and the iteration stops when the endpoints are adjacent.
- `c = 0.5` is the midpoint of `[0, 1]`, so the first step hits the root exactly; a root at an
  endpoint makes `init` report convergence without any step.
- The large-magnitude case uses a bracket at the admissible limit `DBL_MAX/2`; the midpoint must stay
  inside the bracket.
- The callback wrapper evaluates `f(a)`, `f(b)`, then once per step, so `n == iter + 2`; for `[0, 2]`
  and `tol = 1e-6`, `iter = ceil(log2(2 / 1e-6)) = 21`.
- Worst case of `tol = 0`: from a width of `DBL_MAX < 2^1024` down to adjacent subnormals `2^-1074`
  apart takes `1024 + 1074 = 2098` halvings, which the root `DBL_TRUE_MIN` in
  `[-DBL_MAX/2, DBL_MAX/2]` attains. The Python default `max_iter = 2100` is chosen to cover it.
  BISECTION-B4 proves termination and the loose bound `n <= lattice`, not this constant;
  `spec/bisection.md` ("What B4 does not say") records why the tight bound is still only measured,
  so this test is what pins it.
- A rejected `init` or `step` leaves the state unchanged (`test_error_keeps_state`); the Python
  binding relies on it when `Bisection.__init__` is called again with bad arguments or `step` gets a
  non-finite value.
