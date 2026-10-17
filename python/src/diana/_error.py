"""Exceptions raised by diana: from the C extension and from the Python drivers."""

from __future__ import annotations

from diana._diana import BracketError, SingularError

__all__ = ["BracketError", "MaxIterError", "SingularError"]


class MaxIterError(RuntimeError):
    """The iteration limit was reached before the tolerance was met.

    ``estimate`` is the current root estimate, ``uncertainty`` what the method knows about its
    error (the bracket width for bisection, the last correction ``|dx|`` for Newton) and
    ``iter`` the number of steps taken.
    """

    def __init__(self, estimate: float, uncertainty: float, iter: int) -> None:
        super().__init__(estimate, uncertainty, iter)
        self.estimate = estimate
        self.uncertainty = uncertainty
        self.iter = iter

    def __str__(self) -> str:
        return (
            f"iteration limit {self.iter} reached; estimate {self.estimate!r}, "
            f"uncertainty {self.uncertainty!r}"
        )
