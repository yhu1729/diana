"""diana: formally verified numerical methods in C, with a Python binding.

Every iterative kernel is exposed in reverse-communication form (a small state object) and,
for convenience, as a function taking a Python callable. The callable loop runs in Python and is
not part of the verified code.
"""

from __future__ import annotations

from diana import _diana
from diana._bisect import bisect
from diana._diana import CONTINUE, ERR_ARG, ERR_BRACKET, ERR_MAXITER, OK, Bisect
from diana._error import BracketError, MaxIterError

__all__ = [
    "__version__",
    "OK",
    "CONTINUE",
    "ERR_ARG",
    "ERR_BRACKET",
    "ERR_MAXITER",
    "Bisect",
    "BracketError",
    "MaxIterError",
    "bisect",
    "status_str",
    "version",
]

version = _diana.version
status_str = _diana.status_str

__version__ = version()
