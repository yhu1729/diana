# Explicit Euler step

The explicit Euler method solves the initial value problem `y′ = F(t, y)`, `y(t₀) = y₀`, for a
vector `y` of dimension `d` by the step `y ← y + h·F(t, y)`. It is first order: halving `h`
roughly halves the error. The kernel takes one step from a slope `f = F(t, y)` you have computed;
a loop over the steps is yours to write, or `diana_euler` runs it over a callback. Shared
conventions are in the [API overview](overview.md).

## C

`#include <diana/euler.h>`.

- `diana_euler_step(y, f, d, h, y_out)` writes `y_out[i] = y[i] + h·f[i]` for `i < d`, the
  product rounded before the sum (no fused multiply-add). It returns `DIANA_OK`, or
  `DIANA_ERR_ARG` without writing `y_out` for a `NULL` pointer, `d == 0`, or a component that is
  not finite: a NaN or infinite input or `h`, or an overflow. It checks every component before
  writing any, so a failure leaves `y_out` as it was.

`y_out` must not overlap `y` or `f`, so a loop alternates two buffers. The rotation
`y′ = (y₂, −y₁)` from `(0, 1)` has the solution `(sin t, cos t)`, `(0.841471, 0.540302)` at
`t = 1`; with `h = 1/1000` the error is `4.2e-4`, within the proved bound `(h/2)·(e − 1) = 8.6e-4`:

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

### Unchecked step

`diana_euler_step_unchecked(y, f, d, h, y_out)` is the same step without the finiteness check. It
rejects only a `NULL` pointer or `d == 0`; otherwise it writes every component in one pass and
returns `DIANA_OK`, even when a component is NaN or infinite. Where `diana_euler_step` succeeds,
both write the same bits, and checking `y_out` for finiteness afterwards rejects exactly what
`diana_euler_step` rejects.

Use it only when the step itself is a measured cost and you check the state yourself: without
the check pass the compiler vectorizes the loop, which made the kernel 2.8 to 4.8 times faster in
the project's [benchmark](../development/benchmark.md), a saving of 0.3 to 0.4 ns per component.
That saving is small next to a right-hand side that costs a few nanoseconds per component.

## Callback wrapper

`diana_euler(fn, ctx, t0, h, nstep, y, d, work, &done)` takes `nstep` steps from `y(t0) = y`, in
place, with a callback `void fn(double t, const double *y, double *dy, size_t d, void *ctx)`
(`diana_ode_fn` in `diana/ode.h`) that writes `F(t, y)` to every component of `dy`. Step `k`
evaluates `fn` at `t0 + k·h`. `work` holds `2·d` doubles and must not overlap `y`; `done` (may be
`NULL`) receives the number of completed steps. When a step fails, it returns `DIANA_ERR_ARG` with
`y` at the last successful step. Exponential decay `y′ = −r·y` with the rate in `ctx`: each
component is multiplied by `(1 − 0.02)⁵⁰ = 0.364170`, against the exact `e⁻¹ = 0.367879`:

```c
#include <stdio.h>

#include <diana/euler.h>

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

- `diana.euler_step(y, f, h)` returns one checked step as a new `array.array("d")`; `y` and `f`
  are [array arguments](overview.md#array-arguments) of the same length. A non-finite component
  raises `ValueError`.
- `diana.euler(f, t0, y0, h, nstep)` takes `nstep` steps from a copy of `y0`, calling `f(t, y)`
  for the slope at `t0 + k·h`, and returns the final state. `f` must not modify `y`, and its
  result is passed to `euler_step` as an array argument.

The unchecked step has no Python binding.

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

`f` may return a NumPy array, and `np.asarray` views the state without a copy:

```python
>>> import numpy as np
>>> y = diana.euler(lambda t, y: -2.0 * np.asarray(y), 0.0, [1.0, 2.0, 4.0], 0.01, 50)
>>> np.asarray(y)
array([0.36416968, 0.72833936, 1.45667872])
```

## Guarantees

Proved in Lean and Rocq: for `F` Lipschitz in `y` with constant `L` and `‖y″‖ <= M₂` in the max
norm, `k` exact steps of size `h` are within `(M₂·h/(2L))·(e^{L·k·h} − 1)` of the solution.
Proved in Rocq with Flocq: each computed component is within `u·|y[i] + h·f[i]| + u·|h·f[i]|` of
the exact `y[i] + h·f[i]`, to first order in `u = 2⁻⁵³`. Proved of the C code: VST shows that
both steps compute exactly that binary64 value, and Frama-C that they are memory-safe and free of
undefined behaviour. Not proved: a bound on the rounding error accumulated over many steps, and
anything about the wrappers. Theorems: `spec/euler.md` and `spec/euler_unchecked.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-015](../../note/api/API-015.md) evaluation order and exits,
[API-017](../../note/api/API-017.md) ODE wrappers,
[API-018](../../note/api/API-018.md) unchecked kernels,
[API-019](../../note/api/API-019.md) when to use them,
[API-026](../../note/api/API-026.md) Python drivers,
[PROOF-005](../../note/proof/PROOF-005.md) what is proved, with the exact bounds.
