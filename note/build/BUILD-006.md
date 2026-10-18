---
id: BUILD-006
title: Version numbers are checked against each other
kind: fact
path:
  - CMakeLists.txt
  - include/diana/diana.h
  - pyproject.toml
  - test/python/test_status.py
  - test/install/main.c
related: [BUILD-009]
---
The version is written in several places, and two checks tie the main ones together.

- Configure: `CMakeLists.txt` reads `include/diana/diana.h` and stops with `FATAL_ERROR` unless
  `DIANA_VERSION_STRING` equals `project(diana VERSION ...)` and each of `DIANA_VERSION_MAJOR`,
  `_MINOR` and `_PATCH` equals the matching `PROJECT_VERSION_*` part.
- pytest: `test_version_consistent` in `test/python/test_status.py` asserts that the CMake project
  version, the header's `DIANA_VERSION_STRING`, `project.version` of `pyproject.toml` and
  `diana.version()` of the built extension are equal.
- Install test: `test/install/main.c` fails unless the linked `diana_version()` equals the
  `DIANA_VERSION_STRING` of the installed header.

Not checked: `version` in `verification/lean/lakefile.toml`, and the `find_package(diana 1.0 ...)`
requests in `test/install/CMakeLists.txt` and the `doc/api/` example, which need to change only
with the major version because the installed package is `SameMajorVersion`-compatible
(BUILD-009).
