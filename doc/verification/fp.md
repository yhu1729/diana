# Floating-point helpers without libm

A verified kernel calls no external function: each call would need an axiomatised specification in
VST and Frama-C, and CompCert's `clightgen` cannot parse the macOS `<math.h>`. `src/fp.h` provides
pure IEEE arithmetic that Flocq models exactly:

- `diana_fp_finite(x)` is `x == x && x - x == 0`: NaN is the only value with `x != x`, and `x - x` is
  NaN for infinities and `+0` for every finite `x`.
- `diana_fp_abs(x)` is a conditional negation; for `-0.0` it returns `-0.0`, which compares equal to
  `0`.
