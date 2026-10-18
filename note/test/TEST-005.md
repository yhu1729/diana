---
id: TEST-005
title: Spec gate unit tests run check_spec.py with mocked provers
kind: fact
path:
  - test/python/test_check_spec.py
  - script/check_spec.py
related: [GATE-001, GATE-006, WP-007, TEST-042]
---
`test/python/test_check_spec.py` tests `script/check_spec.py` on temporary spec and Frama-C
expectation files with the prover runs mocked, so pytest checks the gate's logic without Lean,
Rocq or Frama-C. PyYAML, which the gate needs for the front matter, is in the uv `test` group.

- The fixture loads the script as a fresh module, with `script/` on `sys.path` for its import of
  `check_provenance`, and points `ROOT`, `SPEC_DIR`,
  `FRAMA_C_EXPECTATION` and `ALLOW_FILE` into `tmp_path`. `write_check_file` and `write_report`
  are mocks; `run_prover` is a mock that marks every listed prover constant `ok`. The default spec
  is `bisection` with one ACSL theorem `BISECTION-C1` on `kernel.c`.
- `--run --strict` passes when the expectation file has a positive goal count for the theorem's
  `acsl` file (other rows may be invalid) and then rewrites the report. A run without `--run`,
  with `--prover rocq`, or with `--run --prover lean` leaves the report alone.
- Strict mode fails with `<ID> [frama-c]: missing expectation for <file>` when the file or row is
  absent, and `invalid expectation` for a row without a count, a non-integer, an extra field, a
  duplicate row, zero or a negative count. Every `acsl` file is checked; two specs may share one
  file's row.
- A run with neither `--run` nor `--strict` calls no prover and ignores the expectation file; an
  explicit `--prover` skips the Frama-C coverage check.
- Two theorems naming one constant both receive its result (`check failed` when `lake` is
  missing). The ID prefix must be the method in capitals with `_` written `-`
  (`OTHER-UNCHECKED-C1` for `other_unchecked`), and `kernel` may be a list whose files must exist.
- The real `write_report`, with the stamp mocked, keeps the head and writes the stamp between the
  marker and the table (GATE-009; the stamp itself is TEST-042).
