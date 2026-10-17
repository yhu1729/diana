---
id: PROVER-006
title: CompCert is a research-only local dependency, never shipped or in CI
kind: rule
path:
  - verification/clight/*.v
  - pyproject.toml
  - .gitlab-ci.yml
related: [VST-001, FP-005, COMPILER-001, VERIFY-001]
---
CompCert is under the INRIA Non-Commercial License (research, teaching, personal and evaluation
use only). Diana uses it only in a local opam switch, to generate the Clight ASTs with
`clightgen` and to build the `ccomp` reference of the compiler comparison (COMPILER-001). No CI
job, container image or release artifact contains it, and `ccomp` is never shipped.

- The committed `verification/clight/*.v` files are `clightgen` output, the only files in the
  tree derived from CompCert. `pyproject.toml` excludes `verification/**` from the sdist.
- `.gitlab-ci.yml` and `ci/docker/` install no CompCert, so CI checks neither the ASTs nor the
  VST proofs (VERIFY-001).
- The shipped library is built by gcc or clang; how the CompCert-based proof carries to it is the
  argument of FP-005.
