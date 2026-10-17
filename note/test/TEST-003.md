---
id: TEST-003
title: Examples in doc/api are compiled, run, formatted and doctested
kind: rule
path:
  - test/doc/test_example.py
  - doc/api/*.md
  - cmake/warning.cmake
  - .clang-format
related: [TEST-001, TEST-002, STYLE-003, FP-004]
---
Every fenced `c` block in `doc/api/*.md` must compile, run and print exactly the following `text`
block, and every `python` block must pass as a doctest; `test/doc/test_example.py` enforces both
under pytest (CI `test_python`, `script/dev.sh test`).

- A `c` block is compiled with `CC` (split with `shlex`), else `cc` from `PATH` (skipped if there
  is neither), together with every `src/*.c` (not the built library), `-I include`, and
  `-std=c11 -pedantic -Werror` plus the warning and floating-point flags of `cmake/warning.cmake`
  (`-Wall -Wextra -Wconversion -Wshadow -Wvla -Wstrict-prototypes -Wmissing-prototypes
  -Wcast-qual -Wpointer-arith -Wundef -Wdouble-promotion -ffp-contract=off -fno-fast-math
  -fno-math-errno`),
  without its GCC-only `-fexcess-precision=standard`, at the default optimization level and
  without sanitizers.
- A block that does not match `int main(` is wrapped in `int main(void) { ... return 0; }` after
  `#include <stdio.h>` and `#include <diana/diana.h>`; a `#line` directive points diagnostics at
  the Markdown file and line.
- The program runs with a 60 s timeout. Its stdout and stderr, merged, must equal the next `text`
  block, which must come before the next `c` block (two `c` blocks in a row fail). Death by a
  signal fails; a non-zero exit status alone does not.
- A `c` block must be unchanged by `clang-format --style=file:.clang-format`. The test looks for
  `clang-format` only in the running environment's scripts directory (the uv `lint` group pins
  it) and is skipped without it.
- The `python` blocks of one page run in page order as doctest sessions sharing one namespace
  (`__name__` is the page stem); each block needs at least one `>>>` example.
- `cmake` blocks are not built. At least one must contain `find_package(diana X.Y`, and every
  requested version must equal `X.Y` of `project(diana VERSION ...)` in `CMakeLists.txt`; the
  `find_package` ctest test (TEST-002) builds an equivalent consumer.
