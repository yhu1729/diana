---
id: PROVER-009
title: Build the Lean project with the Mathlib cache first
kind: procedure
path:
  - verification/lean/lean-toolchain
  - verification/lean/lakefile.toml
  - verification/lean/lake-manifest.json
  - verification/lean/Diana.lean
related: [PROVER-001, GATE-003, GATE-007]
---
The Lean layer-A proofs build with elan and Lake; no opam switch is involved.

1. Install elan; it reads `verification/lean/lean-toolchain` (`leanprover/lean4:v4.35.0`) and
   installs that toolchain on first use.
2. `cd verification/lean && lake exe cache get` fetches prebuilt Mathlib for the commit pinned in
   `lake-manifest.json` (requested as `v4.35.0` in `lakefile.toml`). Without it Lake builds
   Mathlib from source, which is far slower.
3. `lake build` builds the default target `Diana`: `Diana.lean` and the modules it imports,
   `verification/lean/Diana/Real/*.lean`. A new module must be imported from `Diana.lean` to be
   built and to be visible to `CheckSpec.lean` (GATE-003).
4. From the repository root, `uv run script/check_spec.py --run --strict --prover lean --no-report`
   checks the axioms of the listed Lean constants, as CI's `verify_lean` does (GATE-007).

Steps 2 and 3 are the Lean stage of `script/dev.sh verify` and the build of `verify_lean`.
