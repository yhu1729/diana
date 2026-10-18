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

# A = [[2, 1, 1], [4, -6, 0], [-2, 7, 2]] column-major pivots on row 1, then keeps row 1 on a
# tie: L = [[1, 0, 0], [1/2, 1, 0], [-1/2, 1, 1]], U = [[4, -6, 0], [0, 4, 1], [0, 0, 1]], and
# every operation of the factorization and of the solve is exact: A x = b for x = (1, -2, 3).
A3 = [2.0, 4.0, -2.0, 1.0, -6.0, 7.0, 1.0, 0.0, 2.0]
LU3 = [4.0, 0.5, -0.5, -6.0, 4.0, 1.0, 0.0, 1.0, 1.0]
PIV3 = [1, 1, 2]
B3 = [3.0, 16.0, -10.0]
X3 = [1.0, -2.0, 3.0]
IDENTITY3 = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]


def interchange(b, piv):
    """P*b: rows k and piv[k] swapped for k = 0, 1, ..., n-1."""
    c = list(b)
    for k, p in enumerate(piv):
        c[k], c[p] = c[p], c[k]
    return c


def reference(lu, piv, b):
    """The kernel's checks and operations in its order, in binary64 (Python floats round like C
    doubles): ``(y, x)`` on success, else ``"arg"``, ``"singular"`` or ``"overflow"``."""
    n = len(b)
    if not all(math.isfinite(v) for v in lu):
        return "arg"
    if not all(0 <= p < n for p in piv):
        return "arg"
    if not all(math.isfinite(v) for v in b):
        return "arg"
    if any(lu[i + i * n] == 0.0 for i in range(n)):
        return "singular"
    y = interchange(b, piv)
    for i in range(n):
        s = y[i]
        for k in range(i):
            s = s - lu[i + k * n] * y[k]
        if not math.isfinite(s):
            return "overflow"
        y[i] = s
    x = list(y)
    for i in reversed(range(n)):
        s = x[i]
        for k in range(n - 1, i, -1):
            s = s - lu[i + k * n] * x[k]
        r = s / lu[i + i * n]
        if not math.isfinite(r):
            return "overflow"
        x[i] = r
    return y, x


def same(a, b):
    return a == b and math.copysign(1.0, a) == math.copysign(1.0, b)


def gamma(k):
    return k * U / (1 - k * U)


def random_matrix(rng, n, scale=1.0):
    return [scale * rng.uniform(-1.0, 1.0) for _ in range(n * n)]


MAKERS = [
    list,
    tuple,
    iter,
    lambda v: [Fraction(x) for x in v],
    lambda v: array.array("d", v),
    lambda v: np.array(v),
    lambda v: memoryview(array.array("d", v).tobytes()).cast("d"),
    lambda v: (ctypes.c_double * len(v))(*v),
]
MAKER_IDS = ["list", "tuple", "iterator", "fraction", "array", "numpy", "readonly", "ctypes"]


@pytest.mark.parametrize("make", MAKERS, ids=MAKER_IDS)
def test_container(make):
    r = diana.lu_solve(make(LU3), PIV3, make(B3))
    assert type(r) is array.array
    assert r.typecode == "d"
    assert list(r) == X3


@pytest.mark.parametrize(
    "make",
    [list, tuple, iter, lambda v: array.array("q", v), lambda v: np.array(v)],
    ids=["list", "tuple", "iterator", "array", "numpy"],
)
def test_pivot_container(make):
    assert list(diana.lu_solve(LU3, make(PIV3), B3)) == X3


def test_keyword_and_inputs_kept():
    lu = np.array(LU3)
    piv = list(PIV3)
    b = np.array(B3)
    assert list(diana.lu_solve(lu=lu, piv=piv, b=b)) == X3
    assert list(lu) == LU3
    assert piv == PIV3
    assert list(b) == B3


def test_after_lu():
    assert diana.lu(A3) == (array.array("d", LU3), PIV3)
    assert list(diana.lu_solve(*diana.lu(A3), B3)) == X3
    a = np.array([[2.0, 1.0, 1.0], [4.0, -6.0, 0.0], [-2.0, 7.0, 2.0]])
    assert np.array_equal(
        np.asarray(diana.lu_solve(*diana.lu(a.ravel(order="F")), a @ np.array(X3))), X3
    )


