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

# y + h f with few significant bits: the product and the sum are exact.
Y = [1.0, -2.0, 0.5]
F = [3.0, 4.0, -8.0]
WANT = [1.75, -1.0, -1.5]


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
def test_step_container(make):
    r = diana.euler_step(make(Y), make(F), 0.25)
    assert type(r) is array.array
    assert r.typecode == "d"
    assert list(r) == WANT


def test_step_leaves_inputs():
    y = np.array(Y)
    f = np.array(F)
    diana.euler_step(y, f, 0.25)
    assert list(y) == Y
    assert list(f) == F


def test_step_keyword_and_numeric_h():
    assert list(diana.euler_step(y=Y, f=F, h=0.25)) == WANT
    assert list(diana.euler_step(Y, F, np.float64(0.25))) == WANT
    assert list(diana.euler_step([1.0], [3.0], 2)) == [7.0]


def test_step_no_contraction():
    # h * f = 1 - 2^-104 rounds to 1, so the result is +0; a fused multiply-add gives -2^-104.
    r = diana.euler_step([-1.0], [1.0 - EPS], 1.0 + EPS)
    assert same(r[0], 0.0)


def test_step_zero_step_and_underflow():
    r = diana.euler_step([-0.0, 2.0, 0.0], [-3.0, 5.0, -1.0], 0.0)
    assert [same(a, b) for a, b in zip(r, [-0.0, 2.0, 0.0], strict=True)] == [True] * 3
    assert same(diana.euler_step([0.0], [math.ulp(0.0)], 0.5)[0], 0.0)


@pytest.mark.parametrize(
    ("y", "f", "h"),
    [
        ([math.nan, 1.0], [1.0, 1.0], 1.0),
        ([1.0, math.inf], [1.0, 1.0], 1.0),
        ([1.0, 1.0], [1.0, -math.inf], 1.0),
        ([1.0, 1.0], [1.0, 1.0], math.nan),
        ([1.0, 1.0], [1.0, 1.0], math.inf),
        ([1.0], [math.inf], 0.0),
        ([math.inf], [-math.inf], 1.0),
        ([0.0], [DBL_MAX], 2.0),
        ([DBL_MAX], [DBL_MAX], 1.0),
        ([1.0, 2.0, DBL_MAX], [1.0, 1.0, DBL_MAX], 1.0),
    ],
)
def test_step_nonfinite(y, f, h):
    with pytest.raises(ValueError, match="not finite"):
        diana.euler_step(y, f, h)


def test_step_failure_leaves_out():
    out = array.array("d", [42.0, 42.0, 42.0])
    with pytest.raises(ValueError, match="not finite"):
        diana._diana.euler_step(
            array.array("d", [1.0, 2.0, DBL_MAX]), array.array("d", [1.0, 1.0, DBL_MAX]), 1.0, out
        )
    assert list(out) == [42.0, 42.0, 42.0]


@pytest.mark.parametrize(
    ("y", "f", "match"),
    [
        ([], [], "y must have at least one sample"),
        (np.array([]), [1.0], "y must have at least one sample"),
        ([1.0], [], "f must have at least one sample"),
        ([1.0, 2.0], [1.0], "same length"),
        ([1.0], [1.0, 2.0], "same length"),
        (np.ones((2, 2)), [1.0], "y must be one-dimensional"),
        ([1.0, 2.0], np.ones((2, 1)), "f must be one-dimensional"),
        (np.arange(4.0)[::2], [1.0, 1.0], "y must be C-contiguous"),
        ([1.0, 1.0], np.arange(4.0)[::2], "f must be C-contiguous"),
        (
            np.frombuffer(bytearray(8 * 2 + 1), dtype=np.float64, offset=1),
            [1.0, 1.0],
            "y is not aligned",
        ),
        (
            [1.0, 1.0],
            np.frombuffer(bytearray(8 * 2 + 1), dtype=np.float64, offset=1),
            "f is not aligned",
        ),
    ],
)
def test_step_bad_shape(y, f, match):
    with pytest.raises(ValueError, match=match):
        diana.euler_step(y, f, 1.0)


@pytest.mark.parametrize(
    ("y", "f", "match"),
    [
        (np.ones(2, dtype=np.float32), [1.0, 1.0], "y must be a buffer of native float64"),
        ([1.0, 1.0], np.ones(2, dtype=np.int64), "f must be a buffer of native float64"),
        (array.array("f", [1.0, 2.0]), [1.0, 1.0], "y must be a buffer of native float64"),
    ],
)
def test_step_wrong_dtype(y, f, match):
    with pytest.raises(TypeError, match=match):
        diana.euler_step(y, f, 1.0)


@pytest.mark.parametrize(
    ("y", "f", "h"),
    [(1.0, [1.0], 1.0), ([1.0], None, 1.0), (["a"], [1.0], 1.0), ([1.0], [1.0], "1")],
)
def test_step_wrong_argument_type(y, f, h):
    with pytest.raises(TypeError):
        diana.euler_step(y, f, h)


