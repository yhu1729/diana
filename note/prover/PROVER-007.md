---
id: PROVER-007
title: Rocq build targets of verification/rocq/Makefile
kind: fact
path:
  - verification/rocq/Makefile
  - verification/rocq/_CoqProject
related: [PROVER-008, GATE-003, GATE-004, VERIFY-005, CI-013]
---
`verification/rocq/Makefile` wraps a makefile generated from `_CoqProject` and adds targets that
stop below layer C. Run it inside the opam switch.

- `make` (`all`): regenerates `Makefile.rocq` with `rocq makefile -f _CoqProject` when
  `_CoqProject` is newer, then builds every file listed there: layers A and B, the Clight ASTs
  and the VST proofs, with `-R theory Diana` and `-Q ../clight Diana.Clight`. A `-j N` reaches
  the generated makefile.
- `make real` builds the `theory/Real/*.v` files of layer A; `make float` builds those and the
  `theory/Float/*.v` files of layer B. Both take the files of their directories from
  `_CoqProject`, so a file not listed there is never built, and build them through
  `Makefile.rocq`, which orders them by their imports and takes `-j N`. Neither needs CompCert
  or VST: `rocq dep` still reads the VST proofs and Clight ASTs listed in `_CoqProject`, but only
  warns (`module-not-found`) about the libraries it cannot find. CI's `verify_rocq` runs
  `make float` in an image with Rocq, its standard library, Coquelicot and Flocq (CI-013).
- `make check`: builds `all`, then compiles `CheckSpec.v`, which prints the axioms of the listed
  Rocq theorems. `make check_real` and `make check_float` compile it after `real` or `float`
  instead, and fail if it imports a module of a layer they do not build. `script/check_spec.py`
  writes that file (git-ignored) and runs the target of the highest layer it checks (GATE-004),
  so these targets fail until the gate has run once (VERIFY-005).
- `make clean`: removes the build products, `Makefile.rocq` and the `CheckSpec` outputs.
