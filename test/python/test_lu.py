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
EPS = sys.float_info.epsilon
DBL_MAX = sys.float_info.max

# A = [[2, 2, 1], [-3, 1, 0], [3, -9, 6]] column-major: column 0 pivots on row 1, the first entry
# of magnitude 3, then column 1 on row 2, swapping the stored multipliers with it.
A3 = [2.0, -3.0, 3.0, 2.0, 1.0, -9.0, 1.0, 0.0, 6.0]
LU3 = [-3.0, -1.0, -2.0 / 3.0, 1.0, -8.0, -1.0 / 3.0, 0.0, 6.0, 3.0]
PIV3 = [1, 2, 2]


def reference(a, n):
    """The kernel's checks and operations in its order, in binary64 (Python floats round like C
    doubles): ``(m, piv)`` on success, else ``"arg"``, ``"singular"`` or ``"overflow"``."""
    if not all(math.isfinite(v) for v in a):
        return "arg"
    m = list(a)
    piv = []
    for k in range(n):
        p = k
        top = 0.0
        for i in range(k, n):
            v = m[i + k * n]
            if v < 0.0:
                v = -v
            if v > top:
                p, top = i, v
        if top == 0.0:
            return "singular"
        piv.append(p)
        for j in range(n):
            m[k + j * n], m[p + j * n] = m[p + j * n], m[k + j * n]
        d = m[k + k * n]
        for i in range(k + 1, n):
            m[i + k * n] = m[i + k * n] / d
        for j in range(k + 1, n):
            u = m[k + j * n]
            for i in range(k + 1, n):
                t = m[i + j * n] - m[i + k * n] * u
                if not math.isfinite(t):
                    return "overflow"
                m[i + j * n] = t
    return m, piv


def same(a, b):
    return a == b and math.copysign(1.0, a) == math.copysign(1.0, b)


def gamma(k):
    return k * U / (1 - k * U)


def permute(a, n, piv):
    """P*A: the rows of the column-major a swapped as piv records."""
    rows = list(range(n))
    for k, p in enumerate(piv):
        rows[k], rows[p] = rows[p], rows[k]
    return [a[rows[i] + j * n] for j in range(n) for i in range(n)]


def factors(lu, n):
    f = np.asarray(lu).reshape(n, n, order="F")
    return np.tril(f, -1) + np.eye(n), np.triu(f)


def random_matrix(rng, n, scale=1.0):
    return [scale * rng.uniform(-1.0, 1.0) for _ in range(n * n)]


@pytest.mark.parametrize(
    "make",
    [
        list,
        tuple,
        iter,
        lambda v: [Fraction(x) for x in v],
        lambda v: array.array("d", v),
        lambda v: np.array(v),
        lambda v: memoryview(array.array("d", v).tobytes()).cast("d"),
        lambda v: (ctypes.c_double * len(v))(*v),
    ],
    ids=["list", "tuple", "iterator", "fraction", "array", "numpy", "readonly", "ctypes"],
)
def test_container(make):
    r, piv = diana.lu(make(A3))
    assert type(r) is array.array
    assert r.typecode == "d"
    assert list(r) == LU3
    assert type(piv) is array.array and piv.typecode == "q"
    assert list(piv) == PIV3


def test_keyword_and_inputs_kept():
    a = np.array(A3)
    assert diana.lu(a=a) == (array.array("d", LU3), array.array("q", PIV3))
    assert list(a) == A3


def test_numpy_layout():
    a = np.array([[2.0, 2.0, 1.0], [-3.0, 1.0, 0.0], [3.0, -9.0, 6.0]])
    r, piv = diana.lu(a.ravel(order="F"))
    lo, up = factors(r, 3)
    assert np.allclose(
        np.array(permute(list(a.ravel(order="F")), 3, piv)).reshape(3, 3, order="F"), lo @ up
    )
    assert np.all(np.abs(np.tril(lo, -1)) <= 1.0)


def test_one_by_one():
    assert diana.lu([-5.0]) == (array.array("d", [-5.0]), array.array("q", [0]))
    assert diana.lu([DBL_MAX]) == (array.array("d", [DBL_MAX]), array.array("q", [0]))


def test_pivot_choice():
    # the first entry of largest magnitude: |1| = |-1| keeps row 0
    assert diana.lu([1.0, -1.0, 1.0, 1.0]) == (
        array.array("d", [1.0, -1.0, 1.0, 2.0]),
        array.array("q", [0, 1]),
    )
    r, piv = diana.lu([1.0, -3.0, 2.0, 4.0])
    assert list(piv) == [1, 1]
    assert list(r) == [-3.0, 1.0 / -3.0, 4.0, 2.0 - (1.0 / -3.0) * 4.0]


