---
id: STYLE-007
title: clang-tidy check selection and what each suppression would flag
kind: rationale
path:
  - .clang-tidy
  - python/ext/.clang-tidy
  - test/c/.clang-tidy
  - test/install/.clang-tidy
  - benchmark/.clang-tidy
related: [STYLE-008, STYLE-005, FP-002]
---
`.clang-tidy` enables `bugprone-*`, `cert-*`, `clang-analyzer-*`, `misc-*`, `performance-*` and
`readability-*`, checks headers matching `(include/diana|src)/.*\.h$`, and names functions,
variables and typedefs `lower_case`, macros and enum constants `UPPER_CASE`. Each suppression is a
project convention, so a new finding is a real one. What each would flag (clang-tidy 23):

- `misc-redundant-expression`: `x == x` in `diana_fp_finite`, the libm-free NaN test (FP-002).
- `readability-uppercase-literal-suffix`: the `0u` literal style of `src/` and the tests.
- `readability-trailing-comma`: the enum of `include/diana/status.h` and the CPython tables in
  `python/ext/`, written without a trailing comma.
- `readability-math-missing-parentheses`: mixed `+`/`*` expressions in kernels
  (`src/rk4_step.c`, `src/simpson.c`, `src/euler_step.c`, ...) and in the tests.
- `clang-analyzer-security.insecureAPI.DeprecatedOrUnsafeBufferHandling` (only this analyzer
  check): `fprintf` and `memcpy` in `test/c/` and `test/install/`; its `_s` replacements are
  C11 Annex K, which POSIX systems do not provide.
- `bugprone-signed-bitwise`: `test/c/test_compiler.c`.
- `cert-dcl37-c`, `cert-dcl51-cpp`: aliases of `bugprone-reserved-identifier`, which stays on.
- `readability-braces-around-statements`: redundant with `InsertBraces` (STYLE-005).
- `bugprone-easily-swappable-parameters`, `readability-identifier-length`,
  `readability-magic-numbers`, `readability-isolate-declaration`, `misc-include-cleaner`,
  `readability-function-cognitive-complexity`: adjacent `double` parameters, short mathematical
  names (`a`, `b`, `h`, `x`), literal constants and include lists throughout the tree
  (cognitive complexity only in `test/c/`); no further reason is recorded.

The subdirectory files inherit the root (`InheritParentConfig: true`) and drop more:
`python/ext/` drops `readability-identifier-naming` (CPython names such as `BisectionType`);
`test/c/` drops `cert-err33-c` (the harness reports with `fprintf` and exits),
`clang-analyzer-optin.core.EnumCastOutOfRange` (`test_status.c` casts an out-of-range value to
reach `diana_status_str`'s default branch) and `readability-non-const-parameter` (a callback in
`test_newton.c` leaves an output unwritten but keeps the callback type's signature);
`test/install/` drops only `cert-err33-c`; `benchmark/` drops `cert-err33-c` (the drivers report
with `printf` and exit) and `readability-non-const-parameter` (a right-hand side keeps the
signature of `diana_ode_fn` whether or not it reads every parameter).
