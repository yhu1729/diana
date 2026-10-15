# Diana

[![Release](https://gitlab.com/yhu1729/diana/-/badges/release.svg?key_text=Release&key_width=58)](https://gitlab.com/yhu1729/diana/-/releases)
[![Pipeline](https://gitlab.com/yhu1729/diana/badges/main/pipeline.svg?key_text=Pipeline&key_width=58&ignore_skipped=true)](https://gitlab.com/yhu1729/diana/-/commits/main)
[![C Coverage](https://gitlab.com/yhu1729/diana/badges/main/coverage.svg?key_text=C+Coverage&key_width=78&job=coverage_c)](https://gitlab.com/yhu1729/diana/-/commits/main)
[![Python Coverage](https://gitlab.com/yhu1729/diana/badges/main/coverage.svg?key_text=Python+Coverage&key_width=108&job=coverage_python)](https://gitlab.com/yhu1729/diana/-/commits/main)

Formally verified numerical methods in C, with a Python binding.

- Mathematical specification proven in **Lean 4** (Mathlib) and **Rocq** (Stdlib reals; Coquelicot where
  integrals and derivatives are needed).
- Floating-point error bounds in **Rocq/Flocq**.
- C implementation verified with **VST** (CompCert `clightgen`) and **Frama-C/WP**.
- Hand-written **CPython extension**; NumPy optional.

This release (v0.1.0) is the scaffolding, the proof pipeline, and bisection end-to-end. Bisection
is the only numerical method it provides.

Planned v1.0.0 scope: bisection, Newton, composite trapezoidal and Simpson rules, explicit Euler,
RK4, Cholesky, LU with partial pivoting. `doc/verification.md` says exactly what is proven, by which
tool, about which build. The C and Python API is described in `doc/api.md`.

## Build

```
cmake -S . -B build -DDIANA_BUILD_TEST=ON
cmake --build build
ctest --test-dir build
```

`DIANA_BUILD_PYTHON` is ON by default and needs the Python development headers; pass
`-DDIANA_BUILD_PYTHON=OFF` for a C-only build.

## Python

```
uv sync && uv run python -c "import diana; print(diana.bisection(lambda x: x*x - 2, 0.0, 2.0))"
```

## Contribute

Setup, local workflow, and commit convention are in `CONTRIBUTING.md`. Layers B and C-VST, the
Rocq axiom gate, and the Clight AST are checked only locally, so read "Before you commit" before
touching `src/`, `include/`, `verification/`, or `spec/`.

## License

BSD-3-Clause, see `LICENSE`. Diana has no runtime dependency; the development and verification
tools, with their versions and licenses, are listed in `doc/third-party.md` (CompCert and Alt-Ergo
are not free for commercial use and are never shipped).
