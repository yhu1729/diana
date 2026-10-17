# Classical Runge–Kutta step (RK4)

The classical fourth-order Runge–Kutta method solves `y′ = F(t, y)` for a vector `y` of dimension
`d`. Each step evaluates four slopes and combines them; halving `h` divides the error by about
16. As with the [Euler step](euler.md), the kernels take slopes you have computed: one function
builds the points where the slopes are evaluated, another combines them. `diana_rk4` runs the
whole loop over a callback. Shared conventions are in the [API overview](overview.md).

## C

`#include <diana/rk4.h>`. One step of size `h` from `(t, y)`:

| Slope | Evaluated at | Stage point |
|---|---|---|
| `k1 = F(t, y)` | `t` | `y` |
| `k2 = F(t + h/2, Y2)` | `t + h/2` | `Y2 = y + (h/2)·k1`, `diana_rk4_stage(y, k1, d, h, 2, Y2)` |
| `k3 = F(t + h/2, Y3)` | `t + h/2` | `Y3 = y + (h/2)·k2`, `diana_rk4_stage(y, k2, d, h, 3, Y3)` |
| `k4 = F(t + h, Y4)` | `t + h` | `Y4 = y + h·k3`, `diana_rk4_stage(y, k3, d, h, 4, Y4)` |

and then `diana_rk4_step(y, k1, k2, k3, k4, d, h, y_out)` writes
`y + h·(k1 + 2·k2 + 2·k3 + k4)/6`.

- `diana_rk4_stage(y, k, d, h, stage, y_out)` writes the stage point for `stage` 2, 3 or 4.
- `diana_rk4_step(y, k1, k2, k3, k4, d, h, y_out)` writes the new state.

Both return `DIANA_OK`, or `DIANA_ERR_ARG` without writing `y_out` for a `NULL` pointer,
`d == 0`, a `stage` other than 2, 3 or 4, or a component that is not finite: a NaN or infinite
input or `h`, or an overflow. Each checks every component before writing any. Every operation is
rounded to binary64 in a fixed order, with no fused multiply-add. `y_out` must not overlap any
input; the inputs may overlap each other.

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

### Unchecked stage and step

`diana_rk4_stage_unchecked` and `diana_rk4_step_unchecked` take the same arguments and skip the
finiteness check. They reject only a `NULL` pointer, `d == 0` or a bad `stage`; otherwise they
write every component in one pass and return `DIANA_OK`, even when a component is NaN or
infinite. Where the checked function succeeds, both write the same bits, and checking `y_out` for
finiteness afterwards rejects exactly what the checked function rejects. `diana_rk4` uses the
checked functions.

Use them only when the kernel itself is a measured cost and you check the state yourself: in the
project's [benchmark](../development/benchmark.md) the unchecked stage ran 2.9 to 4.8 times and
the unchecked step 2.6 to 4.5 times faster, saving 1.3 to 2.0 ns per component on a whole RK4
step. That saving is small next to four evaluations of a right-hand side that costs a few
nanoseconds per component.

## Callback wrapper

`diana_rk4(fn, ctx, t0, h, nstep, y, d, work, &done)` takes `nstep` RK4 steps from `y(t0) = y`,
in place, with the callback type `diana_ode_fn` of the [Euler wrapper](euler.md#callback-wrapper).
Step `k` evaluates `fn` at `t0 + k·h`, twice at `t0 + (k + ½)·h`, and at `t0 + (k + 1)·h`. `work`
holds `5·d` doubles and must not overlap `y`; `done` (may be `NULL`) receives the number of
completed steps. When a stage or step fails, it returns `DIANA_ERR_ARG` with `y` at the last
successful step. Exponential decay `y′ = −r·y` with the rate in `ctx`: each component is
multiplied by `R(−0.1)¹⁰ = 0.367879774`, with `R(z) = 1 + z + z²/2 + z³/6 + z⁴/24`, against the
exact `e⁻¹ = 0.367879441`:

```c
#include <stdio.h>

#include <diana/rk4.h>

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

- `diana.rk4_stage(y, k, h, stage)` and `diana.rk4_step(y, k1, k2, k3, k4, h)` return one checked
  call as a new `array.array("d")`. Every vector is an
  [array argument](overview.md#array-arguments), all of the same length; a bad `stage` or a
  non-finite component raises `ValueError`.
- `diana.rk4(f, t0, y0, h, nstep)` takes `nstep` steps from a copy of `y0`, calling `f(t, y)` at
  the four stage times of each step, and returns the final state. Each result of `f` is copied,
  so `f` may return the same buffer every time; `f` must not modify `y`.

The unchecked functions have no Python binding.

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

`f` may return a NumPy array, and `np.asarray` views the state without a copy:

```python
>>> import numpy as np
>>> y = diana.rk4(lambda t, y: -2.0 * np.asarray(y), 0.0, [1.0, 2.0, 4.0], 0.05, 10)
>>> np.asarray(y)
array([0.36787977, 0.73575955, 1.4715191 ])
```

## Guarantees

Proved in Lean and Rocq: RK4 has order 4. For `F` Lipschitz in `y` with constant `L` and smooth
enough, one exact step is within `C·h⁵` of the solution and `k` steps within
`(C·h⁴/L)·(e^{L·k·h} − 1)`, where `C = M₅/120 + N₄/24` comes from bounds on higher derivatives.
Proved in Rocq with Flocq: each computed stage and step component is within a few roundings
(`u = 2⁻⁵³` relative) of its exact value. Proved of the C code: VST shows that all four functions
compute exactly those binary64 values, and Frama-C that they are memory-safe and free of
undefined behaviour. Not proved: a bound on the rounding error accumulated over many steps, and
anything about the wrapper. Theorems: `spec/rk4.md` and `spec/rk4_unchecked.md`; status: the
[verification report](../verification/report.md).

## Technical notes

[API-016](../../note/api/API-016.md) evaluation order and exits,
[API-017](../../note/api/API-017.md) ODE wrappers,
[API-018](../../note/api/API-018.md) unchecked kernels,
[API-019](../../note/api/API-019.md) when to use them,
[API-026](../../note/api/API-026.md) Python drivers,
[PROOF-006](../../note/proof/PROOF-006.md) and [PROOF-008](../../note/proof/PROOF-008.md) what is
proved, with the exact bounds and hypotheses.
