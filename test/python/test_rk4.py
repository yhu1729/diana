import array
import ctypes
import math
import random
import sys
from fractions import Fraction

import numpy as np
import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

import diana

DBL_MAX = sys.float_info.max
EPS = sys.float_info.epsilon
TRUE_MIN = math.ulp(0.0)

# Values with few significant bits: every operation is exact.
Y = [1.0, -2.0, 0.5]
K = [3.0, 4.0, -8.0]
HALF = [1.75, -1.0, -1.5]  # y + (1/4) k, stages 2 and 3 with h = 1/2
FULL = [2.5, 0.0, -3.5]  # y + (1/2) k, stage 4 with h = 1/2
SY = [1.0, 0.0, -2.0]
K1 = [6.0, 0.0, 1.0]
K2 = [12.0, 3.0, 2.0]
K3 = [0.0, -3.0, 2.0]
K4 = [6.0, 6.0, 1.0]
STEP = [5.5, 0.75, -0.75]  # h = 3/4: y + s/8


def same(a, b):
    return a == b and math.copysign(1.0, a) == math.copysign(1.0, b)


MAKERS = [
    list,
    tuple,
    iter,
    lambda v: [Fraction(x) for x in v],
    lambda v: array.array("d", v),
    lambda v: np.array(v),
    lambda v: memoryview(array.array("d", v)),
    lambda v: (ctypes.c_double * len(v))(*v),
]
MAKER_IDS = ["list", "tuple", "iterator", "fraction", "array", "numpy", "memoryview", "ctypes"]


@pytest.mark.parametrize("make", MAKERS, ids=MAKER_IDS)
def test_stage_container(make):
    for stage, want in ((2, HALF), (3, HALF), (4, FULL)):
        r = diana.rk4_stage(make(Y), make(K), 0.5, stage)
        assert type(r) is array.array
        assert r.typecode == "d"
        assert [same(a, b) for a, b in zip(r, want, strict=True)] == [True] * 3


@pytest.mark.parametrize("make", MAKERS, ids=MAKER_IDS)
def test_step_container(make):
    r = diana.rk4_step(make(SY), make(K1), make(K2), make(K3), make(K4), 0.75)
    assert type(r) is array.array
    assert r.typecode == "d"
    assert list(r) == STEP


def test_leaves_inputs():
    y, k = np.array(Y), np.array(K)
    diana.rk4_stage(y, k, 0.5, 2)
    assert list(y) == Y and list(k) == K
    args = [np.array(v) for v in (SY, K1, K2, K3, K4)]
    diana.rk4_step(*args, 0.75)
    assert [list(a) for a in args] == [SY, K1, K2, K3, K4]


def test_keyword_and_numeric_arguments():
    assert list(diana.rk4_stage(y=Y, k=K, h=0.5, stage=4)) == FULL
    assert list(diana.rk4_stage(Y, K, np.float64(0.5), np.int64(3))) == HALF
    assert list(diana.rk4_stage([1.0], [3.0], 2, 2)) == [4.0]
    assert list(diana.rk4_step(y=SY, k1=K1, k2=K2, k3=K3, k4=K4, h=0.75)) == STEP
    assert list(diana.rk4_step([0.0], [1.0], [1.0], [1.0], [1.0], 3)) == [3.0]


def test_stage_no_contraction():
    # c * k = 1 - 2^-104 rounds to 1, so the result is +0; a fused multiply-add gives -2^-104.
    assert same(diana.rk4_stage([-1.0], [1.0 - EPS], 1.0 + EPS, 4)[0], 0.0)
    assert same(diana.rk4_stage([-1.0], [1.0 - EPS], 2.0 + 2.0 * EPS, 2)[0], 0.0)


def test_stage_coefficient_rounding():
    # h/2 for h = 3 * 2^-1074 rounds to 2 * 2^-1074 (a tie, to even) before the product.
    assert diana.rk4_stage([0.0], [1024.0], 3 * TRUE_MIN, 2)[0] == 2048 * TRUE_MIN


