# Contributing

Diana is a C11 library whose specification is machine-checked, so a change rarely stands alone: a
kernel comes with its test, its ACSL contract, and the proof layers that still have to hold.
This file is the setup and workflow guide. `doc/README.md` indexes the rest: `doc/development/`
explains why each tool is configured the way it is, `doc/api/` describes the API, and
`doc/verification/trust.md` states what is proven and what is merely assumed.

## Quick start

```
ln -s ../../.git-hooks/commit-msg .git/hooks/commit-msg   # once per clone, see Commit
ln -s ../../.git-hooks/pre-push .git/hooks/pre-push       # once per clone, see Commit
script/dev.sh config
script/dev.sh build
script/dev.sh test
```

That covers everything except the proofs, which need the opam switch below. `script/dev.sh help`
lists the commands and the environment variables that steer them (build directory, build type,
sanitizer, opam switch, `clang-tidy` binary).

## Convention

- **Name:** single-form noun and base-form verb, in directory, identifier, CI job, and Python API
  alike: `test/`, `diana_bisection_init`, `diana.bisection`. No plural, no `-ing`/`-s` verb form.
  The `style_name` CI job rejects a plural directory. In prose the project is `Diana`; lowercase
  `diana` is only for identifiers (package, CMake target, library file, URL).
- **Format:** `clang-format` (LLVM style plus the additions in `.clang-format`) for C, `ruff` for
  Python; `.editorconfig` carries the indent rules per file type. Both are checked in CI and by
  `script/dev.sh test`, with the `clang-format` version pinned in the uv `lint` group so local runs
  and CI agree.
- **Comment:** keep in-code comments to a minimum. Rationale belongs in `doc/`, API description in
  `doc/api/`, proof notes in `spec/<method>.md`. ACSL `/*@ ... */` annotations are code, not
  comments, and so are Python docstrings and CPython `tp_doc` strings, which are part of the
  runtime API.
- **Living document:** update `CHANGELOG.md` (`Unreleased`, Keep a Changelog) and, when a change
  alters a fact recorded there, `CLAUDE.md`.
- **Kernel shape:** a verified kernel is a pure state machine on a caller-owned struct
  (`init`/`step`/`result`) or a function over tabulated arrays — no `malloc`, no libm call, no
  function pointer. Callback convenience wrappers live in `src/wrapper/` and are outside the
  VST-verified core.

`CLAUDE.md` records the same conventions in condensed form, together with the toolchain pins.

## Environment

### C

CMake ≥ 3.25 and gcc or clang. For a debug build with ASan/UBSan and warnings as errors, as CI
runs it:

```
cmake -S . -B build -DDIANA_BUILD_TEST=ON -DDIANA_SANITIZER=ON -DDIANA_WERROR=ON
cmake --build build
ctest --test-dir build
```

This also builds the CPython extension, because `DIANA_BUILD_PYTHON` is ON by default; add
`-DDIANA_BUILD_PYTHON=OFF` on a machine without the Python development headers, as the C-only CI
jobs do.

### Python

`uv` manages both the interpreter and the environment. Never use `pip` or the system Python.

```
uv python install
uv sync --group test
uv run pytest
```

The pytest suite is in `test/python/`, beside the C suite in `test/c/`; `test/doc/` checks the
examples in `doc/api/` (add `--group lint` to the sync for the clang-format check of their C code).

### Lean

`elan` installs the pinned toolchain from `verification/lean/lean-toolchain` by itself:

```
cd verification/lean && lake exe cache get && lake build
```

Fetch the Mathlib cache first, as above; building Mathlib from source takes hours.

### Rocq, Flocq, CompCert, VST, and Frama-C (one opam switch)

Use the versions pinned under "Toolchain pin" in `CLAUDE.md`. Install everything in a single solve
in an OCaml 4.14 switch — resolving the packages one at a time lets the solver drop an already
installed package to satisfy the next request, which once removed Frama-C while installing
Alt-Ergo on its own:

```
opam repo add rocq-released https://rocq-prover.org/opam/released
opam install frama-c.33.0 alt-ergo.2.6.4 rocq-prover rocq-core.9.2.0 \
    coq-flocq.4.2.2 coq-coquelicot.3.4.5 coq-compcert.3.18 coq-vst.2.17
why3 config detect
```

Two version traps are worth stating outright. Rocq stays at 9.2 because the CompCert 3.18 opam
package caps `coq < 9.3~`, so a Homebrew `rocq` 9.3 on `PATH` is unused — `script/dev.sh verify`
runs every prover through `opam exec` to keep it out. And Why3 1.8.2 detects Alt-Ergo 2.6.x but
not Homebrew Z3 5.1, which the project therefore does not use.

CompCert is under the INRIA non-commercial license: it is a research-only dependency, lives only
in a local opam switch, and is never shipped or baked into a CI image. `doc/third-party.md` lists
every tool with its version and license.

