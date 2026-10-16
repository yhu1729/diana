"""Bisection driver: runs the reverse-communication state :class:`diana.Bisection` on a callable."""

from __future__ import annotations

from collections.abc import Callable

from diana._convert import real
from diana._diana import CONTINUE, ERR_MAXITER, Bisection
from diana._error import MaxIterError

__all__ = ["bisection"]


def bisection(
    f: Callable[[float], float],
    a: float,
    b: float,
    tol: float = 0.0,
    max_iter: int = 2100,
) -> float:
    """Return a root of ``f`` in ``[a, b]`` by bisection.

    ``f(a)`` and ``f(b)`` must not have the same strict sign. The bracket is halved until its
    width is at most ``tol`` (``tol == 0`` stops at adjacent doubles) or ``max_iter`` steps were
    taken, in which case :class:`MaxIterError` is raised with the current estimate. The default
    ``max_iter`` covers the worst case of ``tol == 0``: 2098 steps for ``|a|, |b| <= DBL_MAX/2``.
    ``a``, ``b``, ``tol`` and every value ``f`` returns must be real numbers (``__float__`` or
    ``__index__``; a string is not converted): :class:`TypeError` otherwise.
    """
    a = real(a, "a")
    b = real(b, "b")
    state = Bisection(a, b, real(f(a), "f(a)"), real(f(b), "f(b)"), real(tol, "tol"), max_iter)
    status = state.status
    while status == CONTINUE:
        status = state.step(real(f(state.x), "f(x)"))
    root, width = state.result()
    if status == ERR_MAXITER:
        raise MaxIterError(root, width, state.iter)
    return root
