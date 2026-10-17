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

# L = [[2, 0, 0], [1, 4, 0], [-1, 2, 1]] column-major and x = (3, -2, 5): every operation is
# exact, so both solves return x.
L3 = [2.0, 1.0, -1.0, 0.0, 4.0, 2.0, 0.0, 0.0, 1.0]
X3 = [3.0, -2.0, 5.0]
FB3 = [6.0, -5.0, -2.0]  # L x
BB3 = [-1.0, 2.0, 5.0]  # L^T x

SOLVES = [diana.forward_substitution, diana.back_substitution]
SOLVE_IDS = ["forward", "back"]


def forward_reference(lower, n, b):
    """The forward kernel's checks and operations in its order, in binary64."""
    if not all(math.isfinite(lower[i + j * n]) for j in range(n) for i in range(j, n)):
        return "arg"
    if not all(math.isfinite(v) for v in b):
        return "arg"
    if any(lower[i + i * n] == 0.0 for i in range(n)):
        return "singular"
    x = []
    for i in range(n):
        s = b[i]
        for k in range(i):
            s = s - lower[i + k * n] * x[k]
        r = s / lower[i + i * n]
        if not math.isfinite(r):
            return "overflow"
        x.append(r)
    return x


def back_reference(lower, n, b):
    """The back kernel: row i = n-1, ..., 0, products subtracted from k = n-1 down to i+1."""
    if not all(math.isfinite(lower[i + j * n]) for j in range(n) for i in range(j, n)):
        return "arg"
    if not all(math.isfinite(v) for v in b):
        return "arg"
    if any(lower[i + i * n] == 0.0 for i in range(n)):
        return "singular"
    x = [0.0] * n
    for i in reversed(range(n)):
        s = b[i]
        for k in range(n - 1, i, -1):
            s = s - lower[k + i * n] * x[k]
        r = s / lower[i + i * n]
        if not math.isfinite(r):
            return "overflow"
        x[i] = r
    return x


REFERENCES = {
    diana.forward_substitution: forward_reference,
    diana.back_substitution: back_reference,
}


def same(a, b):
    return a == b and math.copysign(1.0, a) == math.copysign(1.0, b)


def gamma(k):
    return k * U / (1 - k * U)


def system(rng, n, scale=1.0):
    """A random lower-triangular L with diagonal of modulus 1 to 2 (random strict upper part,
    which is not read) and a random b, column-major."""
    lower = [rng.uniform(-1.0, 1.0) for _ in range(n * n)]
    for i in range(n):
        lower[i + i * n] = rng.choice([-1.0, 1.0]) * rng.uniform(1.0, 2.0)
    b = [scale * rng.uniform(-1.0, 1.0) for _ in range(n)]
    return lower, b


def flip(lower, n):
    """L'[p, q] = L[n-1-q, n-1-p]: the reversed system of L^T as a lower-triangular one."""
    return [lower[(n - 1 - q) + (n - 1 - p) * n] for q in range(n) for p in range(n)]


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
    for solve, b in ((diana.forward_substitution, FB3), (diana.back_substitution, BB3)):
        r = solve(make(L3), make(b))
        assert type(r) is array.array
        assert r.typecode == "d"
        assert list(r) == X3


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
def test_keyword_and_inputs_kept(solve):
    lower = np.array(L3)
    b = np.array(FB3)
    solve(lower=lower, b=b)
    assert list(lower) == L3
    assert list(b) == FB3


def test_numpy_layout():
    lo = np.array([[2.0, 0.0, 0.0], [1.0, 4.0, 0.0], [-1.0, 2.0, 1.0]])
    x = np.array(X3)
    assert np.array_equal(np.asarray(diana.forward_substitution(lo.ravel(order="F"), lo @ x)), x)
    assert np.array_equal(np.asarray(diana.back_substitution(lo.ravel(order="F"), lo.T @ x)), x)


def test_cholesky_solve():
    # A = L L^T with L = [[2, 0, 0], [1, 3, 0], [-1, 2, 4]]: A x = b for x = (1, -2, 3).
    a = [4.0, 2.0, -2.0, 2.0, 10.0, 5.0, -2.0, 5.0, 21.0]
    lo = diana.cholesky(a)
    y = diana.forward_substitution(lo, [-6.0, -3.0, 51.0])
    assert list(y) == [-3.0, 0.0, 12.0]
    assert list(diana.back_substitution(lo, y)) == [1.0, -2.0, 3.0]


