# Roadmap

Ideas for future work, one line each, grouped by the release they aim at and in no particular
order within a section. An entry is a candidate, not a commitment or a design; it gets a design
when someone picks it up. What is done is in `CHANGELOG.md`.

Each idea carries a priority: `high` is what the release is for, or a prerequisite of it; `medium`
goes in once its prerequisites exist and slips to the next release otherwise; `low` is large for
its value or far from the current proof tooling. An item that changes a public signature, layout
or documented behaviour waits for a major release, so the API breaks once; everything else is
additive and fits a minor release.

## Toward 1.1

Closing the trust and tooling gaps of 1.0.

- `high` Second Clight target (x86-64 Linux)
- `high` Compiler comparison on x86-64 Linux
- `high` Benchmark suite covering every kernel
- `high` GIL released in the Python array functions
- `high` Dot product, norm, `axpy`
- `medium` pkg-config file
- `medium` `CITATION.cff`

## Toward 1.2

Summation and its error bound, the first second-order ODE method, and the proofs that make the
trust statement shorter.

- `high` Explicit midpoint and Heun (second-order Runge–Kutta)
- `high` Error bound for reordered summation (pairwise, compensated, vectorized, threaded)
- `medium` Compensated summation
- `medium` Pairwise summation in the quadrature rules
- `medium` Explicit worst-case iteration count for bisection
- `medium` Cholesky never `DIANA_ERR_SINGULAR` on a well-conditioned positive definite binary64 matrix
- `medium` Overflow-free triangular and LU solve from a successful factorization
- `medium` Horner polynomial evaluation
- `medium` Free-threaded CPython
- `medium` Coverage-guided fuzzing of the C kernels

## Toward 1.3

Methods built on what 1.2 added, and the remaining error bounds.

- `medium` Secant method
- `medium` Regula falsi with the Illinois modification
- `medium` Brent's method
- `medium` Safeguarded Newton (Newton step kept inside a bisection bracket)
- `medium` Romberg extrapolation
- `medium` Adaptive Simpson
- `medium` Embedded Runge–Kutta pair with step-size control
- `medium` Implicit Euler
- `medium` Tridiagonal solve
- `medium` Clenshaw recurrence for Chebyshev series
- `medium` Barycentric Lagrange interpolation
- `medium` Piecewise linear and cubic spline interpolation
- `medium` Perturbed-Newton theorem combining layers A and B
- `medium` Global floating-point error bound for the ODE methods
- `medium` RK4 local-error constants `M₅`, `N₄` from bounds on the derivatives of `F`
- `medium` Growth-factor bound on the LU factors under partial pivoting
- `medium` Forward error bound on the Cholesky factor, the LU factors and the LU solve

## Toward 2.0

The one API break: the interfaces the high-performance work needs.

- `high` Leading dimension or stride argument on every array and matrix kernel
- `high` Batched kernel interface solving many independent problems per call
- `medium` Computed error bound returned by each kernel whose layer-B theorem proves one
- `medium` Reverse-communication state with room for an iteration count and step-size control

## After 2.0

High-performance implementation on the 2.0 interfaces, measured against the benchmark suite.

- `medium` SIMD-vectorized array kernels
- `medium` OpenMP threading of the array and batched kernels
- `medium` Deterministic parallel reduction
- `low` Blocked Cholesky and LU
- `low` GPU offload of the batched kernels
- `low` Distributed-memory linear algebra with MPI
- `low` Sparse matrix storage for the iterative solvers
- `low` FMA variant of each kernel

## Unscheduled

- `low` Fixed-point iteration
- `low` Composite midpoint rule
- `low` Gauss–Legendre rule
- `low` Störmer–Verlet
- `low` Adams–Bashforth
- `low` Householder QR
- `low` Jacobi, Gauss–Seidel, conjugate gradient
- `low` Power iteration
- `low` Newton divided differences
- `low` Finite-difference derivative
- `low` VST proof of the callback wrappers
- `low` Composition of the per-function VST proofs into a whole-program proof
- `low` Mutation testing of the C test suite
