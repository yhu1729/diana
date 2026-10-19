import math
import pickle
import sys
from decimal import Decimal
from fractions import Fraction

import pytest

import diana


def test_sqrt2_tol():
    root = diana.bisection(lambda x: x * x - 2.0, 0.0, 2.0, tol=1e-12)
    assert abs(root - math.sqrt(2.0)) <= 1e-12


def test_sqrt2_adjacent():
    root = diana.bisection(lambda x: x * x - 2.0, 0.0, 2.0)
    ulp = math.nextafter(math.sqrt(2.0), 2.0) - math.sqrt(2.0)
    assert abs(root - math.sqrt(2.0)) <= ulp


def test_cos_fixed_point():
    root = diana.bisection(lambda x: math.cos(x) - x, 0.0, 1.0, tol=1e-10)
    assert abs(math.cos(root) - root) <= 1e-9


def test_state_machine_invariant():
    def f(x):
        return x**3 - x - 1.0

    s = diana.Bisection(1.0, 2.0, f(1.0), f(2.0), 1e-9, 100)
    assert s.status == diana.CONTINUE
    n = 0
    while s.status == diana.CONTINUE:
        a, b = s.a, s.b
        s.step(f(s.x))
        n += 1
        assert a <= s.a <= s.b <= b
        assert (s.fa <= 0.0 <= s.fb) or (s.fb <= 0.0 <= s.fa)
    assert s.status == diana.OK
    assert s.iter == n
    root, width = s.result()
    assert 0.0 <= width <= 1e-9
    assert abs(f(root)) < 1e-8


def test_exact_hit():
    assert diana.bisection(lambda x: x - 0.5, 0.0, 1.0) == 0.5
    assert diana.bisection(lambda x: x, 0.0, 1.0) == 0.0


def test_bracket_error():
    with pytest.raises(diana.BracketError):
        diana.bisection(lambda x: x * x + 1.0, 0.0, 1.0)
    assert issubclass(diana.BracketError, ValueError)


def test_arg_error():
    with pytest.raises(ValueError):
        diana.bisection(lambda x: x, 1.0, 0.0)
    with pytest.raises(ValueError):
        diana.bisection(lambda x: x, 0.0, 1.0, tol=-1.0)
    with pytest.raises(ValueError):
        diana.bisection(lambda x: math.nan, 0.0, 1.0)
    with pytest.raises(ValueError):
        diana.Bisection(0.0, 1.0, -1.0, 1.0, 0.0, 0)


def test_max_iter_range():
    with pytest.raises(OverflowError):
        diana.Bisection(0.0, 1.0, -1.0, 1.0, 0.0, -1)
    with pytest.raises(OverflowError):
        diana.Bisection(0.0, 1.0, -1.0, 1.0, 0.0, 2**32)
    with pytest.raises(TypeError):
        diana.Bisection(0.0, 1.0, -1.0, 1.0, 0.0, 2.5)
    with pytest.raises(OverflowError):
        diana.bisection(lambda x: x - 0.3, 0.0, 1.0, max_iter=-1)
    assert diana.Bisection(0.0, 1.0, -1.0, 1.0, 0.0, max_iter=7).max_iter == 7


def test_real_number_argument():
    def f(x):
        return Fraction(x) - Fraction(1, 2)

    assert diana.bisection(f, Fraction(0), Decimal(1), tol=Fraction(0)) == 0.5


@pytest.mark.parametrize(
    ("args", "kwargs", "match"),
    [
        (("0", 1.0), {}, "a must be a real number, not str"),
        ((0.0, "1"), {}, "b must be a real number, not str"),
        ((0.0, 1.0), {"tol": "0"}, "tol must be a real number, not str"),
    ],
)
def test_string_argument(args, kwargs, match):
    with pytest.raises(TypeError, match=match):
        diana.bisection(lambda x: x - 0.5, *args, **kwargs)


def test_string_callback_value():
    with pytest.raises(TypeError, match=r"f\(a\) must be a real number, not str"):
        diana.bisection(lambda x: str(x - 0.5), 0.0, 1.0)
    with pytest.raises(TypeError, match=r"f\(x\) must be a real number, not str"):
        diana.bisection(lambda x: str(x) if x == 0.5 else x - 0.3, 0.0, 1.0)


def test_callback_sees_kernel_endpoint():
    calls = []

    def f(x):
        calls.append(x)
        return x - 0.3

    diana.bisection(f, 0, 1)
    assert calls[:3] == [0.0, 1.0, 0.5]
    assert all(type(x) is float for x in calls)