def test_step_weights_and_order():
    unit = [[1.0, 0.0, 0.0, 0.0], [0.0, 1.0, 0.0, 0.0], [0.0, 0.0, 1.0, 0.0], [0.0, 0.0, 0.0, 1.0]]
    assert list(diana.rk4_step([0.0] * 4, *unit, 6.0)) == [1.0, 2.0, 2.0, 1.0]
    # (k1 + k4) + 2 (k2 + k3) = 1 + 2^-52: k1 + k4 = 1 + 2^-53 ties to 1. Left to right gives 1.
    r = diana.rk4_step([0.0], [1.0], [EPS / 4], [EPS / 4], [EPS / 2], 6.0)
    assert r[0] == 1.0 + EPS


def test_zero_step_and_underflow():
    y = [-0.0, 2.0, 0.0]
    k = [-3.0, 5.0, -1.0]
    for stage in (2, 3, 4):
        r = diana.rk4_stage(y, k, 0.0, stage)
        assert [same(a, b) for a, b in zip(r, y, strict=True)] == [True] * 3
    r = diana.rk4_step(y, k, k, k, k, 0.0)
    assert [same(a, b) for a, b in zip(r, y, strict=True)] == [True] * 3
    assert same(diana.rk4_step([0.0], [1.0], [0.0], [0.0], [0.0], TRUE_MIN)[0], 0.0)


@pytest.mark.parametrize(
    ("y", "k", "h", "stage"),
    [
        ([math.nan, 1.0], [1.0, 1.0], 1.0, 2),
        ([1.0, math.inf], [1.0, 1.0], 1.0, 3),
        ([1.0, 1.0], [1.0, -math.inf], 1.0, 4),
        ([1.0, 1.0], [1.0, 1.0], math.nan, 2),
        ([1.0, 1.0], [1.0, 1.0], math.inf, 4),
        ([1.0], [math.inf], 0.0, 4),
        ([math.inf], [-math.inf], 2.0, 2),
        # the first component overflows, a later input is not finite
        ([DBL_MAX, 1.0, math.nan], [DBL_MAX, 1.0, 1.0], 2.0, 3),
        ([DBL_MAX, 1.0, 1.0], [DBL_MAX, 1.0, math.inf], 2.0, 2),
    ],
)
def test_stage_nonfinite(y, k, h, stage):
    with pytest.raises(ValueError, match="input is not finite") as info:
        diana.rk4_stage(y, k, h, stage)
    assert not isinstance(info.value, diana.FloatOverflowError)


@pytest.mark.parametrize(
    ("y", "k", "h", "stage"),
    [
        ([0.0], [DBL_MAX], 2.0, 4),
        ([0.0], [4.0], DBL_MAX, 2),
        ([DBL_MAX], [DBL_MAX], 2.0, 3),
        ([1.0, 2.0, DBL_MAX], [1.0, 1.0, DBL_MAX], 2.0, 4),
        ([DBL_MAX, 1.0, 1.0], [DBL_MAX, 1.0, 1.0], 2.0, 2),
    ],
)
def test_stage_overflow(y, k, h, stage):
    with pytest.raises(diana.FloatOverflowError, match="result overflows"):
        diana.rk4_stage(y, k, h, stage)


@pytest.mark.parametrize(
    ("y", "k1", "k2", "k3", "k4", "h"),
    [
        ([math.nan], [1.0], [1.0], [1.0], [1.0], 1.0),
        ([1.0], [math.inf], [1.0], [1.0], [1.0], 1.0),
        ([1.0], [1.0], [math.nan], [1.0], [1.0], 1.0),
        ([1.0], [1.0], [1.0], [-math.inf], [1.0], 1.0),
        ([1.0], [1.0], [1.0], [1.0], [math.nan], 1.0),
        ([1.0], [1.0], [1.0], [1.0], [1.0], math.inf),
        ([0.0], [math.inf], [0.0], [0.0], [0.0], 0.0),
    ],
)
def test_step_nonfinite(y, k1, k2, k3, k4, h):
    with pytest.raises(ValueError, match="input is not finite") as info:
        diana.rk4_step(y, k1, k2, k3, k4, h)
    assert not isinstance(info.value, diana.FloatOverflowError)


