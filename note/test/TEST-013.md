---
id: TEST-013
title: Simpson exact cubic cases and the operation-order pins
kind: fact
path:
  - test/c/test_simpson.c
  - test/python/test_simpson.py
  - src/simpson.c
related: [TEST-014, TEST-015]
---
`diana_simpson` sums the odd interior samples (`so`) and the even interior samples (`se`) left to
right from `+0`, forms `s = ((y[0] + y[n-1]) + 4 so) + 2 se` and returns `(h * s) / 3`
(`src/simpson.c`). The exact cases leave only the division to round; three cases pin the order.

- The rule is exact for cubic `f`, and the samples and `h` have few significant bits: 64 for
  `x^3` on `[0, 4]` with `h = 1`; `28/3`, correctly rounded, for `x^3 - 2x^2 + x + 1` on `[-1, 3]`
  with `h = 1/2` (`-28/3` with `h = -1/2`), where the weighted sum is exactly 56 so only the
  division rounds; 26000007000 for `y_i = (i - 400)^3 + 7`, `i = 0..1000`, whose samples change
  sign, with `h = 1`, and 3250000875 with `h = 2^-3`. Three nodes `{1, 2, 3}` give 12, 3 and -12
  for `h = 3`, `3/4` and `-3`.
- Endpoint pair first: `{2^53, 1/2, 1/4, 1/2, -2^53}` with `h = 3` gives 4.5, because the
  endpoints cancel before the weighted interior is added; adding the interior to `2^53` first
  would give 4.
- Odd sum left to right from `+0`: in `{0, 2^53, 0, 1, 0, -2^53, 0}` the odd sum is
  `(2^53 + 1) - 2^53`, and `2^53 + 1` is a tie that rounds to `2^53`, so the sum and the result
  (`h = 3`) are `+0`; summing right to left would give 1 and the result 4.
- Even sum the same way: `{0, 0, 2^53, 0, 1, 0, -2^53, 0, 0}` gives `+0`; right to left, 2.
- The C test, the Python test and the compiler corpus all carry the three order cases.
