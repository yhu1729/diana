"""Cholesky driver: factors a matrix with the C kernel ``diana._diana.cholesky``."""

from __future__ import annotations

from array import array
from collections.abc import Buffer, Iterable

from diana import _diana

__all__ = ["cholesky"]


def cholesky(a: Buffer | Iterable[float]) -> array:
    """Return the Cholesky factor ``L`` of ``A = L*L^T`` as a new ``array.array("d")``.

    ``a`` holds a symmetric positive definite ``n`` by ``n`` matrix ``A`` in column-major order,
    ``a[i + j*n] = A[i, j]``, so its length is ``n*n``; only the entries on or below the diagonal
    (``i >= j``) are read. The result has the same layout: ``L`` is lower triangular with a
    positive diagonal, and its strict upper triangle is zero. With NumPy, pass
    ``A.ravel(order="F")`` (for a symmetric ``A``, ``A.ravel()`` is the same) and recover ``L``
    with ``np.asarray(L).reshape(n, n, order="F")``. A buffer, such as a NumPy ``float64`` array
    or ``array.array("d")``, is read in place and must be one-dimensional, C-contiguous, aligned
    and of native ``float64``: :class:`TypeError` for another element type, :class:`ValueError`
    otherwise. Any other iterable is first copied into an ``array.array("d")``.

    Column ``j`` is computed after columns ``0`` to ``j - 1``: the pivot
    ``A[j, j] - L[j, 0]**2 - ... - L[j, j-1]**2`` and each ``A[i, j] - L[i, 0]*L[j, 0] - ...``
    subtract the rounded products in that order, ``L[j, j]`` is the correctly rounded square
    root of the pivot, and ``L[i, j]`` the quotient by it.

    Raises :class:`ValueError` for an empty ``a``, for a length that is not a square, and for a
    NaN or infinite entry on or below the diagonal; :class:`SingularError` (a
    :class:`ValueError`) when a pivot is not positive, that is when ``A`` is not positive definite
    to working precision.
    """
    if not isinstance(a, Buffer):
        a = array("d", a)
    out = array("d", bytes(8 * (memoryview(a).nbytes // 8)))
    _diana.cholesky(a, out)
    return out
