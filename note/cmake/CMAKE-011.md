---
id: CMAKE-011
title: Source distribution contents
kind: fact
path:
  - pyproject.toml
  - .gitignore
related: [CMAKE-004, PYTHON-006]
---
The sdist excludes `verification/**`, `ci/**` and `build/**` (`sdist.exclude` in
`pyproject.toml`), so the committed `clightgen` output `verification/clight/*.v`, the only files
derived from CompCert, is never distributed.

- `minimum-version = "build-system.requires"` sets the minimum to 0.11, below 0.12, so
  `sdist.inclusion-mode` defaults to `classic`: every file not matched by `.gitignore` or by
  scikit-build-core's built-in list (`.git`, `__pycache__/`, …). The sdist therefore also carries
  `test/`, `doc/`, `note/`, `spec/` and `script/`, and any untracked, unignored file in the
  working tree it is built from.
- `sdist.include` lists what the build needs (`include/**`, `src/**`, `cmake/**`,
  `python/src/**`, `python/ext/**`, `CMakeLists.txt`); it takes precedence over `sdist.exclude`
  and keeps these even if a later ignore rule matched them.
- CI job `test_python` runs `uv build`, which builds the sdist and then the wheel from it, and
  `twine check` on both, so a missing build input fails there.
