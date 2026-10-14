# Contributing

## Convention

Read `CLAUDE.md` first: naming (single-form noun, base-form verb), signed-off Conventional Commits,
no skipped hook, living `CHANGELOG.md`.

## Environment

`script/dev.sh config`, `build`, `test`, and `verify` run the local configure, build, test, and
verification steps (`script/dev.sh help`, details in `doc/development.md`). The sections below
set up the tools they need.

### C

CMake ≥ 3.25 and gcc or clang. `cmake -S . -B build -DDIANA_BUILD_TEST=ON -DDIANA_SANITIZER=ON
-DDIANA_WERROR=ON` for a debug build with ASan/UBSan and warnings as errors, as in CI. That also
builds the CPython extension (`DIANA_BUILD_PYTHON`, ON by default); add `-DDIANA_BUILD_PYTHON=OFF`
when no Python development headers are available.

### Python

```
uv python install
uv sync --group test
uv run pytest
```

The pytest suite lives in `test/python/`, next to the C suite in `test/c/`.

### Lean

`elan` installs the pinned toolchain from `verification/lean/lean-toolchain` automatically.
`cd verification/lean && lake exe cache get && lake build`.

### Rocq and Frama-C (one opam switch)

Package versions are the pins in `CLAUDE.md` (Toolchain pin). In an OCaml 4.14 switch, install
everything in one solve so the dependency solver cannot drop a package (installing Alt-Ergo alone
removed Frama-C once):

```
opam repo add rocq-released https://rocq-prover.org/opam/released
opam install frama-c.33.0 alt-ergo.2.6.4 rocq-prover rocq-core.9.2.0 \
    coq-flocq.4.2.2 coq-coquelicot.3.4.5 coq-compcert.3.18 coq-vst.2.17
why3 config detect
```

Why3 1.8.2 recognizes Alt-Ergo 2.6.x; Homebrew Z3 5.1 is not recognized and is unused. The
Homebrew `rocq` 9.3 is not used by this project either (CompCert 3.18 caps at Rocq < 9.3).
Build the proofs with `cd verification/rocq && make`; `make check` prints the axioms of the listed
theorems. `make check` compiles the generated, uncommitted `CheckSpec.v`, so run
`uv run script/check_spec.py --run --prover rocq` (or `script/dev.sh verify`) once before it.

CI checks only layer A of the proofs (Lean fully, Rocq compilation) and Frama-C. Layers B and
C-VST, the Rocq axiom gate, and the Clight AST are your responsibility: before committing a change
to `src/`, `include/`, `verification/`, or `spec/`, run the steps under "Local verification" in
`doc/development.md` and commit the regenerated report.

## Commit

The `commit-msg` hook is not active in a fresh clone; link the tracked hook into `.git/hooks` once
per clone:

```
ln -s ../../.git-hooks/commit-msg .git/hooks/commit-msg
```

```
git commit -s
```

Subject: `<type>[(scope)]: <summary>` with type in `feat fix perf refactor build style test ci doc chore`.
The subject line is the whole message: no body, and no trailer beyond the `Signed-off-by` that `-s`
adds. Keep it near 50 characters and drop articles — `feat: add bisect header`, not `feat: add the
bisection reverse-communication header`. Rationale belongs in `doc/` or `spec/`, not in the log.

Commit one logical step at a time, usually a single file; group files only when they are meaningless
apart, such as a kernel and the `CMakeLists.txt` line that builds it. A change spanning the library,
its test and its documentation is three commits.

Update `CHANGELOG.md` `Unreleased` in the same commit as any user-visible change.
