# Roadmap

Ideas for future work, one line each, in no particular order within a section. An entry is a
candidate, not a commitment or a design; it gets a design when someone picks it up. What is done
is in `CHANGELOG.md`.

Each idea carries a priority: `high` is a 1.0 item, a prerequisite of one, or a small change that
closes a known gap; `medium` is worth doing once its prerequisites exist; `low` is large for its
value or far from the current proof tooling.

## Toward 1.0

- `high` Solve with the LU factors: row interchanges, then unit lower and upper triangular solves

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
- `medium` Compensated summation
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

- `medium` SIMD-vectorized array kernels
- `medium` Pairwise summation in the quadrature rules
- `medium` Batched kernels solving many independent problems per call
- `medium` OpenMP threading of the array and batched kernels
- `medium` Deterministic parallel reduction
- `low` Blocked Cholesky and LU
- `low` GPU offload of the batched kernels
- `low` Distributed-memory linear algebra with MPI
- `low` Sparse matrix storage for the iterative solvers
- `low` FMA variant of each kernel
- `medium` Error bound for reordered summation, covering vectorized and threaded sums
- `high` GIL released in the Python array functions

## Verification

- `medium` Perturbed-Newton theorem combining layers A and B
- `medium` Explicit worst-case iteration count for bisection
- `medium` Global floating-point error bound for the ODE methods
- `medium` RK4 local-error constants `M₅`, `N₄` from bounds on the derivatives of `F`
- `low` VST proof of the callback wrappers
- `high` Second Clight target (x86-64 Linux)

## Test

- `medium` Coverage-guided fuzzing of the C kernels
- `high` Compiler comparison on x86-64 Linux
- `low` Mutation testing of the C test suite
- `medium` Benchmark suite covering every kernel

## Tooling

- `medium` Free-threaded CPython
- `medium` pkg-config file
- `medium` `CITATION.cff`
