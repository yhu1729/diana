"""Euler driver: explicit Euler steps through the C kernel ``diana._diana.euler_step``."""

from __future__ import annotations

import operator
from array import array
from collections.abc import Buffer, Callable, Iterable

from diana import _diana

__all__ = ["euler", "euler_step"]


def _samples(v: Buffer | Iterable[float]) -> Buffer:
    return v if isinstance(v, Buffer) else array("d", v)


def _real(x: object, name: str) -> float:
    if not (hasattr(type(x), "__float__") or hasattr(type(x), "__index__")):
        raise TypeError(f"{name} must be a real number, not {type(x).__name__}")
    return float(x)


def euler_step(y: Buffer | Iterable[float], f: Buffer | Iterable[float], h: float) -> array:
    """Return one explicit Euler step ``y + h*f`` as a new ``array.array("d")``.

    Each component is ``y[i] + h*f[i]`` with the product rounded before the sum. ``f`` holds
    the derivative ``F(t, y)`` at the current state. A buffer, such as a NumPy ``float64`` array
    or ``array.array("d")``, is read in place and must be one-dimensional, C-contiguous, aligned
    and of native ``float64``: :class:`TypeError` for another element type, :class:`ValueError`
    otherwise. Any other iterable is first copied into an ``array.array("d")``.

    Raises :class:`ValueError` for an empty ``y``, for ``y`` and ``f`` of different lengths, and
    when a component is not finite: a NaN or infinite ``y[i]``, ``f[i]`` or ``h``, or an
    overflow.
    """
    y = _samples(y)
    f = _samples(f)
    out = array("d", bytes(8 * (memoryview(y).nbytes // 8)))
    _diana.euler_step(y, f, h, out)
    return out


def euler(
    f: Callable[[float, array], Buffer | Iterable[float]],
    t0: float,
    y0: Buffer | Iterable[float],
    h: float,
    nstep: int,
) -> array:
    """Return the state after ``nstep`` explicit Euler steps of size ``h`` from ``y0`` at ``t0``.

    ``f(t, y)`` returns the derivative at time ``t`` and state ``y`` (an ``array.array("d")``,
    which ``f`` must not modify) as a buffer or iterable of floats of the same length. Step ``k``
    evaluates ``f`` at ``t0 + k*h``, computed from ``k`` rather than accumulated, then calls
    :func:`euler_step`. ``y0`` is copied, so the caller's data is never modified. The loop runs in
    Python, so ``f`` is not part of the verified code.

    Raises :class:`ValueError` for an empty ``y0``, for a negative ``nstep``, and from
    :func:`euler_step` when a step fails; :class:`TypeError` when ``nstep`` is not an integer or
    ``t0`` or ``h`` is not a real number (a string is not converted).
    """
    nstep = operator.index(nstep)
    if nstep < 0:
        raise ValueError("nstep must be non-negative")
    t0 = _real(t0, "t0")
    h = _real(h, "h")
    y = array("d", y0)
    if len(y) == 0:
        raise ValueError("y0 must have at least one sample")
    for k in range(nstep):
        y = euler_step(y, f(t0 + k * h, y), h)
    return y
