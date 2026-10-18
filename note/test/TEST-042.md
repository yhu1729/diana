---
id: TEST-042
title: Provenance check unit tests run check_provenance.py on a temporary tree
kind: fact
path:
  - test/python/test_check_provenance.py
  - script/check_provenance.py
related: [TEST-005, VST-009, GATE-009, CI-016]
---
`test/python/test_check_provenance.py` loads `script/check_provenance.py` as a fresh module and
points `ROOT`, `CLIGHT_DIR`, `MANIFEST` and `REPORT` at a temporary tree: a source
`src/kernel.c`, the headers `include/diana/kernel.h`, `include/diana/status.h` and `src/fp.h`, and
an AST `kernel_aarch64_macos.v` whose `Info.source_file` names the source. `listed_file` is a
directory walk there, so the tests need no git; one test, skipped without git, checks that the git
listing drops ignored files and keeps untracked ones.

- The include closure is transitive and sorted, takes an angle-bracket name found in `include/`
  and skips `<stddef.h>`, and fails on a quoted name it cannot resolve.
- After `write_manifest`, a change to the AST, the source or a header fails the manifest check
  with `<AST>: <file> changed since the AST was checked`; so do a new include, an AST missing from
  the manifest, a line for a removed AST, a missing manifest and a malformed line. Writing one
  target keeps another target's lines, which then go stale on their own; an AST whose
  `Info.source_file` does not match its name is rejected.
- A change in any input of the stamp, a directory or one of the two scripts, and a new file in a
  directory fail the stamp with `<input> changed since doc/verification/report.md was generated`;
  another file in `script/` does not. A report without stamp or without theorem row, and a
  `missing`, `check failed`, `planned` or `ok (2/3)` cell, fail the report check.
- A digest, of a directory or of one file, is the SHA-256 of the `sha256sum` listing; the stamp
  lists the inputs in `INPUT` order, and a `|` in a tool version is escaped.
