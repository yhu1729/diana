---
id: COMPILER-007
title: Corpus random inputs are built from bits by a fixed-seed splitmix64
kind: fact
path:
  - test/c/test_compiler.c
related: [COMPILER-005, COMPILER-006]
---
The random part of the corpus draws integers from splitmix64 with the fixed seed
`0x2545f4914f6cdd1d` and builds each double from sign, exponent and mantissa bits, so the inputs
are the same bits whatever compiler or optimization level builds the driver.

- Draws alternate by index: even-indexed draws use moderate exponents only (biased 1003 to 1043,
  and 1019 to 1027 with only the top 6 mantissa bits); odd-indexed draws cover all of binary64:
  with probability 2/64 a value from a table of 20 special bit patterns (`±0`, `±inf`, `±NaN`, a
  signalling NaN, `±DBL_TRUE_MIN`, the largest subnormals, `±DBL_MIN`, `±DBL_MAX/2`, `±DBL_MAX`,
  `±1`, `2^-52`), 4/64 subnormals, 2/64 the lowest and 2/64 the highest normal exponents, 4/64 any
  exponent, and the moderate ranges otherwise.
- Array kernels: 200 draws each. Trapezoidal `n` is 2 to 41 and Simpson `n` odd from 3 to 39;
  Euler and RK4 `d` is 1 to 32; `h` comes from the same distribution. Each RK4 draw runs a stage
  (number 2 to 4) and a step on the same `y` and slopes, checked and unchecked.
- Bisection: 96 runs. Three values bounded by `DBL_MAX/2` (redrawn otherwise) are sorted into
  `a <= c <= b`; `f` is `x - c` (1/2), `c - x` (1/4) or `x^2 - c^2` (1/4); `tol` is 0 or a random
  non-negative value; `max_iter` is 2100, or 1 to 60 with probability 1/8.
- Newton: 96 runs of `x - c`, `x^2 - c` or `x^3 - c` (1/3 each) with bounded random `c` and
  `x0`, `tol` 0 or random, `max_iter` 100 or 1 to 60 with probability 1/8.
- A random run prints its first line, then only `  end <steps> <digest>`: a 64-bit FNV-1a digest
  (offset `0xcbf29ce484222325`, prime `0x100000001b3`) over the bytes, least significant first,
  of the returned status and every state field, `status` last, after each step, then the final
  state and `result`.
