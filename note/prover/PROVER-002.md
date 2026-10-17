---
id: PROVER-002
title: Install the prover opam switch in a single solve
kind: procedure
path:
  - CONTRIBUTING.md
related: [PROVER-001, PROVER-004, PROVER-005]
---
Install Frama-C, Alt-Ergo, Rocq, Flocq, Coquelicot, CompCert and VST with one `opam install`, in
an OCaml 4.14 switch. Resolving the packages one at a time lets the solver remove an installed
package to satisfy the next request; installing Alt-Ergo alone once removed Frama-C.

1. `opam repo add rocq-released https://rocq-prover.org/opam/released`
2. In one solve:

   ```sh
   opam install frama-c.32.1 alt-ergo.2.6.4 rocq-prover rocq-core.9.2.0 \
       coq-flocq.4.2.2 coq-coquelicot.3.4.5 coq-compcert.3.18 coq-vst.2.17
   ```

3. `opam pin add -n frama-c 32.1`, so `opam upgrade` keeps the CI version (PROVER-005).
4. `why3 config detect`, which configures Alt-Ergo for WP (PROVER-004).
5. Check with `opam list --installed` that the versions match PROVER-001.

`script/dev.sh verify` then runs the opam tools through `opam exec` in `DIANA_OPAM_SWITCH`, or in
the current switch when that is unset (PROVER-003).