def test_one_by_one():
    assert list(diana.lu_solve([2.0], [0], [6.0])) == [3.0]
    assert list(diana.lu_solve([-0.5], [0], [DBL_MAX / 2])) == [-DBL_MAX]


def test_interchange_order():
    # (1, 2, 2) turns b into (b1, b2, b0); applying the swaps in reverse order would give
    # (b2, b0, b1). A pivot row below k is an interchange too.
    assert list(diana.lu_solve(IDENTITY3, [1, 2, 2], [1.0, 2.0, 3.0])) == [2.0, 3.0, 1.0]
    assert list(diana.lu_solve(IDENTITY3, [0, 0, 1], [1.0, 2.0, 3.0])) == [2.0, 3.0, 1.0]
    assert list(diana.lu_solve(IDENTITY3, [2, 1, 2], [1.0, 2.0, 3.0])) == [3.0, 2.0, 1.0]
    # (2, 1, 0) swaps rows 0 and 2 at step 0 and back at step 2
    assert list(diana.lu_solve(IDENTITY3, [2, 1, 0], [1.0, 2.0, 3.0])) == [1.0, 2.0, 3.0]


def test_operation_order():
    # 5/3 rounds up; multiplying by fl(1/3) would round down.
    assert diana.lu_solve([3.0], [0], [5.0])[0] == float.fromhex("0x1.aaaaaaaaaaaabp+0")
    # (1 + 3*2^-52) - fl((1 + 2^-52)^2) is 2^-52 in each solve; a fused multiply-add would give
    # 2^-52 - 2^-104.
    lower = [1.0, 1.0 + EPS, 0.0, 1.0]
    upper = [1.0, 0.0, 1.0 + EPS, 1.0]
    assert list(diana.lu_solve(lower, [0, 1], [1.0 + EPS, 1.0 + 3 * EPS])) == [1.0 + EPS, EPS]
    assert list(diana.lu_solve(upper, [0, 1], [1.0 + 3 * EPS, 1.0 + EPS])) == [EPS, 1.0 + EPS]
    # 2^-53 - (-1) - (-2^-53) is two ties that round to 1; the other order gives 1 + 2^-52.
    t = 2.0**-53
    lower3 = [1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0]
    upper3 = [1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 1.0, 0.0, 1.0]
    assert list(diana.lu_solve(lower3, [0, 1, 2], [-1.0, -t, t])) == [-1.0, -t, 1.0]
    assert list(diana.lu_solve(upper3, [0, 1, 2], [t, -t, -1.0])) == [1.0, -t, -1.0]


def test_signed_zero_and_underflow():
    r = diana.lu_solve([-2.0, 0.0, 0.0, 4.0], [0, 1], [0.0, 0.0])
    assert same(r[0], -0.0)
    assert same(r[1], 0.0)
    tiny = math.ulp(0.0)
    assert same(diana.lu_solve([2.0], [0], [tiny])[0], 0.0)
    assert diana.lu_solve([0.5], [0], [tiny])[0] == 2 * tiny


@pytest.mark.parametrize("p", range(3))
@pytest.mark.parametrize("zero", [0.0, -0.0])
def test_singular(p, zero):
    lu = list(LU3)
    lu[p + 3 * p] = zero
    with pytest.raises(diana.SingularError, match="singular"):
        diana.lu_solve(lu, PIV3, B3)
    assert issubclass(diana.SingularError, ValueError)


def test_argument_error_before_singular():
    lu = list(LU3)
    lu[0] = 0.0
    with pytest.raises(ValueError, match="non-finite") as info:
        diana.lu_solve(lu, PIV3, [3.0, math.nan, -10.0])
    assert not isinstance(info.value, diana.SingularError)
    with pytest.raises(ValueError, match="pivot row") as info:
        diana.lu_solve(lu, [3, 1, 2], B3)
    assert not isinstance(info.value, diana.SingularError)


@pytest.mark.parametrize("p", range(9))
@pytest.mark.parametrize("v", [math.nan, math.inf, -math.inf])
def test_nonfinite_lu(p, v):
    lu = list(LU3)
    lu[p] = v
    with pytest.raises(ValueError, match="non-finite") as info:
        diana.lu_solve(lu, PIV3, B3)
    assert info.type is ValueError


