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

U = Fraction(1, 2**53)
ETA = Fraction(1, 2**1075)

# L = [[2, 0, 0], [1, 3, 0], [-1, 2, 4]] and A = L L^T, column-major: every operation of the
# factorization is exact, so it returns L.
A3 = [4.0, 2.0, -2.0, 2.0, 10.0, 5.0, -2.0, 5.0, 21.0]
L3 = [2.0, 1.0, -1.0, 0.0, 3.0, 2.0, 0.0, 0.0, 4.0]


def reference(a, n):
    """The kernel's operations in its order, in binary64 (Python floats round like C doubles)."""
    m = [0.0] * (n * n)
    for j in range(n):
        s = a[j + j * n]
        for k in range(j):
            s = s - m[j + k * n] * m[j + k * n]
        if not s > 0.0:
            return None
        d = math.sqrt(s)
        m[j + j * n] = d
        for i in range(j + 1, n):
            s = a[i + j * n]
            for k in range(j):
                s = s - m[i + k * n] * m[j + k * n]
            m[i + j * n] = s / d
    return m


def same(a, b):
    return a == b and math.copysign(1.0, a) == math.copysign(1.0, b)


def gamma(k):
    return k * U / (1 - k * U)


def spd(rng, n, scale=1.0):
    """Column-major B^T B + n I for a random B: symmetric positive definite."""
    b = np.array([[rng.uniform(-1.0, 1.0) for _ in range(n)] for _ in range(n)])
    return list((scale * (b.T @ b + n * np.eye(n))).ravel(order="F"))


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
        lambda v: memoryview(array.array("d", v).tobytes()).cast("d"),
        lambda v: (ctypes.c_double * len(v))(*v),
    ],
    ids=["list", "tuple", "iterator", "int", "fraction", "array", "numpy", "readonly", "ctypes"],
)
def test_container(make):
    r = diana.cholesky(make(A3))
    assert type(r) is array.array
    assert r.typecode == "d"
    assert list(r) == L3


def test_keyword_and_inputs_kept():
    a = np.array(A3)
    assert list(diana.cholesky(a=a)) == L3
    assert list(a) == A3


def test_numpy_layout():
    lo = np.array([[2.0, 0.0, 0.0], [1.0, 3.0, 0.0], [-1.0, 2.0, 4.0]])
    a = lo @ lo.T
    r = np.asarray(diana.cholesky(a.ravel(order="F"))).reshape(3, 3, order="F")
    assert np.array_equal(r, lo)
    assert np.array_equal(np.asarray(diana.cholesky(a.ravel())), r.ravel(order="F"))


def test_one_by_one():
    assert list(diana.cholesky([2.0])) == [math.sqrt(2.0)]
    assert list(diana.cholesky([0.25])) == [0.5]


def test_upper_triangle_ignored():
    a = list(A3)
    a[3], a[6], a[7] = math.nan, math.inf, -math.inf
    assert list(diana.cholesky(a)) == L3


def test_strict_upper_zero():
    r = diana.cholesky([4.0, 0.0, 0.0, 0.0, 9.0, -0.0, 0.0, 0.0, 0.25])
    want = [2.0, 0.0, 0.0, 0.0, 3.0, -0.0, 0.0, 0.0, 0.5]
    assert all(same(a, b) for a, b in zip(r, want, strict=True))
    assert all(same(r[p], 0.0) for p in (3, 6, 7))


def test_operation_order():
    # The pivot 1 + 3*2^-52 - fl((1 + 2^-52)^2) is 2^-52; a fused multiply-add would leave
    # 2^-52 - 2^-104 and the root 2^-26 * (1 - 2^-53).
    eps = sys.float_info.epsilon
    assert list(diana.cholesky([1.0, 1.0 + eps, 0.0, 1.0 + 3 * eps])) == [
        1.0,
        1.0 + eps,
        0.0,
        2.0**-26,
    ]
    # 1 - 2^-54 - 2^-54 in order rounds back to 1 at each step; summing the products first
    # would give the pivot 1 - 2^-53.
    t = 2.0**-27
    a = [1.0, 0.0, t, 0.0, 1.0, t, 0.0, 0.0, 1.0]
    assert diana.cholesky(a)[8] == 1.0
    # 5/3 rounds up; multiplying by fl(1/3) would round down.
    assert diana.cholesky([9.0, 5.0, 0.0, 100.0])[1] == float.fromhex("0x1.aaaaaaaaaaaabp+0")


def test_subnormal_pivot():
    tiny = math.ulp(0.0)
    assert list(diana.cholesky([tiny, 0.0, 0.0, 4 * tiny])) == [2.0**-537, 0.0, 0.0, 2.0**-536]


@pytest.mark.parametrize(
    "a",
    [
        [0.0],
        [-0.0],
        [-1.0],
        [0.0, 0.0, 0.0, 0.0],
        [1.0, 2.0, 2.0, 1.0],
        [1.0, 1.0, 1.0, 1.0],
        [4.0, 2.0, 0.0, 0.0, 2.0, 1.0, 0.0, 0.0, 0.5],
        [math.ulp(0.0), 1e300, 0.0, 1.0],
        [math.ulp(0.0), 0.0, 1e300, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0],
    ],
    ids=[
        "zero",
        "negative-zero",
        "negative",
        "zero-2",
        "indefinite",
        "semidefinite",
        "last-pivot",
        "overflow",
        "nan-pivot",
    ],
)
def test_not_positive_definite(a):
    with pytest.raises(diana.SingularError, match="not positive definite"):
        diana.cholesky(a)
    assert issubclass(diana.SingularError, ValueError)


