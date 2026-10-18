"""LU driver: factors a matrix with the C kernel ``diana._diana.lu``."""

from __future__ import annotations

from array import array
from collections.abc import Buffer, Iterable

from diana import _diana

__all__ = ["lu"]


def lu(a: Buffer | Iterable[float]) -> tuple[array, list[int]]:
    """Return ``(lu, piv)``, the LU factorization ``P*A = L*U`` with partial pivoting.

    ``a`` holds an ``n`` by ``n`` matrix ``A`` in column-major order, ``a[i + j*n] = A[i, j]``,
    so its length is ``n*n``. ``lu`` is a new ``array.array("d")`` in the same layout holding
    ``L`` strictly below the diagonal (its diagonal of ones is not stored) and ``U`` on and above
    it. ``piv`` lists the row interchanges: at step ``k``, rows ``k`` and ``piv[k] >= k`` were
    swapped, so applying the swaps in order to the rows of ``A`` (or of a right-hand side) gives
    ``P*A``. With NumPy, pass ``A.ravel(order="F")``, recover
    ``F = np.asarray(lu).reshape(n, n, order="F")``, ``L = np.tril(F, -1) + np.eye(n)`` and
    ``U = np.triu(F)``. A buffer, such as a NumPy ``float64`` array or ``array.array("d")``, is
    read in place and must be one-dimensional, C-contiguous, aligned and of native ``float64``:
    :class:`TypeError` for another element type, :class:`ValueError` otherwise. Any other
    iterable is first copied into an ``array.array("d")``.

    Step ``k`` takes as pivot the first entry of largest magnitude in column ``k`` on or below
    the diagonal, swaps its row with row ``k`` across all columns, divides the entries below the
    pivot by it (``|L[i, k]| <= 1``), then subtracts ``L[i, k]*U[k, j]``, the product rounded
    first, from each entry below and right of the pivot.

    Raises :class:`ValueError` for an empty ``a``, for a length that is not a square, for a NaN
    or infinite entry and when an update overflows; :class:`SingularError` (a
    :class:`ValueError`) when every candidate pivot of a column is zero; in exact arithmetic that
    happens exactly when ``A`` is singular.
    """
    if not isinstance(a, Buffer):
        a = array("d", a)
    out = array("d", bytes(8 * (memoryview(a).nbytes // 8)))
    piv = _diana.lu(a, out)
    return out, piv