Build the proofs with `cd verification/rocq && make`. `make check` prints the axioms of the listed
theorems, but it compiles the generated, uncommitted `CheckSpec.v`, so run
`uv run script/check_spec.py --run --prover rocq` — or just `script/dev.sh verify`, which orders
the steps — at least once before it.

## Before you commit

CI checks the C build, ctest, pytest, Frama-C WP, layer A in Lean with its axiom gate, and that
layer A compiles in Rocq. It does **not** check layers B and C-VST, the Rocq axiom gate, or the
Clight AST, because no CI image carries Flocq, CompCert, or VST. A green pipeline says nothing
about those, so they are your responsibility before the commit lands.

- Always: `script/dev.sh test` (ctest including the installed-consumer tests, pytest, ruff,
  `clang-format`, `clang-tidy`).
- After a change to `src/`, `include/`, `verification/`, or `spec/`: `script/dev.sh verify`, and
  commit the report it rewrites, `doc/verification/report.md`. It runs the spec gate with
  `--strict`, so a theorem listed in `spec/` that no prover proves fails it, as does an ACSL
  specification without a valid Frama-C expectation entry. It also checks that the `ccomp` build
  of the kernels prints the same bits as gcc/clang builds on a fixed corpus
  (`script/compare_compiler.sh`). The individual steps are in `doc/verification/local.md`.
- After a change to a verified kernel or a header it includes, the Clight AST has to be
  regenerated, and only on the CompCert target it is named for (`bisection_aarch64_macos.v` is
  AArch64 macOS). `script/dev.sh verify` checks the AST of the current target and fails on a stale
  one; `DIANA_CLIGHT_UPDATE=1` makes it overwrite instead. Nothing in CI notices staleness.
- Adding a method: give it a `spec/<method>.md` with its theorem IDs (`<METHOD>-<layer><n>`, such as
  `BISECTION-A1`, with `_` in the method written as `-`, such as `EULER-UNCHECKED-C1`), layer,
  informal statement, and per-prover constant name. `script/check_spec.py`
  is the gate — every listed constant must exist, use only an allowed axiom, and contain no `sorry`
  or `Admitted`.

## Commit

The `commit-msg` and `pre-push` hooks are tracked in `.git-hooks/` and are not active in a fresh
clone. Link them into `.git/hooks` once per clone:

```
ln -s ../../.git-hooks/commit-msg .git/hooks/commit-msg
ln -s ../../.git-hooks/pre-push .git/hooks/pre-push
```

The links are relative to `.git/hooks`, so they survive moving the checkout. `git config
core.hooksPath .git-hooks` would work too, but it replaces `.git/hooks` wholesale and so disables
any other hook you keep there. Never commit with `--no-verify`.

Commit with `git commit -s`, which adds the `Signed-off-by` line every commit carries.

The subject is `<type>[(scope)]: <summary>`, with the type one of
`feat fix perf refactor build style test ci doc chore` — note `doc`, not `docs`. The
`commit-msg` hook checks that form when you commit. `script/check_commit.sh` checks the history:
the `pre-push` hook runs it on the commits the remote does not have yet, and the `style_git` CI job
on the commits since the previous pipeline of the branch (the merge request's commits in a merge
request pipeline, the whole history when there is no previous pipeline). It rejects:

- a merge commit: rebase onto the target instead, so history stays linear;
- a subject not of the form above, longer than 50 characters, or containing `a`, `an` or `the`;
- any message other than the subject, a blank line and one `Signed-off-by` line naming the
  committer, so no body and no other trailer;
- an author date different from the commit date, which an amended or rebased commit has. Recreate
  such commits fresh after `git reset --soft` (`git read-tree <sha>` then `git commit -s` for each).

Run `script/check_commit.sh` with no argument for the commits not yet on the upstream branch (the
whole history without one), with `HEAD` for the whole history, or with any `git rev-list` range.
The rest is convention:

- Name the thing, not the reason:
  `feat: add bisection header`, not `feat: add the bisection reverse-communication header`.
  Rationale goes in `doc/` or `spec/`, never in the log.
- One logical step per commit, usually a single file. Group files only when they are meaningless
  apart, such as a kernel and the `CMakeLists.txt` line that builds it. A change spanning the
  library, its test, and its documentation is three commits.
- Update `CHANGELOG.md` `Unreleased` for any user-visible change.

## Propose a change

Work on a branch off `main` and open a merge request on
[GitLab](https://gitlab.com/yhu1729/diana). Merge-request pipelines keep the path filters, so a
job runs only when a file it depends on changes; when you add a job, or a file an existing job
reads, extend the matching `.change_*` list at the top of `.gitlab-ci.yml`. Report a bug or
discuss a method before implementing it at
[Issues](https://gitlab.com/yhu1729/diana/-/issues).