def test_cholesky_solve_agrees_with_lapack():
    rng = random.Random(11)
    for n in (3, 10, 40):
        b = np.array([[rng.uniform(-1.0, 1.0) for _ in range(n)] for _ in range(n)])
        a = b.T @ b + n * np.eye(n)
        rhs = np.array([rng.uniform(-1.0, 1.0) for _ in range(n)])
        lo = diana.cholesky(a.ravel(order="F"))
        x = np.asarray(diana.back_substitution(lo, diana.forward_substitution(lo, rhs)))
        assert np.allclose(x, np.linalg.solve(a, rhs), rtol=1e-12, atol=1e-14)


def test_one_by_one():
    assert list(diana.forward_substitution([4.0], [2.0])) == [0.5]
    assert list(diana.back_substitution([-4.0], [2.0])) == [-0.5]


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
def test_upper_triangle_ignored(solve):
    lower = list(L3)
    lower[3], lower[6], lower[7] = math.nan, math.inf, -math.inf
    b = FB3 if solve is diana.forward_substitution else BB3
    assert list(solve(lower, b)) == X3


def test_operation_order():
    # 5/3 rounds up; multiplying by fl(1/3) would round down.
    want = float.fromhex("0x1.aaaaaaaaaaaabp+0")
    assert diana.forward_substitution([3.0], [5.0])[0] == want
    assert diana.back_substitution([3.0], [5.0])[0] == want
    # (1 + 3*2^-52) - fl((1 + 2^-52)^2) is 2^-52; a fused multiply-add would leave
    # 2^-52 - 2^-104.
    lower = [1.0, 1.0 + EPS, 0.0, 1.0]
    assert diana.forward_substitution(lower, [1.0 + EPS, 1.0 + 3 * EPS])[1] == EPS
    assert diana.back_substitution(lower, [1.0 + 3 * EPS, 1.0 + EPS])[0] == EPS
    # 2^-53 - (-1) - (-2^-53) in this order is two ties that round to 1; the other order gives
    # 1 + 2^-52. Each solve subtracts first the product of the unknown it computed first.
    t = 2.0**-53
    forward = [1.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0]
    assert list(diana.forward_substitution(forward, [-1.0, -t, t])) == [-1.0, -t, 1.0]
    back = [1.0, 1.0, 1.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
    assert list(diana.back_substitution(back, [t, -t, -1.0])) == [1.0, -t, -1.0]


def test_signed_zero_and_underflow():
    r = diana.forward_substitution([-2.0, 0.0, 0.0, 4.0], [0.0, 0.0])
    assert same(r[0], -0.0) and same(r[1], 0.0)
    r = diana.back_substitution([-2.0, 0.0, 0.0, 4.0], [0.0, 0.0])
    assert same(r[0], -0.0) and same(r[1], 0.0)
    tiny = math.ulp(0.0)
    assert same(diana.forward_substitution([2.0], [tiny])[0], 0.0)
    assert diana.back_substitution([0.5], [tiny])[0] == 2 * tiny


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
@pytest.mark.parametrize(
    "lower",
    [
        [0.0],
        [-0.0],
        [0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0],
        [1.0, 1.0, 1.0, 0.0, -0.0, 1.0, 0.0, 0.0, 1.0],
        [1.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0],
    ],
    ids=["zero", "negative-zero", "first", "middle", "last"],
)
def test_singular(solve, lower):
    n = math.isqrt(len(lower))
    with pytest.raises(diana.SingularError, match="singular"):
        solve(lower, [1.0] * n)


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
def test_argument_error_before_singular(solve):
    zero_diagonal = [0.0, 1.0, 1.0, 0.0, 1.0, math.nan, 0.0, 0.0, 1.0]
    with pytest.raises(ValueError, match="non-finite") as info:
        solve(zero_diagonal, [1.0, 2.0, 3.0])
    assert info.type is ValueError
    with pytest.raises(ValueError, match="non-finite") as info:
        solve([0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0], [1.0, math.inf, 3.0])
    assert info.type is ValueError


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
@pytest.mark.parametrize("p", [0, 1, 2, 4, 5, 8])
@pytest.mark.parametrize("v", [math.nan, math.inf, -math.inf])
def test_nonfinite_lower(solve, p, v):
    lower = list(L3)
    lower[p] = v
    with pytest.raises(ValueError, match="non-finite"):
        solve(lower, [1.0, 2.0, 3.0])


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
@pytest.mark.parametrize("p", [0, 1, 2])
@pytest.mark.parametrize("v", [math.nan, math.inf, -math.inf])
def test_nonfinite_rhs(solve, p, v):
    b = [1.0, 2.0, 3.0]
    b[p] = v
    with pytest.raises(ValueError, match="non-finite"):
        solve(L3, b)


@pytest.mark.parametrize(
    ("solve", "lower", "b"),
    [
        (diana.forward_substitution, [1e-300], [1e300]),
        (diana.back_substitution, [1e-300], [1e300]),
        (diana.forward_substitution, [1.0, 1e300, 0.0, 1.0], [1e300, 0.0]),
        (diana.forward_substitution, [1.0, -1.0, 0.0, 1.0], [DBL_MAX, DBL_MAX]),
        (diana.back_substitution, [1.0, -1.0, 0.0, 1.0], [DBL_MAX, DBL_MAX]),
        (
            diana.forward_substitution,
            [1.0, 0.0, -1e300, 0.0, 1.0, 1e300, 0.0, 0.0, 1.0],
            [1e300, 1e300, 0.0],
        ),
        (
            diana.back_substitution,
            [1.0, 1e300, -1e300, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
            [0.0, 1e300, 1e300],
        ),
    ],
    ids=["quotient-f", "quotient-b", "product", "difference-f", "difference-b", "nan-f", "nan-b"],
)
def test_overflow(solve, lower, b):
    with pytest.raises(ValueError, match="overflows") as info:
        solve(lower, b)
    assert info.type is ValueError


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
@pytest.mark.parametrize(
    ("lower", "b", "match"),
    [
        ([1.0], [], "b must have at least one sample"),
        ([], [1.0], "lower must have at least one sample"),
        ([1.0, 0.0], [1.0], "n\\*n samples"),
        ([1.0, 0.0, 0.0, 1.0], [1.0], "n\\*n samples"),
        ([1.0, 0.0, 0.0], [1.0, 1.0], "n\\*n samples"),
        (np.eye(2), [1.0, 1.0], "one-dimensional"),
        ([1.0, 0.0, 0.0, 1.0], np.ones((2, 1)), "one-dimensional"),
        (np.ones(8)[::2], [1.0, 1.0], "C-contiguous"),
        ([1.0, 0.0, 0.0, 1.0], np.ones(4)[::2], "C-contiguous"),
    ],
)
def test_bad_shape(solve, lower, b, match):
    with pytest.raises(ValueError, match=match):
        solve(lower, b)


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
@pytest.mark.parametrize(
    "v", [np.ones(4, dtype=np.float32), np.ones(4, dtype=np.int64), np.ones(4, dtype=">f8")]
)
def test_wrong_dtype(solve, v):
    if v.dtype.byteorder == ">" and sys.byteorder == "big":
        pytest.skip("big-endian host")
    with pytest.raises(TypeError, match="native float64"):
        solve(v, [1.0, 1.0])
    with pytest.raises(TypeError, match="native float64"):
        solve([1.0] * 16, v)


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
def test_wrong_element_type(solve):
    with pytest.raises(TypeError):
        solve(["1.0"], [1.0])
    with pytest.raises(TypeError):
        solve([1.0], "1")


@pytest.mark.parametrize("name", ["forward_substitution", "back_substitution"])
def test_extension_checks_out(name):
    ext = getattr(diana._diana, name)
    lower = array.array("d", L3)
    b = array.array("d", FB3 if name == "forward_substitution" else BB3)
    with pytest.raises(TypeError):
        ext(lower, b, [0.0] * 3)
    with pytest.raises(BufferError):
        ext(lower, b, bytes(24))
    with pytest.raises(ValueError, match="out must have at least one sample"):
        ext(lower, b, array.array("d"))
    with pytest.raises(ValueError, match="out must have the same length as b"):
        ext(lower, b, array.array("d", [0.0] * 4))
    with pytest.raises(ValueError, match="overlap"):
        ext(lower, b, b)
    data = np.zeros(9)
    data[:] = L3
    with pytest.raises(ValueError, match="overlap"):
        ext(data, b, data[6:])
    out = array.array("d", [7.0] * 3)
    bad = array.array("d", b)
    bad[1] = math.nan
    with pytest.raises(ValueError, match="non-finite"):
        ext(lower, bad, out)
    assert list(out) == [7.0] * 3
    with pytest.raises(diana.SingularError):
        ext(array.array("d", [0.0, 1.0, 1.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0]), b, out)
    assert list(out) == [7.0] * 3
    assert ext(lower, b, out) is None
    assert list(out) == X3


def test_matches_binary64_random():
    rng = random.Random(1729)
    for n in (1, 2, 3, 7, 16, 31):
        for scale in (1.0, 1e-300, 2.0**900):
            lower, b = system(rng, n, scale)
            for solve in SOLVES:
                want = REFERENCES[solve](lower, n, b)
                assert isinstance(want, list)
                r = solve(lower, b)
                assert all(same(x, y) for x, y in zip(r, want, strict=True))


def test_back_is_reversed_forward():
    rng = random.Random(2718)
    for n in range(1, 25):
        lower, b = system(rng, n)
        x = diana.back_substitution(lower, b)
        xr = diana.forward_substitution(flip(lower, n), b[::-1])
        assert all(same(p, q) for p, q in zip(x, xr[::-1], strict=True))


square = st.integers(1, 6).flatmap(
    lambda n: st.tuples(
        st.lists(
            st.floats(allow_nan=False, allow_infinity=False, width=64),
            min_size=n * n,
            max_size=n * n,
        ),
        st.lists(
            st.floats(allow_nan=False, allow_infinity=False, width=64), min_size=n, max_size=n
        ),
    )
)


@pytest.mark.parametrize("solve", SOLVES, ids=SOLVE_IDS)
@settings(database=None, derandomize=True, max_examples=500)
@given(square)
def test_matches_binary64_any(solve, case):
    lower, b = case
    n = len(b)
    want = REFERENCES[solve](lower, n, b)
    if want == "singular":
        with pytest.raises(diana.SingularError):
            solve(lower, b)
    elif want == "overflow":
        with pytest.raises(ValueError, match="overflows"):
            solve(lower, b)
    else:
        r = solve(lower, b)
        assert all(same(x, y) for x, y in zip(r, want, strict=True))
        assert all(math.isfinite(x) for x in r)


def residual_bound(lower, n, x, rows):
    """For each row i the pair (residual, bound) of the backward error theorems in rationals:
    rows(i) lists the (entry, unknown) indices of row i, the diagonal one last."""
    out = []
    for i in range(n):
        terms = [Fraction(lower[e]) * Fraction(x[k]) for e, k in rows(i)]
        g = gamma(len(terms))
        out.append((terms, g, len(terms) - 1, abs(Fraction(lower[i + i * n]))))
    return out


def forward_rows(n):
    return lambda i: [(i + k * n, k) for k in range(i + 1)]


def back_rows(n):
    return lambda i: [(k + i * n, k) for k in range(n - 1, i - 1, -1)]


def exact_forward(lower, n, b):
    x = []
    for i in range(n):
        s = b[i] - sum(lower[i + k * n] * x[k] for k in range(i))
        x.append(s / lower[i + i * n])
    return x


def exact_back(lower, n, b):
    x = [Fraction(0)] * n
    for i in reversed(range(n)):
        s = b[i] - sum(lower[k + i * n] * x[k] for k in range(i + 1, n))
        x[i] = s / lower[i + i * n]
    return x


@pytest.mark.parametrize(
    ("solve", "rows", "exact", "comparison"),
    [
        (diana.forward_substitution, forward_rows, exact_forward, exact_forward),
        (diana.back_substitution, back_rows, exact_back, exact_back),
    ],
    ids=SOLVE_IDS,
)
def test_error_bounds(solve, rows, exact, comparison):
    # Backward error, row i with m = i + 1 (forward) or n - i (back) terms:
    #   |b[i] - sum_k L x^| <= gamma(m) sum_k |L x^| + (1 + gamma(m)) (m - 1 + |L[i, i]|) eta.
    # Forward error: |x - x^| <= z, z the solve of the bounds with the comparison matrix
    # (|L[i, i]| on the diagonal, -|L[i, k]| off it). Both evaluated exactly in rationals.
    rng = random.Random(42)
    for n in (2, 5, 10, 20):
        for scale in (1.0, 2.0**-1000, 2.0**1000):
            lower, b = system(rng, n, scale)
            x = solve(lower, b)
            rho = []
            for i, (terms, g, products, diag) in enumerate(residual_bound(lower, n, x, rows(n))):
                err = abs(Fraction(b[i]) - sum(terms))
                bound = g * sum(abs(t) for t in terms) + (1 + g) * (products + diag) * ETA
                assert err <= bound
                rho.append(bound)
            fl = [Fraction(v) for v in lower]
            cmp = [-abs(v) for v in fl]
            for i in range(n):
                cmp[i + i * n] = abs(fl[i + i * n])
            xs = exact(fl, n, [Fraction(v) for v in b])
            z = comparison(cmp, n, rho)
            assert all(abs(xs[i] - Fraction(x[i])) <= z[i] for i in range(n))
