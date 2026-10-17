# Compiler comparison

The VST proofs are about the C semantics of CompCert, but the shipped library is compiled with
gcc or clang ([trust statement](trust.md#verified-code-versus-shipped-library)).
`script/compare_compiler.sh` checks that the two agree, bit for bit, on a fixed corpus of inputs.

It compiles the library with the driver `test/c/test_compiler.c` once with CompCert's `ccomp`
and once with every gcc and clang it finds at `-O0`, `-O2` and `-O3`, under the project's strict
IEEE flags, runs each build, and fails unless every output is byte-identical to the `ccomp` one.
The driver prints every status and every double as its bit pattern, so even the sign of a zero
counts. The corpus covers every argument error, NaN and infinite inputs, subnormals, overflow in
each operation, the cases that pin the operation order, the longest bisection run and the Newton
two-cycle step by step, and seeded random inputs.

On AArch64 macOS, Apple clang 21, Homebrew GCC 13 to 16 and Homebrew LLVM clang 20 to 23 all match
CompCert. Apple clang and GCC built with FMA contraction or `-ffast-math` do not, so the corpus
detects the deviations the strict flags exclude. This is evidence on a finite corpus, not a proof,
and no x86-64 build has been compared yet.

It needs `ccomp`, so it runs only locally, as a step of `script/dev.sh verify`; run alone, it
skips itself when `ccomp` is missing. Choose the compilers with `DIANA_COMPARE_CC`. ctest also builds and runs
the driver as the `compiler` test, which only checks that it runs.

## Technical notes

[COMPILER-001](../../note/compiler/COMPILER-001.md) builds and flags,
[COMPILER-002](../../note/compiler/COMPILER-002.md) compiler discovery,
[COMPILER-006](../../note/compiler/COMPILER-006.md) corpus coverage,
[COMPILER-008](../../note/compiler/COMPILER-008.md) what a mismatch can detect,
[COMPILER-009](../../note/compiler/COMPILER-009.md) static arrays in the driver,
[COMPILER-011](../../note/compiler/COMPILER-011.md) recorded results.
