"""Bisection driver: runs the reverse-communication state :class:`diana.Bisect` on a callable."""

from __future__ import annotations

from collections.abc import Callable

from diana._diana import CONTINUE, ERR_MAXITER, Bisect
from diana._error import MaxIterError

__all__ = ["bisect"]


def bisect(
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
    """
    a = float(a)
    b = float(b)
    state = Bisect(a, b, float(f(a)), float(f(b)), float(tol), max_iter)
    status = state.status
    while status == CONTINUE:
        status = state.step(float(f(state.x)))
    root, width = state.result()
    if status == ERR_MAXITER:
        raise MaxIterError(root, width, state.iter)
    return root
