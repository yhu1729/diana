---
id: TEST-028
title: Newton with tol 0 on x^2 - 2 ends in a two-cycle of adjacent doubles
kind: fact
path:
  - test/c/test_newton.c
  - test/python/test_newton.py
related: [TEST-027, TEST-029]
---
With `tol = 0` the Newton iteration on `x^2 - 2` from 2 never stops by itself: from step 5 on, `x`
alternates between `1.4142135623730951` (the correctly rounded `sqrt(2)`) and its lower neighbour
`1.414213562373095`, because the computed `f` at either is a non-zero `±2^-51`.

- `test_two_cycle` in `test/c/test_newton.c` runs it with `max_iter = 100`, requires every iterate
  after step 6 to be one of the two doubles, and ends with `DIANA_ERR_MAXITER`, `iter == 100`,
  `x` on the lower neighbour and `dx != 0`.
- `test_two_cycle_at_zero_tol` in `test/python/test_newton.py` gets `MaxIterError` with
  `iter == 100`, `estimate` within one ulp of `sqrt(2)` and `0 < uncertainty < ulp(1)`.
- This is why Python's `Newton` and `newton` take `tol` without a default (`test_tol_required`):
  `tol = 0` commonly ends in such a cycle rather than a stop.
- The compiler corpus prints this run step by step, and also the genuine two-cycle `0 <-> 1` of
  `x^3 - 2x + 2` from 0.
