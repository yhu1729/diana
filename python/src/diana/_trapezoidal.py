"""Trapezoidal driver: passes tabulated samples to the C kernel ``diana._diana.trapezoidal``."""

from __future__ import annotations

from array import array
from collections.abc import Buffer, Iterable

from diana import _diana

__all__ = ["trapezoidal"]


def trapezoidal(y: Buffer | Iterable[float], h: float) -> float:
    """Return the composite trapezoidal rule ``h * (y[0]/2 + y[1] + ... + y[n-2] + y[n-1]/2)``.

    ``y`` holds the samples ``f(a + i*h)``, ``i = 0, ..., n-1``, of ``n - 1`` panels of width
    ``h`` (a negative ``h`` integrates in the opposite direction). A buffer, such as a NumPy
    ``float64`` array or ``array.array("d")``, is read in place and must be one-dimensional,
    C-contiguous, aligned and of native ``float64``: :class:`TypeError` for another element type,
    :class:`ValueError` otherwise. Any other iterable is first copied into an ``array.array("d")``.

    Raises :class:`ValueError` for fewer than two samples and when the result is not finite: a
    NaN or infinite sample or ``h``, or an overflow anywhere in the sum.
    """
    if not isinstance(y, Buffer):
        y = array("d", y)
    return _diana.trapezoidal(y, h)
