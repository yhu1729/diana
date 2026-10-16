import math
import sys
from decimal import Decimal
from fractions import Fraction

import pytest

import diana


def sq(x):
    return x * x - 2.0, 2.0 * x


def test_sqrt2_tol():
    root = diana.newton(sq, 2.0, 1e-12)
    assert abs(root - math.sqrt(2.0)) <= 1e-12


def test_cbrt10():
    assert diana.newton(lambda x: (x**3 - 10.0, 3.0 * x * x), 2.0, 1e-12) == 2.154434690031884


def test_cos_fixed_point():
    # the fifth iterate satisfies cos(x) == x exactly in binary64
    root = diana.newton(lambda x: (math.cos(x) - x, -math.sin(x) - 1.0), 1.0, 1e-12)
    assert math.cos(root) == root


def test_state_machine_quadratic():
    # f'' = 2 and f' >= 2 sqrt(2) on [sqrt(2), 2]: each error is at most 0.354 times the square
    # of the previous one while the iterate stays above the root
    s = diana.Newton(2.0, 1e-12)
    assert s.status == diana.CONTINUE
    assert (s.x, s.dx, s.tol, s.iter, s.max_iter) == (2.0, 0.0, 1e-12, 0, 100)
    prev = abs(2.0 - math.sqrt(2.0))
    n = 0
    while s.status == diana.CONTINUE:
        s.step(*sq(s.x))
        n += 1
        err = abs(s.x - math.sqrt(2.0))
        if n <= 5:
            assert err <= 0.36 * prev * prev
        prev = err
    assert s.status == diana.OK
    assert s.iter == n == 6
    root, dx = s.result()
    assert root == s.x and dx == s.dx
    assert 0.0 < abs(dx) <= 1e-12


def test_exact_hit():
    assert diana.newton(lambda x: (x - 0.5, 1.0), 0.0, 0.0) == 0.5
    s = diana.Newton(3.0, 0.0)
    assert s.step(0.0, 0.0) == diana.OK
    assert s.result() == (3.0, 0.0)
    assert s.iter == 1


def test_stagnation():
    s = diana.Newton(1.0, 0.0)
    assert s.step(-0.5 * sys.float_info.epsilon, 1.0) == diana.OK
    assert s.result() == (1.0, -0.5 * sys.float_info.epsilon)


def test_two_cycle_at_zero_tol():
    with pytest.raises(diana.MaxIterError) as info:
        diana.newton(sq, 2.0, 0.0)
    assert info.value.iter == 100
    assert abs(info.value.estimate - math.sqrt(2.0)) <= math.ulp(math.sqrt(2.0))
    assert 0.0 < info.value.width < math.ulp(1.0)


def test_double_root():
    s = diana.Newton(1.0, 1e-6)
    while s.status == diana.CONTINUE:
        s.step(s.x * s.x, 2.0 * s.x)
    assert s.status == diana.OK
    assert (s.iter, s.x, s.dx) == (20, 2.0**-20, 2.0**-20)


def test_max_iter():
    with pytest.raises(diana.MaxIterError) as info:
        diana.newton(sq, 2.0, 1e-12, max_iter=3)
    assert info.value.iter == 3
    assert info.value.estimate == 1.4142156862745099
    assert 0.0 < info.value.width < 0.003


def test_default_max_iter():
    assert diana.Newton(0.0, 0.0).max_iter == 100


def test_tol_required():
    with pytest.raises(TypeError):
        diana.newton(sq, 2.0)
    with pytest.raises(TypeError):
        diana.Newton(2.0)


@pytest.mark.parametrize(
    ("f", "x0", "match"),
    [
        (lambda x: (math.nan, 1.0), 0.0, "must be finite"),
        (lambda x: (1.0, math.inf), 0.0, "must be finite"),
        (lambda x: (1.0, 0.0), 0.0, "is zero"),
        (lambda x: (-1.0, -0.0), 0.0, "is zero"),
        (lambda x: (sys.float_info.max, 0.5), 0.0, "step is not finite"),
        (lambda x: (sys.float_info.max, 1.0), -sys.float_info.max, "step is not finite"),
    ],
)
def test_step_error(f, x0, match):
    with pytest.raises(ValueError, match=match):
        diana.newton(f, x0, 0.0)


def test_init_error():
    with pytest.raises(ValueError):
        diana.Newton(math.nan, 0.0)
    with pytest.raises(ValueError):
        diana.Newton(0.0, math.inf)
    with pytest.raises(ValueError):
        diana.Newton(0.0, -1.0)
    with pytest.raises(ValueError):
        diana.Newton(0.0, 1.0, 0)
    assert diana.Newton(0.0, -0.0).tol == 0.0


