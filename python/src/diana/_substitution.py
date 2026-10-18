"""Triangular solve drivers: forward and back substitution with the C kernels
``diana._diana.forward_substitution`` and ``diana._diana.back_substitution``."""

from __future__ import annotations

from array import array
from collections.abc import Buffer, Iterable

from diana import _diana

__all__ = ["back_substitution", "forward_substitution"]


def _samples(v: Buffer | Iterable[float]) -> Buffer:
    return v if isinstance(v, Buffer) else array("d", v)


def forward_substitution(lower: Buffer | Iterable[float], b: Buffer | Iterable[float]) -> array:
    """Return the solution ``x`` of ``L*x = b`` as a new ``array.array("d")``.

    ``lower`` holds an ``n`` by ``n`` lower-triangular matrix ``L`` in column-major order,
    ``lower[i + j*n] = L[i, j]``, so its length is ``n*n`` for the length ``n`` of ``b``; only the
    entries on or below the diagonal (``i >= j``) are read, and the factor returned by
    :func:`cholesky` can be passed as is. With NumPy, pass ``L.ravel(order="F")``. A buffer, such
    as a NumPy ``float64`` array or ``array.array("d")``, is read in place and must be
    one-dimensional, C-contiguous, aligned and of native ``float64``: :class:`TypeError` for
    another element type, :class:`ValueError` otherwise. Any other iterable is first copied into
    an ``array.array("d")``.

    Entry ``i`` is ``(b[i] - L[i, 0]*x[0] - ... - L[i, i-1]*x[i-1]) / L[i, i]``, each product
    rounded and subtracted in that order, then divided.

    Raises :class:`ValueError` for an empty ``b``, for a length of ``lower`` other than ``n*n``, for
    a NaN or infinite entry of ``b`` or on or below the diagonal of ``lower``;
    :class:`FloatOverflowError` (a :class:`ValueError` and an :class:`OverflowError`) when an entry
    of ``x`` overflows; :class:`SingularError` (a :class:`ValueError`) when a diagonal entry of
    ``L`` is zero.
    """
    lower = _samples(lower)
    b = _samples(b)
    out = array("d", bytes(8 * (memoryview(b).nbytes // 8)))
    _diana.forward_substitution(lower, b, out)
    return out


def back_substitution(lower: Buffer | Iterable[float], b: Buffer | Iterable[float]) -> array:
    """Return the solution ``x`` of ``L^T*x = b`` as a new ``array.array("d")``.

    ``lower`` holds the lower-triangular ``L`` exactly as for :func:`forward_substitution`, column
    major with only the entries on or below the diagonal read, and the system solved is the one
    of its transpose, an upper-triangular matrix. So ``A*x = b`` for ``A = L*L^T`` is
    ``back_substitution(L, forward_substitution(L, b))`` with ``L = cholesky(A)``.

    Entry ``i``, from ``i = n - 1`` down to 0, is
    ``(b[i] - L[n-1, i]*x[n-1] - ... - L[i+1, i]*x[i+1]) / L[i, i]``, the products subtracted in
    the order their unknowns were computed. This is :func:`forward_substitution` on the system
    with its indices reversed, bit for bit.

    Raises as :func:`forward_substitution`.
    """
    lower = _samples(lower)
    b = _samples(b)
    out = array("d", bytes(8 * (memoryview(b).nbytes // 8)))
    _diana.back_substitution(lower, b, out)
    return out
