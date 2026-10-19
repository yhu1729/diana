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
TRUE_MIN = math.ulp(0.0)
NORM = (diana.norm_1, diana.norm_2, diana.norm_inf)
U = Fraction(1, 2**53)
ETA = Fraction(1, 2**1075)

# Small integers: every operation of every norm is exact. In the 2-norm m = 4 at index 1, and
# s = 1 + (3/4)^2 + (1/4)^2 = 1.625, so the result is 4 * fl(sqrt(1.625)).
VECTOR = [3.0, -4.0, 1.0]


def gamma(k):
    return k * U / (1 - k * U)


def sequential_1(x):
    s = 0.0
    for v in x:
        s = s + abs(v)
    return s


def sequential_2(x):
    m = 0.0
    k = 0
    for i, v in enumerate(x):
        if abs(v) > m:
            m = abs(v)
            k = i
    if m == 0.0:
        return 0.0
    s = 1.0
    for i, v in enumerate(x):
        if i != k:
            q = v / m
            s = s + q * q
    return m * math.sqrt(s)


def same(a, b):
    return a == b and math.copysign(1.0, a) == math.copysign(1.0, b)


@pytest.mark.parametrize(
    "make",
    [
        list,
        tuple,
        iter,
        lambda v: [int(x) for x in v],
        lambda v: [Fraction(x) for x in v],
        lambda v: array.array("d", v),
        lambda v: np.array(v),
        lambda v: memoryview(array.array("d", v)),
        lambda v: memoryview(array.array("d", v).tobytes()).cast("d"),
        lambda v: (ctypes.c_double * len(v))(*v),
    ],
    ids=[
        "list",
        "tuple",
        "iterator",
        "int",
        "fraction",
        "array",
        "numpy",
        "memoryview",
        "readonly",
        "ctypes",
    ],
)
def test_container(make):
    want = (8.0, 4.0 * math.sqrt(1.625), 4.0)
    for norm, w in zip(NORM, want, strict=True):
        r = norm(make(VECTOR))
        assert type(r) is float
        assert r == w


def test_keyword_and_slice_in_place():
    data = np.arange(-3.0, 20.0)
    view = data[4:7]
    assert not view.flags.owndata
    assert diana.norm_1(x=view) == 6.0
    assert diana.norm_2(x=view) == 3.0 * math.sqrt(1.0 + (1.0 / 3.0) ** 2 + (2.0 / 3.0) ** 2)
    assert diana.norm_inf(x=view) == 3.0


@pytest.mark.parametrize("x", [[], (), np.array([]), array.array("d"), [0.0, -0.0], [-0.0]])
def test_zero(x):
    for norm in NORM:
        assert same(norm(x), 0.0)


def test_pythagorean():
    assert diana.norm_2([3.0, -4.0]) == 5.0
    assert diana.norm_2([-4.0, 3.0]) == 5.0
    assert diana.norm_2([4.0, -4.0]) == 4.0 * math.sqrt(2.0)


def test_norm_1_order():
    # Left to right: 2^53 + 1 rounds to 2^53 (ties to even) at each step, not the exact 2^53 + 2.
    p53 = 2.0**53
    assert diana.norm_1([p53, 1.0, -1.0]) == p53


def test_norm_2_order():
    # The sum starts from the 1 of the largest entry: each 2^-54 that follows is below half an
    # ulp of 1, so the sum stays 1 wherever the largest entry is.
    small = [2.0**-27] * 16
    assert diana.norm_2(small + [1.0]) == 1.0
    assert diana.norm_2([1.0] + small) == 1.0


@pytest.mark.parametrize(
    ("x", "want"),
    [
        ([-DBL_MAX], DBL_MAX),
        ([1e300, -1e300], 1e300 * math.sqrt(2.0)),
        ([1e-200, 1e-200], 1e-200 * math.sqrt(2.0)),
        ([TRUE_MIN], TRUE_MIN),
        ([TRUE_MIN, -TRUE_MIN], TRUE_MIN),
        ([DBL_MAX, TRUE_MIN], DBL_MAX),
        ([DBL_MAX, 2.0**970], DBL_MAX),
        ([DBL_MAX, DBL_MAX * 2.0**-26], DBL_MAX),
    ],
)
def test_norm_2_scale(x, want):
    # No quotient or square overflows: the naive sqrt(sum of squares) would overflow on the
    # large vectors and return 0 on the small ones.
    assert diana.norm_2(x) == want


def test_extreme():
    assert diana.norm_inf([TRUE_MIN, -DBL_MAX, sys.float_info.min]) == DBL_MAX
    assert diana.norm_1([TRUE_MIN, -TRUE_MIN]) == 2.0 * TRUE_MIN
    assert diana.norm_inf([DBL_MAX, -DBL_MAX]) == DBL_MAX


@pytest.mark.parametrize(
    "x",
    [[1.0, math.nan], [math.inf], [0.0, -math.inf, 1.0], [DBL_MAX, DBL_MAX, math.nan]],
)
def test_nonfinite(x):
    for norm in NORM:
        with pytest.raises(ValueError, match="non-finite entry") as info:
            norm(x)
        assert not isinstance(info.value, diana.FloatOverflowError)


@pytest.mark.parametrize(
    ("norm", "x"),
    [
        (diana.norm_1, [DBL_MAX, -DBL_MAX]),
        (diana.norm_1, [DBL_MAX, 2.0**970]),
        (diana.norm_2, [DBL_MAX, -DBL_MAX]),
        (diana.norm_2, np.array([DBL_MAX, DBL_MAX / 2.0])),
    ],
)
def test_overflow(norm, x):
    with pytest.raises(diana.FloatOverflowError, match="norm overflows"):
        norm(x)


