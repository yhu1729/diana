---
id: VERIFY-001
title: Checks that run only locally, before committing proof-relevant changes
kind: rule
path:
  - script/dev.sh
  - .gitlab-ci.yml
  - CONTRIBUTING.md
related: [VERIFY-002, CI-002, PROVER-006, WP-003]
---
Before committing a change to `src/`, `include/`, `verification/` or `spec/`, run
`script/dev.sh verify` and commit the `doc/verification/report.md` it rewrites. No CI image has
Flocq, CompCert or VST, so CI cannot catch what only this run checks:

| Check | CI job | Local, in `script/dev.sh verify` |
|---|---|---|
| Layer A in Lean, with axiom gate | `verify_lean` | Lean build and spec gate |
| Layer A in Rocq | `verify_rocq`: `make real`, compilation only | `make`, axiom gate |
| Layers B (Flocq) and C-VST, Rocq axiom gate | none | `make`, then `make -s check` in the gate |
| Clight AST matches the source | none | Clight check (VST-003) |
| `ccomp` and gcc/clang print the same bits | none | `script/compare_compiler.sh` |
| Frama-C WP and goal counts | `verify_frama_c` | the same `script/verify_frama_c.sh` |
| Report regeneration | none | spec gate `--run --strict` |

The ctest `compiler` test in CI only runs the comparison driver; it compares nothing with `ccomp`
(COMPILER-001). A green pipeline therefore says nothing about layers B and C-VST or the ASTs,
and its WP result assumes the `diana_bisection_mid` contract that only the local Flocq build
discharges (WP-003). CI jobs also run only when their path filters match (CI-002).
