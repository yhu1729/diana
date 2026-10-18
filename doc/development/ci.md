# CI

GitLab CI (`.gitlab-ci.yml`) runs on merge requests, on the default branch, on release tags
`vX.Y.Z` and on schedules; a branch push without a merge request runs nothing. Jobs run in Linux
containers on x86-64 shared runners, as a graph of dependencies rather than strictly stage by
stage, and every job is interruptible, so a newer pipeline can cancel an older one.

| Stage | Jobs | What they check |
|---|---|---|
| style | `style_c`, `style_python`, `style_name`, `style_git` | C formatting; `ruff`, the spec structure and the documentation check; directory names; commit messages |
| build | `build_{gcc,clang}_{debug,release}` | the C library and tests with gcc 14 and clang 18, Debug with sanitizers and Release, warnings as errors |
| test | `test_{gcc,clang}_{debug,release}`, `test_install`, `test_python` | ctest on each build; the installed CMake package; pytest, the documentation examples and the wheels |
| report | `coverage_c`, `coverage_python` | coverage of the C library and of the Python package and extension (the README badges) |
| verify | `verify_frama_c`, `verify_lean`, `verify_rocq`, `verify_provenance` | Frama-C WP on every source; layer A in Lean with its axiom gate; layer A compiles in Rocq; the committed Clight AST manifest and report match the sources |
| release | `release` | a GitLab release for a tag, once the test and verify jobs pass |

## What CI does not check

- Layers B and C-VST, the Rocq axiom gate, the Clight ASTs and the compiler comparison: no CI
  image carries Flocq, CompCert or VST. Run [local verification](../verification/local.md).
  `verify_provenance` only checks, from hashes, that its committed output is current.
- macOS: the macOS-only build paths run only on developer machines.
- `clang-tidy` and EditorConfig: local only.

## Path filters

A job runs only when a file it depends on changes; the lists of paths are the `.change_*` anchors
at the top of `.gitlab-ci.yml`. Tag and scheduled pipelines run every job. When you add a job, or
a file an existing job reads, extend the matching list.

## Technical notes

[CI-001](../../note/ci/CI-001.md) stages and graph,
[CI-002](../../note/ci/CI-002.md) path filters,
[CI-003](../../note/ci/CI-003.md) platform,
[CI-005](../../note/ci/CI-005.md) commit range of `style_git`,
[CI-006](../../note/ci/CI-006.md) `style_name`,
[CI-012](../../note/ci/CI-012.md) `verify_lean` and its image,
[CI-014](../../note/ci/CI-014.md) what gates a release,
[CI-015](../../note/ci/CI-015.md) the Lean container image,
[CI-016](../../note/ci/CI-016.md) `verify_provenance`.
