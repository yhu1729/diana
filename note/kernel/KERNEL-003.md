---
id: KERNEL-003
title: A kernel variant gets its own source, proofs and spec
kind: rule
path:
  - src/euler_step_unchecked.c
  - src/rk4_stage_unchecked.c
  - src/rk4_step_unchecked.c
  - src/axpy_unchecked.c
  - spec/euler_unchecked.md
  - spec/rk4_unchecked.md
  - spec/axpy_unchecked.md
related: [KERNEL-002, KERNEL-006, GATE-001, VST-005]
---
A variant of a method, such as the `_unchecked` kernels, shares no verification artifact with the
checked kernel: each of its functions is its own source file with its own Frama-C expectation
row, Clight AST and VST file, and the variant has its own Flocq file and its own
`spec/<method>_unchecked.md`, whose IDs are `<METHOD>-UNCHECKED-…`.

- `src/euler_step_unchecked.c`: row `src/euler_step_unchecked.c 19` in
  `verification/frama-c/expectation.txt`, AST `euler_step_unchecked_aarch64_macos.v`,
  `theory/VST/EulerStepUnchecked.v`, `theory/Float/EulerUnchecked.v`, `spec/euler_unchecked.md`
  (EULER-UNCHECKED-B1, C1, C2).
- `src/rk4_stage_unchecked.c` (21 goals) and `src/rk4_step_unchecked.c` (22 goals): ASTs
  `rk4_stage_unchecked_aarch64_macos.v` and `rk4_step_unchecked_aarch64_macos.v`,
  `theory/VST/RK4StageUnchecked.v` and `theory/VST/RK4StepUnchecked.v`, one
  `theory/Float/RK4Unchecked.v`, `spec/rk4_unchecked.md` (RK4-UNCHECKED-B1/B2, C1 to C4).
- `src/axpy_unchecked.c` (19 goals): AST `axpy_unchecked_aarch64_macos.v`,
  `theory/VST/AxpyUnchecked.v`, `theory/Float/AxpyUnchecked.v`, `spec/axpy_unchecked.md`
  (AXPY-UNCHECKED-B1, C1, C2). The checked `VST/Axpy.v` imports its AST, so the unchecked proof
  states its result with `c_euler` of the AST-free `VST/Euler.v`, which `c_axpy_euler` equates
  with `c_axpy` (VST-004).
- The spec names the variant as a method of its own (`method: rk4_unchecked`) and lists its
  sources under `kernel`.

ASTs are under `verification/clight/`, proof files under `verification/rocq/theory/`. The variant
is declared in the method's public header next to the checked kernel. It is opt-in: neither the
callback wrappers nor the Python package call an `_unchecked` kernel. The unchecked kernels make
one pass, write every component as computed, and do not include `src/fp.h`.
