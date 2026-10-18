---
id: PROVER-001
title: Prover toolchain versions and where each is pinned
kind: fact
path:
  - CLAUDE.md
  - verification/lean/lean-toolchain
  - verification/lean/lakefile.toml
  - verification/lean/lake-manifest.json
  - .gitlab-ci.yml
related: [PROVER-002, PROVER-003, PROVER-005]
---
The project pins are the "Toolchain pin" table of `CLAUDE.md`. Lean comes from elan; everything
else lives in one opam switch on OCaml 4.14 (locally the switch `4.14.1`), which holds:

| Tool | Version | Pinned by |
|---|---|---|
| Lean 4 | `leanprover/lean4:v4.35.0` | `verification/lean/lean-toolchain` |
| Mathlib | `v4.35.0` | `lakefile.toml` (`rev`), `lake-manifest.json` (commit) |
| Rocq | 9.2.0 (`rocq-core`) | install command; CI image `mathcomp/mathcomp:2.6.0-rocq-prover-9.2` |
| Flocq | 4.2.2 | install command; `FLOCQ_VERSION` in `.gitlab-ci.yml` |
| Coquelicot | 3.4.5 | install command; `COQUELICOT_VERSION` in `.gitlab-ci.yml` |
| CompCert | 3.18 (`clightgen` and the AST `Info.version` say 3.17) | install command |
| VST | 2.17 | install command |
| Frama-C | 32.1 | `opam pin`; CI image `framac/frama-c:32.1` |
| Alt-Ergo | 2.6.4 | install command |
| Why3 | 1.8.2 | not pinned; installed as a Frama-C dependency |

The install command is PROVER-002. Rocq is held below 9.3 by CompCert (PROVER-003) and Frama-C at
the CI version (PROVER-005).
