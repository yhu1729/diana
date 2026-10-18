# Newton's method

Newton's method finds a root of a differentiable function `f` from a starting point `x₀` by the
iteration `x ← x − f(x)/f′(x)`. Near a simple root it converges quadratically, roughly doubling
the number of correct digits per step, but it may diverge from a poor start. Shared conventions are
in the [API overview](overview.md).

## C

`#include <diana/newton.h>`. Like [bisection](bisection.md), the kernel is a state machine: you
evaluate `f` and `f′` at `s.x` and pass both values back.

- `diana_newton_init(&s, x0, tol, max_iter)` starts at `x0` and returns `DIANA_CONTINUE`.
- `diana_newton_step(&s, f(s.x), f′(s.x))` applies the correction `dx = f(x)/f′(x)`. It returns
  `DIANA_CONTINUE` with the new iterate in `s.x`; `DIANA_OK` when `|dx| <= tol`, when `f(x)` is
  exactly zero, or when the correction no longer changes `x`; `DIANA_ERR_MAXITER` after
  `max_iter` steps; and `DIANA_ERR_SINGULAR` when `f′(x)` is zero and `f(x)` is not. Once the
  run has finished, a further `step` is rejected.
- `diana_newton_result(&s, &root, &dx)` gives the current iterate and the last correction.
  Either output may be `NULL`.

`init` returns `DIANA_ERR_ARG` for a `NULL` state, a NaN or infinite `x0` or `tol`, `tol < 0` or
`max_iter == 0`; `step` returns it for a NaN or infinite `f(x)` or `f′(x)` or a state whose
`status` is not `DIANA_CONTINUE` (a finished run, or a zero-initialized struct), and
`DIANA_ERR_OVERFLOW` for a correction or iterate that overflows. A step that fails with
`DIANA_ERR_ARG`, `DIANA_ERR_SINGULAR` or `DIANA_ERR_OVERFLOW` leaves the state unchanged.
Finding `√2` as the root of `x² − 2` from `x₀ = 2`:

```c
#include <stdio.h>

#include <diana/newton.h>

int main(void) {
  diana_newton_state s;
  double root, dx;
  diana_status st = diana_newton_init(&s, 2.0, 1e-12, 100u);
  while (st == DIANA_CONTINUE) {
    st = diana_newton_step(&s, s.x * s.x - 2.0, 2.0 * s.x);
  }
  if (st != DIANA_OK) {
    fprintf(stderr, "newton: %s\n", diana_status_str(st));
    return 1;
  }
  diana_newton_result(&s, &root, &dx);
  printf("root %.17g, dx %.3g, %u steps\n", root, dx, s.iter);
  return 0;
}
```

```text
root 1.4142135623730949, dx 1.57e-16, 6 steps
```

| Field | Meaning |
|---|---|
| `x` | current iterate, where `f` and `f′` are evaluated next |
| `dx` | last correction applied to `x` (0 before the first step) |
| `tol` | stop once `|dx| <= tol` |
| `iter`, `max_iter` | steps taken so far, and the limit |
| `status` | `DIANA_CONTINUE` while the run goes on, then the `DIANA_OK` or `DIANA_ERR_MAXITER` that ended it |

Always pass a positive tolerance. With `tol = 0` the iteration usually never stops by itself: in
binary64 the computed `f(x)` at the double nearest the root is rarely exactly zero, and the
iterate alternates between the two doubles around the root until `max_iter`. A step that returns
`DIANA_ERR_MAXITER` has still updated the state, so `diana_newton_result` reports the estimate:

```c
#include <stdio.h>

#include <diana/newton.h>

int main(void) {
  diana_newton_state s;
  double root, dx;
  diana_status st = diana_newton_init(&s, 2.0, 0.0, 8u);
  while (st == DIANA_CONTINUE) {
    printf("step %u: x = %.17g\n", s.iter, s.x);
    st = diana_newton_step(&s, s.x * s.x - 2.0, 2.0 * s.x);
  }
  diana_newton_result(&s, &root, &dx);
  printf("%s after %u steps: root %.17g, dx %.3g\n", diana_status_str(st),
         s.iter, root, dx);
  return st == DIANA_OK ? 0 : 1;
}
```

```text
step 0: x = 2
step 1: x = 1.5
step 2: x = 1.4166666666666667
step 3: x = 1.4142156862745099
step 4: x = 1.4142135623746899
step 5: x = 1.4142135623730951
step 6: x = 1.4142135623730949
step 7: x = 1.4142135623730951
iteration limit reached after 8 steps: root 1.4142135623730949, dx 1.57e-16
```

