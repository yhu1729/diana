---
id: CMAKE-007
title: DIANA_WERROR is OFF by default and ON in CI and dev.sh
kind: rationale
path:
  - CMakeLists.txt
  - cmake/warning.cmake
  - script/dev.sh
  - script/check_wheel.py
  - .gitlab-ci.yml
related: [CMAKE-001, CMAKE-002]
---
`-Werror` is the option `DIANA_WERROR`, OFF by default, so that an end user who builds from the
sdist with a newer compiler that adds a warning still gets a library. Every build the project
controls turns it ON, so a warning still fails development and CI:

- CI: every job that runs CMake passes `-DDIANA_WERROR=ON`; the uv jobs (template `.uv`) set
  `SKBUILD_CMAKE_DEFINE: DIANA_WERROR=ON`, and `coverage_python` keeps it in its own
  `SKBUILD_CMAKE_DEFINE`.
- `script/dev.sh config` passes `-DDIANA_WERROR=ON`, and its `uv sync` (in `config` and `build`)
  prepends `DIANA_WERROR=ON` to `SKBUILD_CMAKE_DEFINE`.
- `script/check_wheel.py` builds both wheels with `cmake.define.DIANA_WERROR=ON`.

A plain `uv sync` or `cmake` outside these paths builds without `-Werror`; use `script/dev.sh` or
pass the option to see warnings fail locally as they would in CI.
