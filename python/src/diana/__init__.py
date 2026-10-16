"""Diana: formally verified numerical methods in C, with a Python binding.

Every iterative kernel is exposed in reverse-communication form (a small state object) and,
for convenience, as a function taking a Python callable. The callable loop runs in Python and is
not part of the verified code. Kernels over tabulated samples, :func:`trapezoidal` and
:func:`simpson`, take a float64 buffer or a sequence of numbers.
"""

from __future__ import annotations

from diana import _diana
from diana._bisection import bisection
from diana._diana import CONTINUE, ERR_ARG, ERR_BRACKET, ERR_MAXITER, OK, Bisection
from diana._error import BracketError, MaxIterError
from diana._simpson import simpson
from diana._trapezoidal import trapezoidal

__all__ = [
    "__version__",
    "OK",
    "CONTINUE",
    "ERR_ARG",
    "ERR_BRACKET",
    "ERR_MAXITER",
    "Bisection",
    "BracketError",
    "MaxIterError",
    "bisection",
    "simpson",
    "status_str",
    "trapezoidal",
    "version",
]

version = _diana.version
status_str = _diana.status_str

__version__ = version()