## Callback wrapper

`diana_newton(f, ctx, x0, tol, max_iter, &root, &iter)` runs the loop over a callback
`double f(double x, double *dfx, void *ctx)` (`diana_newton_fn`) that returns `f(x)` and writes
`f′(x)` to `*dfx`. `root` receives the iterate on `DIANA_OK` and `DIANA_ERR_MAXITER`; `iter` (may
be `NULL`) receives the number of steps. The cube root of 10 as the root of `x³ − c` with `c` in
`ctx`:

```c
#include <stdio.h>

#include <diana/newton.h>

struct cubic {
  double c;
};

static double cube_minus_c(double x, double *dfx, void *ctx) {
  const struct cubic *p = ctx;
  *dfx = 3.0 * x * x;
  return x * x * x - p->c;
}

int main(void) {
  struct cubic p = {10.0};
  double root;
  unsigned iter;
  diana_status st =
      diana_newton(cube_minus_c, &p, 2.0, 1e-12, 100u, &root, &iter);
  if (st != DIANA_OK) {
    fprintf(stderr, "newton: %s after %u steps\n", diana_status_str(st), iter);
    return 1;
  }
  printf("cube root of %g: %.15g (%u steps)\n", p.c, root, iter);
  return 0;
}
```

```text
cube root of 10: 2.15443469003188 (5 steps)
```

## Python

`diana.newton(f, x0, tol, max_iter=100)` returns a root of the callable `f`, which returns the
pair `(f(x), f′(x))`. `tol` is required, for the reason above.

```python
>>> import math
>>> import diana
>>> diana.newton(lambda x: (x * x - 2, 2 * x), 2.0, 1e-12)
1.414213562373095
>>> diana.newton(lambda x: (math.cos(x) - x, -math.sin(x) - 1), 1.0, 1e-12)
0.7390851332151607
```

`diana.Newton(x0, tol, max_iter=100)` is the state machine, with the C fields, `status` among
them, as read-only attributes, `step(fx, dfx)` (returns the new status) and `result()`:

```python
>>> s = diana.Newton(2.0, 1e-6)
>>> while s.status == diana.CONTINUE:
...     _ = s.step(s.x * s.x - 2, 2 * s.x)
>>> s.status == diana.OK, s.iter, s.x
(True, 5, 1.4142135623730951)
>>> s.result()
(1.4142135623730951, 1.5947429102833119e-12)
```

A zero derivative where `f(x)` is not zero raises `diana.SingularError`, a non-finite value
`ValueError`, and an overflowing step `diana.FloatOverflowError`; each leaves the state at the last
iterate.
`diana.newton` raises `diana.MaxIterError` when `max_iter` is reached first, with the `estimate`
(the current iterate), its `uncertainty` (the last `|dx|`) and `iter`:

```python
>>> diana.newton(lambda x: (x * x + 1, 2 * x), 0.0, 1e-12)
Traceback (most recent call last):
  ...
diana._diana.SingularError: f'(x) is zero
>>> try:
...     diana.newton(lambda x: (x * x - 2, 2 * x), 2.0, 1e-12, max_iter=2)
... except diana.MaxIterError as e:
...     print(e.estimate, e.uncertainty, e.iter)
1.4166666666666667 0.08333333333333333 2
>>> try:
...     diana.newton(lambda x: (x * x - 2, 2 * x), 2.0, 0.0)
... except diana.MaxIterError as e:
...     print(e.iter, abs(e.estimate - math.sqrt(2)) <= math.ulp(math.sqrt(2)))
100 True
```

## Guarantees

Proved in Lean and Rocq, in exact arithmetic: each step near a simple root squares the error up to
a constant, and the iteration converges from a start close enough to the root. Proved in Rocq
with Flocq: the binary64 step stays within a rounding bound of the exact step, and a step that
leaves `x` unchanged has a correction of at most half an ulp. Proved of the C code: VST shows that
each function computes that binary64 model, and Frama-C that it is memory-safe and free of
undefined behaviour. Not proved: that the binary64 iteration converges from a given `x₀`;
`max_iter` is the only bound on the number of steps. Theorems: `spec/newton.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-010](../../note/api/API-010.md) step exits in check order,
[API-011](../../note/api/API-011.md) the `tol = 0` two-cycle,
[API-012](../../note/api/API-012.md) callback wrapper,
[API-023](../../note/api/API-023.md) Python state objects,
[API-025](../../note/api/API-025.md) Python defaults,
[PROOF-002](../../note/proof/PROOF-002.md) what is proved.
