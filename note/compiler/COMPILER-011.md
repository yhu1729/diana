---
id: COMPILER-011
title: Compilers recorded as matching CompCert, on AArch64 macOS only
kind: fact
path:
  - script/compare_compiler.sh
  - test/c/test_compiler.c
related: [COMPILER-001, COMPILER-008, FP-005, VERIFY-001]
---
In the comparison run of 2026-10-17 on AArch64 macOS (`build/verify/compiler.log` of a local
`script/dev.sh verify`, not committed), every host build at `-O0`, `-O2` and `-O3` printed
exactly the bytes of the CompCert build: 7454 lines against `ccomp` version 3.17, the version the
CompCert 3.18 opam package reports.

- Matching compilers: Apple clang 21.0.0; Homebrew GCC 13.4.0, 14.4.0, 15.3.0 and 16.2.0;
  Homebrew LLVM clang 20.1.8, 21.1.8, 22.1.8 and 23.1.3 (`llvm@20` to `llvm@22` and the `llvm`
  keg; `gcc`, `cc` and `llvm@23` were dropped as duplicates).
- This is evidence on a finite corpus, not a proof, and only for the platform it ran on. No
  comparison on x86-64 is recorded; CI runs the driver on Linux without comparing it
  (COMPILER-010).
- The record is a local log; to refresh it, run `script/dev.sh verify` or
  `opam exec -- script/compare_compiler.sh` and keep its output.
