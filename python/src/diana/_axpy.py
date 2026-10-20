"""Axpy driver: the update ``y = a*x + y`` through the C kernel ``diana._diana.axpy``."""

from __future__ import annotations

from array import array
from collections.abc import Buffer, Iterable

from diana import _diana

__all__ = ["axpy"]


def _samples(v: Buffer | Iterable[float]) -> Buffer:
    return v if isinstance(v, Buffer) else array("d", v)


def axpy(a: float, x: Buffer | Iterable[float], y: Buffer) -> None:
    """Update ``y`` in place to ``a*x + y``: ``y[i] = y[i] + a*x[i]`` for every ``i``.

    Each component rounds the product before the sum. ``y`` is a writable buffer, such as a
    NumPy ``float64`` array or ``array.array("d")``, that is one-dimensional, C-contiguous,
    aligned and of native ``float64``: :class:`TypeError` for another element type or for an
    object that is not a buffer, :class:`ValueError` for another layout, and the buffer's own
    error (a :class:`BufferError` for ``bytes``) when it is read-only. ``x`` is read in place
    under the same rules when it is a buffer; any other iterable is first copied into an
    ``array.array("d")``. Both may be empty.

    Raises :class:`ValueError` when ``x`` and ``y`` differ in length or overlap, and when a
    component is not finite because of a NaN or infinite ``a``, ``x[i]`` or ``y[i]``;
    :class:`FloatOverflowError` (a :class:`ValueError` and an :class:`OverflowError`) when every
    input is finite and a component overflows. No component is written unless every one is
    finite, so a failed call leaves ``y`` as it was.
    """
    _diana.axpy(a, _samples(x), y)
