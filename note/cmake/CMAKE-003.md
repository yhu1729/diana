---
id: CMAKE-003
title: Why DIANA_BUILD_PYTHON is ON by default
kind: rationale
path:
  - CMakeLists.txt
  - script/dev.sh
related: [CMAKE-002, PYTHON-005]
---
`DIANA_BUILD_PYTHON` is ON by default so that a plain configure describes `python/ext/` in
`compile_commands.json`. Without those entries clang-tidy parses the extension with a guessed
command, does not find `<Python.h>`, and reports findings that are artefacts of the failed parse;
the clang-tidy step of `script/dev.sh test` therefore fails when the database has no
`python/ext/` entry.

- The option needs a Python interpreter and its development headers
  (`find_package(Python COMPONENTS Interpreter Development.Module REQUIRED)`), so a machine
  without them configures with `-DDIANA_BUILD_PYTHON=OFF`, as the C-only CI jobs do.
- `script/dev.sh config` points `Python_EXECUTABLE` at `.venv/bin/python`, so the database uses
  the interpreter the pytest suite runs on.
- The `_diana` built in the CMake tree (Debug, sanitized under `script/dev.sh`) serves the
  compile database and clang-tidy; pytest imports the extension that `uv sync` installs, a
  Release build without sanitizers (PYTHON-005).
- `cmake --install` never installs the extension: its `install()` rule exists only when `SKBUILD`
  is defined.
