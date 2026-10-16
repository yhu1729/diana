import array
import ctypes
import math
import random
import sys
from fractions import Fraction

import mpmath
import numpy as np
import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

import diana

DBL_MAX = sys.float_info.max

# f(x) = x^3 on [0, 4] at h = 1: integers, so every operation is exact and the rule, exact for
# cubic f, returns the integral 64 exactly (the weighted sum is 192).
CUBIC = [0.0, 1.0, 8.0, 27.0, 64.0]


def sequential(y, h):
    so = 0.0
    for v in y[1:-1:2]:
        so = so + v
    se = 0.0
    for v in y[2:-1:2]:
        se = se + v
    return h * (((y[0] + y[-1]) + 4.0 * so) + 2.0 * se) / 3.0


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
        lambda v: np.array(v, dtype=np.dtype("=f8")),
        lambda v: memoryview(array.array("d", v)),
        lambda v: memoryview(array.array("d", v).tobytes()).cast("d"),
        lambda v: memoryview(array.array("d", v)).cast("B").cast("@d"),
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
        "numpy-native",
        "memoryview",
        "readonly",
        "native-prefix",
        "ctypes",
    ],
)
def test_container(make):
    r = diana.simpson(make(CUBIC), 1.0)
    assert type(r) is float
    assert r == 64.0


def test_contiguous_slice_in_place():
    data = np.array([-1.0, -2.0, *CUBIC, 5.0])
    view = data[2:7]
    assert not view.flags.owndata
    assert list(view) == CUBIC
    assert diana.simpson(view, 1.0) == 64.0


def test_keyword_and_numeric_h():
    assert diana.simpson(y=CUBIC, h=1.0) == 64.0
    assert diana.simpson(CUBIC, np.float64(1.0)) == 64.0
    assert diana.simpson(CUBIC, 2) == 128.0


def test_cubic_rounds_once():
    # f(x) = x^3 - 2x^2 + x + 1 on [-1, 3] at h = 1/2: the weighted sum is exactly 56, so only
    # the division by 3 rounds and the result is the correctly rounded integral 28/3.
    y = [x**3 - 2 * x**2 + x + 1 for x in (-1 + 0.5 * i for i in range(9))]
    assert diana.simpson(y, 0.5) == 28 / 3
    assert diana.simpson(y, -0.5) == -28 / 3


def test_operation_order():
    p53 = 2.0**53
    # The endpoint pair cancels first; adding the weighted interior to 2^53 first would give 4.
    assert diana.simpson([p53, 0.5, 0.25, 0.5, -p53], 3.0) == 4.5
    # Each interior sum runs left to right from +0: 2^53 + 1 rounds to 2^53 (ties to even), so
    # the sum is 0; right to left it would be 1.
    assert same(diana.simpson([0.0, p53, 0.0, 1.0, 0.0, -p53, 0.0], 3.0), 0.0)
    assert same(diana.simpson([0.0, 0.0, p53, 0.0, 1.0, 0.0, -p53, 0.0, 0.0], 3.0), 0.0)


def test_direction_and_zero_step():
    assert diana.simpson(CUBIC, -1.0) == -64.0
    assert same(diana.simpson(CUBIC, 0.0), 0.0)
    assert same(diana.simpson(CUBIC, -0.0), -0.0)
    assert same(diana.simpson([DBL_MAX / 2, DBL_MAX / 8, 0.0], 0.0), 0.0)


def test_underflow_is_not_an_error():
    assert same(diana.simpson([0.5, 0.0, 0.5], math.ulp(0.0)), 0.0)


@pytest.mark.parametrize("y", [[], [1.0], [1.0, 2.0], np.array([]), np.ones(2), array.array("d")])
def test_too_few_samples(y):
    with pytest.raises(ValueError, match="at least three samples"):
        diana.simpson(y, 1.0)


@pytest.mark.parametrize("y", [[1.0] * 4, np.ones(6), array.array("d", [1.0] * 100)])
def test_even_sample_count(y):
    with pytest.raises(ValueError, match="odd number of samples"):
        diana.simpson(y, 1.0)


@pytest.mark.parametrize(
    ("y", "h"),
    [
        ([1.0, math.nan, 3.0], 1.0),
        ([math.inf, 2.0, 3.0], 1.0),
        ([1.0, 2.0, 3.0, 4.0, -math.inf], 1.0),
        ([math.inf, 2.0, -math.inf], 1.0),
        ([1.0, math.inf, 3.0, -math.inf, 5.0], 1.0),
        ([1.0, 2.0, 3.0], math.nan),
        ([1.0, 2.0, 3.0], math.inf),
        ([0.0, 0.0, 0.0], -math.inf),
        ([DBL_MAX, 0.0, DBL_MAX], 1.0),
        ([DBL_MAX, 0.0, DBL_MAX], 0.0),
        ([0.0, DBL_MAX, 0.0], 0.25),
        ([0.0, 0.0, DBL_MAX, 0.0, 0.0], 1.0),
        ([1.0, 1.0, 1.0], DBL_MAX / 4),
        (np.array([1.0, 1.0, 1.0]), -DBL_MAX / 4),
    ],
)
def test_nonfinite_result(y, h):
    with pytest.raises(ValueError, match="not finite"):
        diana.simpson(y, h)


