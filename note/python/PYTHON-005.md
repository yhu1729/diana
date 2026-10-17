---
id: PYTHON-005
title: Rebuild the Python extension after a C change
kind: procedure
path:
  - pyproject.toml
  - script/dev.sh
related: [PYTHON-006, BUILD-003, BUILD-004]
---
`uv sync` installs the package in editable mode through scikit-build-core: the modules of
`python/src/diana/` are loaded from the source tree, so a Python edit takes effect at once, but
the compiled `_diana` lives in `.venv` and `uv sync` does not notice a change to `src/`,
`include/` or `python/ext/`. After such a change:

1. `uv sync --reinstall-package diana`, adding the dependency groups in use
   (`--group test --group lint`), or `script/dev.sh build`, which builds the CMake tree and then
   runs that `uv sync` with `SKBUILD_CMAKE_DEFINE=DIANA_WERROR=ON`.
2. `uv run pytest`, or `script/dev.sh test` (it runs `uv run --no-sync pytest`).

The installed extension is a Release build (scikit-build-core's default build type) without
sanitizers, in the persistent build directory `build/{wheel_tag}` (`pyproject.toml`); the
sanitized Debug `_diana` in the CMake `build/` tree is not what pytest imports (BUILD-003).

Use `uv` for every Python step; never `pip` and never the system interpreter (`uv` installs the
version in `.python-version`).
