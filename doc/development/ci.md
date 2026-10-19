# CI

GitLab CI (`.gitlab-ci.yml`) runs on merge requests, on the default branch, on release tags
`vX.Y.Z` and on schedules; a branch push without a merge request runs nothing. Jobs run in Linux
containers on x86-64 shared runners, as a graph of dependencies rather than strictly stage by
stage, and every job is interruptible, so a newer pipeline can cancel an older one. The GitHub
mirror runs the same jobs again, plus macOS and more Python versions ([GitHub
Actions](#github-actions)).

| Stage | Jobs | What they check |
|---|---|---|
| style | `style_c`, `style_python`, `style_name`, `style_git` | C formatting; `ruff`, the spec structure and the documentation check; directory names; commit messages |
| build | `build_{gcc,clang}_{debug,release}` | the C library and tests with gcc 14 and clang 18, Debug with sanitizers and Release, warnings as errors |
| test | `test_{gcc,clang}_{debug,release}`, `test_install`, `test_python` | ctest on each build; the installed CMake package; pytest, the documentation examples and the wheels |
| report | `coverage_c`, `coverage_python` | coverage of the C library and of the Python package and extension (the README badges) |
| verify | `verify_frama_c`, `verify_lean`, `verify_rocq`, `verify_provenance` | Frama-C WP on every source; layer A in Lean and layers A and B in Rocq, each with its axiom gate; the committed Clight AST manifest and report match the sources |
| release | `release` | a GitLab release for a tag, once the test and verify jobs pass |

## What CI does not check

- Layer C-VST with its Rocq axiom gate, the Clight ASTs and the compiler comparison: no CI image
  carries CompCert or VST. Run [local verification](../verification/local.md).
  `verify_provenance` only checks, from hashes, that its committed output is current.
- macOS: GitLab never runs the macOS-only build paths; the GitHub mirror does (below).
- `clang-tidy` and EditorConfig: local only.

## Path filters

A job runs only when a file it depends on changes; the lists of paths are the `.change_*` anchors
at the top of `.gitlab-ci.yml`. Tag and scheduled pipelines run every job. When you add a job, or
a file an existing job reads, extend the matching list, and the `paths:` of the GitHub workflow
that mirrors it.

## GitHub Actions

The GitHub repository is a push mirror of the GitLab project, and `.github/workflows/` runs a
second pipeline over the same commits. GitLab stays the primary pipeline and the only one that
makes a release. `ci.yml` holds every GitLab job but `release`, with the same job
names, images, commands and `needs`: the C builds wait for `style_c`, `test_install` and
`verify_frama_c` for `test_gcc_release`, and each coverage job for its tests. Its first job,
`change`, reads the `.change_*` lists of `.gitlab-ci.yml` with `script/ci_change.py`, so a job runs
for the same changed files as on GitLab and the path lists exist once. On a branch the changed
files are those since the merge base with the default branch, as for a merge request, and on the
default branch those of each push, whose runs are never cancelled; `style_git` checks the commits
of the same ranges. A newer push to a branch cancels the run it supersedes, and the merge base
keeps that run's changes in the next one.

It closes two gaps GitLab leaves: macOS jobs (`test_macos_{debug,release}`, `test_install_macos`,
`test_python_macos`) build and test on AArch64 macOS with Apple clang, and `test_python` runs every
Python version `requires-python` admits instead of only `.python-version`. Unlike GitLab, it runs
on every branch push, since a mirrored branch has no merge request; a version tag or a manual run
(`workflow_dispatch`) runs every job. Actions are pinned to commit SHAs and images to digests;
coverage reports and the Frama-C report are run artifacts, and there are no badges. To save run
time it caches the uv downloads, elan, Mathlib and the Lean build, and the WP verdicts, each under
a key of its own inputs.

## Technical notes

[CI-001](../../note/ci/CI-001.md) stages and graph,
[CI-002](../../note/ci/CI-002.md) path filters,
[CI-003](../../note/ci/CI-003.md) platform,
[CI-005](../../note/ci/CI-005.md) commit range of `style_git`,
[CI-006](../../note/ci/CI-006.md) `style_name`,
[CI-012](../../note/ci/CI-012.md) `verify_lean` and its image,
[CI-013](../../note/ci/CI-013.md) `verify_rocq`,
[CI-014](../../note/ci/CI-014.md) what gates a release,
[CI-015](../../note/ci/CI-015.md) the Lean container image,
[CI-016](../../note/ci/CI-016.md) `verify_provenance`,
[CI-017](../../note/ci/CI-017.md) the GitHub workflow and its `needs`,
[CI-018](../../note/ci/CI-018.md) the `change` job,
[CI-019](../../note/ci/CI-019.md) their commit range,
[CI-021](../../note/ci/CI-021.md) Frama-C and Rocq under `docker run`,
[CI-023](../../note/ci/CI-023.md) the macOS jobs,
[CI-024](../../note/ci/CI-024.md) the Python versions,
[CI-025](../../note/ci/CI-025.md) updating the pins,
[CI-026](../../note/ci/CI-026.md) the caches.
