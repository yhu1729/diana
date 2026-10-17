"""Diana: formally verified numerical methods in C, with a Python binding.

Every iterative kernel, :class:`Bisection` and :class:`Newton`, is exposed in
reverse-communication form (a small state object) and, for convenience, as a function taking a
Python callable (:func:`bisection`, :func:`newton`). The callable loop runs in Python and is
not part of the verified code. Kernels over tabulated samples, :func:`trapezoidal` and
:func:`simpson`, take a float64 buffer or a sequence of numbers. :func:`euler_step` takes one
explicit Euler step and :func:`euler` loops over it with a callable; :func:`rk4_stage` and
:func:`rk4_step` build one classical Runge–Kutta step and :func:`rk4` loops over them.
"""

from __future__ import annotations

from diana import _diana
from diana._bisection import bisection
from diana._diana import (
    CONTINUE,
    ERR_ARG,
    ERR_BRACKET,
    ERR_MAXITER,
    ERR_SINGULAR,
    OK,
    Bisection,
    Newton,
)
from diana._error import BracketError, MaxIterError, SingularError
from diana._euler import euler, euler_step
from diana._newton import newton
from diana._rk4 import rk4, rk4_stage, rk4_step
from diana._simpson import simpson
from diana._trapezoidal import trapezoidal

__all__ = [
    "__version__",
    "OK",
    "CONTINUE",
    "ERR_ARG",
    "ERR_BRACKET",
    "ERR_MAXITER",
    "ERR_SINGULAR",
    "Bisection",
    "BracketError",
    "MaxIterError",
    "Newton",
    "SingularError",
    "bisection",
    "euler",
    "euler_step",
    "newton",
    "rk4",
    "rk4_stage",
    "rk4_step",
    "simpson",
    "status_str",
    "trapezoidal",
    "version",
]

version = _diana.version
status_str = _diana.status_str

__version__ = version()
