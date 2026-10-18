"""LU solve driver: solves ``A*x = b`` from the factors of :func:`lu` with the C kernel
``diana._diana.lu_solve``."""

from __future__ import annotations

from array import array
from collections.abc import Buffer, Iterable

from diana import _diana

__all__ = ["lu_solve"]


def lu_solve(
    lu: Buffer | Iterable[float], piv: Iterable[int], b: Buffer | Iterable[float]
) -> array:
    """Return the solution ``x`` of ``A*x = b`` as a new ``array.array("d")``.

    ``lu`` and ``piv`` are the factorization ``P*A = L*U`` that :func:`lu` returns: ``lu`` holds
    ``L`` strictly below the diagonal (its diagonal of ones is not stored) and ``U`` on and above
    it, in column-major order, so its length is ``n*n`` for the length ``n`` of ``b``; ``piv``
    holds ``n`` pivot rows. So ``lu_solve(*lu(a), b)`` solves ``A*x = b``. A buffer, such as a
    NumPy ``float64`` array or ``array.array("d")``, is read in place and must be
    one-dimensional, C-contiguous, aligned and of native ``float64``: :class:`TypeError` for
    another element type, :class:`ValueError` otherwise. Any other iterable is first copied into
    an ``array.array("d")``. ``piv`` may be any iterable of integers.

    Rows ``k`` and ``piv[k]`` of ``b`` are swapped for ``k = 0, 1, ..., n-1``, giving ``P*b``.
    Then ``y[i] = (P*b)[i] - L[i, 0]*y[0] - ... - L[i, i-1]*y[i-1]`` for ``i = 0, ..., n-1``,
    with no division, and ``x[i] = (y[i] - U[i, n-1]*x[n-1] - ... - U[i, i+1]*x[i+1]) / U[i, i]``
    for ``i = n-1`` down to 0: each product rounded and subtracted in the order its unknown was
    computed.

    Raises :class:`ValueError` for an empty ``b``, for a length of ``lu`` other than ``n*n`` or of
    ``piv`` other than ``n``, for a NaN or infinite entry of ``lu`` or ``b`` and for a pivot row
    that is not below ``n``; :class:`FloatOverflowError` (a :class:`ValueError` and an
    :class:`OverflowError`) when an entry of ``y`` or ``x`` overflows; :class:`OverflowError` for
    a negative pivot row and :class:`TypeError` for one that is not an integer;
    :class:`SingularError` (a :class:`ValueError`) when a diagonal entry of ``U`` is zero, which
    :func:`lu` never returns.
    """
    if not isinstance(lu, Buffer):
        lu = array("d", lu)
    if not isinstance(b, Buffer):
        b = array("d", b)
    out = array("d", bytes(8 * (memoryview(b).nbytes // 8)))
    _diana.lu_solve(lu, piv, b, out)
    return out
