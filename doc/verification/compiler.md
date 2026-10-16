# Compiler comparison

The VST proofs are about CompCert's Clight semantics, but the shipped library is built with gcc
or clang ([verified artifact versus shipped binary](trust.md#verified-artifact-versus-shipped-binary)).
`script/compare_compiler.sh` checks the two agree on a fixed corpus, locally, since no CI image
carries CompCert.

## Build

- It builds the library sources `src/*.c` (the kernels and `status.c`, not `src/wrapper/`) with
  the driver `test/c/test_compiler.c` once with `ccomp -std=c11` at its default optimization, and
  with every host compiler at `-O0`, `-O2` and `-O3` using `-std=c11 -ffp-contract=off
  -fno-fast-math`, the warning set of `cmake/warning.cmake` with `-Werror`, and
  `-fexcess-precision=standard` for gcc. It fails unless each host output is byte-identical to
  the `ccomp` output, prints the first 20 lines of `diff`, and keeps the outputs.
- The host compilers are `DIANA_COMPARE_CC` when set, else `clang`, `gcc`, `cc`, every `gcc-N`
  and `clang-N` on `PATH`, and the Homebrew LLVM `clang`; candidates with the same first line of
  `--version` are one compiler (on macOS `gcc` and `cc` are Apple clang). A candidate that cannot
  link a trivial program is skipped with its first error line: Homebrew GCC 13 on macOS 27 passes
  `-mmacosx-version-min=18.0`, which the linker rejects. A driver that does not build fails.
- Without `ccomp` on `PATH` it prints that the comparison is skipped and exits 0, so
  `script/dev.sh verify` (which runs it through `opam exec`) skips it as the Clight check skips a
  foreign target.

## Corpus

The driver prints one line per case with every status as `s` plus 8 hex digits and every double as
its 16 hex-digit bit pattern, inputs included, so the sign of zero and any change to the corpus
itself show up in the diff. The corpus (976 cases, 5693 lines) covers:

- bisection: every `init` argument error (NaN, signalling NaN, ±∞ in each argument, `a > b`,
  `tol < 0`, `max_iter == 0`, `|a|` or `|b|` past `DBL_MAX / 2`), both bracket errors, each
  immediate convergence (`fa` or `fb` equal to ±0, `tol` at least the width, adjacent endpoints
  in a binade, across a binade and among subnormals); full runs printing the state after every
  step, including the 2098-step worst case of `test/c/test_bisection.c` and its mirror, roots at
  0.1, `sqrt(2)`, `1e300` and subnormals, `ERR_MAXITER` and one step past it; `step` with a
  non-finite, zero or subnormal `fx`; `result` with each output pointer omitted;
- the trapezoidal and Simpson rules: every argument error, the operation-order and overflow cases
  of the ctest suites, `h = ±0`, ±0 samples, subnormal samples and `h`, results that underflow to
  0, and NaN, signalling NaN and ±∞ at each position and in `h`;
- the Euler step: every argument error, the case that tells a fused multiply-add from separate
  rounding, `h = ±0` with signed-zero components, underflow ties, `DBL_MAX + 1`, overflow in the
  product and in the sum, failures in the first and last component (the output keeps its
  sentinels), and non-finite `y`, `f` and `h`;
- seeded random inputs: 200 arrays per array kernel and 96 bisection runs, half drawn from all of
  binary64 (special values, subnormals, both ends of the exponent range) and half from moderate
  exponents. The generator is splitmix64 on integers and builds each double from its bits, so the
  inputs do not depend on the compiler. A random bisection run prints its first and last state
  and an FNV-1a digest of every intermediate one.

No kernel writes a non-finite value, so no NaN produced by arithmetic is printed and NaN payloads,
which may differ between compilers, cannot cause a false mismatch. The corpus does detect a
deviation from strict IEEE evaluation: built at `-O2` with `-ffp-contract=fast` (FMA
contraction), Apple clang 21 and GCC 16 differ from `ccomp` on 301 and 132 lines, and with
`-ffast-math` (clang `-O2`, GCC `-O3`) on 477 and 488.

## Static arrays

All arrays of the driver are static. CompCert 3.17 on AArch64 macOS allocates a `main` frame
larger than about 500 bytes with `sub sp, sp, #(n - 8)` and stores the frame link at `[sp]`
before the final `sub sp, sp, #8`, so the store uses a stack pointer that is not 16-byte aligned
and the program dies with `SIGBUS` before its first statement. Its inlining of functions called
once moves the locals of the driver's test functions into `main`; other functions are not affected.

## ctest

ctest also builds and runs the driver as the `compiler` test, which checks only that it runs: the
CI compilers and the sanitizers of the Debug build then cover it, while the comparison itself needs
`ccomp`.
