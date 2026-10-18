---
id: KERNEL-006
title: Add a method
kind: procedure
path:
  - CMakeLists.txt
  - cmake/symbol.txt
  - include/diana/diana.h
  - test/c/CMakeLists.txt
  - test/c/test_compiler.c
  - verification/frama-c/expectation.txt
  - verification/rocq/_CoqProject
  - verification/rocq/Makefile
  - verification/lean/Diana.lean
related:
  - KERNEL-001
  - KERNEL-003
  - KERNEL-005
  - KERNEL-007
  - PYTHON-007
  - GATE-001
  - VST-002
  - WP-007
  - PROVER-007
  - VERIFY-002
  - BUILD-012
---
A method touches the library, its tests, the binding, every proof layer and the docs. Wire it as
`simpson` (one function) or `rk4` (several functions) is wired:

1. `include/diana/<method>.h` with `extern "C"` guards, included from `include/diana/diana.h`;
   each public function also in `cmake/symbol.txt` (BUILD-012).
2. One `src/<function>.c` per function (KERNEL-001), and `src/<method>.c` for an optional callback
   wrapper (KERNEL-004); list each in `add_library(diana ...)` of `CMakeLists.txt`. Shared helper:
   KERNEL-005; shared ACSL predicates: KERNEL-007.
3. An ACSL contract per verified source and its `src/<function>.c <goals>` row in
   `verification/frama-c/expectation.txt` (WP-007).
4. `test/c/test_<method>.c` with `diana_add_test(<method>)` in `test/c/CMakeLists.txt`; cases in
   the compiler corpus `test/c/test_compiler.c` (COMPILER-001).
5. The Python binding and `test/python/test_<method>.py` (PYTHON-007).
6. `spec/<method>.md` with the theorem IDs and prover constants (GATE-001).
7. Layer A: `verification/lean/Diana/Real/<Method>.lean`, imported in
   `verification/lean/Diana.lean`; `verification/rocq/theory/Real/<Method>.v` in `_CoqProject`
   and in the `real` target of `verification/rocq/Makefile`, the list CI compiles (PROVER-007).
8. Layer B: `theory/Float/<Method>.v` in `_CoqProject`.
9. Layer C-VST, per source: the Clight AST `verification/clight/<function>_aarch64_macos.v`
   (VST-002) and `theory/VST/<Function>.v`, models shared by several files in an AST-free
   `theory/VST/<Method>.v`, all in `_CoqProject`; one listed theorem per `src/fp.h` helper copy.
10. `doc/api/<method>.md` (examples run in `test/doc/`, TEST-003) with a "Guarantees" paragraph
    and a "Technical notes" link list, linked from `doc/README.md` and `README.md`; the test
    values and proof details as notes under `note/test/`, `note/proof/` and the other topics.
11. `CHANGELOG.md` (`Unreleased`) and `CLAUDE.md` (Status and the `clightgen` kernel list).
12. `uv run script/check_doc.py --write` (note index), `script/dev.sh test`, then
    `script/dev.sh verify`; commit the report it rewrites (GATE-006).

Globs pick up the rest: CI path filters (CI-002), `script/check_spec.py` (`spec/*.md`),
`test/doc/test_example.py` (`doc/api/*.md`, `src/*.c`), `script/compare_compiler.sh` (`src/*.c`).
