---
id: STYLE-008
title: clang-tidy runs only in script/dev.sh test, on the build's compile database
kind: fact
path:
  - script/dev.sh
  - CMakeLists.txt
related: [STYLE-007, STYLE-005, BENCHMARK-003]
---
`script/dev.sh test` runs ctest, pytest, `ruff check`, `ruff format --check`, the `clang-format`
check, then clang-tidy, then `script/check_doc.py`, stopping at the first failure. No CI job runs
clang-tidy.

- Binary: `DIANA_CLANG_TIDY` when set, else the first `clang-tidy` on `PATH`, else
  `/opt/homebrew/opt/llvm/bin/clang-tidy` or `/usr/local/opt/llvm/bin/clang-tidy`. When none is
  found it prints `clang-tidy: not found; check skipped` and goes on: clang-tidy is not a pinned
  dependency, unlike `clang-format` (STYLE-005).
- Files: `git ls-files 'src/*.c' 'test/c/*.c' 'test/install/*.c' 'python/ext/*.c'
  'benchmark/*.c'`, run as `clang-tidy --quiet -p <build dir> --warnings-as-errors='*'`, so any
  finding fails (the file's own `WarningsAsErrors` is empty); headers are checked through
  `HeaderFilterRegex` (STYLE-007).
- Compile database: `CMakeLists.txt` sets `CMAKE_EXPORT_COMPILE_COMMANDS ON`, so
  `<build dir>/compile_commands.json` exists after `script/dev.sh config`; the step fails when it
  is missing, and also when it has no `python/ext/` entry (a build configured with
  `DIANA_BUILD_PYTHON=OFF`). Without those entries clang-tidy would guess the extension's compile
  command, miss the include path of `<Python.h>`, and report the failed parse as findings.
- `script/dev.sh config` runs `uv sync` before `cmake` and passes
  `-DPython_EXECUTABLE=$PWD/.venv/bin/python`, so the extension entries use the headers of the
  interpreter pytest runs against, and `-DDIANA_BUILD_BENCHMARK=ON`, so the database has the
  `benchmark/` entries (BENCHMARK-003). The database comes from the `build/` configuration (Debug with
  sanitizers by default); pytest itself uses the extension uv builds.
