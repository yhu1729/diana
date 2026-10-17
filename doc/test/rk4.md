# Classical Runge–Kutta step test values

## C

Expected values in `test/c/test_rk4.c`:

- Exact stages and steps use values with few significant bits. For the stage, `h = 1/2` makes
  the coefficient `1/4` (stages 2 and 3) or `1/2` (stage 4), and the 100-component case checks
  `y_out[i] = i/2 - 48.5` with both. For the step, `h = 3/4` makes `h * s / 6 = s / 8` exact for
  small integer `s`; the 100-component cases have slopes `2i, -i, -i, 2i` (the sum cancels to 0)
  and `2i, 0, 0, 2i` (`y + i/2`). Unit slopes with `h = 6` give the weights `1, 2, 2, 1`.
- `y = -1`, `c = 1 + 2^-52`, `k = 1 - 2^-52` pins the separately rounded product of the stage
  (`c * k = 1 - 2^-104` rounds to 1 and the result is `+0`), both with `h = c` at stage 4 and with
  `h = 2c` at stage 2.
- `h = 3 * 2^-1074` pins the rounding of the coefficient: `h/2` is a tie that rounds to
  `2 * 2^-1074`, so the stage point with `k = 1024` is `2^-1063`, where `(h * k)/2` would be the
  exact `3 * 2^-1065`.
- `k1 = 1`, `k2 = k3 = 2^-54`, `k4 = 2^-53`, `h = 6` pins the slope sum: `k1 + k4` is a tie that
  rounds to 1, `s = 1 + 2^-52`, `6 s` rounds to `6 + 2^-49` and dividing by 6 gives `1 + 2^-52`.
  Summing left to right gives 1, and the correctly rounded sum `1 + 2^-51`.
- `h = 0` keeps each `y[i]`, including its sign of zero, in both functions.
- `h = 2^-1074` with `s = 1` underflows `h * s / 6` to `+0`: underflow is not an error.
- Overflow cases have finite inputs and overflow in exactly one operation: the stage product, the
  stage coefficient times `k` (`h = DBL_MAX`, `k = 4`; with `k = 2` the result is exactly
  `DBL_MAX`), the stage sum, `k2 + k3`, the doubling, the slope sum, `h * s` and the final sum
  (`DBL_MAX + 2^1020`). `k1 + k4` cancelling `DBL_MAX` and `DBL_MAX + 1` rounding back to
  `DBL_MAX` are finite.
- NaN and infinity are placed in each position of `y` and each slope, and in `h`; `inf - inf` in
  `k1 + k4` and `k2 + k3`, and `0 * inf`, give NaN.
- Two failing cases per function, one in the last component and one in the first, check that
  `y_out` keeps its sentinel values: the first pass rejects before the second pass writes.
