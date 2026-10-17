---
id: TEST-006
title: C tests keep every library line and branch covered
kind: rule
path:
  - test/c/test_*.c
  - src/*.c
  - .gitlab-ci.yml
related: [TEST-001, COMPILER-010, CI-002]
---
Each method's `test/c/test_<method>.c` keeps its kernel files and callback wrapper at 100% line and
branch coverage (the convention recorded per method in `CLAUDE.md` and `CHANGELOG.md`). Nothing
fails automatically when coverage drops: CI only reports it.

- `coverage_c` (stage `report`) configures a Debug build with `-DCMAKE_C_FLAGS=--coverage
  -DCMAKE_EXE_LINKER_FLAGS=--coverage -DDIANA_BUILD_PYTHON=OFF`, runs the whole ctest suite, and
  runs `gcovr --root . --filter src/ --filter include/` with a summary, Cobertura XML and HTML
  under `coverage/`. GitLab reads the line percentage from the summary; there is no
  `--fail-under`, so a gap does not fail the job.
- The ctest run includes the `compiler` corpus driver and the `find_package` consumer, which also
  execute library code, so the job's figure can hide a gap in one method's test file. To measure
  one file, run only its test (`ctest -R '^euler$'`) on a fresh coverage build.
- `coverage_python` does the same for the extension: `pytest --cov=diana --cov-branch` and gcovr
  over `python/ext/`, also without a threshold.
- When a change adds a branch to a kernel or wrapper, add the C case that takes it in the same
  method's test file.
