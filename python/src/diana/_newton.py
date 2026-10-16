"""Newton driver: runs the reverse-communication state :class:`diana.Newton` on a callable."""

from __future__ import annotations

from collections.abc import Callable

from diana._diana import CONTINUE, ERR_MAXITER, Newton
from diana._error import MaxIterError

__all__ = ["newton"]


def newton(
    f: Callable[[float], tuple[float, float]],
    x0: float,
    tol: float,
    max_iter: int = 100,
) -> float:
    """Return a root of ``f`` found by Newton's method from ``x0``.

    ``f(x)`` returns the pair ``(f(x), f'(x))``. Each step moves ``x`` by the correction
    ``dx = f(x) / f'(x)``; the iteration stops when ``|dx| <= tol``, when the move does not change
    ``x``, or when ``f(x) == 0``. After ``max_iter`` steps :class:`MaxIterError` is raised with
    the current estimate and ``|dx|``. ``tol`` has no default because Newton has no
    parameter-free stopping rule: with ``tol == 0`` the iteration commonly ends in a two-cycle
    of adjacent doubles around the root, and the default ``max_iter`` of 100 is a safety limit,
    not a convergence guarantee. A non-finite ``f(x)`` or ``f'(x)``, a zero ``f'(x)``, or a
    correction or iterate that overflows raises :class:`ValueError` and leaves the state at the
    last iterate.
    """
    state = Newton(x0, tol, max_iter)
    status = state.status
    while status == CONTINUE:
        fx, dfx = f(state.x)
        status = state.step(fx, dfx)
    root, dx = state.result()
    if status == ERR_MAXITER:
        raise MaxIterError(root, abs(dx), state.iter)
    return root
