---
id: TEST-014
title: Simpson overflow, non-finite, zero-step and underflow cases
kind: fact
path:
  - test/c/test_simpson.c
  - test/python/test_simpson.py
  - spec/simpson.md
related: [TEST-013, API-003]
---
Every Simpson overflow case has finite samples and `h` and overflows in exactly one operation;
most of them have a finite exact result, which shows that the kernel's range is limited by its
intermediates (`spec/simpson.md`). The kernel returns `DIANA_ERR_OVERFLOW`, and the C test checks
that `*result` keeps its sentinel.

With `M = DBL_MAX`, each case, the operation that overflows, and the exact `h s / 3`:

- `{M, 0, M}`, `h = 1`: the endpoint sum, `2M/3`; with `h = 0` it still fails (`0 * inf` is NaN),
  exact 0. `{-M, 0, -M}`: the endpoint sum, `-2M/3`.
- `{0, M, 0}`, `h = 1/4`: `4 so`, `M/3`. `{0, M, 0, M, 0}`, `h = 1`: the odd sum, `8M/3`.
- `{0, 0, M, 0, 0}`, `h = 1`: `2 se`, `2M/3`. `{0, 0, M, 0, M, 0, 0}`, `h = 1`: the even sum,
  `4M/3`.
- `{M, M/4, 0}`, `h = 1`: adding `4 so`, `2M/3`. `{M, 0, M/2, 0, 0}`, `h = 1`: adding `2 se`,
  `2M/3`.
- `{1, 1, 1}`, `h = ±M/4`: the product `h s`, `±M/2`.

Only the odd-sum and even-sum cases have an exact result beyond `DBL_MAX`. `{M, 0, 0}` with
`h = 1` succeeds with `M/3`.

- Non-finite input, `DIANA_ERR_ARG`: NaN, `+inf` and `-inf` at each of five positions; opposite
  infinities at both ends or at positions 1 and 3; NaN or `±inf` as `h`, and `h = inf` with
  all-zero samples.
- Classification (`test_overflow_classify`): `{1, M, 1, M, 1}` with `h = 1` overflows in the odd
  sum, `DIANA_ERR_OVERFLOW`; with the last sample NaN or `+inf` it is `DIANA_ERR_ARG`.
- Argument errors: NULL `y` (with `n` 3 or 0), NULL `result`, and `n` of 0, 1, 2 or 4.
- `h = ±0` gives `±0` for `{1, 2, 3}`, and `+0` for `{M/2, M/8, 0}`. `{0.5, 0, 0.5}` with
  `h = DBL_TRUE_MIN` gives `2^-1074 / 3`, which rounds to `+0`: underflow is a finite result,
  `DIANA_OK`.
- Python: `test_overflow` expects `diana.FloatOverflowError` ("result overflows");
  `test_nonfinite_input` a plain `ValueError` ("input is not finite"), also after an overflow.
