---
id: PROVER-007
title: Rocq build targets of verification/rocq/Makefile
kind: fact
path:
  - verification/rocq/Makefile
  - verification/rocq/_CoqProject
related: [PROVER-008, GATE-003, VERIFY-005]
---
`verification/rocq/Makefile` wraps a makefile generated from `_CoqProject` and adds a layer-A
target for CI. Run it inside the opam switch.

- `make` (`all`): regenerates `Makefile.rocq` with `rocq makefile -f _CoqProject` when
  `_CoqProject` is newer, then builds every file listed there: layers A and B, the Clight ASTs
  and the VST proofs, with `-R theory Diana` and `-Q ../clight Diana.Clight`. A `-j N` reaches
  the generated makefile.
- `make check`: builds `all`, then compiles `CheckSpec.v`, which prints the axioms of the listed
  Rocq theorems. `script/check_spec.py` writes that file (git-ignored), so `make check` fails
  until the gate has run once (VERIFY-005); the gate itself calls `make -s check`.
- `make real`: compiles the twelve `theory/Real/*.v` files of layer A with `rocq compile`, one after
  another in a fixed order. CI's `verify_rocq` runs it in an image with only Rocq, its standard
  library and Coquelicot; it bypasses `Makefile.rocq`, which covers all of `_CoqProject`,
  including the Flocq, VST and Clight files that image cannot build. The file list is written by
  hand: a new layer-A file must be added to it, or CI never compiles it.
- `make clean`: removes the build products, `Makefile.rocq` and the `CheckSpec` outputs.
