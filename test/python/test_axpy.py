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
U = Fraction(1, 2**53)
ETA = Fraction(1, 2**1075)

# y + a x with few significant bits: the product and the sum are exact.
A = 0.5
X = [2.0, 4.0, -8.0]
Y = [1.0, -1.0, 0.25]
WANT = [2.0, 1.0, -3.75]


def same(a, b):
    return a == b and math.copysign(1.0, a) == math.copysign(1.0, b)


def updated(a, x, y):
    """The C order in Python floats, which are binary64 rounded to nearest-even."""
    return [v + a * u for u, v in zip(x, y, strict=True)]


X_MAKERS = [
    list,
    tuple,
    iter,
    lambda v: [Fraction(u) for u in v],
    lambda v: array.array("d", v),
    lambda v: np.array(v),
    lambda v: memoryview(array.array("d", v)),
    lambda v: memoryview(array.array("d", v).tobytes()).cast("d"),
    lambda v: (ctypes.c_double * len(v))(*v),
]
X_IDS = [
    "list",
    "tuple",
    "iterator",
    "fraction",
    "array",
    "numpy",
    "memoryview",
    "readonly",
    "ctypes",
]
Y_MAKERS = [
    lambda v: array.array("d", v),
    lambda v: np.array(v),
    lambda v: memoryview(array.array("d", v)),
    lambda v: (ctypes.c_double * len(v))(*v),
]
Y_IDS = ["array", "numpy", "memoryview", "ctypes"]


@pytest.mark.parametrize("make_x", X_MAKERS, ids=X_IDS)
@pytest.mark.parametrize("make_y", Y_MAKERS, ids=Y_IDS)
def test_container(make_x, make_y):
    y = make_y(Y)
    assert diana.axpy(A, make_x(X), y) is None
    assert list(y) == WANT


def test_updates_in_place_and_leaves_x():
    x = np.array(X)
    y = np.array(Y)
    view = y
    diana.axpy(A, x, y)
    assert list(x) == X
    assert view is y
    assert list(view) == WANT


def test_keyword_and_numeric_a():
    y = array.array("d", Y)
    diana.axpy(a=A, x=X, y=y)
    assert list(y) == WANT
    y = array.array("d", Y)
    diana.axpy(np.float64(A), X, y)
    assert list(y) == WANT
    y = array.array("d", [1.0])
    diana.axpy(2, [3.0], y)
    assert list(y) == [7.0]


def test_slice_in_place():
    data = np.arange(0.0, 8.0)
    y = data[2:5]
    assert not y.flags.owndata
    diana.axpy(10.0, [1.0, 1.0, 1.0], y)
    assert list(data) == [0.0, 1.0, 12.0, 13.0, 14.0, 5.0, 6.0, 7.0]


@pytest.mark.parametrize("y", [array.array("d"), np.array([])])
def test_empty(y):
    diana.axpy(A, [], y)
    assert len(y) == 0
    diana.axpy(A, np.array([]), y)
    assert len(y) == 0


def test_empty_rejects_nonfinite_a():
    with pytest.raises(ValueError, match="input is not finite"):
        diana.axpy(math.nan, [], array.array("d"))


def test_inverse():
    y = array.array("d", Y)
    diana.axpy(A, X, y)
    diana.axpy(-A, X, y)
    assert list(y) == Y


def test_zero_coefficient_signed_zero():
    # a * x is a signed zero that is added: -0 + +0 is +0, -0 + -0 is -0.
    y = array.array("d", [-0.0, -0.0, 0.0, 0.0])
    diana.axpy(0.0, [1.0, -1.0, 1.0, -1.0], y)
    assert [math.copysign(1.0, v) for v in y] == [1.0, -1.0, 1.0, 1.0]
    y = array.array("d", [-0.0, -0.0, 0.0, 0.0])
    diana.axpy(-0.0, [1.0, -1.0, 1.0, -1.0], y)
    assert [math.copysign(1.0, v) for v in y] == [-1.0, 1.0, 1.0, 1.0]


def test_no_contraction():
    # a * x = 1 - 2^-104 rounds to 1, so the result is +0; a fused multiply-add gives -2^-104.
    y = array.array("d", [-1.0])
    diana.axpy(1.0 + EPS, [1.0 - EPS], y)
    assert same(y[0], 0.0)


