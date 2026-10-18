---
id: GATE-009
title: The report stamp records input digests and tool versions
kind: fact
path:
  - script/axiom_allow.yaml
  - script/run_frama_c.sh
  - script/check_spec.py
  - script/check_provenance.py
  - doc/verification/report.md
related: [GATE-005, GATE-006, VST-009, WP-003, CI-016, VERIFY-002]
---
When the spec gate rewrites `doc/verification/report.md` (GATE-006), `write_report` puts two
tables from `script/check_provenance.py` between the marker and the theorem table:

- Input digests of `include/`, `script/axiom_allow.yaml`, `script/run_frama_c.sh`, `spec/`,
  `src/` and `verification/` (`INPUT`): the two scripts because they set what an `ok` means, the
  allowed axioms (GATE-005) and the contracts WP may assume (WP-003). Each digest is the SHA-256
  of a `sha256sum` listing (`<hex>  <path>` per line), sorted by path, of the existing files that
  git tracks or would track at or under the input (`git ls-files --cached --others
  --exclude-standard`). Ignored build output (`*.vo`, `.lake/`, WP sessions and caches,
  `CheckSpec.*`) is left out, and so is the report itself. `git ls-files --cached --others --exclude-standard -- src | LC_ALL=C sort |
  xargs shasum -a 256 | shasum -a 256` gives the same value on a tree with no deleted file.
- Tool versions: `platform` (system and machine from Python's `platform`, `Darwin arm64`),
  `lean` (first line of `lake env lean --version` in `verification/lean`), and the installed
  versions of the opam packages `rocq-core`, `coq-flocq`, `coq-coquelicot`, `coq-compcert`,
  `coq-vst`, `frama-c` and `alt-ergo` (`opam list --installed`). A package that is absent reads
  `not installed`, a tool that cannot be run `unknown (...)`. Nothing checks these values.

There is no date, so a run with nothing changed leaves the report byte for byte the same. The
stamp names the inputs the table was generated from, not that the table is green: a failing full
run writes it too, and `script/check_provenance.py` checks the table separately (CI-016).
`script/dev.sh verify` takes the digests after the Clight check and fails if they differ after the
gate, so no input changed while the provers ran (VERIFY-002).
