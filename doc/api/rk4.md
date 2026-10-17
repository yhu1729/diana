# Classical Runge–Kutta step (RK4)

Status codes, linking, and the Python conventions shared by every kernel are in the
[API overview](overview.md); the theorems cited below are listed in `spec/rk4.md`.

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
cases and that `y_out` is untouched on `DIANA_ERR_ARG` (RK4-C1).

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
