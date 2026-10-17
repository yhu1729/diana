---
id: PROVER-005
title: Frama-C is pinned to 32.1 locally to match the CI image
kind: rule
path:
  - .gitlab-ci.yml
  - verification/frama-c/expectation.txt
  - CONTRIBUTING.md
related: [PROVER-002, WP-007]
---
The local Frama-C is 32.1, the version of the CI image `framac/frama-c:32.1` (`FRAMA_C_IMAGE` in
`.gitlab-ci.yml`), so the local WP run and the goal counts in
`verification/frama-c/expectation.txt` are the ones CI checks.

- A new switch pins it at install, `opam pin add -n frama-c 32.1` (PROVER-002); `opam upgrade`
  then leaves it alone, and `opam pin list` shows `frama-c.32.1`.
- An existing switch with a newer Frama-C downgrades in place with `opam pin add frama-c 32.1`;
  check that the plan opam shows changes no other package before accepting it.
- Moving to another version means changing `FRAMA_C_IMAGE` and the pin together and rerunning
  `script/verify_frama_c.sh` to confirm every count.