def test_operation_order():
    # 2 - fl((1 - 2^-53) * (1 + 2^-52)) is 1; a fused multiply-add would give 1 - 2^-53.
    a = [1.0, 1.0 - EPS / 2, 1.0 + EPS, 2.0]
    assert list(diana.lu(a)[0]) == [1.0, 1.0 - EPS / 2, 1.0 + EPS, 1.0]
    # 1 - 2^-54 - 2^-54 in order rounds back to 1 at each step; summing the products first
    # would give 1 - 2^-53.
    t = 2.0**-27
    assert diana.lu([1.0, 0.0, t, 0.0, 1.0, t, t, t, 1.0])[0][8] == 1.0
    # 3/5 rounds down; multiplying by fl(1/5) would round up.
    r, _ = diana.lu([5.0, 3.0, 1.0, 1.0])
    assert r[1] == float.fromhex("0x1.3333333333333p-1")
    assert r[1] != 3.0 * (1.0 / 5.0)


def test_signed_zero_and_underflow():
    tiny = math.ulp(0.0)
    r, _ = diana.lu([2.0, -0.0, tiny, 2.0**-1060])
    assert all(same(x, y) for x, y in zip(r, [2.0, -0.0, tiny, 2.0**-1060], strict=True))
    # 2^-538 * 3 * 2^-537 underflows and rounds to 2^-1073
    r, _ = diana.lu([1.0, 2.0**-538, 3 * 2.0**-537, 2.0**-1060])
    assert r[3] == 2.0**-1060 - 2.0**-1073


@pytest.mark.parametrize(
    "a",
    [
        [0.0],
        [-0.0],
        [0.0, 0.0, 0.0, 0.0],
        [-0.0, 0.0, 0.0, 1.0],
        [0.0, 0.0, 1.0, 1.0],
        [1.0, 2.0, 2.0, 4.0],
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0],
    ],
    ids=[
        "zero",
        "negative-zero",
        "zero-2",
        "signed-zero-column",
        "zero-column",
        "rank-one",
        "last",
    ],
)
def test_singular(a):
    with pytest.raises(diana.SingularError, match="singular"):
        diana.lu(a)
    assert issubclass(diana.SingularError, ValueError)


@pytest.mark.parametrize(
    "a",
    [
        [1.0, 1.0, -DBL_MAX, DBL_MAX],
        [1.0, 0.5, -1.0, 1.0, 1.0, DBL_MAX, -DBL_MAX, 0.0, -DBL_MAX],
    ],
    ids=["first", "late"],
)
def test_overflow(a):
    with pytest.raises(diana.FloatOverflowError, match="an update overflows") as info:
        diana.lu(a)
    assert info.type is diana.FloatOverflowError


@pytest.mark.parametrize("p", range(9))
@pytest.mark.parametrize("v", [math.nan, math.inf, -math.inf])
def test_nonfinite(p, v):
    a = list(A3)
    a[p] = v
    with pytest.raises(ValueError, match="non-finite") as info:
        diana.lu(a)
    assert info.type is ValueError


@pytest.mark.parametrize(
    ("a", "match"),
    [
        ([], "at least one sample"),
        (np.array([]), "at least one sample"),
        ([1.0, 0.0], "square number"),
        ([1.0] * 5, "square number"),
        (np.eye(2), "one-dimensional"),
        (np.ones(8)[::2], "C-contiguous"),
    ],
)
def test_bad_shape(a, match):
    with pytest.raises(ValueError, match=match):
        diana.lu(a)


@pytest.mark.parametrize(
    "a", [np.ones(4, dtype=np.float32), np.ones(4, dtype=np.int64), np.ones(4, dtype=">f8")]
)
def test_wrong_dtype(a):
    if a.dtype.byteorder == ">" and sys.byteorder == "big":
        pytest.skip("big-endian host")
    with pytest.raises(TypeError, match="native float64"):
        diana.lu(a)


def test_wrong_element_type():
    with pytest.raises(TypeError):
        diana.lu(["1.0"])
    with pytest.raises(TypeError):
        diana.lu("1.0")


def test_extension_checks_out():
    a = array.array("d", A3)
    with pytest.raises(TypeError):
        diana._diana.lu(A3, array.array("d", [0.0] * 9))
    with pytest.raises(BufferError):
        diana._diana.lu(a, bytes(72))
    with pytest.raises(ValueError, match="out must have at least one sample"):
        diana._diana.lu(a, array.array("d"))
    with pytest.raises(ValueError, match="out must have the same length as a"):
        diana._diana.lu(a, array.array("d", [0.0] * 4))
    with pytest.raises(ValueError, match="overlap"):
        diana._diana.lu(a, a)
    data = np.zeros(12)
    data[:9] = A3
    with pytest.raises(ValueError, match="overlap"):
        diana._diana.lu(data[:9], data[3:])
    out = array.array("d", [7.0] * 9)
    bad = array.array("d", A3)
    bad[4] = math.nan
    with pytest.raises(ValueError, match="non-finite"):
        diana._diana.lu(bad, out)
    assert list(out) == [7.0] * 9
    assert diana._diana.lu(a, out) == PIV3
    assert list(out) == LU3