@pytest.mark.parametrize(
    ("y", "k1", "k2", "k3", "k4", "h"),
    [
        ([0.0], [0.0], [DBL_MAX], [DBL_MAX], [0.0], 1.0),
        ([0.0], [0.0], [DBL_MAX], [0.0], [0.0], 1.0),
        ([0.0], [DBL_MAX], [DBL_MAX / 2], [0.0], [0.0], 1.0),
        ([0.0], [DBL_MAX], [0.0], [0.0], [0.0], 2.0),
        ([DBL_MAX], [2.0**1020], [0.0], [0.0], [0.0], 6.0),
        ([1.0, 2.0, DBL_MAX], [1.0, 1.0, DBL_MAX], [0.0] * 3, [0.0] * 3, [0.0] * 3, 1.0),
    ],
)
def test_step_overflow(y, k1, k2, k3, k4, h):
    with pytest.raises(diana.FloatOverflowError, match="result overflows"):
        diana.rk4_step(y, k1, k2, k3, k4, h)


@pytest.mark.parametrize("position", range(5))
def test_step_overflow_then_nonfinite(position):
    # The first component overflows with finite inputs; a NaN later in any argument makes the
    # failure a non-finite input.
    args = [[DBL_MAX, 1.0, 1.0], [DBL_MAX, 1.0, 1.0], [0.0] * 3, [0.0] * 3, [0.0] * 3]
    with pytest.raises(diana.FloatOverflowError):
        diana.rk4_step(*args, 6.0)
    args[position][2] = math.nan
    with pytest.raises(ValueError, match="input is not finite") as info:
        diana.rk4_step(*args, 6.0)
    assert not isinstance(info.value, diana.FloatOverflowError)


@pytest.mark.parametrize(
    ("last", "error"),
    [(1.0, diana.FloatOverflowError), (math.nan, ValueError)],
    ids=["overflow", "nonfinite"],
)
def test_failure_leaves_out(last, error):
    y = array.array("d", [DBL_MAX, 2.0, last])
    k = array.array("d", [DBL_MAX, 1.0, 1.0])
    out = array.array("d", [42.0] * 3)
    with pytest.raises(error) as info:
        diana._diana.rk4_stage(y, k, 2.0, 4, out)
    assert info.type is error
    assert list(out) == [42.0] * 3
    with pytest.raises(error) as info:
        diana._diana.rk4_step(y, k, k, k, k, 1.0, out)
    assert info.type is error
    assert list(out) == [42.0] * 3


@pytest.mark.parametrize("stage", [1, 5, 0, -2, True, 2**40])
def test_stage_bad_number(stage):
    error = OverflowError if stage == 2**40 else ValueError
    with pytest.raises(error):
        diana.rk4_stage(Y, K, 1.0, stage)


@pytest.mark.parametrize("stage", [2.0, "2", None])
def test_stage_number_type(stage):
    with pytest.raises(TypeError):
        diana.rk4_stage(Y, K, 1.0, stage)


@pytest.mark.parametrize(
    ("y", "k", "match"),
    [
        ([], [], "y must have at least one sample"),
        ([1.0], [], "k must have at least one sample"),
        ([1.0, 2.0], [1.0], "y and k must have the same length"),
        (np.ones((2, 2)), [1.0], "y must be one-dimensional"),
        ([1.0, 2.0], np.ones((2, 1)), "k must be one-dimensional"),
        (np.arange(4.0)[::2], [1.0, 1.0], "y must be C-contiguous"),
        (
            [1.0, 1.0],
            np.frombuffer(bytearray(8 * 2 + 1), dtype=np.float64, offset=1),
            "k is not aligned",
        ),
    ],
)
def test_stage_bad_shape(y, k, match):
    with pytest.raises(ValueError, match=match):
        diana.rk4_stage(y, k, 1.0, 2)


@pytest.mark.parametrize("position", range(5))
def test_step_bad_shape(position):
    name = ["y", "k1", "k2", "k3", "k4"][position]
    args = [[1.0, 2.0] for _ in range(5)]
    args[position] = []
    with pytest.raises(ValueError, match=f"{name} must have at least one sample"):
        diana.rk4_step(*args, 1.0)
    args[position] = [1.0]
    with pytest.raises(ValueError, match="y, k1, k2, k3 and k4 must have the same length"):
        diana.rk4_step(*args, 1.0)
    args[position] = np.arange(4.0)[::2]
    with pytest.raises(ValueError, match=f"{name} must be C-contiguous"):
        diana.rk4_step(*args, 1.0)
    args[position] = np.ones(2, dtype=np.float32)
    with pytest.raises(TypeError, match=f"{name} must be a buffer of native float64"):
        diana.rk4_step(*args, 1.0)


