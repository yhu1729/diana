---
id: PYTHON-006
title: Extension sources live outside the package directory
kind: rationale
path:
  - python/ext/*.c
  - pyproject.toml
related: [PYTHON-001, PYTHON-002, CMAKE-004, CMAKE-011]
---
The C sources of the extension are in `python/ext/`, beside rather than inside the package
directory `python/src/diana/`, so the wheel does not carry them: `wheel.packages =
["python/src/diana"]` in `pyproject.toml` copies that directory as the package, and the wheel
adds only the compiled `_diana` module (and, for a shared build, the library, CMAKE-004).

The sdist still needs them to build, so `sdist.include` lists `python/ext/**` with `include/**`,
`src/**`, `cmake/**`, `python/src/**` and `CMakeLists.txt` (CMAKE-011). `pyproject.toml` sits at
the repository root for the same reason: the sdist must contain the C library and the root
`CMakeLists.txt` that builds both.
