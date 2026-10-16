# CI

`.gitlab-ci.yml` has six stages: style (format, naming, spec structure), build (per compiler and
configuration), test (ctest and pytest against the build artifacts), report (code coverage), verify
(Frama-C, Lean, Rocq), and release (the tag release once everything is green). Jobs run as a DAG
through `needs:`, and every job is interruptible so superseded pipelines stop.

## Path filter

Jobs normally run only when a file they depend on changes (`rules: changes:` against the hidden
`.change_*` path lists at the top of the file); a change to `.gitlab-ci.yml` runs everything.
Both coverage jobs also run on every default-branch pipeline, including changes only to `doc/`
or top-level Markdown files, so the README badges have values in the latest successful pipeline.
Merge-request pipelines retain the path filters. Tag and scheduled pipelines (`.rule_full`)
always run every job, so a release is gated on a full run. Because a job can be absent from a
pipeline, `needs:` on a job from another path set is `optional: true`. When adding a job or a file
a job reads, extend the matching list.

## Style

- `style_c` checks the C sources (`include/`, `src/`, `test/c/`, `test/install/`, `python/ext/`) with the pinned
  `clang-format --dry-run --Werror`. It installs only the `lint` group (`uv sync --only-group`), so
  it builds nothing and skips the compiler install of `.uv`.
- `style_git` runs `script/check_commit.sh` on the commits since the previous pipeline of the
  branch, `CI_COMMIT_BEFORE_SHA..CI_COMMIT_SHA`. GitLab sets `CI_COMMIT_BEFORE_SHA` to zeros in
  merge request, scheduled, manual and tag pipelines and on a branch's first push, so a merge
  request pipeline checks the merge request's commits (`CI_MERGE_REQUEST_DIFF_BASE_SHA..`, up to
  `CI_MERGE_REQUEST_SOURCE_BRANCH_SHA` in a merged-results pipeline, whose own head is a merge
  commit), and the others check the whole history, as does a force push whose previous head is no
  longer in the clone. It has no path filter, because a commit needs checking whatever it touches,
  and `GIT_DEPTH: "0"`, so that every base commit is present.
- `style_name` enforces single-form noun directory names by rejecting plural directories. It runs
  on any selected path and scans the whole tree, so a plural directory added in a doc-only push is
  caught by the next pipeline that runs it.
- `style_python` runs the structural spec gate (`--no-report`). It does not regenerate the report:
  without `--run` every prover status would read `planned`, and no CI job runs both Lean and Rocq,
  so the report is regenerated locally with `--run` and committed (see
  [local verification](../verification/local.md)).

## Test

- `test_install` runs the C suite and the installed consumer twice: once with
  `CMAKE_INSTALL_INCLUDEDIR=include/custom`, once with `BUILD_SHARED_LIBS=ON`, so the exported
  include path and the versioned shared install are both covered. The release job requires it.
- `test_python` runs the Python suite and package metadata checks, then `script/check_wheel.py`
  to check both static and shared installed wheels.

## Report

- `coverage_c` rebuilds the C library and ctest suite with `--coverage` (Debug, no sanitizer) and
  reports `src/` and `include/` with gcovr; the job's coverage value is the line rate.
- `coverage_python` rebuilds the extension with `--coverage` (`SKBUILD_CMAKE_DEFINE`), runs pytest
  under pytest-cov for the Python package, and reports the extension source `python/ext/` with
  gcovr. The job's coverage value is the Python line rate; both Cobertura files feed the merge
  request diff annotation.

## Verify

- `verify_frama_c`: 162/162 goals are proved locally with Frama-C 33.0 and Alt-Ergo 2.6.4; the CI
  image is 32.1 until a 33 tag exists. If 32.1 behaves differently, pin the image forward rather
  than re-adding `allow_failure`.
- `verify_lean` runs `script/check_spec.py --run --strict --prover lean --no-report` with the
  image's system `python3` (3.11 on Debian bookworm), not with `uv`, so ruff checks `script/`
  against Python 3.11 (`per-file-target-version` in `pyproject.toml`). The script exits non-zero
  when the Lean check fails to run, a listed Lean theorem is missing, or a theorem depends on an
  axiom outside `script/axiom_allow.yaml`. Selecting `--prover lean` excludes Rocq-only layers
  and Frama-C coverage from this gate. The job uses `LEAN_IMAGE`, a stock Debian image until the
  project image (`ci/docker/lean.Dockerfile`) is in the registry.
- `verify_rocq` compiles layer A on the stock MathComp image (`mathcomp/mathcomp:2.6.0-rocq-prover-9.2`,
  Rocq 9.2 with MathComp 2.6.0) after `opam install coq-coquelicot.$COQUELICOT_VERSION`, so layer A
  may use Coquelicot integrals and derivatives. The image already carries Coquelicot's only
  dependency, MathComp ssreflect, so the job compiles Coquelicot alone; on the stock
  `rocq/rocq-prover` image the same install would also build elpi, Hierarchy Builder and MathComp.
  The image predates Coquelicot 3.4.5, hence the `opam update` of `rocq-released` first. It does not
  run the Rocq axiom gate: `make check` imports every layer.
- No CI job installs Flocq, CompCert, or VST, so every CI image is public and stock. Layers B and
  C-VST, the Rocq axiom gate, and the Clight AST are checked only locally.

## Release

- `release` is the last job of a tag pipeline, gated on every test and verification job.

## Container image

- `ci/docker/lean.Dockerfile`: the pinned Lean toolchain with the Mathlib cache pre-fetched, so CI
  jobs do not download several GB per run. Rebuild when `verification/lean/lean-toolchain` or
  `lake-manifest.json` changes.
