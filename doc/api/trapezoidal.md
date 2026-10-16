# Composite trapezoidal rule

Status codes, linking, and the Python conventions shared by every kernel are in the
[API overview](overview.md); the theorems cited below are listed in `spec/trapezoidal.md`.

## C (`diana/trapezoidal.h`)

A function over tabulated samples: the caller evaluates `f` at the nodes. There is no callback
wrapper; Python calls the kernel as `diana.trapezoidal` (see [Python](#python)).

- `diana_trapezoidal(y, n, h, result)` writes `h * (0.5 * (y[0] + y[n-1]) + y[1] + ... + y[n-2])` to
  `*result`, evaluated in binary64 in that order (`n - 1` panels of width `h`; a negative `h`
  integrates in the opposite direction). Returns `DIANA_OK` when the result is finite. Returns
  `DIANA_ERR_ARG`, without writing `*result`, for a NULL `y` or `result`, for `n < 2`, and when the
  result is not finite: a NaN or infinite sample or `h`, or an overflow anywhere in the sum. A
  finite result implies that no intermediate overflowed (TRAPEZOIDAL-B1 in `spec/trapezoidal.md`).
  `y[0 .. n-1]` is only read and must not overlap `*result`.

Frama-C WP proves memory safety, termination, the status cases and the finiteness of `*result` on
`DIANA_OK` (TRAPEZOIDAL-C1). For exact samples of an `f` whose second derivative is bounded by `M₂`
on `[a, b]`, the rule in exact arithmetic is within `(b − a)·h²·M₂/12` of the integral
(TRAPEZOIDAL-A2, proved in Lean and Rocq). The binary64 evaluation order above is within
`γₙ·|h|·A + (1 + γₙ₋₁)·|h|·η + η` of the exact rule whenever its result is finite, with
`A = |y[0] + y[n-1]|/2 + |y[1]| + ... + |y[n-2]|`, `γₖ = k·u/(1 − k·u)`, `u = 2⁻⁵³` and
`η = 2⁻¹⁰⁷⁵` (TRAPEZOIDAL-B2, Flocq); the bound is relative to `A`, not to the result, so it says
little under heavy cancellation. VST proves that the C computes exactly this binary64 value and returns
`DIANA_OK` exactly when it is finite, leaving `*result` unchanged otherwise (TRAPEZOIDAL-C2, for
non-NULL `y` with `n >= 2`).

## Python

`diana.trapezoidal(y, h)` returns the composite trapezoidal rule of `diana_trapezoidal` as a
`float`, with the same operation order. `y` is an [array argument](overview.md#array-argument) of
at least two samples. A non-finite result (`DIANA_ERR_ARG` in C) raises `ValueError`.
