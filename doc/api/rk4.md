# Classical Runge–Kutta step (RK4)

Status codes, linking, and the Python conventions shared by every kernel are in the
[API overview](overview.md); the theorems cited below are listed in `spec/rk4.md` and, for the
unchecked variants, `spec/rk4_unchecked.md`.

## C (`diana/rk4.h`)

One step of the classical fourth-order Runge–Kutta method on a vector of dimension `d`, in
reverse communication: the caller evaluates the four slopes and the kernel builds the stage
points and combines the slopes. For `y′ = F(t, y)` and a step `h` from `(t, y)`:

| slope | evaluated at | stage point |
|---|---|---|
| `k1 = F(t, y)` | `t` | `y` |
| `k2 = F(t + h/2, Y2)` | `t + h/2` | `Y2 = y + (h/2)·k1`, `diana_rk4_stage(y, k1, d, h, 2, Y2)` |
| `k3 = F(t + h/2, Y3)` | `t + h/2` | `Y3 = y + (h/2)·k2`, `diana_rk4_stage(y, k2, d, h, 3, Y3)` |
| `k4 = F(t + h, Y4)` | `t + h` | `Y4 = y + h·k3`, `diana_rk4_stage(y, k3, d, h, 4, Y4)` |

and `diana_rk4_step(y, k1, k2, k3, k4, d, h, y_out)` writes `y + h·(k1 + 2·k2 + 2·k3 + k4)/6`.

- `diana_rk4_stage(y, k, d, h, stage, y_out)` writes the point of stage `stage` (2, 3 or 4),
  `y_out[i] = y[i] + c * k[i]` with `c = 0.5 * h` for stages 2 and 3 and `c = h` for stage 4, the
  coefficient computed once and the product rounded before the sum (no fused multiply-add).
  `0.5 * h` is exact unless `|h| < 2^-1021`. Returns `DIANA_OK` when every component is finite.
  Returns `DIANA_ERR_ARG`, without writing `y_out`, for a NULL `y`, `k` or `y_out`, for `d == 0`,
  for a `stage` other than 2, 3 or 4, and when any component is not finite: a NaN or infinite
  `y[i]`, `k[i]` or `h`, or an overflow in the product or the sum.
- `diana_rk4_step(y, k1, k2, k3, k4, d, h, y_out)` writes
  `y_out[i] = y[i] + h * s / 6` with `s = (k1[i] + k4[i]) + 2 * (k2[i] + k3[i])`, each operation
  rounded in that order: the product `h * s` is divided by 6, then added. Returns `DIANA_OK` when
  every component is finite. Returns `DIANA_ERR_ARG`, without writing `y_out`, for a NULL `y`,
  slope or `y_out`, for `d == 0`, and when any component is not finite: a NaN or infinite input,
  or an overflow in any operation, including `h * s` when `h * s / 6` would be finite.

`y_out[0 .. d-1]` must not overlap `y[0 .. d-1]` or a slope; the inputs are only read and may
overlap each other. Each function checks every component before it writes any, so a failure in
the last one leaves `y_out` as it was. Frama-C WP proves memory safety, termination, the status
cases and that `y_out` is untouched on `DIANA_ERR_ARG` (RK4-C1, C2).

- `diana_rk4_stage_unchecked(y, k, d, h, stage, y_out)` and
  `diana_rk4_step_unchecked(y, k1, k2, k3, k4, d, h, y_out)` are the same stage and step without
  the finiteness check, chosen explicitly by the caller. Each returns `DIANA_ERR_ARG`, without
  writing `y_out`, for a NULL pointer, for `d == 0` and, for the stage, for a `stage` other than
  2, 3 or 4, and otherwise writes every component in one pass, in the same operation order, and
  returns `DIANA_OK`. A non-finite component (NaN or ±∞, from a non-finite input or an overflow)
  is written as computed, and the components before and after it are written too: `DIANA_OK`
  says nothing about finiteness. Whenever the checked function returns `DIANA_OK`, the two write
  the same bits.

The checked functions are the default, and `diana_rk4` uses them. Use the unchecked ones only
where the caller checks the state itself, or does not need to stop at the first non-finite
component, and the kernel is a measured cost: with one pass and no branch the compiler
vectorizes the loop. On an Apple Silicon Mac (Release build, Apple clang 21 and gcc 15, `d` from
64 to 16384) the checked stage takes about 0.44 to 0.52 ns per component and the unchecked one
0.10 to 0.16, a factor of 2.8 to 4.8; the checked step takes 0.86 to 1.23 ns and the unchecked
one 0.25 to 0.41, a factor of 2.2 to 4.5. A whole RK4 step calls the stage three times and the
step once, so the kernels save about 1.3 to 2 ns per component, small next to four evaluations
of a right-hand side that costs a few nanoseconds per component.

