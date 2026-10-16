# Explicit Euler step

Status codes, linking, and the Python conventions shared by every kernel are in the
[API overview](overview.md); the theorems cited below are listed in `spec/euler.md`.

## C (`diana/euler.h`)

One step of the explicit Euler method on a vector of dimension `d`; the caller evaluates
`f = F(t, y)` and loops over the steps, or lets `diana_euler` ([below](#callback-wrapper)) do it;
Python calls the kernel as `diana.euler_step` and loops as `diana.euler` (see [Python](#python)).

- `diana_euler_step(y, f, d, h, y_out)` writes `y_out[i] = y[i] + h * f[i]` for
  `i = 0, ..., d-1`, the product rounded before the sum (no fused multiply-add). `y_out[0 .. d-1]`
  must not overlap `y[0 .. d-1]` or `f[0 .. d-1]`, which are only read. Returns `DIANA_OK` when
  every component is finite. Returns `DIANA_ERR_ARG`, without writing `y_out`, for a NULL `y`,
  `f` or `y_out`, for `d == 0`, and when any component is not finite: a NaN or infinite `y[i]`,
  `f[i]` or `h`, or an overflow in either operation. The kernel checks every component before it
  writes any, so a failure in the last one leaves `y_out` as it was.

Frama-C WP proves memory safety, termination, the status cases and that `y_out` is untouched on
`DIANA_ERR_ARG` (EULER-C1). For `y′ = F(t, y)` with `F` L-Lipschitz in `y` and `‖y″‖ ≤ M₂` in the max
norm, `k` exact Euler steps of size `h` from `y(t₀)` are within `(M₂·h/(2L))·(e^{L·k·h} − 1)` of
`y(t₀ + k·h)` (EULER-A2, proved in Lean and Rocq; one step is within `M₂·h²/2`, EULER-A1).
Each computed component is within `u·|y[i] + h·f[i]| + (1 + u)·(u·|h·f[i]| + η)` of the exact
`y[i] + h·f[i]` whenever it is finite, with `u = 2⁻⁵³` and `η = 2⁻¹⁰⁷⁵` (EULER-B2, Flocq).
VST proves that the C writes exactly these binary64 values and returns `DIANA_OK` exactly when all
of them are finite, leaving `y_out` unchanged otherwise (EULER-C2, for non-NULL, disjoint `y`, `f`
and `y_out` with `d >= 1`).

`y_out` must not overlap `y`, so a loop alternates two buffers. The rotation `y′ = (y₂, −y₁)` from
`(0, 1)` has the solution `(sin t, cos t)`, `(0.841471, 0.540302)` at `t = 1`; with `h = 1/1000`
the error is `4.2e-4`, within the EULER-A2 bound `(h/2)·(e − 1) = 8.6e-4` (`L = M₂ = 1`):

```c
#include <stdio.h>

#include <diana/euler.h>

#define NSTEP 1000

static void rotate(const double *y, double *dy) {
  dy[0] = y[1];
  dy[1] = -y[0];
}

int main(void) {
  double state[2][2] = {{0.0, 1.0}};
  double *y = state[0], *y_next = state[1], f[2];
  const double h = 1.0 / NSTEP;
  for (unsigned k = 0; k < NSTEP; ++k) {
    rotate(y, f);
    diana_status st = diana_euler_step(y, f, 2, h, y_next);
    if (st != DIANA_OK) {
      fprintf(stderr, "step %u: %s\n", k, diana_status_str(st));
      return 1;
    }
    double *tmp = y;
    y = y_next;
    y_next = tmp;
  }
  printf("y(1) = (%.6f, %.6f)\n", y[0], y[1]);
  return 0;
}
```

```text
y(1) = (0.841892, 0.540573)
```

## Callback wrapper

`diana/wrapper.h`; not verified, see [callback wrapper](overview.md#callback-wrapper).

- `diana_euler(fn, ctx, t0, h, nstep, y, d, work, done)` takes `nstep` explicit Euler steps of size
  `h` from `y(t0) = y[0 .. d-1]`, in place, with `fn` of type `diana_ode_fn`: `fn(t, y, dy, d, ctx)`
  must write `F(t, y)` to `dy[0 .. d-1]`. Step `k` evaluates `fn` at `t0 + k * h`, computed from `k`
  rather than accumulated, then calls `diana_euler_step`. `work` holds `2 * d` doubles and must not
  overlap `y`. It returns `DIANA_ERR_ARG` for a NULL `fn`, `y` or `work`, for `d == 0`, and when a
  step fails (a non-finite derivative or result); `y` then holds the state after the last
  successful step. `*done` (optional) receives the number of completed steps on every return
  (0 when the arguments are rejected). `nstep == 0` leaves `y` unchanged and returns `DIANA_OK`.

The same loop with a callback: exponential decay `y′ = −r·y` with the rate `r` in `ctx`, three
components, 50 steps of `0.01`. Each component is multiplied by `(1 − 0.02)⁵⁰ = 0.364170` against
the exact `e⁻¹ = 0.367879`:

```c
#include <stdio.h>

#include <diana/wrapper.h>

#define D 3

struct decay {
  double rate;
};

static void decay(double t, const double *y, double *dy, size_t d, void *ctx) {
  const struct decay *p = ctx;
  (void)t;
  for (size_t i = 0; i < d; ++i) {
    dy[i] = -p->rate * y[i];
  }
}

int main(void) {
  struct decay p = {2.0};
  double y[D] = {1.0, 2.0, 4.0}, work[2 * D];
  unsigned done;
  diana_status st = diana_euler(decay, &p, 0.0, 0.01, 50u, y, D, work, &done);
  if (st != DIANA_OK) {
    fprintf(stderr, "euler: %s after %u steps\n", diana_status_str(st), done);
    return 1;
  }
  printf("y(0.5) = (%.6f, %.6f, %.6f)\n", y[0], y[1], y[2]);
  return 0;
}
```

```text
y(0.5) = (0.364170, 0.728339, 1.456679)
```

## Python

`diana.euler_step(y, f, h)` returns one step of `diana_euler_step` as a new `array.array("d")`,
with the same operation order. `y` and `f` are [array arguments](overview.md#array-argument), each
with its own name in the messages and at least one sample; a length mismatch, then a non-finite
component, raise `ValueError`. The output is a fresh array, so it never overlaps the inputs, and
the inputs are never modified. `diana.euler(f, t0, y0, h, nstep)` copies `y0` element by element
into an `array.array("d")` (a `bytes` object is a sequence of integers, not raw float64 data) and
takes `nstep` steps, calling `f(t0 + k*h, y)` for the derivative of step
`k`; the loop runs in Python, like `diana.bisection`, and `f` must not modify `y`. It raises
`ValueError` for an empty `y0` or a negative `nstep`, `TypeError` for a non-integer `nstep` or a
`t0` or `h` that is not a real number (a string is not converted), and lets the errors of
`euler_step` through.

```python
>>> import diana
>>> diana.euler_step([1.0, 0.0], [0.0, -1.0], 0.5)
array('d', [1.0, -0.5])
>>> y = diana.euler(lambda t, y: [y[1], -y[0]], 0.0, [0.0, 1.0], 1 / 1000, 1000)
>>> [round(v, 6) for v in y]  # exact: sin 1, cos 1 = 0.841471, 0.540302
[0.841892, 0.540573]
>>> diana.euler_step([1.0], [1.0, 2.0], 0.1)
Traceback (most recent call last):
  ...
ValueError: y and f must have the same length
```

`f` receives the time of each step: for `y′ = t` from `t0 = 1` with `h = 1/4`, the four steps
sample `t = 1, 1.25, 1.5, 1.75`, so `y = (1 + 1.25 + 1.5 + 1.75)/4`:

```python
>>> diana.euler(lambda t, y: [t], 1.0, [0.0], 0.25, 4)
array('d', [1.375])
```

`f` may return a NumPy array; `np.asarray` views the state without a copy:

```python
>>> import numpy as np
>>> y = diana.euler(lambda t, y: -2.0 * np.asarray(y), 0.0, [1.0, 2.0, 4.0], 0.01, 50)
>>> np.asarray(y)
array([0.36416968, 0.72833936, 1.45667872])
```