def test_underflow():
    y = array.array("d", [0.0, 0.0])
    diana.axpy(0.5, [TRUE_MIN, 3.0 * TRUE_MIN], y)
    assert same(y[0], 0.0)
    assert y[1] == 2.0 * TRUE_MIN


@pytest.mark.parametrize(
    ("a", "x", "y"),
    [
        (1.0, [math.nan, 1.0], [1.0, 1.0]),
        (1.0, [1.0, math.inf], [1.0, 1.0]),
        (1.0, [1.0, 1.0], [1.0, -math.inf]),
        (math.nan, [1.0, 1.0], [1.0, 1.0]),
        (math.inf, [1.0, 1.0], [1.0, 1.0]),
        (0.0, [math.inf], [1.0]),
        (1.0, [math.inf], [-math.inf]),
        # the first component overflows, a later input is not finite
        (1.0, [DBL_MAX, 1.0, math.nan], [DBL_MAX, 1.0, 1.0]),
        (1.0, [DBL_MAX, 1.0, 1.0], [DBL_MAX, 1.0, -math.inf]),
    ],
)
def test_nonfinite(a, x, y):
    y = array.array("d", y)
    before = list(y)
    with pytest.raises(ValueError, match="input is not finite") as info:
        diana.axpy(a, x, y)
    assert not isinstance(info.value, diana.FloatOverflowError)
    assert all(
        same(u, v) or (math.isnan(u) and math.isnan(v)) for u, v in zip(y, before, strict=True)
    )


@pytest.mark.parametrize(
    ("a", "x", "y"),
    [
        (2.0, [DBL_MAX], [0.0]),
        (1.0, [DBL_MAX], [DBL_MAX]),
        (1.0, [1.0, 1.0, DBL_MAX], [1.0, 2.0, DBL_MAX]),
        (1.0, [DBL_MAX, 1.0, 1.0], [DBL_MAX, 1.0, 1.0]),
    ],
)
def test_overflow_leaves_y(a, x, y):
    y = array.array("d", y)
    before = list(y)
    with pytest.raises(diana.FloatOverflowError, match="result overflows"):
        diana.axpy(a, x, y)
    assert list(y) == before


def test_cancel():
    y = array.array("d", [DBL_MAX])
    diana.axpy(-1.0, [DBL_MAX], y)
    assert same(y[0], 0.0)


def test_length_mismatch():
    with pytest.raises(ValueError, match="same length"):
        diana.axpy(A, [1.0, 2.0], array.array("d", [1.0]))
    with pytest.raises(ValueError, match="same length"):
        diana.axpy(A, [1.0], array.array("d", [1.0, 2.0]))
    with pytest.raises(ValueError, match="same length"):
        diana.axpy(A, [], array.array("d", [1.0]))


def test_overlap():
    data = np.arange(0.0, 6.0)
    with pytest.raises(ValueError, match="overlap"):
        diana.axpy(A, data[0:3], data[1:4])
    with pytest.raises(ValueError, match="overlap"):
        diana.axpy(A, data[1:4], data[0:3])
    with pytest.raises(ValueError, match="overlap"):
        diana.axpy(A, data, data)
    diana.axpy(1.0, data[0:3], data[3:6])
    assert list(data) == [0.0, 1.0, 2.0, 3.0, 5.0, 7.0]


@pytest.mark.parametrize(
    "y",
    [b"\x00" * 24, memoryview(array.array("d", Y).tobytes()).cast("d"), np.array(Y).tobytes()],
    ids=["bytes", "memoryview", "numpy-bytes"],
)
def test_readonly_y(y):
    with pytest.raises((BufferError, TypeError, ValueError)):
        diana.axpy(A, X, y)


def test_readonly_numpy_y():
    y = np.array(Y)
    y.flags.writeable = False
    with pytest.raises(ValueError):
        diana.axpy(A, X, y)
    assert list(y) == Y


@pytest.mark.parametrize(
    "v",
    [
        np.ones(3, dtype=np.float32),
        np.ones(3, dtype=np.int64),
        np.ones(3, dtype=np.dtype(np.float64).newbyteorder()),
        array.array("f", [1.0, 2.0, 3.0]),
    ],
    ids=["float32", "int64", "non-native", "array-f"],
)
def test_wrong_dtype(v):
    with pytest.raises(TypeError, match="native float64"):
        diana.axpy(A, v, array.array("d", Y))
    with pytest.raises(TypeError, match="native float64"):
        diana.axpy(A, X, v)


