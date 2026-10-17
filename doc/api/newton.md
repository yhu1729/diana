# Newton's method

Status codes, linking, and the Python conventions shared by every kernel are in the
[API overview](overview.md); the theorems cited below are listed in `spec/newton.md`.

## C (`diana/newton.h`)

Reverse-communication form, like [bisection](bisection.md): the kernel uses no function pointer,
and the caller evaluates `f` and `f′` at `s.x` between calls. Finding `√2` as the root of `x² − 2`
from `x₀ = 2`:

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
| `x` | current iterate, and the point at which the caller must evaluate `f` and `f′` next |
| `dx` | last correction `f(x)/f′(x)` applied to `x`, `0` before the first step |
| `tol` | stop when `|dx| <= tol`, `tol >= 0` |
| `iter` | steps performed so far |
| `max_iter` | step limit |

Invariant kept by every call (Frama-C WP, NEWTON-C1 to C3 in `spec/newton.md`): `x`, `dx` and `tol`
finite and `tol >= 0`. VST proves that every function computes its model: `init` and `step` with
every status and every field of the state (NEWTON-C5/C6), and `diana_newton_result` (NEWTON-C4);
the correction and the iterate `step` writes are the Flocq `fstep` (NEWTON-C7), so the layer-B
bounds apply to them. A rejected call leaves the state unchanged (NEWTON-C1/C2, and C5/C6 for a
non-NULL `s`): `init` returning `DIANA_ERR_ARG`, and `step` returning `DIANA_ERR_ARG`, write
nothing to `*s`; so does `step` returning `DIANA_ERR_SINGULAR`.

- `diana_newton_init(s, x0, tol, max_iter)` initialises the state at `x0` and returns
  `DIANA_CONTINUE`; `DIANA_ERR_ARG` on NULL, NaN or infinite `x0` or `tol`, `tol < 0`, or
  `max_iter == 0`. Unlike bisection, `init` sees no function value, so it never reports
  convergence itself.
- `diana_newton_step(s, fx, dfx)` consumes `fx = f(s->x)` and `dfx = f′(s->x)`. When `fx == 0`
  it returns `DIANA_OK` with `dx = 0` and `x` unchanged, whatever `dfx`. When `dfx == 0` (either
  sign of zero) the step is undefined: `DIANA_ERR_SINGULAR`, nothing written. Otherwise it
  computes the correction `dx = fx / dfx` and the iterate `x − dx`, each rounded to binary64; if
  either is not finite (a subnormal `dfx` against a large `fx`, an overflow), it returns
  `DIANA_ERR_ARG` and writes nothing. Otherwise it stores `dx` and the new `x`, increments
  `iter`, and returns
  `DIANA_OK` when `|dx| <= tol` or when the new iterate equals the old one (the correction is
  at most half an ulp of `x` under the required
  [floating-point environment](overview.md#floating-point-environment), NEWTON-B3),
  `DIANA_ERR_MAXITER` when `iter` has reached `max_iter`, and `DIANA_CONTINUE` otherwise.
  A NaN or infinite `fx` or `dfx` is
  `DIANA_ERR_ARG`, state unchanged.
- `diana_newton_result(s, root, dx)` reports the current iterate `*root = s->x` and the last
  correction `*dx = s->dx`. Either output may be NULL; a non-NULL output must not alias the state
  or the other output.

`tol = 0` asks for a fixed point of the binary64 Newton map. Near a simple root the computed
`f(x)` is usually not zero and the iterate alternates between the two doubles around the root, a
two-cycle that only `max_iter` ends: from `x₀ = 2`, `x² − 2` reaches `1.4142135623730951`, the
correctly rounded `√2`, at step 5, and then alternates with its lower neighbour. Pass a tolerance.
A step that returns `DIANA_ERR_MAXITER` has still updated the state, so `diana_newton_result`
reports the estimate reached so far:

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

`diana/newton.h`; not verified, see [callback wrapper](overview.md#callback-wrapper).

- `diana_newton(f, ctx, x0, tol, max_iter, root, iter)` runs Newton's method from `x0`, with `f`
  of type `diana_newton_fn`: `f(x, &dfx, ctx)` returns `f(x)` and must write `f′(x)` to `*dfx`.
  It evaluates `f` once per step. On `DIANA_OK` or `DIANA_ERR_MAXITER`, `*root` holds the current
  iterate; on any other status it is not written. `*iter` (optional) receives the number of
  completed steps on every return (0 when the arguments are rejected). `*dfx` is set to `0` before
  each call, so a callback that never writes it fails with `DIANA_ERR_SINGULAR` on the first step
  instead of reading an indeterminate value.

The cube root of 10 as the root of `x³ − c` with `c` in `ctx`:

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

`diana.Newton` is the reverse-communication state object and `diana.newton` the function taking
a Python callable `f(x)` that returns the pair `(f(x), f′(x))`.

`tol` is a required argument of both: Newton's method has no parameter-free stopping rule, and
with `tol = 0` the iteration commonly ends in the two-cycle described above. The default
`max_iter` is 100, a safety limit and not a convergence guarantee; `max_iter` must be an integer
that fits a C `unsigned int` (`OverflowError` otherwise, `ValueError` for 0). `x0`, `tol` and
the values `f` returns must be real numbers (`__float__` or `__index__`; a string is not
converted), `TypeError` otherwise.

```python
>>> import math
>>> import diana
>>> diana.newton(lambda x: (x * x - 2, 2 * x), 2.0, 1e-12)
1.414213562373095
>>> diana.newton(lambda x: (math.cos(x) - x, -math.sin(x) - 1), 1.0, 1e-12)
0.7390851332151607
```

The state object runs the same loop with the caller in control, as in C; `step` returns the new
status, and the fields of the C state are read-only attributes:

```python
>>> s = diana.Newton(2.0, 1e-6)
>>> while s.status == diana.CONTINUE:
...     _ = s.step(s.x * s.x - 2, 2 * s.x)
>>> s.status == diana.OK, s.iter, s.x
(True, 5, 1.4142135623730951)
>>> s.result()
(1.4142135623730951, 1.5947429102833119e-12)
```

A `diana.Newton` allocated directly with `__new__` has status `ERR_ARG` until `__init__` succeeds;
`step()` and `result()` raise `RuntimeError` before that. A failed `__init__` leaves the existing
state and status unchanged, so a previously initialized object remains usable.

A zero `f′(x)` raises `diana.SingularError` (a `ValueError`; `DIANA_ERR_SINGULAR` in C), and a
non-finite `f(x)` or `f′(x)` or a correction or iterate that overflows raises `ValueError`
(`DIANA_ERR_ARG`); either leaves the state at the last iterate. `diana.newton` raises
`diana.MaxIterError` when `max_iter` is reached first, with the attributes `estimate` (the current
iterate), `width` (the last `|dx|`) and `iter`:

```python
>>> diana.newton(lambda x: (x * x + 1, 2 * x), 0.0, 1e-12)
Traceback (most recent call last):
  ...
diana._diana.SingularError: f'(x) is zero
>>> try:
...     diana.newton(lambda x: (x * x - 2, 2 * x), 2.0, 1e-12, max_iter=2)
... except diana.MaxIterError as e:
...     print(e.estimate, e.width, e.iter)
1.4166666666666667 0.08333333333333333 2
>>> try:
...     diana.newton(lambda x: (x * x - 2, 2 * x), 2.0, 0.0)
... except diana.MaxIterError as e:
...     print(e.iter, abs(e.estimate - math.sqrt(2)) <= math.ulp(math.sqrt(2)))
100 True
```