RK4 is of order 4 (Lean and Rocq). For `y′ = F(t, y)` with `F` L-Lipschitz in `y` in the max norm
and the time-augmented field `(1, F)` three times differentiable, `k` exact steps of size `h`
from `y(t₀)` are within `((M₅/120 + N₄/24)·h⁴/L)·(e^{L·k·h} − 1)` of `y(t₀ + k·h)` (RK4-A7), and
one step is within `(M₅/120 + N₄/24)·h⁵` (RK4-A3). `M₅` bounds the fifth derivative of the solution
and `N₄` the fourth derivative of the increment in the step size, each through the Lipschitz
constant of the derivative below it (`spec/rk4.md`, H2 and H3).

Whenever a computed component is finite, Flocq bounds its rounding error, with `u = 2⁻⁵³` and
`η = 2⁻¹⁰⁷⁵`. A stage component is within `u·|y[i] + c·k[i]| + (1 + u)·(u·|c·k[i]| + η)` of the
exact `y[i] + c·k[i]`, `c = h/2` or `h`, when `|h| ≥ 2⁻¹⁰²¹`; below that, rounding `h/2` (at most
`η`) adds `(1 + u)²·η·|k[i]|` (RK4-B2, RK4-B3). A step component is within
`u·|T| + (1 + u)·(γ₄·|h|·A/6 + (1 + u)·η/6 + η)` of the exact
`T = y[i] + h·(k1[i] + 2·k2[i] + 2·k3[i] + k4[i])/6`, with
`A = |k1[i] + k4[i]| + 2·|k2[i] + k3[i]|` and `γ₄ = 4u/(1 − 4u)` (RK4-B5).
VST proves that each function writes exactly these binary64 values and returns `DIANA_OK` exactly
when all of them are finite, leaving `y_out` unchanged otherwise (RK4-C3 to C6, for non-NULL,
disjoint arrays with `d >= 1` and, for the stage, `2 <= stage <= 4`). For the unchecked
functions, WP proves the same memory safety, termination and argument cases
(RK4-UNCHECKED-C1, C2), and VST that they always write these binary64 values and return
`DIANA_OK` (RK4-UNCHECKED-C3, C4), so the bounds above hold for each component they write that
is finite. Flocq proves that a written component is finite exactly when its inputs are finite
and no operation overflows (RK4-UNCHECKED-B1, B2): checking `y_out` for finiteness after the
call rejects exactly the inputs the checked function rejects.

The rotation `y′ = (y₂, −y₁)` from `(0, 1)` has the solution `(sin t, cos t)`,
`(0.841470985, 0.540302306)` at `t = 1`. `F` does not depend on `t`, so the stage times are not
needed; ten steps of `h = 1/10` are within `7e-7`:

```c
#include <stdio.h>

#include <diana/rk4.h>

#define NSTEP 10

static void rotate(const double *y, double *dy) {
  dy[0] = y[1];
  dy[1] = -y[0];
}

static diana_status step(double *y, double h) {
  double k[4][2], ys[2], y_next[2];
  diana_status st;
  rotate(y, k[0]);
  for (int stage = 2; stage <= 4; ++stage) {
    st = diana_rk4_stage(y, k[stage - 2], 2, h, stage, ys);
    if (st != DIANA_OK) {
      return st;
    }
    rotate(ys, k[stage - 1]);
  }
  st = diana_rk4_step(y, k[0], k[1], k[2], k[3], 2, h, y_next);
  if (st == DIANA_OK) {
    y[0] = y_next[0];
    y[1] = y_next[1];
  }
  return st;
}

int main(void) {
  double y[2] = {0.0, 1.0};
  for (unsigned n = 0; n < NSTEP; ++n) {
    diana_status st = step(y, 1.0 / NSTEP);
    if (st != DIANA_OK) {
      fprintf(stderr, "step %u: %s\n", n, diana_status_str(st));
      return 1;
    }
  }
  printf("y(1) = (%.9f, %.9f)\n", y[0], y[1]);
  return 0;
}
```

```text
y(1) = (0.841470478, 0.540302967)
```

## Callback wrapper

