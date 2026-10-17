---
id: TEST-010
title: Trapezoidal exact affine cases and the summation-order pin
kind: fact
path:
  - test/c/test_trapezoidal.c
  - test/python/test_trapezoidal.py
  - src/trapezoidal.c
related: [TEST-011, TEST-012]
---
`diana_trapezoidal` computes `s = 0.5 * (y[0] + y[n-1])`, adds `y[1] .. y[n-2]` to `s` left to
right, and returns `h * s` (`src/trapezoidal.c`). The exact cases make every one of these
operations exact; one case pins the order.

- The rule is exact for affine `f`. The samples are integers or quarter-integers and `h` is
  `1/2`, `3/4` or `2^-7`, so every partial sum and the product are representable and the result
  equals the integral: 20 for `2x + 1` on `[0, 4]` with `h = 1/2` (`-20` with `h = -1/2`), 16.5
  for `7 - x` on `[0, 3]` with `h = 3/4`, and `1000 * 500 / 128 = 3906.25` for `y_i = 3i - 1000`,
  `i = 0..1000`, whose samples change sign, with `h = 2^-7`.
- Two samples `{1, 3}` give 1 with `h = 1/2` and 4 with `h = 2`.
- Order: `y = {2^53, 1, 1, 2^53}`, `h = 1`. The halved endpoint sum is `2^53`, and `2^53 + 1` is
  a tie that rounds to even, `2^53`, at each interior step, so the result is `2^53`; summing the
  interior first would give the exact `2^53 + 2`. The C test, the Python test and the compiler
  corpus all carry this case.
- Python returns 20 for the affine samples given as a list, tuple, iterator, ints, `Fraction`s,
  `array.array("d")`, NumPy arrays, memoryviews (read-only and cast) and a ctypes array, and reads
  a contiguous NumPy slice in place.
