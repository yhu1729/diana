---
id: COMPILER-005
title: Corpus driver output format and size
kind: fact
path:
  - test/c/test_compiler.c
related: [COMPILER-001, COMPILER-006, COMPILER-007]
---
`test/c/test_compiler.c` prints one line per case with every input and every output as exact bit
patterns, so a difference in any bit, the sign of zero included, and any change to the corpus
itself show up in the comparison.

- A case line starts with `<kernel> <case number> <label>`; the case number counts from 0 across
  the whole run.
- Each double is printed as ` %016llx` of its bit pattern, each status as ` s%08x` of
  `(unsigned)status` (so `DIANA_ERR_ARG` is `sffffffff`), and `iter` and `max_iter` as ` %08x`.
  Arrays are printed as ` [ ... ]`. A case prints the inputs of a call, then its status and
  outputs.
- Output buffers and state structs are filled with sentinels first (42.0, and fixed state
  values, `status` `DIANA_ERR_BRACKET`, which no call writes into it), so a slot or field a kernel
  leaves alone is visible. The state's `status` field is printed after `max_iter`.
- Bisection and Newton runs print the `init` line, then `  step <n>` with the state after each
  step (or only a digest, COMPILER-007), `  again` for one more `step` after
  `DIANA_ERR_MAXITER` (bisection; it returns `DIANA_ERR_ARG` with the state unchanged), and
  `  end <steps> <digest>` with the final status, state and `result` outputs. A loop stops after
  4096 steps at most.
- The last line is `end <case count>`; `script/compare_compiler.sh` treats an output without it
  as truncated. `main` returns non-zero only if flushing stdout fails.
- Current size: 3804 cases in 8794 lines. `tail -n 1` of the output gives the case count, and the
  comparison script prints the line count of the `ccomp` reference.