def test_exact_permuted():
    # A = P^T L U with 0 < |L[i, k]| < 1 in eighths and integer U: partial pivoting recovers P,
    # and every operation is exact, so the kernel returns L and U.
    rng = random.Random(20261017)
    for n in (1, 2, 5, 12, 20):
        lo = np.eye(n)
        up = np.zeros((n, n))
        for i in range(n):
            up[i, i] = rng.choice([-3.0, -2.0, -1.0, 1.0, 2.0, 3.0])
            for j in range(i):
                lo[i, j] = rng.choice([-7, -5, -3, -1, 1, 3, 5, 7]) / 8.0
            for j in range(i + 1, n):
                up[i, j] = float(rng.randint(-9, 9))
        rows = list(range(n))
        rng.shuffle(rows)
        a = np.zeros((n, n))
        a[rows] = lo @ up
        r, piv = diana.lu(a.ravel(order="F"))
        assert list(r) == list((np.tril(lo, -1) + np.triu(up)).ravel(order="F"))
        assert permute(list(a.ravel(order="F")), n, piv) == list((lo @ up).ravel(order="F"))


def test_matches_binary64_random():
    rng = random.Random(1729)
    for n in (1, 2, 3, 7, 16, 31):
        for scale in (1.0, 1e-300, 1e300):
            a = random_matrix(rng, n, scale)
            want = reference(a, n)
            assert isinstance(want, tuple)
            r, piv = diana.lu(a)
            assert all(same(x, y) for x, y in zip(r, want[0], strict=True))
            assert list(piv) == want[1]


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
    if want == "singular":
        with pytest.raises(diana.SingularError):
            diana.lu(a)
    elif want == "overflow":
        with pytest.raises(diana.FloatOverflowError, match="overflows"):
            diana.lu(a)
    else:
        r, piv = diana.lu(a)
        assert all(same(x, y) for x, y in zip(r, want[0], strict=True))
        assert list(piv) == want[1]
        assert all(math.isfinite(x) for x in r)
        assert all(k <= p < n for k, p in enumerate(piv))
        assert all(abs(r[i + j * n]) <= 1.0 for j in range(n) for i in range(j + 1, n))


def test_backward_error_bound():
    # With B = P*A, evaluated exactly in rationals (0-based indices):
    # i <= j: |B[i, j] - sum_{t<i} L[i, t] U[t, j] - U[i, j]|
    #           <= gamma(i) (sum_{t<i} |L[i, t] U[t, j]| + |U[i, j]|) + (1 + gamma(i)) i eta
    # i > j:  |B[i, j] - sum_{t<j} L[i, t] U[t, j] - L[i, j] U[j, j]|
    #           <= gamma(j + 1) (sum_{t<j} |L[i, t] U[t, j]| + |L[i, j] U[j, j]|)
    #              + (1 + gamma(j + 1)) (j + |U[j, j]|) eta
    rng = random.Random(42)
    for n in (2, 5, 10, 20):
        for scale in (1.0, 2.0**-1000, 2.0**1000):
            a = random_matrix(rng, n, scale)
            r, piv = diana.lu(a)
            b = permute(a, n, piv)
            for j in range(n):
                for i in range(n):
                    m = min(i, j)
                    prods = [Fraction(r[i + t * n]) * Fraction(r[t + j * n]) for t in range(m)]
                    if i <= j:
                        prods.append(Fraction(r[i + j * n]))
                        g = gamma(i)
                        under = (1 + g) * i * ETA
                    else:
                        prods.append(Fraction(r[i + j * n]) * Fraction(r[j + j * n]))
                        g = gamma(j + 1)
                        under = (1 + g) * (j + abs(Fraction(r[j + j * n]))) * ETA
                    err = abs(Fraction(b[i + j * n]) - sum(prods))
                    assert err <= g * sum(abs(p) for p in prods) + under


def test_agrees_with_lapack_solve():
    rng = random.Random(7)
    for n in (3, 10, 40):
        a = random_matrix(rng, n)
        rhs = np.array([rng.uniform(-1.0, 1.0) for _ in range(n)])
        r, piv = diana.lu(a)
        lo, up = factors(r, n)
        pb = rhs.copy()
        for k, p in enumerate(piv):
            pb[[k, p]] = pb[[p, k]]
        x = np.linalg.solve(up, np.linalg.solve(lo, pb))
        want = np.linalg.solve(np.array(a).reshape(n, n, order="F"), rhs)
        assert np.allclose(x, want, rtol=1e-9, atol=1e-12)
