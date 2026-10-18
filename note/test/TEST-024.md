---
id: TEST-024
title: RK4 untouched output on error and the unchecked stage and step
kind: fact
path:
  - test/c/test_rk4.c
  - src/rk4_stage_unchecked.c
  - src/rk4_step_unchecked.c
related: [TEST-018, TEST-023, KERNEL-002]
---
The checked RK4 stage and step write nothing when they reject; the unchecked ones write the same
bits wherever the checked ones succeed, and the IEEE results where they reject.

- Failure position: `(1, 2, DBL_MAX)` with slope `(1, 1, DBL_MAX)` fails in the last component and
  `(DBL_MAX, 2, 3)` with `(DBL_MAX, 1, 1)` in the first (stage 4 with `h = 2`, step with `h = 1`);
  both `DIANA_ERR_OVERFLOW`, and all 100 output slots keep the sentinel, so the first pass rejects
  before the second writes.
- Argument errors for all four functions: NULL `y`, `k` (or each of `k1 .. k4`) or `y_out`,
  `d == 0`, and for the stage numbers 0, 1, 5 and -3.
- `stage_ok` and `step_ok` run the checked and the unchecked function on every successful case
  and compare all 100 slots by bit pattern, so both write only `y_out[0 .. d-1]`.
- Unchecked stage on rejected input: `+inf` from the product with `c = h` and with `c = h/2`
  (`h = DBL_MAX`, `k = 4`) and from the sum, `-inf` from a negative product, NaN from `inf - inf`
  and `0 * inf`, NaN everywhere for NaN `h`, `+inf` for `h = +inf` at stage 2, and
  `(1, 2, DBL_MAX) + 2 (1, 1, DBL_MAX) = (3, 4, +inf)`.
- Unchecked step: `+inf` from `k2 + k3`, the doubling, the slope sum, `h * s` and the final sum,
  `-inf` from a negative overflow, NaN from `inf - inf` in each pair sum and from `0 * inf`, NaN
  for NaN `h`, and `y = (-1, NaN, 0.5)` with every slope `(6, 0, -inf)` and `h = 1` giving
  `(5, NaN, -inf)`.
- An expected NaN is checked with `isnan`, not by bits.
