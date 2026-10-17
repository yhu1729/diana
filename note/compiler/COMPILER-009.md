---
id: COMPILER-009
title: Keep the corpus driver's arrays static (CompCert AArch64 main-frame bug)
kind: rule
path:
  - test/c/test_compiler.c
related: [COMPILER-001, COMPILER-005]
---
Arrays in `test/c/test_compiler.c` are `static` (the input tables, the output buffers, the
1001-sample arrays and the random-input buffers), and a new test function must keep its arrays
`static` too. The only automatic array is the three-element `v` of the random bisection loop.

- Reason, as recorded: CompCert 3.17 on AArch64 macOS allocates a `main` frame larger than about
  500 bytes with `sub sp, sp, #(n - 8)` and stores the frame link at `[sp]` before the final
  `sub sp, sp, #8`, so the store uses a stack pointer that is not 16-byte aligned and the program
  dies with `SIGBUS` before its first statement.
- CompCert inlines a function called once, so the locals of `test_bisection`, `test_euler` and
  the other `test_*` functions that `main` calls move into `main`'s frame. Functions called many
  times (the `*_case` and `*_run` helpers) are not inlined, so their automatic state structs do
  not count; their output buffers are `static` all the same.
- Breaking the rule shows up only in the `ccomp` build, which runs only locally (COMPILER-004);
  gcc and clang builds of the driver are unaffected.
