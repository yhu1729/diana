# Build

- `cmake/warning.cmake` (`diana_set_strict_flag`) applies the strict warning set and compiler
  settings for IEEE binary64 arithmetic to every Diana target. The verified semantics assume no
  FMA contraction, no fast-math, and SSE2 or AArch64 arithmetic; `src/fp.h` makes the last one a
  compile-time check (`_Static_assert(FLT_EVAL_METHOD == 0)`). Callers must also maintain the
  [runtime floating-point environment](../api/overview.md#floating-point-environment); these
  compiler settings do not select the runtime rounding mode, underflow handling, or trap state.
- `DIANA_BUILD_PYTHON` is ON by default, so a plain `cmake -S . -B build` describes `python/ext/`
  in `compile_commands.json`; without it clang-tidy parses those files with a guessed command, fails
  to find `<Python.h>`, and reports a cascade of findings that are artefacts of the failed parse.
  It needs Python with `Development.Module` (`find_package(... REQUIRED)`), so a build on a machine
  with no Python headers passes `-DDIANA_BUILD_PYTHON=OFF`, as the C-only CI jobs do. The extension
  is installed only under scikit-build; `cmake --install` of the C library never carries it.
- scikit-build-core builds the CPython extension in-tree and sets `SKBUILD`, which forces
  `DIANA_BUILD_PYTHON=ON`. Static wheels carry only the extension module and the Python package.
  With `DIANA_BUILD_SHARED_LIB=ON`, the wheel also carries an unversioned `libdiana` runtime
  beside the extension, without headers, archives, or CMake exports. Standalone CMake
  installations retain the library's `VERSION`/`SOVERSION`. The wheel extension uses an install
  RPATH of `@loader_path` on macOS and `$ORIGIN` on Linux; the macOS library has an `@rpath` install
  name.
- `DIANA_BUILD_SHARED_LIB` selects the library type explicitly (`add_library(diana SHARED|STATIC)`),
  so the generic `BUILD_SHARED_LIBS` of an enclosing project does not change it. Linux and macOS
  are the supported platforms; there is no Windows or MSVC branch.
- `GNUInstallDirs` is loaded before configuring the target's installed include directory, so
  `CMAKE_INSTALL_INCLUDEDIR` controls both header installation and the exported include path.
- `DIANA_WERROR` (`-Werror`) is OFF by default, so building from the sdist with a newer compiler
  that adds a warning does not fail for an end user. CI turns it ON in every job that compiles (CMake
  `-DDIANA_WERROR=ON`, and `SKBUILD_CMAKE_DEFINE` for the uv jobs that build the extension), and so
  does `script/dev.sh` (`config` and the `uv sync` of `config`/`build`).
- `DIANA_SANITIZER` uses directory-wide `add_compile_options`, which only reach targets created
  after the call, so it comes before `add_library(diana)`. The required sanitizer runtime link
  options are public usage requirements of `diana::diana`, including its installed target.