@pytest.mark.parametrize(
    ("y", "k", "match"),
    [
        (np.ones(2, dtype=np.float32), [1.0, 1.0], "y must be a buffer of native float64"),
        ([1.0, 1.0], np.ones(2, dtype=np.int64), "k must be a buffer of native float64"),
    ],
)
def test_stage_wrong_dtype(y, k, match):
    with pytest.raises(TypeError, match=match):
        diana.rk4_stage(y, k, 1.0, 2)


@pytest.mark.parametrize(
    ("y", "k", "h"),
    [(1.0, [1.0], 1.0), ([1.0], None, 1.0), (["a"], [1.0], 1.0), ([1.0], [1.0], "1")],
)
def test_wrong_argument_type(y, k, h):
    with pytest.raises(TypeError):
        diana.rk4_stage(y, k, h, 2)
    with pytest.raises(TypeError):
        diana.rk4_step(y, k, k, k, k, h)


def test_extension_checks_out():
    y = array.array("d", [1.0, 2.0, 3.0, 4.0])
    k = array.array("d", [1.0, 1.0, 1.0, 1.0])
    with pytest.raises(BufferError):
        diana._diana.rk4_stage(y, k, 1.0, 2, bytes(32))
    with pytest.raises(BufferError):
        diana._diana.rk4_step(y, k, k, k, k, 1.0, bytes(32))
    for call in (
        lambda out: diana._diana.rk4_stage(y, k, 2.0, 4, out),
        lambda out: diana._diana.rk4_step(y, k, k, k, k, 2.0, out),
    ):
        with pytest.raises(ValueError, match="out must have at least one sample"):
            call(array.array("d"))
        with pytest.raises(ValueError, match="out must have the same length as y"):
            call(array.array("d", [0.0, 0.0]))
        with pytest.raises(ValueError, match="overlap"):
            call(y)
        with pytest.raises(ValueError, match="overlap"):
            call(k)
        out = array.array("d", [0.0] * 4)
        assert call(out) is None
        assert list(out) == [3.0, 4.0, 5.0, 6.0]
    data = np.zeros(6)
    with pytest.raises(ValueError, match="overlap"):
        diana._diana.rk4_stage(data[:4], k, 1.0, 2, data[2:])
    for position in range(5):
        data = np.zeros(6)
        args = [k] * 5
        args[position] = data[:4]
        with pytest.raises(ValueError, match="out must not overlap y or a slope"):
            diana._diana.rk4_step(*args, 1.0, data[2:])


def same_length(count):
    return st.integers(1, 20).flatmap(
        lambda n: st.tuples(*[st.lists(st.floats(), min_size=n, max_size=n)] * count)
    )


@settings(database=None, derandomize=True, max_examples=500)
@given(same_length(2), st.floats(), st.sampled_from([2, 3, 4]))
def test_stage_matches_binary64(yk, h, stage):
    y, k = yk
    c = h if stage == 4 else 0.5 * h
    want = [a + c * b for a, b in zip(y, k, strict=True)]
    if all(math.isfinite(v) for v in want):
        r = diana.rk4_stage(y, k, h, stage)
        assert all(same(a, b) for a, b in zip(r, want, strict=True))
    elif all(math.isfinite(v) for v in [*y, *k, h]):
        with pytest.raises(diana.FloatOverflowError, match="overflows"):
            diana.rk4_stage(y, k, h, stage)
    else:
        with pytest.raises(ValueError, match="input is not finite") as info:
            diana.rk4_stage(y, k, h, stage)
        assert not isinstance(info.value, diana.FloatOverflowError)


@settings(database=None, derandomize=True, max_examples=500)
@given(same_length(5), st.floats())
def test_step_matches_binary64(v, h):
    want = [y + h * ((a + e) + 2.0 * (b + c)) / 6.0 for y, a, b, c, e in zip(*v, strict=True)]
    if all(math.isfinite(x) for x in want):
        r = diana.rk4_step(*v, h)
        assert all(same(a, b) for a, b in zip(r, want, strict=True))
    elif math.isfinite(h) and all(math.isfinite(x) for a in v for x in a):
        with pytest.raises(diana.FloatOverflowError, match="overflows"):
            diana.rk4_step(*v, h)
    else:
        with pytest.raises(ValueError, match="input is not finite") as info:
            diana.rk4_step(*v, h)
        assert not isinstance(info.value, diana.FloatOverflowError)


