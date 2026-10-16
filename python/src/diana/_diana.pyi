from collections.abc import Buffer
from typing import Final

OK: Final[int]
CONTINUE: Final[int]
ERR_ARG: Final[int]
ERR_BRACKET: Final[int]
ERR_MAXITER: Final[int]

class BracketError(ValueError): ...

class Bisection:
    a: float
    b: float
    fa: float
    fb: float
    x: float
    tol: float
    iter: int
    max_iter: int
    status: int
    def __init__(
        self, a: float, b: float, fa: float, fb: float, tol: float = 0.0, max_iter: int = 2100
    ) -> None: ...
    def step(self, fx: float) -> int: ...
    def result(self) -> tuple[float, float]: ...

def version() -> str: ...
def status_str(status: int, /) -> str: ...
def trapezoidal(y: Buffer, h: float) -> float: ...
def simpson(y: Buffer, h: float) -> float: ...
def euler_step(y: Buffer, f: Buffer, h: float, out: Buffer) -> None: ...
