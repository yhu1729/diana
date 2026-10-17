---
id: STYLE-005
title: clang-format is LLVM style plus braces, an ACSL pragma and CPython macros
kind: fact
path:
  - .clang-format
  - pyproject.toml
related: [CI-004, STYLE-007, TEST-003]
---
`.clang-format` is `BasedOnStyle: LLVM` (2-space indent, 80 columns) with four additions:

- `InsertBraces: true`: every `if`, `else`, `for`, `while` and `do` body becomes a braced block,
  which also makes clang-tidy's `readability-braces-around-statements` redundant (STYLE-007).
- `CommentPragmas: '^@'`: a comment starting with `@`, that is every ACSL `/*@ ... */`
  annotation, is left as written. Without it the long `ensures` lines of `src/bisection_step.c`
  and the Newton contracts are rewrapped at 80 columns, and the continuation lines lose their
  leading `@`.
- `StatementMacros: [PyObject_HEAD, PyObject_VAR_HEAD]` and the `Macros` expansion
  `PyVarObject_HEAD_INIT(type, size)={type, size},`: these CPython macros carry their own `;` or
  `,`, so without the hint the next member is joined onto the macro's line
  (`PyObject_HEAD diana_bisection_state s;` in `python/ext/bisection_object.h`), and so is the
  next designator (`PyVarObject_HEAD_INIT(NULL, 0).tp_name = ...` in
  `python/ext/bisection_exec.c`).

The version is pinned as the PyPI wheel `clang-format==23.1.3` in the uv `lint` group, so
`script/dev.sh test`, CI `style_c` (CI-004) and the `doc/api/` example check, which formats each
example with `--style=file:.clang-format` (TEST-003), use one binary. To format:
`uv sync --group lint && git ls-files '*.c' '*.h' | xargs uv run clang-format -i`.
