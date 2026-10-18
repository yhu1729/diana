---
id: KERNEL-002
title: Checked kernels validate every component before writing any
kind: rule
path:
  - src/euler_step.c
  - src/rk4_stage.c
  - src/rk4_step.c
  - src/trapezoidal.c
  - src/simpson.c
  - src/cholesky.c
  - src/forward_substitution.c
  - src/back_substitution.c
related: [KERNEL-003, API-003, FP-002]
---
A checked kernel writes its output only once it knows the call succeeds, so `DIANA_ERR_ARG`
leaves every output untouched. The vector kernels do this in two passes without a scratch buffer.

- `diana_euler_step`, `diana_rk4_stage`, `diana_rk4_step`: the first loop computes each component
  into a local, tests it with `diana_fp_finite` and returns `DIANA_ERR_ARG` at the first
  non-finite one; the second loop recomputes each component with the same expression (so the
  same bits) and stores it in `y_out`.
- `diana_trapezoidal`, `diana_simpson`: the scalar is computed into a local, tested, then written
  to `*result`.
- The state machines check every argument before they assign to the struct.
- `diana_cholesky` is the exception: it checks its arguments and every input entry before
  writing (so `DIANA_ERR_ARG` leaves `l` untouched), but column `j` needs columns `0` to `j - 1`,
  so it writes as it goes and a failing pivot (`DIANA_ERR_SINGULAR`) leaves `l` partly written
  (API-028). Keeping `l` untouched would take a second `n*n` buffer.
- `diana_forward_substitution` and `diana_back_substitution` are the other exception: they check
  their arguments, every input entry and the diagonal before writing (so `DIANA_ERR_ARG` for an
  input and `DIANA_ERR_SINGULAR` leave `x` untouched), but entry `i` needs the entries computed
  before it, so an overflowing entry (`DIANA_ERR_ARG`) is found with `x` partly written
  (API-030). Keeping `x` untouched would take a second `n`-vector.
- Proved: `y_out` untouched on `DIANA_ERR_ARG` by WP (EULER-C1, RK4-C1, RK4-C2) and unchanged
  unless every component is finite by VST (EULER-C2, RK4-C3, RK4-C4).

Keep the check in every build configuration: there is no `NDEBUG` or other conditional
compilation in `src/`, and none may be added. The status code and the Python `ValueError` are
API, and the proofs are about the code that ships, so a Debug-only check would leave Release
builds unverified. The one-pass alternative exists only as the opt-in `_unchecked` variants
(KERNEL-003). Revisit the two-pass design only when a benchmark (`script/benchmark.sh`) shows
that kernel time matters next to the caller's right-hand side.
