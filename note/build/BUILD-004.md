---
id: BUILD-004
title: Wheel layout, static and shared
kind: fact
path:
  - CMakeLists.txt
  - pyproject.toml
  - script/check_wheel.py
related: [BUILD-002, BUILD-005, BUILD-011, PYTHON-006]
---
scikit-build-core (`>= 0.11`) builds the wheel from the root `CMakeLists.txt` and defines
`SKBUILD`, which forces `DIANA_BUILD_PYTHON=ON`. The wheel holds the package directory
`python/src/diana` (`wheel.packages`) and the extension `diana/_diana.<soabi>.so`
(`install(TARGETS _diana DESTINATION diana)`, `Python_add_library(... WITH_SOABI)`).

- Static (default): `libdiana.a` is linked into the extension; the wheel has no library, header,
  archive or CMake file.
- Shared (`DIANA_BUILD_SHARED_LIB=ON`): the wheel also holds `diana/libdiana.dylib` (macOS) or
  `diana/libdiana.so` (Linux) beside the extension, unversioned because `VERSION`/`SOVERSION` are
  set only outside scikit-build; the `ARCHIVE` destination is `EXCLUDE_FROM_ALL`, and headers and
  CMake exports are not installed.
- Only with `SKBUILD` and a shared library: the extension's install RPATH is `@loader_path`
  (macOS) or `$ORIGIN` (Linux) with `INSTALL_RPATH_USE_LINK_PATH OFF`, and the macOS library has
  `MACOSX_RPATH ON` and install name directory `@rpath`. A static wheel sets no RPATH.
- Build type Release (scikit-build-core default); persistent build directory `build/{wheel_tag}`.

`uv run script/check_wheel.py` builds both kinds (`DIANA_WERROR=ON`, `DIANA_SANITIZER=OFF`),
checks that the only `libdiana.*` entry is the expected runtime (none for static) and that no
`.h`, `.a` or `.cmake` file is packaged, installs each into a fresh venv with
`uv pip install --no-deps --no-index`, and imports it with `-I` and every `PYTHONPATH`,
`LD_*` and `DYLD_*` variable removed. CI runs it in `test_python`.
