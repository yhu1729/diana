"""RK4 driver: classical Runge–Kutta steps through ``diana._diana.rk4_stage`` and ``rk4_step``."""

from __future__ import annotations

import operator
from array import array
from collections.abc import Buffer, Callable, Iterable

from diana import _diana
from diana._convert import real

__all__ = ["rk4", "rk4_stage", "rk4_step"]


def _samples(v: Buffer | Iterable[float]) -> Buffer:
    return v if isinstance(v, Buffer) else array("d", v)


def _output(y: Buffer) -> array:
    return array("d", bytes(8 * (memoryview(y).nbytes // 8)))


def rk4_stage(
    y: Buffer | Iterable[float], k: Buffer | Iterable[float], h: float, stage: int
) -> array:
    """Return the point of RK4 stage ``stage`` as a new ``array.array("d")``.

    Stages 2 and 3 return ``y + (h/2)*k`` (``k`` the slope of the previous stage) and stage 4
    returns ``y + h*k``; the coefficient is computed once and each product is rounded before the
    sum. A buffer, such as a NumPy ``float64`` array or ``array.array("d")``, is read in place and
    must be one-dimensional, C-contiguous, aligned and of native ``float64``: :class:`TypeError`
    for another element type, :class:`ValueError` otherwise. Any other iterable is first copied
    into an ``array.array("d")``.

    Raises :class:`ValueError` for a ``stage`` other than 2, 3 or 4, for an empty ``y``, for ``y``
    and ``k`` of different lengths, and when a component is not finite: a NaN or infinite
    ``y[i]``, ``k[i]`` or ``h``, or an overflow.
    """
    y = _samples(y)
    k = _samples(k)
    out = _output(y)
    _diana.rk4_stage(y, k, h, stage, out)
    return out


def rk4_step(
    y: Buffer | Iterable[float],
    k1: Buffer | Iterable[float],
    k2: Buffer | Iterable[float],
    k3: Buffer | Iterable[float],
    k4: Buffer | Iterable[float],
    h: float,
) -> array:
    """Return one RK4 step ``y + h*(k1 + 2*k2 + 2*k3 + k4)/6`` as a new ``array.array("d")``.

    Each component is ``y[i] + h*s/6`` with ``s = (k1[i] + k4[i]) + 2*(k2[i] + k3[i])``, each
    operation rounded in that order. The arguments are read as in :func:`rk4_stage`.

    Raises :class:`ValueError` for an empty ``y``, for arguments of different lengths, and when a
    component is not finite: a NaN or infinite input, or an overflow in any operation.
    """
    y = _samples(y)
    out = _output(y)
    _diana.rk4_step(y, _samples(k1), _samples(k2), _samples(k3), _samples(k4), h, out)
    return out


def rk4(
    f: Callable[[float, array], Buffer | Iterable[float]],
    t0: float,
    y0: Buffer | Iterable[float],
    h: float,
    nstep: int,
) -> array:
    """Return the state after ``nstep`` RK4 steps of size ``h`` from ``y0`` at ``t0``.

    ``f(t, y)`` returns the derivative at time ``t`` and state ``y`` (an ``array.array("d")``,
    which ``f`` must not modify) as a buffer or iterable of floats of the same length. Step ``n``
    evaluates ``f`` at ``t0 + n*h``, ``t0 + (n + 0.5)*h`` (twice) and ``t0 + (n + 1)*h``, each
    computed from ``n`` rather than accumulated, at the stage points of :func:`rk4_stage`, then
    calls :func:`rk4_step`. Each result of ``f`` is copied element by element, so ``f`` may reuse
    one output buffer. ``y0`` is copied element by element (``bytes`` is a sequence of integers,
    not raw float64 data), so the caller's data is never modified. The loop runs in Python, so
    ``f`` is not part of the verified code.

    Raises :class:`ValueError` for an empty ``y0``, for a negative ``nstep``, and from
    :func:`rk4_stage` and :func:`rk4_step` when a stage or step fails; :class:`TypeError` when
    ``nstep`` is not an integer or ``t0`` or ``h`` is not a real number (a string is not
    converted).
    """
    nstep = operator.index(nstep)
    if nstep < 0:
        raise ValueError("nstep must be non-negative")
    t0 = real(t0, "t0")
    h = real(h, "h")
    y = array("d", iter(y0))
    if len(y) == 0:
        raise ValueError("y0 must have at least one sample")
    for n in range(nstep):
        k1 = array("d", iter(f(t0 + n * h, y)))
        k2 = array("d", iter(f(t0 + (n + 0.5) * h, rk4_stage(y, k1, h, 2))))
        k3 = array("d", iter(f(t0 + (n + 0.5) * h, rk4_stage(y, k2, h, 3))))
        k4 = array("d", iter(f(t0 + (n + 1) * h, rk4_stage(y, k3, h, 4))))
        y = rk4_step(y, k1, k2, k3, k4, h)
    return y
