"""Simpson driver: passes tabulated samples to the C kernel ``diana._diana.simpson``."""

from __future__ import annotations

from array import array
from collections.abc import Buffer, Iterable

from diana import _diana

__all__ = ["simpson"]


def simpson(y: Buffer | Iterable[float], h: float) -> float:
    """Return the composite Simpson rule ``h/3 * (y[0] + 4*y[1] + 2*y[2] + ... + y[n-1])``.

    ``y`` holds the samples ``f(a + i*h)``, ``i = 0, ..., n-1``, of ``n - 1`` panels of width
    ``h``; ``n`` must be odd, so the number of panels is even (a negative ``h`` integrates in the
    opposite direction). A buffer, such as a NumPy ``float64`` array or ``array.array("d")``, is
    read in place and must be one-dimensional, C-contiguous, aligned and of native ``float64``:
    :class:`TypeError` for another element type, :class:`ValueError` otherwise. Any other iterable
    is first copied into an ``array.array("d")``.

    Raises :class:`ValueError` for fewer than three samples, for an even number of samples, and
    when the result is not finite: a NaN or infinite sample or ``h``, or an overflow in any
    operation, including ``h * s`` when ``h * s / 3`` alone would be finite.
    """
    if not isinstance(y, Buffer):
        y = array("d", y)
    return _diana.simpson(y, h)
