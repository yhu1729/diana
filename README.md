# Diana

[![Release](https://gitlab.com/yhu1729/diana/-/badges/release.svg?key_text=Release&key_width=58)](https://gitlab.com/yhu1729/diana/-/releases)
[![Pipeline](https://gitlab.com/yhu1729/diana/badges/main/pipeline.svg?key_text=Pipeline&key_width=58&ignore_skipped=true)](https://gitlab.com/yhu1729/diana/-/commits/main)
[![C Coverage](https://gitlab.com/yhu1729/diana/badges/main/coverage.svg?key_text=C+Coverage&key_width=78&job=coverage_c)](https://gitlab.com/yhu1729/diana/-/commits/main)
[![Python Coverage](https://gitlab.com/yhu1729/diana/badges/main/coverage.svg?key_text=Python+Coverage&key_width=108&job=coverage_python)](https://gitlab.com/yhu1729/diana/-/commits/main)

Diana is a library of numerical methods in C, with a Python binding.
Implementation correctness is machine-checked from the mathematics down to the C code.

Every method comes with a proof that the algorithm converges or meets its error bound over the
real numbers, a proof of what rounding does to it in binary64 arithmetic, and a proof that the
C function computes exactly that rounded result without undefined behaviour. The proofs are
written in Lean 4 and Rocq, with Frama-C checking the C contracts; `doc/verification/trust.md`
states precisely what is proven, by which tool, and what is only tested.

## Methods

- Bisection, as a state machine the caller drives, and as a function taking a callback.
- Composite trapezoidal and Simpson rules over tabulated samples.
- Cholesky factorization of a symmetric positive definite matrix, and forward and back
  substitution with its triangular factor.
- Explicit Euler step, with a loop over a callback.
- Classical Runge–Kutta (RK4) step, with a loop over a callback.
- Newton's method, as a state machine the caller drives, and as a function taking a callback.

Each is available from C (`include/diana/`) and from Python (`import diana`). The C kernels
allocate nothing, call no libm function, and use no function pointer; the convenience wrappers
and the Python package drive those kernels and are tested rather than proven. The one square
root, in the Cholesky factorization, is a compiler builtin. LU with partial pivoting is planned
for 1.0.

## Quick start

C library and test suite (this also builds the Python extension; add `-DDIANA_BUILD_PYTHON=OFF`
on a machine without the Python development headers):

```
cmake -S . -B build -DDIANA_BUILD_TEST=ON
cmake --build build
ctest --test-dir build
```

Python package, built in place by `uv`:

```
uv sync
uv run python -c "import diana; print(diana.bisection(lambda x: x*x - 2, 0.0, 2.0))"
```

## Documentation

- `doc/README.md` indexes everything below.
- `doc/api/`: the C and Python API, one page per method with runnable examples.
- `doc/verification/`: the trust statement, the generated theorem report, and how each proof
  layer is checked.
- `doc/development/`: build, local workflow, tests, style, the Python binding, CI and the
  benchmark.
- `note/`: short technical notes, one fact or rule each, with the exact detail behind `doc/`;
  indexed by topic and by source file for AI agents and reviewers.
- `CONTRIBUTING.md`: setup, toolchain versions and the commit convention. Changes to the kernels
  or proofs need the local verification steps it describes.
- `CHANGELOG.md`: what each release contains.

## License

BSD-3-Clause, see `LICENSE`. Diana has no runtime dependency. The development and verification
tools, with their versions and licenses, are listed in `doc/third-party.md`.