@pytest.mark.parametrize("p", range(3))
@pytest.mark.parametrize("v", [math.nan, math.inf, -math.inf])
def test_nonfinite_rhs(p, v):
    b = list(B3)
    b[p] = v
    with pytest.raises(ValueError, match="non-finite") as info:
        diana.lu_solve(LU3, PIV3, b)
    assert info.type is ValueError


@pytest.mark.parametrize("p", range(3))
@pytest.mark.parametrize("row", [3, 2**64 - 1])
def test_pivot_row_out_of_range(p, row):
    piv = list(PIV3)
    piv[p] = row
    with pytest.raises(ValueError, match="pivot row"):
        diana.lu_solve(LU3, piv, B3)


@pytest.mark.parametrize(
    ("piv", "error"),
    [
        ([1, -1, 2], OverflowError),
        ([1, 2**64, 2], OverflowError),
        ([1, 1.0, 2], TypeError),
        ([1, "1", 2], TypeError),
        (None, TypeError),
        (5, TypeError),
    ],
    ids=["negative", "too-large", "float", "str", "none", "int"],
)
def test_pivot_type(piv, error):
    with pytest.raises(error):
        diana.lu_solve(LU3, piv, B3)


def test_pivot_snapshot():
    # The extension converts a copy of piv, so an __index__ that empties the list reads no freed
    # item and the solve uses the rows piv held when it was called.
    class Clear:
        def __index__(self):
            piv.clear()
            return PIV3[0]

    piv = [Clear(), *PIV3[1:]]
    assert list(diana.lu_solve(LU3, piv, B3)) == X3
    assert piv == []


@pytest.mark.parametrize(
    ("lu", "b"),
    [
        # the forward solve: -DBL_MAX - 1 * DBL_MAX
        ([1.0, 1.0, 0.0, 1.0], [DBL_MAX, -DBL_MAX]),
        # the forward solve: 0 - (-inf) - inf is NaN
        ([1.0, 0.0, -1e300, 0.0, 1.0, 1e300, 0.0, 0.0, 1.0], [1e300, 1e300, 0.0]),
        # the back solve: 1e300 / 1e-300, a product 1e300 * 1e300, DBL_MAX - (-1) * DBL_MAX
        ([1e-300], [1e300]),
        ([1.0, 0.0, 1e300, 1.0], [0.0, 1e300]),
        ([1.0, 0.0, -1.0, 1.0], [DBL_MAX, DBL_MAX]),
    ],
    ids=["forward-difference", "forward-nan", "quotient", "product", "difference"],
)
def test_overflow(lu, b):
    with pytest.raises(diana.FloatOverflowError, match="the solution overflows") as info:
        diana.lu_solve(lu, list(range(len(b))), b)
    assert info.type is diana.FloatOverflowError


@pytest.mark.parametrize(
    ("lu", "piv", "b", "match"),
    [
        ([1.0], [0], [], "b must have at least one sample"),
        ([], [0], [1.0], "lu must have at least one sample"),
        ([1.0, 0.0], [0], [1.0], "n\\*n samples"),
        ([1.0, 0.0, 0.0], [0, 1], [1.0, 1.0], "n\\*n samples"),
        ([1.0], [], [1.0], "piv must have the same length as b"),
        ([1.0], [0, 0], [1.0], "piv must have the same length as b"),
        (np.eye(2), [0, 1], [1.0, 1.0], "one-dimensional"),
        ([1.0, 0.0, 0.0, 1.0], [0, 1], np.ones((2, 1)), "one-dimensional"),
        (np.ones(8)[::2], [0, 1], [1.0, 1.0], "C-contiguous"),
    ],
)
def test_bad_shape(lu, piv, b, match):
    with pytest.raises(ValueError, match=match):
        diana.lu_solve(lu, piv, b)


@pytest.mark.parametrize(
    "v", [np.ones(4, dtype=np.float32), np.ones(4, dtype=np.int64), np.ones(4, dtype=">f8")]
)
def test_wrong_dtype(v):
    if v.dtype.byteorder == ">" and sys.byteorder == "big":
        pytest.skip("big-endian host")
    with pytest.raises(TypeError, match="native float64"):
        diana.lu_solve(v, [0, 1], [1.0, 1.0])
    with pytest.raises(TypeError, match="native float64"):
        diana.lu_solve([1.0] * 16, [0, 1, 2, 3], v)


