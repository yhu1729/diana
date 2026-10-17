---
id: TEST-018
title: Unchecked Euler step agrees bitwise and writes IEEE results
kind: fact
path:
  - test/c/test_euler.c
  - src/euler_step_unchecked.c
related: [TEST-016, TEST-017, TEST-024]
---
Where the checked Euler step succeeds, `diana_euler_step_unchecked` must write the same bits; where
the checked step rejects the inputs, the unchecked step returns `DIANA_OK` and writes the IEEE
result of each operation.

- `check_ok` in `test/c/test_euler.c` runs both functions on every successful case into buffers of
  100 sentinels and compares all 100 slots by bit pattern, so both write only `y_out[0 .. d-1]`.
  Each argument error is checked for both functions.
- `check_raw` cases (unchecked only): `0 + 2 * DBL_MAX = +inf` and `0 - 2 * DBL_MAX = -inf`
  (product); `DBL_MAX + DBL_MAX = +inf` and `-DBL_MAX - DBL_MAX = -inf` (sum); `inf - inf` and
  `1 + 0 * inf` are NaN; `(1, 2, DBL_MAX) + (1, 1, DBL_MAX)` gives `(2, 3, +inf)`, so finite
  components beside a non-finite one are written; `y = (-1, NaN, 0.5)`, `f = (2, 1, -inf)`,
  `h = 1` gives `(1, NaN, -inf)`; NaN `h` gives NaN everywhere; `h = +inf` gives `+inf` for
  positive `f`.
- An expected NaN is checked with `isnan`, not by bits, so the C test does not pin NaN sign or
  payload; the compiler corpus prints those bits (COMPILER-008).
