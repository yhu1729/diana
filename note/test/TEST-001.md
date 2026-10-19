---
id: TEST-001
title: Test suite layout and how to run it
kind: fact
path:
  - test/c/CMakeLists.txt
  - test/c/check.h
  - pyproject.toml
  - script/dev.sh
related: [TEST-002, TEST-003, TEST-004, TEST-005, TEST-043, COMPILER-010, BUILD-002]
---
The C tests are ctest executables in `test/c/`; the Python tests are pytest modules in
`test/python/` and `test/doc/`. `script/dev.sh test` runs both, then the lint checks.

- `test/c/CMakeLists.txt` defines `diana_add_test(<name>)`: it builds `test_<name>.c` into
  `test_<name>`, links `diana::diana` and `m`, applies `diana_set_strict_flag` (the library's
  warning and floating-point flags, plus `-Werror` with `DIANA_WERROR`) and registers ctest test
  `<name>`. The tests are `status`, `bisection`, `cholesky`, `compiler` (the corpus driver,
  COMPILER-010), `euler`, `lu`, `lu_solve`, `newton`, `norm`, `rk4`, `simpson`, `substitution`
  and `trapezoidal`; the CMake script test `configure` (`test_configure.cmake`, TEST-043) reconfigures
  the project to check the compiler refusal and the floating-point flag guard;
  outside scikit-build ctest also has `install` and `find_package` (TEST-002). `test/c/` is built
  only with `-DDIANA_BUILD_TEST=ON` (default OFF; the wheel build passes OFF).
- `test/c/check.h` needs only `<stdio.h>`: `CHECK(cond)` and `CHECK_EQ_STATUS(got, want)` count a
  failure and print `file:line` to stderr without stopping; `main` returns
  `check_report("<name>")`, which prints `<name>: ok` and returns 0, or prints the failure count
  and returns 1. `test_compiler.c` does not use it.
- pytest collects `test/python` and `test/doc` (`testpaths` in `pyproject.toml`). The uv `test`
  group brings pytest, NumPy, mpmath, Hypothesis and PyYAML; NumPy appears only in tests.
- Run: `cmake -S . -B build -DDIANA_BUILD_TEST=ON -DDIANA_WERROR=ON`, `cmake --build build`,
  `ctest --test-dir build`; `uv sync --group test --group lint && uv run pytest`.
  `script/dev.sh test` runs ctest on its build directory (Debug with sanitizers by default),
  pytest against the extension `uv sync` built with scikit-build-core (not the sanitized
  `build/` tree), ruff, the clang-format check, clang-tidy and `script/check_doc.py`.
- CI: `test_{gcc,clang}_{debug,release}` run ctest on the `build_*` artifacts (Debug with
  sanitizers, Release without, `-DDIANA_BUILD_PYTHON=OFF`); `test_install` runs ctest on two
  fresh configurations; `test_python` runs pytest and the wheel check (TEST-004).
