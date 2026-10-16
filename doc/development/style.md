# Format and lint

## clang-format

`.clang-format` is LLVM style with `InsertBraces: true` (every `if`/`else`/`for`/`while` body is a
braced block) and three additions needed for the code to survive formatting:

- `CommentPragmas: '^@'` leaves ACSL annotations (`/*@ ... */`) untouched; LLVM would reflow them
  at 80 columns and drop the `@` continuation prefix.
- `StatementMacros` for `PyObject_HEAD`/`PyObject_VAR_HEAD`, and a `Macros` expansion of
  `PyVarObject_HEAD_INIT`: these CPython macros carry their own `;` or `,`, so without the hint the
  next member or designator is joined onto the same line.

The `clang-format` version is pinned in the uv `lint` group, so local runs and CI `style_c` agree.

## EditorConfig

`.editorconfig` carries the same conventions for editors, per file type: 2-space C, Rocq and Lean,
4-space Python, shell and CMake, tabs in `Makefile`. It sets no `max_line_length` for C, because
`clang-format` wraps C at 80 columns but deliberately leaves the ACSL annotations alone, and nine of
them are longer than that.

## clang-tidy

`.clang-tidy` selects `bugprone`, `cert`, `clang-analyzer`, `misc`, `performance` and `readability`,
and its suppressions are each a deliberate project convention, so a new finding is a real one:

- `misc-redundant-expression` fires on `x == x` in `src/fp.h`, which is the libm-free NaN test;
- `readability-uppercase-literal-suffix` and `readability-trailing-comma` contradict the existing
  `0u` and enum style;
- `readability-math-missing-parentheses` and `clang-analyzer-security.insecureAPI.*` fire only in
  test code (`fprintf_s` is not POSIX);
- `python/ext/.clang-tidy` drops `readability-identifier-naming`, because the extension follows
  CPython's `BisectionObject`/`BisectionType` naming rather than the library's `lower_case`;
- `test/c/.clang-tidy` and `test/install/.clang-tidy` drop `cert-err33-c` (the harness reports
  through `fprintf` and exits) and `clang-analyzer-optin.core.EnumCastOutOfRange`
  (`test_status.c` casts an out-of-range value on purpose).

`script/dev.sh test` runs it over every C source with `--warnings-as-errors='*'`, using the
`compile_commands.json` that `CMAKE_EXPORT_COMPILE_COMMANDS` writes into the build directory. It
takes `DIANA_CLANG_TIDY` when set, else the first `clang-tidy` on `PATH`, else the Homebrew LLVM one; when
none is found the step prints that it is skipped instead of failing, because `clang-tidy` is not a
pinned dependency (unlike `clang-format`).

The database has to cover `python/ext/`, so `script/dev.sh config` runs `uv sync` before `cmake` and
passes `-DPython_EXECUTABLE=.venv/bin/python`, which makes the entries describe the same interpreter
the pytest suite runs against. The step fails outright when the entry is absent: clang-tidy then
falls back to a guessed compile command, loses `<Python.h>`, and turns the failed parse into findings
across every file that are artefacts rather than defects.
