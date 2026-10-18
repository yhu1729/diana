# Roadmap

Ideas for future work, one line each, grouped by the release they aim at and in no particular
order within a section. An entry is a candidate, not a commitment or a design; it gets a design
when someone picks it up. What is done is in `CHANGELOG.md`.

Each idea carries a priority: `high` is what the release is for, or a prerequisite of it; `medium`
goes in once its prerequisites exist and slips to the next release otherwise; `low` is large for
its value or far from the current proof tooling. An item that changes a public signature, layout
or documented behaviour waits for a major release, so the API breaks once; everything else is
additive and fits a minor release. A minor release carries at most three new kernels, since each
one costs a source file, a WP row, a Clight AST, a VST file, both layer-A proofs, a Flocq file, a
spec, a doc page, tests and a Python binding; a major release carries the API break and nothing
else.

## Toward 1.1

Closing the tooling gaps of 1.0.

- `high` Benchmark suite covering every kernel
- `high` GIL released in the Python array functions
- `high` Dot product, norm, `axpy`
- `medium` pkg-config file
- `medium` `CITATION.cff`

## Toward 1.2

Summation and its error bound, and the first second-order ODE method.

- `high` Explicit midpoint and Heun (second-order Runge–Kutta)
- `high` Error bound for reordered summation (pairwise, compensated, vectorized, threaded)
- `medium` Compensated summation
- `medium` Pairwise summation in the quadrature rules
- `medium` Explicit worst-case iteration count for bisection
- `medium` Free-threaded CPython
- `medium` Coverage-guided fuzzing of the C kernels

## Toward 1.3

Small evaluation kernels, and the proofs that make the trust statement shorter.

- `medium` Horner polynomial evaluation
- `low` Composite midpoint rule
- `low` Finite-difference derivative
- `medium` Cholesky never `DIANA_ERR_SINGULAR` on a well-conditioned positive definite matrix
- `medium` Overflow-free triangular and LU solve from a successful factorization
- `medium` Perturbed-Newton theorem combining layers A and B
- `low` Mutation testing of the C test suite

## Toward 1.4

Bracketing root finders.

- `medium` Secant method
- `medium` Regula falsi with the Illinois modification
- `medium` Safeguarded Newton (Newton step kept inside a bisection bracket)
- `medium` Global floating-point error bound for the ODE methods

## Toward 1.5

Brent on the 1.4 bracketing methods, and extrapolated quadrature.

- `medium` Brent's method
- `medium` Romberg extrapolation
- `medium` Adaptive Simpson
- `medium` RK4 local-error constants `M₅`, `N₄` from bounds on the derivatives of `F`

## Toward 1.6

Adaptive and implicit ODE methods on the 1.2 Runge–Kutta pair.

- `medium` Embedded Runge–Kutta pair with step-size control
- `medium` Implicit Euler
- `low` Störmer–Verlet
- `medium` Growth-factor bound on the LU factors under partial pivoting

## Toward 1.7

Multistep integration, Gauss quadrature and the banded solve.

- `low` Adams–Bashforth
- `low` Gauss–Legendre rule
- `medium` Tridiagonal solve
- `medium` Forward error bound on the Cholesky factor, the LU factors and the LU solve

## Toward 1.8

Polynomial interpolation and series evaluation.

- `medium` Clenshaw recurrence for Chebyshev series
- `medium` Barycentric Lagrange interpolation
- `low` Newton divided differences

## Toward 1.9

Piecewise interpolation and the last root finder.

- `medium` Piecewise linear and cubic spline interpolation
- `low` Fixed-point iteration

## Toward 2.0

The one API break: the interfaces the high-performance work needs.

- `high` Leading dimension or stride argument on every array and matrix kernel
- `high` Batched kernel interface solving many independent problems per call
- `medium` Computed error bound returned by each kernel whose layer-B theorem proves one
- `medium` Reverse-communication state with room for an iteration count and step-size control

## Toward 2.1

Vectorized and threaded kernels on the 2.0 interfaces, measured against the benchmark suite.

- `medium` SIMD-vectorized array kernels
- `medium` OpenMP threading of the array and batched kernels
- `medium` Deterministic parallel reduction
- `low` VST proof of the callback wrappers

## Toward 2.2

Dense factorizations on the stride interface.

- `low` Householder QR
- `low` Power iteration
- `low` Blocked Cholesky and LU
- `low` FMA variant of each kernel

## Toward 2.3

Iterative solvers and their storage.

- `low` Jacobi, Gauss–Seidel, conjugate gradient
- `low` Sparse matrix storage for the iterative solvers

## Toward 2.4

Distributed memory and the whole-program proof.

- `low` Distributed-memory linear algebra with MPI
- `low` Composition of the per-function VST proofs into a whole-program proof
