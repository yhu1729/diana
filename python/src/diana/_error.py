"""Exceptions raised by diana: from the C extension and from the Python drivers."""

from __future__ import annotations

from diana._diana import BracketError

__all__ = ["BracketError", "MaxIterError"]


class MaxIterError(RuntimeError):
    """The iteration limit was reached before the tolerance was met."""

    def __init__(self, estimate: float, width: float, iter: int) -> None:
        super().__init__(estimate, width, iter)
        self.estimate = estimate
        self.width = width
        self.iter = iter

    def __str__(self) -> str:
        return (
            f"iteration limit {self.iter} reached; estimate {self.estimate!r}, width {self.width!r}"
        )
