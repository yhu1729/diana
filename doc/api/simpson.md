# Composite Simpson rule

Status codes, linking, and the Python conventions shared by every kernel are in the
[API overview](overview.md); the theorems cited below are listed in `spec/simpson.md`.

## C (`diana/simpson.h`)

A function over tabulated samples, like the [trapezoidal rule](trapezoidal.md). There is no
callback wrapper; Python calls the kernel as `diana.simpson` (see [Python](#python)).

- `diana_simpson(y, n, h, result)` writes `(h * s) / 3` to `*result`, with
  `s = ((y[0] + y[n-1]) + 4 * so) + 2 * se`, where `so = y[1] + y[3] + ... + y[n-2]` and
  `se = y[2] + y[4] + ... + y[n-3]` are each summed left to right from `+0`; every operation is
  binary64 in that order (`n - 1` panels of width `h`, an even number). Returns `DIANA_OK` when the
  result is finite. Returns `DIANA_ERR_ARG`, without writing `*result`, for a NULL `y` or `result`,
  for `n < 3` or an even `n`, and when the result is not finite: a NaN or infinite sample or `h`, or
  an overflow in any operation, including `h * s` when `(h * s) / 3` alone would be finite.
  `y[0 .. n-1]` is only read and must not overlap `*result`.

Frama-C WP proves memory safety, termination, the status cases and the finiteness of `*result` on
`DIANA_OK` (SIMPSON-C1). For exact samples of an `f` whose fourth derivative is bounded by `M₄` on
`[a, b]`, the rule in exact arithmetic is within `(b − a)·h⁴·M₄/180` of the integral (SIMPSON-A2,
proved in Lean and Rocq). The binary64 evaluation order above is within
`γₚ₊₅·|h|·A/3 + (1 + u)·η/3 + η` of the exact rule whenever its result is finite, with `p = (n − 1)/2`,
`A = |y[0] + y[n-1]| + 4·(|y[1]| + |y[3]| + ...) + 2·(|y[2]| + |y[4]| + ...)`,
`γₖ = k·u/(1 − k·u)`, `u = 2⁻⁵³` and `η = 2⁻¹⁰⁷⁵` (SIMPSON-B2, Flocq); like the trapezoidal bound it
is relative to `A`, not to the result. VST proves that the C computes exactly this binary64 value
and returns `DIANA_OK` exactly when it is finite, leaving `*result` unchanged otherwise
(SIMPSON-C2, for non-NULL `y` with an odd `n >= 3`).

## Python

`diana.simpson(y, h)` returns the composite Simpson rule of `diana_simpson` as a `float`, with the
same operation order. `y` is an [array argument](overview.md#array-argument) of at least three
samples; after the array checks, an even number of samples raises `ValueError`. A non-finite result
raises `ValueError`.
