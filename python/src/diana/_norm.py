"""Vector norm drivers: pass a vector to the C kernels ``diana._diana.norm_1``, ``norm_2`` and
``norm_inf``."""

from __future__ import annotations

from array import array
from collections.abc import Buffer, Iterable

from diana import _diana

__all__ = ["norm_1", "norm_2", "norm_inf"]


def _samples(v: Buffer | Iterable[float]) -> Buffer:
    return v if isinstance(v, Buffer) else array("d", v)


def norm_1(x: Buffer | Iterable[float]) -> float:
    """Return the 1-norm ``|x[0]| + ... + |x[n-1]|``, added left to right.

    A buffer, such as a NumPy ``float64`` array or ``array.array("d")``, is read in place and must
    be one-dimensional, C-contiguous, aligned and of native ``float64``: :class:`TypeError` for
    another element type, :class:`ValueError` otherwise. Any other iterable is first copied into an
    ``array.array("d")``. An empty ``x`` has norm ``0.0``.

    Raises :class:`ValueError` for a NaN or infinite entry; :class:`FloatOverflowError` (a
    :class:`ValueError` and an :class:`OverflowError`) when every entry is finite and the sum
    overflows.
    """
    return _diana.norm_1(_samples(x))


def norm_2(x: Buffer | Iterable[float]) -> float:
    """Return the Euclidean norm ``sqrt(x[0]**2 + ... + x[n-1]**2)``.

    The norm is computed as ``m * sqrt(s)``, ``m = max |x[i]|`` at its first index ``k`` and
    ``s = 1 + (x[i]/m)**2 + ...`` over the other indices in order, so no square overflows or
    underflows: the result overflows only when the norm is about ``DBL_MAX`` or more, and is
    nonzero for every nonzero ``x``. Arguments as for :func:`norm_1`.

    Raises :class:`ValueError` for a NaN or infinite entry; :class:`FloatOverflowError` (a
    :class:`ValueError` and an :class:`OverflowError`) when every entry is finite and the result
    overflows.
    """
    return _diana.norm_2(_samples(x))


def norm_inf(x: Buffer | Iterable[float]) -> float:
    """Return the maximum norm ``max |x[i]|``, exactly.

    Arguments as for :func:`norm_1`. Raises :class:`ValueError` for a NaN or infinite entry; the
    result never overflows.
    """
    return _diana.norm_inf(_samples(x))