@pytest.mark.parametrize(
    "x",
    [
        np.ones(3, dtype=np.float32),
        np.ones(3, dtype=np.int64),
        np.ones(3, dtype=np.dtype(np.float64).newbyteorder()),
        array.array("f", [1.0, 2.0]),
        b"\x00" * 16,
    ],
    ids=["float32", "int64", "non-native", "array-f", "bytes"],
)
def test_wrong_dtype(x):
    for norm in NORM:
        with pytest.raises(TypeError, match="native float64"):
            norm(x)


@pytest.mark.parametrize(
    ("x", "match"),
    [
        (np.arange(10.0)[::2], "C-contiguous"),
        (np.ones((3, 3)), "one-dimensional"),
        (np.array(1.0), "one-dimensional"),
        (memoryview(bytearray(8 * 3 + 1))[1:].cast("d"), "aligned"),
    ],
    ids=["strided", "2d", "0d", "misaligned"],
)
def test_bad_layout(x, match):
    for norm in NORM:
        with pytest.raises(ValueError, match=match):
            norm(x)


@pytest.mark.parametrize("x", [1.0, None, "12", ["a"], [[1.0], [2.0]]])
def test_wrong_argument_type(x):
    for norm in NORM:
        with pytest.raises(TypeError):
            norm(x)


def test_extension_requires_buffer():
    for name in ("norm_1", "norm_2", "norm_inf"):
        with pytest.raises(TypeError):
            getattr(diana._diana, name)(VECTOR)
    assert diana._diana.norm_inf(array.array("d", VECTOR)) == 4.0


@settings(database=None, derandomize=True, max_examples=500)
@given(st.lists(st.floats(), max_size=40))
def test_matches_sequential_binary64(x):
    finite = all(math.isfinite(v) for v in x)
    for samples in (x, np.array(x, dtype=np.float64)):
        for norm, model in ((diana.norm_1, sequential_1), (diana.norm_2, sequential_2)):
            if not finite:
                with pytest.raises(ValueError, match="non-finite entry") as info:
                    norm(samples)
                assert not isinstance(info.value, diana.FloatOverflowError)
                continue
            want = model(x)
            if math.isfinite(want):
                assert same(norm(samples), want)
            else:
                with pytest.raises(diana.FloatOverflowError, match="overflows"):
                    norm(samples)
        if finite:
            assert same(diana.norm_inf(samples), max((abs(v) for v in x), default=0.0))
        else:
            with pytest.raises(ValueError, match="non-finite entry"):
                diana.norm_inf(samples)


@settings(database=None, derandomize=True, max_examples=300)
@given(st.lists(st.floats(allow_nan=False, allow_infinity=False, width=64), max_size=40))
def test_sign_and_scale(x):
    # Every norm ignores signs; a power-of-two scaling is exact when nothing over- or underflows.
    for norm in NORM:
        try:
            r = norm(x)
        except diana.FloatOverflowError:
            continue
        assert same(norm([-v for v in x]), r)
        if all(v == 0.0 or 2.0**-900 < abs(v) < 2.0**900 for v in x) and r < 2.0**900:
            assert norm([v * 2.0**64 for v in x]) == r * 2.0**64


def exact_square(x):
    return sum(Fraction(v) ** 2 for v in x)


def scaled(seed, n, low, high):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) * 2.0 ** rng.randint(low, high) for _ in range(n)]


CASES = [
    scaled(1729, 1000, -20, 20),
    scaled(1730, 200, -1070, -1000),
    scaled(1731, 200, 900, 1020),
    scaled(1732, 300, -600, 600),
    [TRUE_MIN, -TRUE_MIN, TRUE_MIN],
    [1.0] + [2.0**-27] * 64,
]


@pytest.mark.parametrize("x", CASES, ids=["normal", "subnormal", "large", "wide", "tiny", "order"])
def test_rounding_error_bound(x):
    n = len(x)
    # NORM-B2: |r - ||x||_1| <= gamma_(n-1) ||x||_1.
    exact_1 = sum(abs(Fraction(v)) for v in x)
    assert abs(Fraction(diana.norm_1(x)) - exact_1) <= gamma(n - 1) * exact_1
    # NORM-B4: |r - ||x||_2| <= gamma_(n+5) ||x||_2 + eta, checked on squares: with
    # c = gamma_(n+5) and S the exact sum of squares, (r - eta)^2 <= (1 + c)^2 S and, when
    # r + eta >= 0, (1 - c)^2 S <= (r + eta)^2.
    r = Fraction(diana.norm_2(x))
    s = exact_square(x)
    c = gamma(n + 5)
    assert r >= Fraction(diana.norm_inf(x))
    assert max(r - ETA, 0) ** 2 <= (1 + c) ** 2 * s
    assert (1 - c) ** 2 * s <= (r + ETA) ** 2
    # NORM-B1: the maximum norm is exact.
    assert Fraction(diana.norm_inf(x)) == max(abs(Fraction(v)) for v in x)


def test_norm_equivalence():
    # NORM-A2 within the rounding bounds: ||x||_inf <= ||x||_2 <= ||x||_1 <= n ||x||_inf.
    for x in CASES[:4]:
        n = len(x)
        a, b, c = diana.norm_inf(x), diana.norm_2(x), diana.norm_1(x)
        assert a <= b * (1 + 2 * float(gamma(n + 5)))
        assert b <= c * (1 + 2 * float(gamma(n + 5)))
        assert c <= n * a * (1 + float(gamma(n)))
