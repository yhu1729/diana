# Bisection

Status codes, linking, and the Python conventions shared by every kernel are in the
[API overview](overview.md); the theorems cited below are listed in `spec/bisection.md`.

## C (`diana/bisection.h`)

Reverse-communication form: the kernel uses no function pointer, and the caller evaluates `f` at
`s.x` between calls.

```c
diana_bisection_state s;
diana_status st = diana_bisection_init(&s, a, b, f(a), f(b), tol, max_iter);
while (st == DIANA_CONTINUE)
    st = diana_bisection_step(&s, f(s.x));
if (st == DIANA_OK)
    diana_bisection_result(&s, &root, &width);
```

| Field | Meaning |
|---|---|
| `a`, `b` | current bracket, `a <= b` |
| `fa`, `fb` | `f(a)`, `f(b)` |
| `x` | point at which the caller must evaluate `f` next (the midpoint) |
| `tol` | stop when `b - a <= tol`, `tol >= 0` |
| `iter` | steps performed so far |
| `max_iter` | step limit |

Invariant kept by every call (Frama-C WP, BISECTION-C2 in `spec/bisection.md`): `a <= b`,
`|a|, |b| <= DBL_MAX/2`, `fa` and `fb` finite, `tol >= 0`, and either `fa` and `fb` of strictly
opposite sign or `a == b` with `fa == fb == 0`; whenever the last status was `DIANA_CONTINUE`,
`a < x < b`. The kernel sets `x` to the binary64 midpoint `0.5 * (a + b)`. VST proves that every
function computes its Flocq model: the midpoint helper (BISECTION-C1), `init` and `step` with
every status and every field of the state (BISECTION-C6/C7; the bracket `step` writes is the
layer-B `fstep`, BISECTION-C8), and `diana_bisection_result` (BISECTION-C5); the state `init`
accepts and every state reached through `DIANA_CONTINUE` satisfy the layer-B invariant
(BISECTION-C9/C10). A rejected call leaves the state unchanged (BISECTION-C2, and BISECTION-C6/C7
for a non-NULL `s`): `init` returning `DIANA_ERR_ARG` or `DIANA_ERR_BRACKET`, and `step` returning
`DIANA_ERR_ARG`, write nothing to `*s`.

- `diana_bisection_init(s, a, b, fa, fb, tol, max_iter)` initialises the state from the bracket
  `[a, b]` and `fa = f(a)`, `fb = f(b)`. Returns `DIANA_CONTINUE` with `s->x` set to the first
  midpoint; `DIANA_OK` if the bracket already satisfies the tolerance, has no representable
  interior point, or `fa == 0` or `fb == 0`;
  `DIANA_ERR_ARG` on NULL, NaN or infinite input, `a > b`, `|a|` or `|b| > DBL_MAX/2`, `tol < 0`, or
  `max_iter == 0`; `DIANA_ERR_BRACKET` if `fa` and `fb` have the same strict sign.
- `diana_bisection_step(s, fx)` consumes `fx = f(s->x)` and halves the bracket: if `fx` and `fa`
  have the same strict sign the root is in `[x, b]`, otherwise in `[a, x]`. Returns `DIANA_CONTINUE`
  with a new `s->x`, `DIANA_OK` on convergence, or `DIANA_ERR_MAXITER`. Convergence also occurs when
  `fx == 0` or the midpoint equals an endpoint (adjacent doubles: no representable interior point
  remains). Returns `DIANA_ERR_ARG` for a NULL state or a non-finite `fx`.
- `diana_bisection_result(s, root, width)` reports the current estimate `root = 0.5 * (a + b)` and
  `width = b - a`. Either output may be NULL; a non-NULL output must not alias the state or the
  other output.

## Callback wrapper

`diana/wrapper.h`; not verified, see [callback wrapper](overview.md#callback-wrapper).

- `diana_bisection(f, ctx, a, b, tol, max_iter, root, iter)` finds a root of `f` in `[a, b]` by
  bisection, with `f` of type `diana_bisection_fn`. It evaluates `f(a)`, then `f(b)`, then `f` once
  per step. On `DIANA_OK` or `DIANA_ERR_MAXITER`, `*root` holds the current estimate
  `0.5 * (a + b)`; on any other status it is not written. `*iter` (optional) receives the number of
  steps on every return (0 when the arguments or the bracket are rejected). The callback result
  must be finite.

## Python

`diana.Bisection` is the reverse-communication state object and `diana.bisection` the function
taking a Python callable.

`diana.bisection` converts `a` and `b` to `float` before evaluating `f`, so `f(a)` and `f(b)` are
the values at the binary64 endpoints the kernel brackets. The default `max_iter` of
`diana.bisection` and `diana.Bisection` is 2100, which covers the worst case of `tol = 0` (2098
steps, for a root at the smallest subnormal in `[-DBL_MAX/2, DBL_MAX/2]`; measured and pinned by a
test — BISECTION-B4 proves termination but not this constant), so with default arguments
`MaxIterError` is not expected. `max_iter` must be an integer that fits a C `unsigned int`
(`OverflowError` otherwise, `ValueError` for 0).

A `diana.Bisection` allocated directly with `__new__` has status `ERR_ARG` until `__init__`
succeeds; `step()` and `result()` raise `RuntimeError` before that. A failed `__init__` leaves the
existing state and status unchanged, so a previously initialized object remains usable.

`diana.bisection` raises `diana.BracketError` when `f(a)` and `f(b)` do not bracket a root, and
`diana.MaxIterError` when `max_iter` is reached first; the latter carries the attributes
`estimate`, `width` and `iter` (also its `args`, so it survives pickling across a process
boundary).
