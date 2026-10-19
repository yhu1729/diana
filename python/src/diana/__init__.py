"""Diana: formally verified numerical methods in C, with a Python binding.

Every iterative kernel, :class:`Bisection` and :class:`Newton`, is exposed in
reverse-communication form (a small state object) and, for convenience, as a function taking a
Python callable (:func:`bisection`, :func:`newton`). The callable loop runs in Python and is
not part of the verified code. Kernels over tabulated samples, :func:`trapezoidal` and
:func:`simpson`, take a float64 buffer or a sequence of numbers. :func:`euler_step` takes one
explicit Euler step and :func:`euler` loops over it with a callable; :func:`rk4_stage` and
:func:`rk4_step` build one classical Runge–Kutta step and :func:`rk4` loops over them.
:func:`cholesky` factors a symmetric positive definite matrix stored column-major, and
:func:`forward_substitution` and :func:`transpose_substitution` solve with its triangular factor.
:func:`lu` factors a square matrix with partial pivoting, and :func:`lu_solve` solves with its
factors. :func:`norm_1`, :func:`norm_2` and :func:`norm_inf` return the vector norms.
"""

from __future__ import annotations

from diana import _diana
from diana._bisection import bisection
from diana._cholesky import cholesky
from diana._diana import (
    CONTINUE,
    ERR_ARG,
    ERR_BRACKET,
    ERR_CALLBACK,
    ERR_MAXITER,
    ERR_OVERFLOW,
    ERR_SINGULAR,
    OK,
    Bisection,
    Newton,
)
from diana._error import BracketError, FloatOverflowError, MaxIterError, SingularError
from diana._euler import euler, euler_step
from diana._lu import lu
from diana._lu_solve import lu_solve
from diana._newton import newton
from diana._norm import norm_1, norm_2, norm_inf
from diana._rk4 import rk4, rk4_stage, rk4_step
from diana._simpson import simpson
from diana._substitution import forward_substitution, transpose_substitution
from diana._trapezoidal import trapezoidal

__all__ = [
    "__version__",
    "OK",
    "CONTINUE",
    "ERR_ARG",
    "ERR_BRACKET",
    "ERR_MAXITER",
    "ERR_SINGULAR",
    "ERR_OVERFLOW",
    "ERR_CALLBACK",
    "Bisection",
    "BracketError",
    "FloatOverflowError",
    "MaxIterError",
    "Newton",
    "SingularError",
    "bisection",
    "cholesky",
    "euler",
    "euler_step",
    "forward_substitution",
    "lu",
    "lu_solve",
    "newton",
    "norm_1",
    "norm_2",
    "norm_inf",
    "rk4",
    "rk4_stage",
    "rk4_step",
    "simpson",
    "status_str",
    "transpose_substitution",
    "trapezoidal",
    "version",
]

version = _diana.version
status_str = _diana.status_str

__version__ = version()
