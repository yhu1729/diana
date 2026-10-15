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

# f(x) = 2x + 1 on [0, 4] at h = 1/2: small integers, so every operation is exact and the rule,
# exact for affine f, returns the integral 20 exactly.
AFFINE = [1.0 + i for i in range(9)]


def sequential(y, h):
    s = 0.5 * (y[0] + y[-1])
    for v in y[1:-1]:
        s = s + v
    return h * s


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
        "ctypes",
    ],
)
def test_container(make):
    r = diana.trapezoidal(make(AFFINE), 0.5)
    assert type(r) is float
    assert r == 20.0


def test_contiguous_slice_in_place():
    data = np.arange(-3.0, 20.0)
    view = data[4:13]
    assert not view.flags.owndata
    assert list(view) == AFFINE
    assert diana.trapezoidal(view, 0.5) == 20.0


def test_keyword_and_numeric_h():
    assert diana.trapezoidal(y=AFFINE, h=0.5) == 20.0
    assert diana.trapezoidal(AFFINE, np.float64(0.5)) == 20.0
    assert diana.trapezoidal(AFFINE, 2) == 80.0


def test_operation_order():
    # Left-to-right after the halved endpoints: 2^53 + 1 rounds to 2^53 (ties to even) at each
    # interior step, so the result is 2^53 and not the exact 2^53 + 2.
    p53 = 2.0**53
    assert diana.trapezoidal([p53, 1.0, 1.0, p53], 1.0) == p53


def test_direction_and_zero_step():
    assert diana.trapezoidal(AFFINE, -0.5) == -20.0
    assert same(diana.trapezoidal(AFFINE, 0.0), 0.0)
    assert same(diana.trapezoidal(AFFINE, -0.0), -0.0)
    assert same(diana.trapezoidal([DBL_MAX / 2, DBL_MAX / 2, 0.0], 0.0), 0.0)


def test_underflow_is_not_an_error():
    assert same(diana.trapezoidal([0.5, 0.5], math.ulp(0.0)), 0.0)


@pytest.mark.parametrize("y", [[], [1.0], np.array([]), np.ones(1), array.array("d")])
def test_too_few_samples(y):
    with pytest.raises(ValueError, match="at least two samples"):
        diana.trapezoidal(y, 1.0)


@pytest.mark.parametrize(
    ("y", "h"),
    [
        ([1.0, math.nan, 3.0], 1.0),
        ([math.inf, 2.0, 3.0], 1.0),
        ([1.0, 2.0, -math.inf], 1.0),
        ([math.inf, 2.0, -math.inf], 1.0),
        ([1.0, 2.0, 3.0], math.nan),
        ([1.0, 2.0, 3.0], math.inf),
        ([0.0, 0.0, 0.0], -math.inf),
        ([DBL_MAX, DBL_MAX], 1.0),
        ([DBL_MAX, DBL_MAX], 0.0),
        ([DBL_MAX, DBL_MAX, 0.0], 1.0),
        ([DBL_MAX, 0.0], 4.0),
        (np.array([DBL_MAX, 0.0]), -4.0),
    ],
)
def test_nonfinite_result(y, h):
    with pytest.raises(ValueError, match="not finite"):
        diana.trapezoidal(y, h)


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
        memoryview(array.array("d", AFFINE)).cast("B").cast("q"),
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
        diana.trapezoidal(y, 1.0)


@pytest.mark.parametrize(
    ("y", "match"),
    [
        (np.arange(10.0)[::2], "C-contiguous"),
        (np.arange(10.0)[::-1], "C-contiguous"),
        (memoryview(array.array("d", AFFINE))[::2], "C-contiguous"),
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
        diana.trapezoidal(y, 1.0)


@pytest.mark.parametrize(
    ("y", "h"),
    [
        (1.0, 1.0),
        (None, 1.0),
        ("12", 1.0),
        (["a", "b"], 1.0),
        ([[1.0], [2.0]], 1.0),
        (AFFINE, "1"),
        (AFFINE, None),
    ],
)
def test_wrong_argument_type(y, h):
    with pytest.raises(TypeError):
        diana.trapezoidal(y, h)


@settings(database=None, derandomize=True, max_examples=500)
@given(st.lists(st.floats(), min_size=2, max_size=40), st.floats())
def test_matches_sequential_binary64(y, h):
    want = sequential(y, h)
    for samples in (y, np.array(y)):
        if math.isfinite(want):
            assert same(diana.trapezoidal(samples, h), want)
        else:
            with pytest.raises(ValueError, match="not finite"):
                diana.trapezoidal(samples, h)


def test_rounding_error_bound():
    # n - 1 roundings in the sum (halving is exact without underflow) and one in the product:
    # |computed - exact| <= gamma_n |h| sum(w_i |y_i|), gamma_n = n u / (1 - n u), u = 2^-53.
    rng = random.Random(1729)
    y = [rng.uniform(-1.0, 1.0) * 2.0 ** rng.randint(-20, 20) for _ in range(1000)]
    h = 0.1
    n = len(y)
    w = [Fraction(1, 2)] + [Fraction(1)] * (n - 2) + [Fraction(1, 2)]
    exact = Fraction(h) * sum(wi * Fraction(v) for wi, v in zip(w, y, strict=True))
    u = Fraction(1, 2**53)
    gamma = n * u / (1 - n * u)
    bound = (
        gamma * abs(Fraction(h)) * sum(wi * abs(Fraction(v)) for wi, v in zip(w, y, strict=True))
    )
    assert abs(Fraction(diana.trapezoidal(y, h)) - exact) <= bound


def test_exp_convergence():
    # TRAPEZOIDAL-A2 on [0, 1] with M2 = max exp'' = e: 0 < T - I <= e h^2 / 12 (exp is convex).
    # Euler-Maclaurin: T - I = (e - 1) h^2 / 12 - (e - 1) h^4 / 720 + ..., so halving h divides
    # the error by 4 (1 - h^2 / 80): at most 2e-4 away from 4 for h <= 1/16. Rounding (about
    # 1e-13) is negligible against the smallest error here, about 2e-6.
    with mpmath.workdps(40):
        exact = mpmath.e - 1
        error = []
        for m in (16, 32, 64, 128, 256):
            h = 1.0 / m
            err = mpmath.mpf(diana.trapezoidal([math.exp(i * h) for i in range(m + 1)], h)) - exact
            assert 0 < err <= mpmath.e * h**2 / 12
            error.append(err)
        for coarse, fine in zip(error, error[1:], strict=False):
            assert abs(coarse / fine - 4) < 1e-3