@pytest.mark.parametrize(
    ("v", "match"),
    [
        (np.arange(10.0)[::2], "C-contiguous"),
        (np.ones((3, 3)), "one-dimensional"),
        (np.array(1.0), "one-dimensional"),
        (memoryview(bytearray(8 * 3 + 1))[1:].cast("d"), "aligned"),
    ],
    ids=["strided", "2d", "0d", "misaligned"],
)
def test_bad_layout(v, match):
    with pytest.raises(ValueError, match=match):
        diana.axpy(A, v, array.array("d", [0.0] * 5))
    with pytest.raises(ValueError, match=match):
        diana.axpy(A, [0.0] * 5, v)


@pytest.mark.parametrize("v", [1.0, None, "12", ["a"], [[1.0], [2.0]]])
def test_wrong_x_type(v):
    with pytest.raises(TypeError):
        diana.axpy(A, v, array.array("d", Y))


@pytest.mark.parametrize("v", [1.0, None, "12", Y, tuple(Y)])
def test_wrong_y_type(v):
    with pytest.raises(TypeError):
        diana.axpy(A, X, v)


def test_wrong_a_type():
    with pytest.raises(TypeError):
        diana.axpy("1", X, array.array("d", Y))
    with pytest.raises(TypeError):
        diana.axpy(None, X, array.array("d", Y))


def test_extension_requires_buffer():
    with pytest.raises(TypeError):
        diana._diana.axpy(A, X, array.array("d", Y))
    y = array.array("d", Y)
    assert diana._diana.axpy(A, array.array("d", X), y) is None
    assert list(y) == WANT


@settings(database=None, derandomize=True, max_examples=500)
@given(st.floats(), st.lists(st.tuples(st.floats(), st.floats()), max_size=40))
def test_matches_binary64(a, pairs):
    x = [p[0] for p in pairs]
    y0 = [p[1] for p in pairs]
    finite = math.isfinite(a) and all(math.isfinite(v) for v in x + y0)
    for make in (lambda v: array.array("d", v), lambda v: np.array(v, dtype=np.float64)):
        y = make(y0)
        if not finite:
            with pytest.raises(ValueError, match="input is not finite") as info:
                diana.axpy(a, x, y)
            assert not isinstance(info.value, diana.FloatOverflowError)
            continue
        want = updated(a, x, y0)
        if all(math.isfinite(v) for v in want):
            diana.axpy(a, x, y)
            assert all(same(u, v) for u, v in zip(y, want, strict=True))
        else:
            with pytest.raises(diana.FloatOverflowError, match="result overflows"):
                diana.axpy(a, x, y)
            assert all(same(u, v) for u, v in zip(y, y0, strict=True))


def scaled(seed, n, low, high):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) * 2.0 ** rng.randint(low, high) for _ in range(n)]


@pytest.mark.parametrize(
    ("a", "x", "y"),
    [
        (1.0 / 3.0, scaled(1729, 1000, -20, 20), scaled(1730, 1000, -20, 20)),
        (-(2.0**-600), scaled(1731, 200, -600, 600), scaled(1732, 200, -1070, -1000)),
        (2.0**500, scaled(1733, 200, -600, 500), scaled(1734, 200, 900, 1020)),
        (0.7, scaled(1735, 300, -1070, -1000), scaled(1736, 300, -1070, -1000)),
    ],
    ids=["normal", "underflow", "large", "subnormal"],
)
def test_rounding_error_bound(a, x, y):
    # AXPY-B2 per component: |r - (a x + y)| <= u |a x + y| + (1 + u) (u |a x| + eta).
    z = array.array("d", y)
    diana.axpy(a, x, z)
    for u, v, r in zip(x, y, z, strict=True):
        exact = Fraction(a) * Fraction(u) + Fraction(v)
        product = Fraction(a) * Fraction(u)
        assert abs(Fraction(r) - exact) <= U * abs(exact) + (1 + U) * (U * abs(product) + ETA)
