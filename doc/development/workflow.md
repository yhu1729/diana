# Local workflow

`script/dev.sh <command>` runs the local steps from the repository root:

- `config [cmake option...]`: `uv sync` with the `test`, `lint`, and `spec` groups, then
  configures `DIANA_BUILD_DIR` (default `build`, separate from scikit-build's `build/<wheel tag>`)
  with tests on, `DIANA_BUILD_TYPE` (default `Debug`), `DIANA_SANITIZER` (default `ON`), and
  `Python_EXECUTABLE` set to `.venv/bin/python`, using Ninja when available.
- `build`: `cmake --build`, then `uv sync --reinstall-package diana`, because uv does not rebuild
  the extension when only C sources change.
- `test`: ctest (including `install`/`find_package`), pytest, ruff, the `clang-format` check of
  `style_c`, and `clang-tidy` when one is found ([format and lint](style.md)).
- `verify`: the steps of [local verification](../verification/local.md), with the Clight step as a
  check, and the [compiler comparison](../verification/compiler.md) after it. Rocq, CompCert, and
  Frama-C run through `opam exec` in `DIANA_OPAM_SWITCH` (default: the current switch), so a
  Homebrew `rocq` on `PATH` is not picked up.