def test_max_iter_range():
    with pytest.raises(OverflowError):
        diana.Newton(0.0, 0.0, -1)
    with pytest.raises(OverflowError):
        diana.Newton(0.0, 0.0, 2**32)
    with pytest.raises(TypeError):
        diana.Newton(0.0, 0.0, 2.5)
    with pytest.raises(OverflowError):
        diana.newton(sq, 2.0, 1e-12, max_iter=-1)
    assert diana.Newton(0.0, 0.0, max_iter=7).max_iter == 7


def test_string_argument():
    with pytest.raises(TypeError):
        diana.newton(sq, "2", 1e-12)
    with pytest.raises(TypeError):
        diana.newton(sq, 2.0, "0")
    with pytest.raises(TypeError):
        diana.newton(lambda x: ("1", 1.0), 2.0, 1e-12)
    with pytest.raises(TypeError):
        diana.Newton(2.0, 1e-12).step(1.0, "2")


def test_real_number_argument():
    def f(x):
        return Fraction(x) - Fraction(1, 2), Fraction(1)

    assert diana.newton(f, Fraction(0), Decimal(0)) == 0.5


def test_callback_shape():
    with pytest.raises(TypeError):
        diana.newton(lambda x: x - 0.5, 0.0, 0.0)
    with pytest.raises(ValueError):
        diana.newton(lambda x: (x - 0.5, 1.0, 2.0), 0.0, 0.0)


def test_callback_sees_kernel_iterate():
    calls = []

    def f(x):
        calls.append(x)
        return x - 0.5, 1.0

    diana.newton(f, 0, 0)
    assert calls == [0.0, 0.5]
    assert all(type(x) is float for x in calls)


def test_error_keeps_state():
    s = diana.Newton(1.0, 0.0)
    assert s.step(-1.0, 1.0) == diana.CONTINUE
    before = (s.x, s.dx, s.tol, s.iter, s.max_iter, s.status, s.result())
    for fx, dfx in [(math.nan, 1.0), (1.0, math.nan), (1.0, 0.0), (sys.float_info.max, 0.5)]:
        with pytest.raises(ValueError):
            s.step(fx, dfx)
    assert (s.x, s.dx, s.tol, s.iter, s.max_iter, s.status, s.result()) == before
    assert s.step(0.0, 1.0) == diana.OK
    assert s.result() == (2.0, 0.0)


def test_step_after_finish():
    s = diana.Newton(3.0, 0.0)
    assert s.step(0.0, 1.0) == diana.OK
    with pytest.raises(RuntimeError):
        s.step(0.0, 1.0)


def test_uninitialized_state():
    s = diana.Newton.__new__(diana.Newton)
    assert s.status == diana.ERR_ARG
    with pytest.raises(RuntimeError, match="not initialized"):
        s.result()
    with pytest.raises(RuntimeError, match="not initialized"):
        s.step(0.0, 1.0)
    with pytest.raises(RuntimeError, match="not initialized"):
        s.step(object(), 1.0)


@pytest.mark.parametrize(
    ("args", "error"),
    [
        ((), TypeError),
        ((0.0, -1.0), ValueError),
        ((math.inf, 0.0), ValueError),
        ((0.0, 0.0, 0), ValueError),
    ],
)
def test_failed_initialization(args, error):
    s = diana.Newton.__new__(diana.Newton)
    with pytest.raises(error):
        s.__init__(*args)
    assert s.status == diana.ERR_ARG
    with pytest.raises(RuntimeError, match="not initialized"):
        s.result()
    with pytest.raises(RuntimeError, match="not initialized"):
        s.step(0.0, 1.0)

    s.__init__(0.0, 0.0)
    assert s.status == diana.CONTINUE
    assert s.result() == (0.0, 0.0)
    assert s.step(0.0, 1.0) == diana.OK


@pytest.mark.parametrize(
    ("args", "error"),
    [
        ((), TypeError),
        ((0.0, -1.0), ValueError),
        ((math.inf, 0.0), ValueError),
        ((0.0, 0.0, 0), ValueError),
    ],
)
def test_failed_reinitialization_preserves_state(args, error):
    s = diana.Newton(1.0, 0.0)
    assert s.step(-1.0, 1.0) == diana.CONTINUE
    before = (s.x, s.dx, s.tol, s.iter, s.max_iter, s.status, s.result())
    with pytest.raises(error):
        s.__init__(*args)
    assert (s.x, s.dx, s.tol, s.iter, s.max_iter, s.status, s.result()) == before
    assert s.step(0.0, 1.0) == diana.OK


def test_callback_exception_propagates():
    class Boom(Exception):
        pass

    def f(x):
        if x == 0.5:
            raise Boom
        return x - 0.5, 1.0

    with pytest.raises(Boom):
        diana.newton(f, 0.0, 0.0)
