# Roadmap

Ideas for future work, one line each, in no particular order within a section. An entry is a
candidate, not a commitment or a design; it gets a design when someone picks it up. What is done
is in `CHANGELOG.md`.

Each idea carries a priority: `high` is an item for the next release, a prerequisite of one, or a
small change that closes a known gap; `medium` is worth doing once its prerequisites exist; `low`
is large for its value or far from the current proof tooling. An item that changes a public
signature, layout or documented behaviour is under `Toward 2.0`, whatever its priority, so the
API breaks once; everything else is additive and fits a 1.x release.

## Toward 2.0

- `high` Leading dimension or stride argument on every array and matrix kernel
- `high` Batched kernel interface solving many independent problems per call
- `medium` Computed error bound returned by each kernel whose layer-B theorem proves one
- `medium` Reverse-communication state with room for an iteration count and step-size control

## Method

Root finding:

- `medium` Secant method
- `medium` Regula falsi with the Illinois modification
- `medium` Brent's method
- `medium` Safeguarded Newton (Newton step kept inside a bisection bracket)
- `low` Fixed-point iteration

Quadrature:

- `low` Composite midpoint rule
- `medium` Romberg extrapolation
- `medium` Adaptive Simpson
- `low` Gauss–Legendre rule

Ordinary differential equation:

- `high` Explicit midpoint and Heun (second-order Runge–Kutta)
- `medium` Embedded Runge–Kutta pair with step-size control
- `medium` Implicit Euler
- `low` Störmer–Verlet
- `low` Adams–Bashforth

Linear algebra:

- `high` Dot product, norm, `axpy`
- `medium` Compensated summation, after the reordered-summation bound
- `medium` Tridiagonal solve
- `low` Householder QR
- `low` Jacobi, Gauss–Seidel, conjugate gradient
- `low` Power iteration

Interpolation and approximation:

- `medium` Horner polynomial evaluation
- `medium` Clenshaw recurrence for Chebyshev series
- `medium` Barycentric Lagrange interpolation
- `low` Newton divided differences
- `medium` Piecewise linear and cubic spline interpolation
- `low` Finite-difference derivative

## High performance implementation

Every item here needs the benchmark suite as its baseline and the stride and batched interfaces of
`Toward 2.0` as its shape.

- `medium` SIMD-vectorized array kernels, after the reordered-summation bound
- `medium` Pairwise summation in the quadrature rules, after the reordered-summation bound
- `medium` OpenMP threading of the array and batched kernels
- `medium` Deterministic parallel reduction
- `low` Blocked Cholesky and LU
- `low` GPU offload of the batched kernels
- `low` Distributed-memory linear algebra with MPI
- `low` Sparse matrix storage for the iterative solvers
- `low` FMA variant of each kernel
- `high` GIL released in the Python array functions

## Verification

- `high` Second Clight target (x86-64 Linux)
- `medium` Error bound for reordered summation, the prerequisite of pairwise, compensated, vectorized and threaded sums
- `medium` Perturbed-Newton theorem combining layers A and B
- `medium` Explicit worst-case iteration count for bisection
- `medium` Global floating-point error bound for the ODE methods
- `medium` RK4 local-error constants `M₅`, `N₄` from bounds on the derivatives of `F`
- `medium` Cholesky success: a positive definite binary64 matrix of small enough condition number factors without `DIANA_ERR_SINGULAR`
- `medium` Growth-factor bound on the LU factors under partial pivoting
- `medium` Forward error bound on the Cholesky factor, the LU factors and the LU solve
- `medium` Overflow-free triangular and LU solve from a successful factorization
- `low` VST proof of the callback wrappers
- `low` Composition of the per-function VST proofs into a whole-program proof

## Test

- `high` Compiler comparison on x86-64 Linux
- `high` Benchmark suite covering every kernel
- `medium` Coverage-guided fuzzing of the C kernels
- `low` Mutation testing of the C test suite

## Tooling

- `medium` Free-threaded CPython, after the GIL release
- `medium` pkg-config file
- `medium` `CITATION.cff`
