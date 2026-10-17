---
id: COMPILER-008
title: Computed NaN bits are compared, and the corpus detects FMA and fast-math
kind: fact
path:
  - test/c/test_compiler.c
  - script/compare_compiler.sh
related: [COMPILER-001, COMPILER-011, TEST-018, FP-004]
---
The comparison covers NaN bits produced by arithmetic: the unchecked Euler and RK4 kernels write
the NaN and `±inf` they compute, and the driver prints every output slot as a bit pattern. A
compiler that produced a NaN with another sign or payload would therefore show as a mismatch; on
the recorded platform none did (COMPILER-011).

- The checked kernels write no non-finite value, and NaN inputs (quiet, signalling, negative) are
  built from fixed bit patterns, so they print the same for every compiler.
- Detection power was measured once, on an earlier and smaller corpus (976 cases, 5693 lines:
  bisection, trapezoidal, Simpson and the checked Euler step, recorded in commit `cf086b9`). Built
  at `-O2` with `-ffp-contract=fast` (FMA contraction), Apple clang 21 and GCC 16 differed from
  `ccomp` on 301 and 132 lines; with `-ffast-math` (clang at `-O2`, GCC at `-O3`) on 477 and 488.
  These counts were not re-measured after Newton, RK4 and the unchecked kernels joined the
  corpus.
- The normal comparison builds pass `-ffp-contract=off -fno-fast-math` (COMPILER-001), so such a
  deviation would come from a compiler default or a changed flag.
