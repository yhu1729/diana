# Compiler comparison

The VST proofs are about CompCert's Clight semantics, but the shipped library is built with gcc
or clang ([verified artifact versus shipped binary](trust.md#verified-artifact-versus-shipped-binary)).
`script/compare_compiler.sh` checks the two agree on a fixed corpus, locally, since no CI image
carries CompCert.

## Build

- It builds the library sources `src/*.c` (the kernels, `status_str.c`, `version.c` and the callback
  wrappers, which the driver does not call) with the driver `test/c/test_compiler.c` once with
  `ccomp -std=c11` at its default optimization, and with every host compiler at `-O0`, `-O2` and
  `-O3` using `-std=c11 -ffp-contract=off -fno-fast-math`, the warning set of `cmake/warning.cmake`
  with `-Werror`, and `-fexcess-precision=standard` for gcc. It fails unless each host output is
  byte-identical to the `ccomp` output, prints the first 20 lines of `diff`, and keeps the outputs.
- The host compilers are `DIANA_COMPARE_CC` when set, else `clang`, `gcc`, `cc`, every `gcc-N`
  and `clang-N` on `PATH`, and the `clang` of every Homebrew LLVM keg (`llvm` and each
  `llvm@N` under `/opt/homebrew/opt` or `/usr/local/opt`); candidates with the same first line of
  `--version` are one compiler (on macOS `gcc` and `cc` are Apple clang, and `llvm` is the
  newest `llvm@N`). Each result line names the candidate, its optimization level and a short
  description taken from that first line: the vendor string of gcc (`Homebrew GCC 16.2.0`) or
  `<vendor> clang <version>` (`Apple clang 21.0.0`). A candidate that cannot
  link a trivial program is skipped with its first error line. A driver that does not build fails.
- On macOS, when `MACOSX_DEPLOYMENT_TARGET` is unset or empty, the script sets it to the running
  version (`sw_vers -productVersion`) for every build, `ccomp` included. Without it Homebrew GCC 13
  derives `-mmacosx-version-min=18.0` from Darwin 27, which the clang it runs as assembler and
  linker rejects, so it could not build even the trivial program. A value set by the caller is
  kept.
- Without `ccomp` on `PATH` it prints that the comparison is skipped and exits 0, so
  `script/dev.sh verify` (which runs it through `opam exec`) skips it as the Clight check skips a
  foreign target.

## Corpus

The driver prints one line per case with every status as `s` plus 8 hex digits and every double as
its 16 hex-digit bit pattern, inputs included, so the sign of zero and any change to the corpus
itself show up in the diff. The corpus (2464 cases, 7454 lines) covers:

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
- the Euler step, checked and unchecked on the same inputs: every argument error, the case that
  tells a fused multiply-add from separate rounding, `h = ±0` with signed-zero components,
  underflow ties, `DBL_MAX + 1`, overflow in the product and in the sum, failures in the first
  and last component (the checked output keeps its sentinels), and non-finite `y`, `f` and `h`,
  where the unchecked step writes the NaN and ±∞ it computes, so their bits are compared too;
- the RK4 stage and step, checked and unchecked on the same inputs: every argument error (each
  NULL pointer, `d = 0`, stages 1, 5 and -2), each stage with exact and inexact `h`, `h = ±0`, the
  coefficient tie at `h = 3·2⁻¹⁰⁷⁴`, `h = DBL_MAX`, the fused multiply-add case, the slope-sum
  order case, overflow in each operation of both functions, cancellation, failures in the first
  and last component, and non-finite values in every position and in `h`, where the unchecked
  functions write the NaN and ±∞ they compute;
- Newton: every `init` argument error, `step` with NaN, signalling NaN and ±∞ in `f` and `f′`, a
  zero or negative-zero `f′`, an exact zero `f` (with a zero or NaN `f′`), corrections that
  underflow, that are a rounding tie, that overflow, and an iterate that overflows; full runs
  printing every step for `√2` with a tolerance, with `tol = 0` (the two-cycle), from `x₀ = 1`,
  the cube root of 10, exact linear roots, the double root of `x²` (digest only, 539 steps), the
  genuine two-cycle of `x³ − 2x + 2` from 0, a flat `f`, a step limit of one, a root at `1e300`,
  an overflowing square and a function without a real root; `result` with each output pointer
  omitted;
- seeded random inputs: 200 arrays per array kernel (for RK4, one stage and one step per draw), 96 bisection runs and 96 Newton runs
  (linear, square and cubic `f` with random coefficient, start and tolerance), half drawn from all of
  binary64 (special values, subnormals, both ends of the exponent range) and half from moderate
  exponents. The generator is splitmix64 on integers and builds each double from its bits, so the
  inputs do not depend on the compiler. A random bisection or Newton run prints its first and
  last state and an FNV-1a digest of every intermediate one.

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