def test_max_iter():
    with pytest.raises(diana.MaxIterError) as info:
        diana.bisection(lambda x: x * x - 2.0, 0.0, 2.0, tol=1e-12, max_iter=5)
    assert info.value.iter == 5
    assert abs(info.value.estimate - math.sqrt(2.0)) <= 2.0 / 2**5


def test_default_max_iter_worst_case():
    m = sys.float_info.max / 2
    tiny = math.ulp(0.0)
    s = diana.Bisection(-m, m, -m - tiny, m - tiny)
    assert s.max_iter == 2100
    while s.status == diana.CONTINUE:
        s.step(s.x - tiny)
    assert s.status == diana.OK
    assert s.iter == 2098
    assert abs(diana.bisection(lambda x: x - tiny, -m, m) - tiny) <= tiny


def test_max_iter_error_pickle():
    err = diana.MaxIterError(1.5, 0.25, 7)
    restored = pickle.loads(pickle.dumps(err))
    assert type(restored) is diana.MaxIterError
    assert (restored.estimate, restored.uncertainty, restored.iter) == (1.5, 0.25, 7)
    assert str(restored) == str(err) == "iteration limit 7 reached; estimate 1.5, uncertainty 0.25"


def test_step_after_finish():
    s = diana.Bisection(0.0, 1.0, -1.0, 1.0, 1.0, 10)
    assert s.status == diana.OK
    with pytest.raises(RuntimeError):
        s.step(0.0)


def test_uninitialized_state():
    s = diana.Bisection.__new__(diana.Bisection)
    assert s.status == diana.ERR_ARG
    with pytest.raises(RuntimeError, match="not initialized"):
        s.result()
    with pytest.raises(RuntimeError, match="not initialized"):
        s.step(0.0)
    with pytest.raises(RuntimeError, match="not initialized"):
        s.step(object())


@pytest.mark.parametrize(
    ("args", "error"),
    [
        ((), TypeError),
        ((0.0, 1.0, -1.0, 1.0, 0.0, 0), ValueError),
        ((0.0, 1.0, 1.0, 1.0), diana.BracketError),
    ],
)
def test_failed_initialization(args, error):
    s = diana.Bisection.__new__(diana.Bisection)
    with pytest.raises(error):
        s.__init__(*args)
    assert s.status == diana.ERR_ARG
    with pytest.raises(RuntimeError, match="not initialized"):
        s.result()
    with pytest.raises(RuntimeError, match="not initialized"):
        s.step(0.0)

    s.__init__(0.0, 1.0, -1.0, 1.0)
    assert s.status == diana.CONTINUE
    assert s.result() == (0.5, 1.0)
    assert s.step(0.0) == diana.OK
    assert s.result() == (0.5, 0.0)


@pytest.mark.parametrize(
    ("args", "error"),
    [
        ((), TypeError),
        ((0.0, 1.0, -1.0, 1.0, 0.0, 0), ValueError),
        ((0.0, 1.0, 1.0, 1.0), diana.BracketError),
    ],
)
def test_failed_reinitialization_preserves_state(args, error):
    s = diana.Bisection(0.0, 1.0, -0.25, 0.75)
    assert s.step(s.x - 0.25) == diana.CONTINUE
    before = (s.a, s.b, s.fa, s.fb, s.x, s.tol, s.iter, s.max_iter, s.status, s.result())
    with pytest.raises(error):
        s.__init__(*args)
    after = (s.a, s.b, s.fa, s.fb, s.x, s.tol, s.iter, s.max_iter, s.status, s.result())
    assert after == before
    assert s.step(s.x - 0.25) == diana.OK
    assert s.result() == (0.25, 0.0)


def test_callback_exception_propagates():
    class Boom(Exception):
        pass

    def f(x):
        if x == 0.5:
            raise Boom
        return x - 0.3

    with pytest.raises(Boom):
        diana.bisection(f, 0.0, 1.0)


def test_nonfinite_callback():
    with pytest.raises(ValueError):
        diana.bisection(lambda x: math.inf if x == 0.5 else x - 0.3, 0.0, 1.0)


@pytest.mark.parametrize("fx", [math.nan, math.inf, -math.inf])
def test_step_nonfinite_keeps_state(fx):
    s = diana.Bisection(0.0, 1.0, -1.0, 1.0, 0.0)
    before = (s.a, s.b, s.fa, s.fb, s.iter, s.status, s.result())
    with pytest.raises(ValueError, match="f\\(x\\) must be finite") as info:
        s.step(fx)
    assert not isinstance(info.value, diana.FloatOverflowError)
    assert (s.a, s.b, s.fa, s.fb, s.iter, s.status, s.result()) == before
    assert s.step(-0.1) == diana.CONTINUE
    assert s.a == 0.5
