---
id: TEST-043
title: ctest configure checks the compiler refusal and the flag guard
kind: fact
path:
  - test/c/test_configure.cmake
  - test/c/CMakeLists.txt
  - CMakeLists.txt
related: [BUILD-013, FP-004, TEST-001]
---
The ctest test `configure`, registered in `test/c/CMakeLists.txt`, runs the CMake script
`test/c/test_configure.cmake` (`cmake -P`). It configures the project again, configuration only,
into `<build>/test/c/configure` with the parent's compiler, generator and make program,
`CMAKE_BUILD_TYPE=Check`, `DIANA_BUILD_PYTHON=OFF` and `DIANA_BUILD_TEST=OFF`. Every run passes all
six variables the guard reads (`CMAKE_C_FLAGS`, its `_DEBUG`, `_RELEASE`, `_RELWITHDEBINFO`,
`_MINSIZEREL` and `_CHECK` forms), all empty but the one under test.

1. A run with no flag must succeed; it detects the compiler once, and the later runs reuse it.
2. `CMAKE_C_FLAGS` with the strict flags and their safe neighbours (`-ffp-contract=off`,
   `-fno-fast-math`, `-fsigned-zeros`, `-ffp-model=precise`, `-fp-model strict`, `-mfma`, …) must
   succeed: the guard has no false positive on them.
3. Each rejected flag of FP-004, as `-O2 <flag> -g` in `CMAKE_C_FLAGS`, and `-ffp-contract=fast` in
   each of the six variables must fail with `Diana must not be built with <flag> (<var>)`.
4. The script rewrites `CMAKE_C_COMPILER_ID` to `DianaUnknown` in the build tree's
   `CMakeFiles/<version>/CMakeCCompiler.cmake`. A run must then fail with the refusal of
   BUILD-013, one with `DIANA_ALLOW_UNKNOWN_COMPILER=ON` succeed with its warning, and one that
   adds `-ffast-math` fail on the guard.

Messages are compared with whitespace collapsed, since CMake wraps them. Step 4 depends on that
CMake-internal file; the script fails, rather than passes, when it finds no file or no ID line.
It takes about 3 s; CI runs it in every job that runs ctest.