`diana/wrapper.h`; not verified, see [callback wrapper](overview.md#callback-wrapper).

- `diana_rk4(fn, ctx, t0, h, nstep, y, d, work, done)` takes `nstep` RK4 steps of size `h` from
  `y(t0) = y[0 .. d-1]`, in place, with `fn` of type `diana_ode_fn`: `fn(t, y, dy, d, ctx)` must
  write `F(t, y)` to `dy[0 .. d-1]`. Step `k` evaluates `fn` at `t0 + k * h`,
  `t0 + (k + 0.5) * h` (twice) and `t0 + (k + 1) * h`, each computed from `k` rather than
  accumulated, building the stage points with `diana_rk4_stage` and the new state with
  `diana_rk4_step`. `work` holds `5 * d` doubles (the four slopes and the stage point) and must
  not overlap `y`. It returns `DIANA_ERR_ARG` for a NULL `fn`, `y` or `work`, for `d == 0`, and
  when a stage or step fails (a non-finite slope or result); `y` then holds the state after the
  last successful step. `*done` (optional) receives the number of completed steps on every
  return (0 when the arguments are rejected). `nstep == 0` leaves `y` unchanged and returns
  `DIANA_OK`.

Exponential decay `y′ = −r·y` with the rate `r` in `ctx`, three components, 10 steps of `0.05`.
Each component is multiplied by `R(−0.1)¹⁰ = 0.367879774`, with
`R(z) = 1 + z + z²/2 + z³/6 + z⁴/24`, against the exact `e⁻¹ = 0.367879441`:

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
  double y[D] = {1.0, 2.0, 4.0}, work[5 * D];
  unsigned done;
  diana_status st = diana_rk4(decay, &p, 0.0, 0.05, 10u, y, D, work, &done);
  if (st != DIANA_OK) {
    fprintf(stderr, "rk4: %s after %u steps\n", diana_status_str(st), done);
    return 1;
  }
  printf("y(0.5) = (%.9f, %.9f, %.9f)\n", y[0], y[1], y[2]);
  return 0;
}
```

```text
y(0.5) = (0.367879774, 0.735759549, 1.471519098)
```

## Python

`diana.rk4_stage(y, k, h, stage)` and `diana.rk4_step(y, k1, k2, k3, k4, h)` return one call of
`diana_rk4_stage` and `diana_rk4_step` as a new `array.array("d")`, with the same operation
order. Every vector is an [array argument](overview.md#array-argument), each with its own name in
the messages and at least one sample; a `stage` other than 2, 3 or 4, a length mismatch, then a
non-finite component, raise `ValueError` (`stage` must be an integer: `TypeError` otherwise). The
output is a fresh array, so it never overlaps the inputs, and the inputs are never modified.
`diana.rk4(f, t0, y0, h, nstep)` copies `y0` element by element into an `array.array("d")` (a
`bytes` object is a sequence of integers, not raw float64 data) and takes `nstep` steps, calling
`f(t, y)` at `t0 + n*h`, `t0 + (n + 0.5)*h` (twice) and `t0 + (n + 1)*h` for step `n` and copying
each result element by element, so `f` may return the same buffer every time; the loop runs in
Python, like `diana.euler`, and `f` must not modify `y`. It raises `ValueError` for an empty `y0`
or a negative `nstep`, `TypeError` for a non-integer `nstep` or a `t0` or `h` that is not a real
number (a string is not converted), and lets the errors of `rk4_stage` and `rk4_step` through.

```python
>>> import diana
>>> diana.rk4_stage([1.0, -2.0], [3.0, 4.0], 0.5, 2)  # y + (h/2) k
array('d', [1.75, -1.0])
>>> diana.rk4_step([1.0], [1.0], [2.0], [2.0], [1.0], 0.75)  # 1 + 0.75 * 10 / 6
array('d', [2.25])
>>> y = diana.rk4(lambda t, y: [y[1], -y[0]], 0.0, [0.0, 1.0], 0.1, 10)
>>> [round(v, 9) for v in y]  # exact: sin 1, cos 1 = 0.841470985, 0.540302306
[0.841470478, 0.540302967]
>>> diana.rk4_stage([1.0], [1.0], 1.0, 1)
Traceback (most recent call last):
  ...
ValueError: stage must be 2, 3 or 4
```

For `y′ = g(t)` a step is Simpson's rule on `[t, t + h]`, so `y′ = t` from `t0 = 1` is integrated
exactly: two steps of `1/4` give `(1.5² − 1)/2`:

```python
>>> diana.rk4(lambda t, y: [t], 1.0, [0.0], 0.25, 2)
array('d', [0.625])
```

`f` may return a NumPy array; `np.asarray` views the state without a copy:

```python
>>> import numpy as np
>>> y = diana.rk4(lambda t, y: -2.0 * np.asarray(y), 0.0, [1.0, 2.0, 4.0], 0.05, 10)
>>> np.asarray(y)
array([0.36787977, 0.73575955, 1.4715191 ])
```
