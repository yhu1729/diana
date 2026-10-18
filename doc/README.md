# Documentation

The repository `README.md` introduces Diana and `CONTRIBUTING.md` sets up a development
environment. The pages here are for developers who use or change the library. They explain what
things do and why; the exact detail — evaluation orders, check orders, proof coverage, tool
quirks, CI internals, the derivation of test values — lives in short technical notes under
[`note/`](../note/README.md), which each page links at its end. The theorems of each method are
listed in `spec/<method>.md`.

## Use the library

- [API overview](api/overview.md): headers, linking, status codes, the Python package
- [Bisection](api/bisection.md) and [Newton's method](api/newton.md): root finding
- [Composite trapezoidal rule](api/trapezoidal.md) and [composite Simpson rule](api/simpson.md):
  quadrature over samples
- [Explicit Euler step](api/euler.md) and [classical Runge–Kutta step](api/rk4.md): ordinary
  differential equations
- [Cholesky factorization](api/cholesky.md),
  [forward and transpose substitution](api/substitution.md),
  [LU factorization with partial pivoting](api/lu.md) and [LU solve](api/lu_solve.md): linear
  algebra

## Understand the proofs

- [Trust statement](verification/trust.md): what is proved, by which tool, what is trusted, what
  is only tested
- [Verification report](verification/report.md): the status of every theorem, generated
- [Local verification](verification/local.md): running the proofs CI cannot run
- [Spec gate](verification/spec-gate.md), [Frama-C](verification/frama-c.md) and
  [compiler comparison](verification/compiler.md): the individual checks

## Work on Diana

- [Build](development/build.md): CMake options, the Python package
- [Local workflow](development/workflow.md): `script/dev.sh`
- [Test](development/test.md): the test suites and what they check
- [Format and lint](development/style.md)
- [Python binding](development/python.md): how the extension and the package are organized
- [CI](development/ci.md): the pipeline and what it leaves to local runs
- [Benchmark](development/benchmark.md): checked against unchecked kernels

## Project

- [Roadmap](roadmap.md): ideas for future work, one line each
- [Third-party components](third-party.md): every development and verification tool, with its
  version and license