@pytest.mark.parametrize(
    "y",
    [
        np.ones(3, dtype=np.float32),
        np.ones(3, dtype=np.int64),
        np.ones(3, dtype=np.complex128),
        np.ones(3, dtype=np.dtype(np.float64).newbyteorder()),
        array.array("f", [1.0, 2.0, 3.0]),
        array.array("q", [1, 2, 3]),
        b"\x00" * 24,
        bytearray(24),
        memoryview(array.array("d", CUBIC)).cast("B").cast("q"),
    ],
    ids=[
        "float32",
        "int64",
        "complex128",
        "non-native",
        "array-f",
        "array-q",
        "bytes",
        "bytearray",
        "memoryview-q",
    ],
)
def test_wrong_dtype(y):
    with pytest.raises(TypeError, match="native float64"):
        diana.simpson(y, 1.0)


@pytest.mark.parametrize(
    ("y", "match"),
    [
        (np.arange(10.0)[::2], "C-contiguous"),
        (np.arange(9.0)[::-1], "C-contiguous"),
        (memoryview(array.array("d", CUBIC))[::2], "C-contiguous"),
        (np.ones((3, 3)), "one-dimensional"),
        (np.ones((3, 3), order="F"), "one-dimensional"),
        (np.array(1.0), "one-dimensional"),
        (memoryview(bytearray(8 * 3 + 1))[1:].cast("d"), "aligned"),
        (np.frombuffer(bytearray(8 * 3 + 1), dtype=np.float64, offset=1), "aligned"),
    ],
    ids=[
        "strided",
        "reversed",
        "memoryview-strided",
        "2d",
        "2d-fortran",
        "0d",
        "misaligned",
        "numpy-misaligned",
    ],
)
def test_bad_layout(y, match):
    with pytest.raises(ValueError, match=match):
        diana.simpson(y, 1.0)


@pytest.mark.parametrize(
    ("y", "h"),
    [
        (1.0, 1.0),
        (None, 1.0),
        ("123", 1.0),
        (["a", "b", "c"], 1.0),
        ([[1.0], [2.0], [3.0]], 1.0),
        (CUBIC, "1"),
        (CUBIC, None),
    ],
)
def test_wrong_argument_type(y, h):
    with pytest.raises(TypeError):
        diana.simpson(y, h)


def test_extension_requires_buffer():
    with pytest.raises(TypeError):
        diana._diana.simpson(CUBIC, 1.0)
    assert diana._diana.simpson(array.array("d", CUBIC), 1.0) == 64.0


odd_samples = st.integers(1, 20).flatmap(
    lambda p: st.lists(st.floats(), min_size=2 * p + 1, max_size=2 * p + 1)
)


@settings(database=None, derandomize=True, max_examples=500)
@given(odd_samples, st.floats())
def test_matches_sequential_binary64(y, h):
    want = sequential(y, h)
    for samples in (y, np.array(y)):
        if math.isfinite(want):
            assert same(diana.simpson(samples, h), want)
        else:
            with pytest.raises(ValueError, match="not finite"):
                diana.simpson(samples, h)


def scaled(seed, n, low, high):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) * 2.0 ** rng.randint(low, high) for _ in range(n)]


@pytest.mark.parametrize(
    ("y", "h"),
    [
        (scaled(1729, 1001, -20, 20), 0.1),
        (scaled(1730, 101, -1000, -990), 0.1 * 2.0**-60),
        ([math.ulp(0.0), 0.0, 0.0], 1.0),
    ],
    ids=["normal", "product-underflow", "division-underflow"],
)
def test_rounding_error_bound(y, h):
    # SIMPSON-B2: |r - h S'/3| <= gamma_(p+5) |h| A / 3 + (1 + u) eta / 3 + eta, p = (n - 1) / 2.
    p = (len(y) - 1) // 2
    u = Fraction(1, 2**53)
    eta = Fraction(1, 2**1075)

    def gamma(k):
        return k * u / (1 - k * u)

    odd = [Fraction(v) for v in y[1:-1:2]]
    even = [Fraction(v) for v in y[2:-1:2]]
    ends = Fraction(y[0]) + Fraction(y[-1])
    exact = Fraction(h) * (ends + 4 * sum(odd) + 2 * sum(even)) / 3
    a = abs(ends) + 4 * sum(map(abs, odd)) + 2 * sum(map(abs, even))
    bound = gamma(p + 5) * abs(Fraction(h)) * a / 3 + (1 + u) * eta / 3 + eta
    assert abs(Fraction(diana.simpson(y, h)) - exact) <= bound


def test_exp_convergence():
    # SIMPSON-A2 on [0, 1] with M4 = max exp'''' = e: 0 < S - I <= e h^4 / 180 (exp'''' > 0).
    # Euler-Maclaurin: S - I = (e - 1) h^4 / 180 - (e - 1) h^6 / 1512 + ..., so halving h
    # divides the error by 16 (1 - (3/4)(180/1512) h^2) + O(h^4): about 0.022 below 16 at
    # h = 1/8 and less for smaller h. SIMPSON-B2 bounds the rounding by about 1.3e-14 at
    # h = 1/128, against an error of about 3.6e-11 there, so it moves a ratio by at most about
    # 0.006; the test allows 0.05.
    with mpmath.workdps(40):
        exact = mpmath.e - 1
        error = []
        for m in (8, 16, 32, 64, 128):
            h = 1.0 / m
            err = mpmath.mpf(diana.simpson([math.exp(i * h) for i in range(m + 1)], h)) - exact
            assert 0 < err <= mpmath.e * h**4 / 180
            error.append(err)
        for coarse, fine in zip(error, error[1:], strict=False):
            assert abs(coarse / fine - 16) < 0.05