def test_wrong_element_type():
    with pytest.raises(TypeError):
        diana.lu_solve(["1.0"], [0], [1.0])
    with pytest.raises(TypeError):
        diana.lu_solve([1.0], [0], "1")


def test_extension_checks_out():
    ext = diana._diana.lu_solve
    lu = array.array("d", LU3)
    b = array.array("d", B3)
    with pytest.raises(TypeError):
        ext(lu, PIV3, b, [0.0] * 3)
    with pytest.raises(BufferError):
        ext(lu, PIV3, b, bytes(24))
    with pytest.raises(ValueError, match="out must have at least one sample"):
        ext(lu, PIV3, b, array.array("d"))
    with pytest.raises(ValueError, match="out must have the same length as b"):
        ext(lu, PIV3, b, array.array("d", [0.0] * 4))
    with pytest.raises(ValueError, match="overlap"):
        ext(lu, PIV3, b, b)
    data = np.zeros(9)
    data[:] = LU3
    with pytest.raises(ValueError, match="overlap"):
        ext(data, PIV3, b, data[6:])
    out = array.array("d", [7.0] * 3)
    bad = array.array("d", b)
    bad[1] = math.nan
    with pytest.raises(ValueError, match="non-finite"):
        ext(lu, PIV3, bad, out)
    assert list(out) == [7.0] * 3
    with pytest.raises(ValueError, match="pivot row"):
        ext(lu, [1, 3, 2], b, out)
    assert list(out) == [7.0] * 3
    with pytest.raises(diana.SingularError):
        ext(array.array("d", [0.0, *LU3[1:]]), PIV3, b, out)
    assert list(out) == [7.0] * 3
    assert ext(lu, PIV3, b, out) is None
    assert list(out) == X3


def test_matches_binary64_random():
    rng = random.Random(1729)
    for n in (1, 2, 3, 7, 16, 31):
        for scale in (1.0, 1e-300, 2.0**900):
            lu, piv = diana.lu(random_matrix(rng, n))
            b = [scale * rng.uniform(-1.0, 1.0) for _ in range(n)]
            want = reference(lu, piv, b)
            assert isinstance(want, tuple)
            r = diana.lu_solve(lu, piv, b)
            assert all(same(x, y) for x, y in zip(r, want[1], strict=True))


def test_matches_substitution():
    # The solve is forward substitution with the unit lower factor on P*b (its division by 1 is
    # exact) and back substitution with the transposed upper factor, bit for bit.
    rng = random.Random(2718)
    for n in range(1, 25):
        lu, piv = diana.lu(random_matrix(rng, n))
        b = [rng.uniform(-1.0, 1.0) for _ in range(n)]
        lower = [lu[i + k * n] if i > k else float(i == k) for k in range(n) for i in range(n)]
        upper_t = [lu[k + i * n] if i >= k else 0.0 for k in range(n) for i in range(n)]
        y = diana.forward_substitution(lower, interchange(b, piv))
        want = diana.back_substitution(upper_t, y)
        assert all(same(x, w) for x, w in zip(diana.lu_solve(lu, piv, b), want, strict=True))


system = st.integers(1, 6).flatmap(
    lambda n: st.tuples(
        st.lists(
            st.floats(allow_nan=False, allow_infinity=False, width=64),
            min_size=n * n,
            max_size=n * n,
        ),
        st.lists(st.integers(0, n - 1), min_size=n, max_size=n),
        st.lists(
            st.floats(allow_nan=False, allow_infinity=False, width=64), min_size=n, max_size=n
        ),
    )
)


@settings(database=None, derandomize=True, max_examples=500)
@given(system)
def test_matches_binary64_any(case):
    lu, piv, b = case
    want = reference(lu, piv, b)
    if want == "singular":
        with pytest.raises(diana.SingularError):
            diana.lu_solve(lu, piv, b)
    elif want == "overflow":
        with pytest.raises(diana.FloatOverflowError, match="overflows"):
            diana.lu_solve(lu, piv, b)
    else:
        r = diana.lu_solve(lu, piv, b)
        assert all(same(x, y) for x, y in zip(r, want[1], strict=True))
        assert all(math.isfinite(x) for x in r)


