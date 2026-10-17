---
id: COMPILER-010
title: The ctest compiler test only runs the corpus driver
kind: fact
path:
  - test/c/CMakeLists.txt
  - test/c/test_compiler.c
related: [COMPILER-004, TEST-001, TEST-006]
---
ctest builds `test/c/test_compiler.c` like every other C test (`diana_add_test(compiler)`: linked
with `diana::diana`, the project's warning and floating-point flags) and runs it as test
`compiler`. The test passes when the driver exits 0, which it does unless flushing stdout fails;
its output is not compared with anything.

- Purpose: every ctest run executes the whole corpus, so the CI compilers (images `gcc:14` and
  `silkeh/clang:18` on Linux runners, Debug with AddressSanitizer and UndefinedBehaviorSanitizer,
  and Release), the local sanitized Debug build of `script/dev.sh` and the `coverage_c` job all
  exercise it.
- The bitwise comparison with CompCert needs `ccomp` and runs only in
  `script/compare_compiler.sh` (COMPILER-001, COMPILER-004), so a CI run gives no evidence of
  agreement with the verified semantics.
- The ctest build links the library as built by CMake; the comparison script compiles `src/*.c`
  and the driver in one command with its own flags.
