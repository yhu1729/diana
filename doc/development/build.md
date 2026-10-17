# Build

Diana builds with CMake ≥ 3.25 and gcc or clang, on Linux and macOS; there is no Windows support.
The Python package is built by `uv` through scikit-build-core from the same `CMakeLists.txt`.

## C library

```bash
cmake -S . -B build -DDIANA_BUILD_TEST=ON
cmake --build build
ctest --test-dir build
cmake --install build --prefix <prefix>
```

| Option | Default | Effect |
|---|---|---|
| `DIANA_BUILD_TEST` | OFF | build the C tests and register them with ctest |
| `DIANA_BUILD_PYTHON` | ON | also build the CPython extension; needs the Python development headers, so turn it off on a machine without them |
| `DIANA_BUILD_SHARED_LIB` | OFF | build a shared instead of a static library (the generic `BUILD_SHARED_LIBS` is ignored) |
| `DIANA_WERROR` | OFF | treat warnings as errors; CI and `script/dev.sh` turn it on |
| `DIANA_SANITIZER` | OFF | build with AddressSanitizer and UndefinedBehaviorSanitizer |

Every target is compiled with a strict warning set and the settings that keep the arithmetic
strict IEEE binary64: no fused multiply-add contraction and no fast-math. Configuration fails if
`CMAKE_C_FLAGS` asks for `-Ofast`, `-ffast-math` or `-funsafe-math-optimizations`, and the build
fails on a compiler that would evaluate `double` in a wider format. These settings do not set the
runtime [floating-point environment](../api/overview.md#floating-point-environment), which stays
the caller's responsibility.

The installed package exports `diana::diana` for `find_package(diana)`
([API overview](../api/overview.md#headers-and-linking)).

## Python package

```bash
uv sync
uv run python -c "import diana; print(diana.version())"
```

`uv sync` builds the extension in Release mode. It does not notice a change to the C sources by
itself: `uv sync --reinstall-package diana` (or `script/dev.sh build`) rebuilds it. A wheel
contains only the extension and the Python package; with `DIANA_BUILD_SHARED_LIB=ON` it also
carries the shared library next to the extension. `uv run script/check_wheel.py` builds and
installs both kinds of wheel and imports them from a clean environment.

## Technical notes

[BUILD-001](../../note/build/BUILD-001.md) warning flags,
[BUILD-002](../../note/build/BUILD-002.md) CMake options,
[BUILD-003](../../note/build/BUILD-003.md) why the extension is on by default,
[BUILD-004](../../note/build/BUILD-004.md) wheel layout,
[BUILD-006](../../note/build/BUILD-006.md) version check,
[BUILD-008](../../note/build/BUILD-008.md) sanitizer,
[BUILD-011](../../note/build/BUILD-011.md) source distribution,
[FP-004](../../note/fp/FP-004.md) strict IEEE flags.