def test_extension_checks_out():
    y = array.array("d", [1.0, 2.0, 3.0, 4.0])
    f = array.array("d", [1.0, 1.0, 1.0, 1.0])
    with pytest.raises(TypeError):
        diana._diana.euler_step([1.0], f, 1.0, array.array("d", [0.0]))
    with pytest.raises(BufferError):
        diana._diana.euler_step(y, f, 1.0, bytes(32))
    with pytest.raises(ValueError, match="out must have at least one sample"):
        diana._diana.euler_step(y, f, 1.0, array.array("d"))
    with pytest.raises(ValueError, match="same length"):
        diana._diana.euler_step(y, f, 1.0, array.array("d", [0.0, 0.0]))
    with pytest.raises(ValueError, match="overlap"):
        diana._diana.euler_step(y, f, 1.0, y)
    with pytest.raises(ValueError, match="overlap"):
        diana._diana.euler_step(y, f, 1.0, f)
    data = np.zeros(6)
    with pytest.raises(ValueError, match="overlap"):
        diana._diana.euler_step(data[:4], f, 1.0, data[2:])
    out = array.array("d", [0.0] * 4)
    assert diana._diana.euler_step(y, f, 1.0, out) is None
    assert list(out) == [2.0, 3.0, 4.0, 5.0]


same_length = st.integers(1, 20).flatmap(
    lambda n: st.tuples(
        st.lists(st.floats(), min_size=n, max_size=n),
        st.lists(st.floats(), min_size=n, max_size=n),
    )
)


@settings(database=None, derandomize=True, max_examples=500)
@given(same_length, st.floats())
def test_step_matches_binary64(yf, h):
    y, f = yf
    want = [a + h * b for a, b in zip(y, f, strict=True)]
    if all(math.isfinite(v) for v in want):
        r = diana.euler_step(y, f, h)
        assert all(same(a, b) for a, b in zip(r, want, strict=True))
    else:
        with pytest.raises(ValueError, match="not finite"):
            diana.euler_step(y, f, h)


def test_step_rounding_error_bound():
    # EULER-B2 per component: |r - (y + h f)| <= u |y + h f| + (1 + u)(u |h f| + eta).
    u = Fraction(1, 2**53)
    eta = Fraction(1, 2**1075)
    rng = random.Random(1729)
    for low, high in ((-40, 40), (-1074, -1000)):
        y = [rng.uniform(-1.0, 1.0) * 2.0 ** rng.randint(low, high) for _ in range(500)]
        f = [rng.uniform(-1.0, 1.0) * 2.0 ** rng.randint(low, high) for _ in range(500)]
        h = rng.uniform(-1.0, 1.0)
        r = diana.euler_step(y, f, h)
        for ri, yi, fi in zip(r, y, f, strict=True):
            product = Fraction(h) * Fraction(fi)
            exact = Fraction(yi) + product
            bound = u * abs(exact) + (1 + u) * (u * abs(product) + eta)
            assert abs(Fraction(ri) - exact) <= bound


def test_euler_exact_paths():
    # y' = -y with h = 1/2 halves the state; the rotation stays on integers.
    assert list(diana.euler(lambda t, y: [-v for v in y], 0.0, [1.0, 3.0], 0.5, 3)) == [
        0.125,
        0.375,
    ]
    assert list(diana.euler(lambda t, y: (y[1], -y[0]), 0.0, [1.0, 0.0], 1.0, 3)) == [-2.0, -2.0]


def test_euler_times_and_copy():
    times = []

    def ramp(t, y):
        times.append(t)
        return [t]

    y0 = np.array([0.0])
    r = diana.euler(ramp, 1, y0, 0.25, 4)
    assert times == [1.0, 1.25, 1.5, 1.75]
    assert list(r) == [1.375]
    assert list(y0) == [0.0]


def test_euler_no_step():
    r = diana.euler(lambda t, y: pytest.fail("f called"), 0.0, [2.0, 3.0], 1.0, 0)
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
def test_euler_arguments(args, error, match):
    with pytest.raises(error, match=match):
        diana.euler(lambda t, y: list(y), *args)


def test_euler_callback_errors():
    with pytest.raises(ValueError, match="same length"):
        diana.euler(lambda t, y: [1.0, 2.0], 0.0, [1.0], 1.0, 1)
    calls = []

    def blow(t, y):
        calls.append(t)
        return [math.inf] if len(calls) == 3 else [1.0]

    with pytest.raises(ValueError, match="not finite"):
        diana.euler(blow, 0.0, [0.0], 1.0, 5)
    assert len(calls) == 3


def test_euler_rotation_convergence():
    # y' = (y2, -y1), y(0) = (0, 1): y(t) = (sin t, cos t). In the max norm F is 1-Lipschitz and
    # |y''| <= 1, so EULER-A2 bounds the error at t = 1 by (h / 2)(e - 1). The error is
    # first order, C h + O(h^2): halving h divides it by 2 up to an O(h) correction, measured at
    # most 0.016 for h <= 1/16. Rounding (about n u, below 1e-13) is negligible against the
    # smallest error here, about 1.6e-3; the test allows 0.05.
    error = []
    for n in (16, 32, 64, 128, 256):
        h = 1.0 / n
        y = diana.euler(lambda t, y: (y[1], -y[0]), 0.0, [0.0, 1.0], h, n)
        err = max(abs(y[0] - math.sin(1.0)), abs(y[1] - math.cos(1.0)))
        assert 0 < err <= h / 2 * (math.e - 1)
        error.append(err)
    for coarse, fine in zip(error, error[1:], strict=False):
        assert abs(coarse / fine - 2) < 0.05