@pytest.mark.parametrize("p", [0, 1, 2, 4, 5, 8])
@pytest.mark.parametrize("v", [math.nan, math.inf, -math.inf])
def test_nonfinite_lower(p, v):
    a = list(A3)
    a[p] = v
    with pytest.raises(ValueError, match="non-finite"):
        diana.cholesky(a)


@pytest.mark.parametrize(
    ("a", "match"),
    [
        ([], "at least one sample"),
        (np.array([]), "at least one sample"),
        ([1.0, 0.0], "square number"),
        ([1.0, 0.0, 0.0], "square number"),
        ([1.0] * 5, "square number"),
        (np.eye(2), "one-dimensional"),
        (np.ones(8)[::2], "C-contiguous"),
    ],
)
def test_bad_shape(a, match):
    with pytest.raises(ValueError, match=match):
        diana.cholesky(a)


@pytest.mark.parametrize(
    "a", [np.ones(4, dtype=np.float32), np.ones(4, dtype=np.int64), np.ones(4, dtype=">f8")]
)
def test_wrong_dtype(a):
    if a.dtype.byteorder == ">" and sys.byteorder == "big":
        pytest.skip("big-endian host")
    with pytest.raises(TypeError, match="native float64"):
        diana.cholesky(a)


def test_wrong_element_type():
    with pytest.raises(TypeError):
        diana.cholesky(["1.0"])
    with pytest.raises(TypeError):
        diana.cholesky("1.0")


def test_extension_checks_out():
    a = array.array("d", A3)
    with pytest.raises(TypeError):
        diana._diana.cholesky(A3, array.array("d", [0.0] * 9))
    with pytest.raises(BufferError):
        diana._diana.cholesky(a, bytes(72))
    with pytest.raises(ValueError, match="out must have at least one sample"):
        diana._diana.cholesky(a, array.array("d"))
    with pytest.raises(ValueError, match="out must have the same length as a"):
        diana._diana.cholesky(a, array.array("d", [0.0] * 4))
    with pytest.raises(ValueError, match="overlap"):
        diana._diana.cholesky(a, a)
    data = np.zeros(12)
    data[:9] = A3
    with pytest.raises(ValueError, match="overlap"):
        diana._diana.cholesky(data[:9], data[3:])
    out = array.array("d", [7.0] * 9)
    bad = array.array("d", A3)
    bad[4] = math.nan
    with pytest.raises(ValueError, match="non-finite"):
        diana._diana.cholesky(bad, out)
    assert list(out) == [7.0] * 9
    assert diana._diana.cholesky(a, out) is None
    assert list(out) == L3


def test_exact_integer_factor():
    rng = random.Random(20261017)
    for n in (1, 2, 5, 12):
        lo = np.zeros((n, n))
        for i in range(n):
            lo[i, i] = rng.choice([1.0, 2.0, 3.0, 4.0])
            for j in range(i):
                lo[i, j] = float(rng.randint(-9, 9))
        a = lo @ lo.T
        r = diana.cholesky(a.ravel(order="F"))
        assert list(r) == list(lo.ravel(order="F"))


def test_matches_binary64_random():
    rng = random.Random(1729)
    for n in (1, 2, 3, 7, 16, 31):
        for scale in (1.0, 1e-300, 1e300):
            a = spd(rng, n, scale)
            want = reference(a, n)
            assert want is not None
            r = diana.cholesky(a)
            assert all(same(x, y) for x, y in zip(r, want, strict=True))


matrix = st.integers(1, 6).flatmap(
    lambda n: st.lists(
        st.floats(allow_nan=False, allow_infinity=False, width=64), min_size=n * n, max_size=n * n
    )
)


@settings(database=None, derandomize=True, max_examples=500)
@given(matrix)
def test_matches_binary64_any(a):
    n = math.isqrt(len(a))
    want = reference(a, n)
    if want is None:
        with pytest.raises(diana.SingularError):
            diana.cholesky(a)
    else:
        r = diana.cholesky(a)
        assert all(same(x, y) for x, y in zip(r, want, strict=True))
        assert all(math.isfinite(x) for x in r)


def test_backward_error_bound():
    # |A[i, j] - sum_k L[i, k] L[j, k]| <= gamma(j + 2) sum_k |L[i, k] L[j, k]|
    #                                      + (1 + gamma(j + 2)) (j + |L[j, j]|) eta
    # for i >= j, k <= j, evaluated exactly in rationals (0-based j).
    rng = random.Random(42)
    for n in (2, 5, 10, 20):
        for scale in (1.0, 2.0**-1000, 2.0**1000):
            a = spd(rng, n, scale)
            r = diana.cholesky(a)
            for j in range(n):
                g = gamma(j + 2)
                for i in range(j, n):
                    prods = [Fraction(r[i + k * n]) * Fraction(r[j + k * n]) for k in range(j + 1)]
                    err = abs(Fraction(a[i + j * n]) - sum(prods))
                    bound = g * sum(abs(p) for p in prods)
                    bound += (1 + g) * (j + abs(Fraction(r[j + j * n]))) * ETA
                    assert err <= bound


def test_agrees_with_lapack():
    rng = random.Random(7)
    for n in (3, 10, 40):
        a = spd(rng, n)
        r = np.asarray(diana.cholesky(a)).reshape(n, n, order="F")
        want = np.linalg.cholesky(np.array(a).reshape(n, n, order="F"))
        assert np.allclose(r, want, rtol=1e-12, atol=1e-14)