def lu_bound(f, n, i, j):
    """The LU-B3 (i <= j) or LU-B4 (i > j) bound of entry (i, j) of P*A - L*U in rationals."""
    m = min(i, j)
    prods = [f[i + t * n] * f[t + j * n] for t in range(m)]
    if i <= j:
        prods.append(f[i + j * n])
        g = gamma(i)
        return g * sum(abs(p) for p in prods) + (1 + g) * i * ETA
    prods.append(f[i + j * n] * f[j + j * n])
    g = gamma(j + 1)
    return g * sum(abs(p) for p in prods) + (1 + g) * (j + abs(f[j + j * n])) * ETA


def test_error_bounds():
    # In exact rational arithmetic, with c = P*b, y^ and x^ the computed solutions:
    # B1: |c[i] - sum_{k<i} L[i, k] y^[k] - y^[i]|
    #       <= gamma(i) (sum_{k<i} |L[i, k] y^[k]| + |y^[i]|) + (1 + gamma(i)) i eta = alpha[i]
    # B2: |y^[i] - sum_{k>=i} U[i, k] x^[k]|
    #       <= gamma(n - i) sum_{k>=i} |U[i, k] x^[k]|
    #          + (1 + gamma(n - i)) (n - 1 - i + |U[i, i]|) eta = beta[i]
    # B3: |c[i] - (L U x^)[i]| <= alpha[i] + beta[i] + sum_{t<i} |L[i, t]| beta[t]
    # B4: |b[prow i] - (A x^)[prow i]| <= B3's bound + sum_j E[i, j] |x^[j]|, E the LU bounds.
    rng = random.Random(42)
    for n in (1, 2, 5, 10, 20):
        for scale in (1.0, 2.0**-1000, 2.0**1000):
            a = random_matrix(rng, n, scale)
            lu, piv = diana.lu(a)
            b = [scale * rng.uniform(-1.0, 1.0) for _ in range(n)]
            y, x = reference(lu, piv, b)
            assert list(diana.lu_solve(lu, piv, b)) == x
            f = [Fraction(v) for v in lu]
            fy = [Fraction(v) for v in y]
            fx = [Fraction(v) for v in x]
            c = [Fraction(v) for v in interchange(b, piv)]
            alpha = []
            beta = [Fraction(0)] * n
            for i in range(n):
                prods = [f[i + k * n] * fy[k] for k in range(i)]
                g = gamma(i)
                bound = g * (sum(abs(p) for p in prods) + abs(fy[i])) + (1 + g) * i * ETA
                assert abs(c[i] - sum(prods) - fy[i]) <= bound
                alpha.append(bound)
            for i in range(n):
                prods = [f[i + k * n] * fx[k] for k in range(i, n)]
                g = gamma(n - i)
                bound = (
                    g * sum(abs(p) for p in prods) + (1 + g) * (n - 1 - i + abs(f[i + i * n])) * ETA
                )
                assert abs(fy[i] - sum(prods)) <= bound
                beta[i] = bound
            ux = [sum(f[t + j * n] * fx[j] for j in range(t, n)) for t in range(n)]
            rows = interchange(list(range(n)), piv)
            fa = [Fraction(v) for v in a]
            for i in range(n):
                factored = alpha[i] + beta[i] + sum(abs(f[i + t * n]) * beta[t] for t in range(i))
                luxi = ux[i] + sum(f[i + t * n] * ux[t] for t in range(i))
                assert abs(c[i] - luxi) <= factored
                r = rows[i]
                assert Fraction(b[r]) == c[i]
                residual = Fraction(b[r]) - sum(fa[r + j * n] * fx[j] for j in range(n))
                assert abs(residual) <= factored + sum(
                    lu_bound(f, n, i, j) * abs(fx[j]) for j in range(n)
                )


def test_agrees_with_lapack():
    rng = random.Random(7)
    for n in (3, 10, 40):
        a = random_matrix(rng, n)
        b = [rng.uniform(-1.0, 1.0) for _ in range(n)]
        x = diana.lu_solve(*diana.lu(a), b)
        want = np.linalg.solve(np.array(a).reshape(n, n, order="F"), np.array(b))
        assert np.allclose(x, want, rtol=1e-9, atol=1e-12)
