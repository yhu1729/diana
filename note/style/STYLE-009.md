---
id: STYLE-009
title: ruff checks and formats Python at 100 columns, script/ for Python 3.11
kind: fact
path:
  - pyproject.toml
related: [CI-007, CI-012, STYLE-006]
---
`[tool.ruff]` in `pyproject.toml` sets `line-length = 100`, `target-version = "py312"` (the
package's `requires-python >= 3.12`) and `src = ["python/src", "test/python", "test/doc",
"script"]`, the roots ruff uses to tell first-party imports apart when sorting them.

- `[tool.ruff.per-file-target-version]` sets `"script/**" = "py311"`: `verify_lean` runs
  `script/check_spec.py` with the system `python3` of Debian bookworm, Python 3.11 (CI-012), so
  ruff must not suggest newer syntax there.
- `[tool.ruff.lint] select = ["E", "F", "W", "I", "UP", "B"]`: pycodestyle errors and warnings,
  Pyflakes, import sorting, pyupgrade and flake8-bugbear.
- The formatter takes ruff's defaults (no `[tool.ruff.format]` table) at 100 columns.

Both `ruff check` and `ruff format --check` run over `python`, `test/python`, `test/doc` and
`script`, in `script/dev.sh test` and CI `style_python` (CI-007). The `lint` group asks for
`ruff>=0.6`; `uv.lock` fixes the version both use. The uv environment itself runs the Python of
`.python-version` (3.13).
