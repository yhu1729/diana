---
id: COMPILER-001
title: Compiler comparison builds and the byte-identical output requirement
kind: fact
path:
  - script/compare_compiler.sh
  - test/c/test_compiler.c
  - cmake/warning.cmake
related: [COMPILER-002, COMPILER-004, COMPILER-005, FP-004, FP-005]
---
`script/compare_compiler.sh` builds all of `src/*.c` together with the corpus driver
`test/c/test_compiler.c` once with CompCert and several times with each host compiler, runs every
binary, and fails unless every host output is byte-identical to the `ccomp` output. The VST proofs
are about CompCert's Clight semantics, so this is the evidence that gcc and clang builds compute
the same bits on the corpus.

- Reference: `ccomp -std=c11 -Wall -Werror -Iinclude` at CompCert's default optimization. Its run
  must exit 0 and its last line must start with `end ` (a truncation check). The script prints
  `compiler: reference <ccomp -version>, <uname -m>, <n> lines`.
- Host builds: each compiler at `-O0`, `-O2` and `-O3` with `-std=c11 -ffp-contract=off
  -fno-fast-math -fno-math-errno`, the warning set of `cmake/warning.cmake` with `-Werror`, and
  `-fexcess-precision=standard` when the compiler predefines `__GNUC__` but not `__clang__`. A
  build error aborts the script; a run that exits non-zero fails it.
- The build includes `status_str.c`, `version.c` and the callback wrappers, which the driver does
  not call.
- Each host output is compared with `cmp`. A match prints
  `compiler: <cc> <opt> (<description>) matches ccomp`. A mismatch prints the first 20 lines of
  `diff` and an error, and the remaining builds still run; the script then fails, keeps its
  temporary directory with every output and names it. On success the directory is removed.