U = Fraction(1, 2**53)
ETA = Fraction(1, 2**1075)


def draw(rng, low, high, n):
    return [rng.uniform(-1.0, 1.0) * 2.0 ** rng.randint(low, high) for _ in range(n)]


def test_stage_rounding_error_bound():
    # RK4-B2/B3 per component: |r - (y + c k)| <= u |y + c k| + (1 + u)(u |c k| + eta)
    # + (1 + u)^2 |fl(c) - c| |k|, with fl(c) - c = 0 for |h| >= 2^-1021.
    rng = random.Random(1729)
    for low, high in ((-40, 40), (-1074, -1000)):
        y = draw(rng, low, high, 500)
        k = draw(rng, low, high, 500)
        for h in (rng.uniform(-1.0, 1.0), 3 * TRUE_MIN, -7 * TRUE_MIN):
            for stage in (2, 4):
                c = Fraction(h) if stage == 4 else Fraction(h) / 2
                ct = Fraction(h if stage == 4 else 0.5 * h)
                assert abs(ct - c) <= ETA
                r = diana.rk4_stage(y, k, h, stage)
                for ri, yi, ki in zip(r, y, k, strict=True):
                    exact = Fraction(yi) + c * Fraction(ki)
                    bound = (
                        U * abs(exact)
                        + (1 + U) * (U * abs(c * Fraction(ki)) + ETA)
                        + (1 + U) ** 2 * abs(ct - c) * abs(Fraction(ki))
                    )
                    assert abs(Fraction(ri) - exact) <= bound


def test_step_rounding_error_bound():
    # RK4-B5 per component: |r - T| <= u |T| + (1 + u)(g4 |h| A / 6 + (1 + u) eta / 6 + eta).
    g4 = 4 * U / (1 - 4 * U)
    rng = random.Random(1729)
    for low, high in ((-40, 40), (-1074, -1000)):
        y, k1, k2, k3, k4 = (draw(rng, low, high, 500) for _ in range(5))
        h = rng.uniform(-1.0, 1.0)
        r = diana.rk4_step(y, k1, k2, k3, k4, h)
        for ri, yi, a, b, c, e in zip(r, y, k1, k2, k3, k4, strict=True):
            a, b, c, e = (Fraction(x) for x in (a, b, c, e))
            exact = Fraction(yi) + Fraction(h) * (a + 2 * b + 2 * c + e) / 6
            big_a = abs(a + e) + 2 * abs(b + c)
            bound = U * abs(exact) + (1 + U) * (
                g4 * abs(Fraction(h)) * big_a / 6 + (1 + U) * ETA / 6 + ETA
            )
            assert abs(Fraction(ri) - exact) <= bound


def test_rk4_exact_paths():
    # y' = -y with h = 1 multiplies by 3/8; the rotation with h = 6 applies 37 I - 30 A.
    assert list(diana.rk4(lambda t, y: [-v for v in y], 0.0, [64.0, -8.0], 1.0, 3)) == [
        3.375,
        -0.421875,
    ]
    assert list(diana.rk4(lambda t, y: (y[1], -y[0]), 0.0, [1.0, 0.0], 6.0, 2)) == [469.0, 2220.0]


def test_rk4_times_and_copy():
    times = []

    def ramp(t, y):
        times.append(t)
        return [t]

    y0 = np.array([0.0])
    r = diana.rk4(ramp, 1, y0, 0.25, 2)
    assert times == [1.0, 1.125, 1.125, 1.25, 1.25, 1.375, 1.375, 1.5]
    assert list(r) == [0.625]
    assert list(y0) == [0.0]


def test_rk4_matches_stages():
    def f(t, y):
        return [t * y[1] - y[0], math.sin(t) + y[0] * y[1]]

    t0, h, y = 0.25, 0.1, array.array("d", [1.0, -0.5])
    want = y
    for n in range(3):
        t = t0 + n * h
        k1 = f(t, want)
        k2 = f(t0 + (n + 0.5) * h, diana.rk4_stage(want, k1, h, 2))
        k3 = f(t0 + (n + 0.5) * h, diana.rk4_stage(want, k2, h, 3))
        k4 = f(t0 + (n + 1) * h, diana.rk4_stage(want, k3, h, 4))
        want = diana.rk4_step(want, k1, k2, k3, k4, h)
    assert diana.rk4(f, t0, y, h, 3) == want


