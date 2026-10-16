"""Argument conversion shared by the Python drivers."""

from __future__ import annotations

__all__ = ["real"]


def real(x: object, name: str) -> float:
    """Return ``x`` as a ``float``; ``TypeError`` unless it has ``__float__`` or ``__index__``."""
    if not (hasattr(type(x), "__float__") or hasattr(type(x), "__index__")):
        raise TypeError(f"{name} must be a real number, not {type(x).__name__}")
    return float(x)
