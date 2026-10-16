# Third-party components

Diana itself is BSD-3-Clause (`LICENSE`). It has **no runtime dependency**: the installed C
library and the Python wheel contain only Diana's own code, so nothing listed below is
redistributed with a release artifact.

Everything here is a *development* or *verification* tool. The versions are the pins in
`CLAUDE.md` (Toolchain pin); licenses are the `license` field of the installed package.

## License condition that constrains how this project is used

Two tools are **not** free for commercial use. Diana is a research project and neither tool is
shipped, so the conditions are met; they still have to be stated.

| Tool | Condition | How Diana complies |
|---|---|---|
| CompCert 3.18 | INRIA Non-Commercial License Agreement: free for research, teaching, personal and evaluation use only | Used only to generate and check the Clight AST in a local opam switch. No CI image and no release artifact contains CompCert, and `ccomp` is never shipped ([trust statement](verification/trust.md)). |
| Alt-Ergo 2.6.4 | dual: `LicenseRef-OCamlpro-Non-Commercial` and Apache-2.0 | Used only as the local/CI proof oracle for Frama-C WP. Not shipped. |

The `verification/clight/<kernel>_<target>.v` files (today `bisection_aarch64_macos.v`,
`euler_aarch64_macos.v`, `simpson_aarch64_macos.v` and `trapezoidal_aarch64_macos.v`) are committed `clightgen` output, so they are the only files in the
tree derived from CompCert. They are excluded from the sdist (`verification/**` in
`sdist.exclude` of `pyproject.toml`).

## Proof assistant and library

| Component | Version | License |
|---|---|---|
| Rocq (prover and Stdlib) | 9.2.0 | LGPL-2.1-only |
| VST (Verified Software Toolchain) | 2.17 | BSD-2-Clause |
| Flocq | 4.2.2 | LGPL-3.0-or-later |
| Coquelicot | 3.4.5 | LGPL-3.0-or-later |
| MathComp ssreflect (pulled in by VST) | 2.6.0 | CECILL-B |
| `coq-vst-zlist` (pulled in by VST) | 2.13 | BSD-2-Clause |
| `rocq-elpi` (pulled in by MathComp) | 3.5.1 | LGPL-2.1-or-later |
| `coq-menhirlib` (pulled in by CompCert) | 20250912 | LGPL-3.0-or-later |
| Lean 4 toolchain | v4.35.0 | Apache-2.0 |
| Mathlib | `v4.35.0` (pinned in `lake-manifest.json`) | Apache-2.0 |

Mathlib's pinned transitive dependencies, all Apache-2.0 except `Cli` (MIT):
`batteries`, `aesop`, `Qq`, `proofwidgets`, `importGraph`, `LeanSearchClient`, `plausible`, `Cli`.

## Verification and analysis tool

| Component | Version | License |
|---|---|---|
| Frama-C (WP, RTE) | 33.0 local, 32.1 in CI | LGPL-2.1-only |
| Why3 | 1.8.2 | LGPL-2.1-only |
| Alt-Ergo | 2.6.4 | see the table above |

## Build and language tool

| Component | Version | License |
|---|---|---|
| CPython | managed by `uv` (`.python-version`) | PSF License 2.0 |
| scikit-build-core | `pyproject.toml` | Apache-2.0 |
| uv | — | Apache-2.0 or MIT |
| CMake | ≥ 3.25 | BSD-3-Clause |
| clang-format | 23.1.3 (uv `lint` group) | Apache-2.0 with LLVM exception |
| clang-tidy | LLVM, optional ([format and lint](development/style.md)) | Apache-2.0 with LLVM exception |
| ruff | `pyproject.toml` | MIT |
| pytest | test group only | MIT |
| NumPy | test group only | BSD-3-Clause (with 0BSD, MIT, Zlib and other terms for bundled code) |
| mpmath | test group only | BSD-3-Clause |
| hypothesis | test group only | MPL-2.0 |
| pytest-cov, gcovr | coverage group only | MIT, BSD-3-Clause |

The Python extension is compiled against the CPython headers and links the Python runtime it is
built for; it contains no CPython source.
