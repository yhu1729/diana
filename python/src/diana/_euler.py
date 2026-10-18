"""Euler driver: explicit Euler steps through the C kernel ``diana._diana.euler_step``."""

from __future__ import annotations

import operator
from array import array
from collections.abc import Buffer, Callable, Iterable

from diana import _diana
from diana._convert import real

__all__ = ["euler", "euler_step"]


def _samples(v: Buffer | Iterable[float]) -> Buffer:
    return v if isinstance(v, Buffer) else array("d", v)


def euler_step(y: Buffer | Iterable[float], f: Buffer | Iterable[float], h: float) -> array:
    """Return one explicit Euler step ``y + h*f`` as a new ``array.array("d")``.

    Each component is ``y[i] + h*f[i]`` with the product rounded before the sum. ``f`` holds
    the derivative ``F(t, y)`` at the current state. A buffer, such as a NumPy ``float64`` array
    or ``array.array("d")``, is read in place and must be one-dimensional, C-contiguous, aligned
    and of native ``float64``: :class:`TypeError` for another element type, :class:`ValueError`
    otherwise. Any other iterable is first copied into an ``array.array("d")``.

    Raises :class:`ValueError` for an empty ``y``, for ``y`` and ``f`` of different lengths, and
    when a component is not finite because of a NaN or infinite ``y[i]``, ``f[i]`` or ``h``;
    :class:`FloatOverflowError` (a :class:`ValueError` and an :class:`OverflowError`) when every
    input is finite and a component overflows.
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
    :func:`euler_step`. ``y0`` is copied element by element (``bytes`` is a sequence of integers,
    not raw float64 data), so the caller's data is never modified. The loop runs in Python, so
    ``f`` is not part of the verified code.

    Raises :class:`ValueError` for an empty ``y0``, for a negative ``nstep``, and from
    :func:`euler_step` when a step fails; :class:`TypeError` when ``nstep`` is not an integer or
    ``t0`` or ``h`` is not a real number (a string is not converted).
    """
    nstep = operator.index(nstep)
    if nstep < 0:
        raise ValueError("nstep must be non-negative")
    t0 = real(t0, "t0")
    h = real(h, "h")
    y = array("d", iter(y0))
    if len(y) == 0:
        raise ValueError("y0 must have at least one sample")
    for k in range(nstep):
        y = euler_step(y, f(t0 + k * h, y), h)
    return y
