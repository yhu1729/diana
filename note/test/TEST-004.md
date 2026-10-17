---
id: TEST-004
title: script/check_wheel.py builds, inspects and smoke-tests both wheel kinds
kind: fact
path:
  - script/check_wheel.py
  - .gitlab-ci.yml
related: [TEST-001, BUILD-002]
---
`uv run script/check_wheel.py` builds a static and a shared wheel, checks their contents, and
imports each from a fresh virtual environment outside the checkout. CI `test_python` runs it after
`uv build` and `twine check`.

- Each wheel is built with `uv build --wheel` for the running interpreter, in its own directory
  under one temporary directory, with `-C build-dir=<temp>`, `DIANA_WERROR=ON`,
  `DIANA_SANITIZER=OFF` and `DIANA_BUILD_SHARED_LIB` `OFF` (static) then `ON` (shared). Exactly
  one wheel must result.
- Contents: the shared wheel must hold exactly one `libdiana.*` member, `diana/libdiana.dylib` on
  macOS or `diana/libdiana.so` elsewhere; the static wheel none. Neither may contain a `.h`, `.a`
  or `.cmake` file. The build tree is deleted before the install.
- Install: `uv venv` with the same interpreter, then `uv pip install --no-deps --no-index`.
- Smoke test: `python -I -c ...` from the temporary directory with `PYTHONPATH`, `PYTHONHOME`,
  `LD_LIBRARY_PATH`, `LD_PRELOAD` and the `DYLD_*` library, framework and insert variables
  removed. It asserts that `diana` was imported from the new environment (`sys.prefix`) and that
  `diana.bisection` on `x*x - 2` over `[0, 2]` with `tol=1e-12` is within `1e-12` of `sqrt(2)`.
  The installed wheel therefore works without the development environment or build-tree RPATHs.
