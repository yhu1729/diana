# Local workflow

`script/dev.sh` runs every local step from the repository root; `script/dev.sh help` lists the
commands and the environment variables that steer them.

| Command | What it does |
|---|---|
| `config [cmake option...]` | syncs the uv environment, then configures a Debug build with tests and sanitizers in `build/` |
| `build` | builds the C library and tests, and rebuilds the Python extension |
| `test` | runs ctest and pytest, then `ruff`, the `clang-format` check, `clang-tidy` (skipped when it is not installed) and the documentation check `script/check_doc.py` |
| `verify` | runs the proofs and the compiler comparison, then the spec gate ([local verification](../verification/local.md)) |

A typical change:

```bash
script/dev.sh config     # once, or after changing CMake options
script/dev.sh build
script/dev.sh test
script/dev.sh verify     # after a change to src/, include/, verification/ or spec/
```

`verify` needs the opam switch with Rocq, CompCert, VST and Frama-C (`CONTRIBUTING.md`); it runs
every prover through `opam exec`, in `DIANA_OPAM_SWITCH` when set. Set `DIANA_JOB=1` to run its
stages one at a time with their output on the terminal.

pytest runs against the extension that `uv` builds, a Release build without sanitizers; the
sanitized build in `build/` serves ctest and `clang-tidy`.

## Technical notes

[VERIFY-002](../../note/verify/VERIFY-002.md) verify stages,
[VERIFY-003](../../note/verify/VERIFY-003.md) parallel run,
[VERIFY-004](../../note/verify/VERIFY-004.md) timing,
[STYLE-008](../../note/style/STYLE-008.md) `clang-tidy` in `test`,
[PYTHON-005](../../note/python/PYTHON-005.md) rebuilding the extension.
