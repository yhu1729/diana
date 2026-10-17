# Floating-point helpers without libm

A verified kernel calls no external function: each call would need an axiomatised specification in
VST and Frama-C, and CompCert's `clightgen` cannot parse the macOS `<math.h>`. `src/fp.h` provides
pure IEEE arithmetic that Flocq models exactly:

- `diana_fp_finite(x)` is `x == x && x - x == 0`: NaN is the only value with `x != x`, and `x - x` is
  NaN for infinities and `+0` for every finite `x`.
- `diana_fp_abs(x)` is a conditional negation; for `-0.0` it returns `-0.0`, which compares equal to
  `0`.

The header also asserts `FLT_EVAL_METHOD == 0` (`_Static_assert`, from `<float.h>`): the
models round every operation to binary64, which a compiler that evaluates `double` expressions in
a wider format (x87) does not do, whatever the flags. The assertion is a declaration, so it
changes no Clight AST and adds no WP goal.