def test_rk4_reused_output_buffer():
    # f returns the same NumPy array on every call; the driver copies each slope.
    out = np.empty(2)

    def rotate(t, y):
        out[0], out[1] = y[1], -y[0]
        return out

    assert list(diana.rk4(rotate, 0.0, [1.0, 0.0], 6.0, 2)) == [469.0, 2220.0]


def test_rk4_bytes_initial_state():
    def zero(t, y):
        return [0.0] * len(y)

    assert list(diana.rk4(zero, 0.0, bytes([1, 2]), 1.0, 0)) == [1.0, 2.0]
    assert list(diana.rk4(zero, 0.0, bytearray(16), 1.0, 1)) == [0.0] * 16


def test_rk4_no_step():
    r = diana.rk4(lambda t, y: pytest.fail("f called"), 0.0, [2.0, 3.0], 1.0, 0)
    assert type(r) is array.array
    assert list(r) == [2.0, 3.0]


@pytest.mark.parametrize(
    ("args", "error", "match"),
    [
        ((0.0, [1.0], 1.0, -1), ValueError, "non-negative"),
        ((0.0, [], 1.0, 1), ValueError, "y0 must have at least one sample"),
        ((0.0, [1.0], 1.0, 1.5), TypeError, None),
        ((0.0, [1.0], "1", 1), TypeError, "h must be a real number"),
        (("0", [1.0], 1.0, 1), TypeError, "t0 must be a real number"),
    ],
)
def test_rk4_arguments(args, error, match):
    with pytest.raises(error, match=match):
        diana.rk4(lambda t, y: list(y), *args)


def test_rk4_index_argument():
    class Index:
        def __index__(self):
            return 2

    assert list(diana.rk4_stage([1.0], [1.0], Index(), Index())) == [2.0]
    assert list(diana.rk4(lambda t, y: [1.0], Index(), [0.0], Index(), 1)) == [2.0]


@pytest.mark.parametrize("fail", range(4))
def test_rk4_callback_errors(fail):
    calls = []

    def blow(t, y):
        calls.append(t)
        return [math.inf] if len(calls) == fail + 1 else [1.0]

    with pytest.raises(ValueError, match="not finite") as info:
        diana.rk4(blow, 0.0, [0.0], 1.0, 5)
    assert not isinstance(info.value, diana.FloatOverflowError)
    assert len(calls) == fail + 1


def test_rk4_overflow():
    # y' = y from DBL_MAX / 2 with h = 1: the stage 4 point y + k3 = (11/8) DBL_MAX overflows.
    with pytest.raises(diana.FloatOverflowError, match="RK4 stage result overflows"):
        diana.rk4(lambda t, y: list(y), 0.0, [DBL_MAX / 2], 1.0, 1)


def test_rk4_callback_length():
    with pytest.raises(ValueError, match="same length"):
        diana.rk4(lambda t, y: [1.0, 2.0], 0.0, [1.0], 1.0, 1)


def test_rk4_rotation_convergence():
    # y' = (y2, -y1), y(0) = (0, 1): y(t) = (sin t, cos t). The error at t = 1 is fourth order,
    # C h^4 + O(h^5) with C about 0.007: halving h divides it by 16 up to an O(h) correction,
    # measured 15.38, 15.71, 15.86, 15.93 for n = 16 to 128. Rounding (about n u, below 3e-14)
    # is at most 1e-3 of the smallest error here, about 2.6e-11; the test allows 0.7.
    error = []
    for n in (8, 16, 32, 64, 128):
        h = 1.0 / n
        y = diana.rk4(lambda t, y: (y[1], -y[0]), 0.0, [0.0, 1.0], h, n)
        error.append(max(abs(y[0] - math.sin(1.0)), abs(y[1] - math.cos(1.0))))
    for coarse, fine in zip(error, error[1:], strict=False):
        assert abs(coarse / fine - 16) < 0.7
