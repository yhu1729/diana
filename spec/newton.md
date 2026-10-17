---
method: newton
kernel: [src/newton_init.c, src/newton_step.c, src/newton_result.c]
model: >
  newton f x₀ n : ℝ. Starting from x₀, step n replaces xₙ by xₙ₊₁ = xₙ − f(xₙ)/f′(xₙ); the
  kernel stops at an exact zero f(xₙ) = 0, when the correction f(xₙ)/f′(xₙ) is at most tol in
  absolute value, or when it no longer changes xₙ in binary64.
hypothesis:
  - "H1: f and f′ have two-sided derivatives f′ and f″ at every point of the interval I, with |f″| ≤ M there; continuity of f″ is not required"
  - "H2: |f′| ≥ m > 0 on I, and f(r) = 0 for a point r of I"
  - "H3 (A2): I = [r − δ, r + δ] with δ ≥ 0, |x₀ − r| ≤ δ, and q = M·δ/(2m) < 1"
  - "H4 (float layers): x, f(x), f′(x) and tol are binary64 values supplied by the caller; tol ≥ 0"
theorem:
  - id: NEWTON-A1
    layer: A
    informal: >
      one-step quadratic bound: under H1 and H2 for x and r in I, the Newton step
      x − f(x)/f′(x) satisfies |x − f(x)/f′(x) − r| ≤ (M/(2m))·(x − r)²
    lean: Diana.Real.Newton.step_error
    rocq: Diana.Real.Newton.step_error
  - id: NEWTON-A2
    layer: A
    informal: >
      quadratic convergence: under H1 to H3, every iterate stays in I and
      |xₙ − r| ≤ δ·q^(2ⁿ − 1) with q = M·δ/(2m) < 1
    lean: Diana.Real.Newton.converge
    rocq: Diana.Real.Newton.converge
  - id: NEWTON-B1
    layer: B
    informal: >
      a finite iterate certifies its evaluation: if the binary64 model fl(x − fl(f/f′)) is
      finite, then x, f and the correction fl(f/f′) are finite; since a finite Bminus or Bdiv of
      finite operands is the rounded exact value (fsub_value, fdiv_value), neither operation
      overflowed.
    rocq: Diana.Float.Newton.finite_result
  - id: NEWTON-B2
    layer: B
    informal: >
      step error: if the binary64 model x′ = fl(x − fl(f/f′)) is finite and f′ ≠ 0, then
      |x′ − (x − f/f′)| ≤ u·|x − f/f′| + (1 + u)·(u·|f/f′| + η), with u = 2⁻⁵³ and η = 2⁻¹⁰⁷⁵
      (underflow in the quotient).
    rocq: Diana.Float.Newton.forward_error
  - id: NEWTON-B3
    layer: B
    informal: >
      stagnation: for finite x and dx with fl(x − dx) finite, fl(x − dx) = x implies
      |dx| ≤ ulp(x)/2, so the kernel's "iterate unchanged" stop means the correction is at most
      half an ulp of the iterate (parameterised by the NaN-payload functions so it instantiates
      to CompCert's Float.sub/Float.div).
    rocq: Diana.Float.Newton.stagnation
  - id: NEWTON-C1
    layer: C
    informal: >
      ACSL contract in src/newton_init.c, Frama-C WP float model with RTE: memory safety, no UB,
      the state invariant (x, dx and tol finite, tol ≥ 0) established with x = x0, dx = 0,
      tol, iter = 0 and max_iter > 0 on DIANA_CONTINUE, and the state unchanged when init reports
      DIANA_ERR_ARG. No assumed contract.
    acsl: src/newton_init.c
  - id: NEWTON-C2
    layer: C
    informal: >
      ACSL contract in src/newton_step.c, Frama-C WP float model with RTE: memory safety, no UB,
      the state invariant preserved, iter increments, DIANA_OK only with |dx| ≤ tol or x
      unchanged, DIANA_CONTINUE only with |dx| > tol, x changed and iter < max_iter,
      DIANA_ERR_MAXITER only with iter = max_iter, DIANA_ERR_SINGULAR only with dfx = 0 and
      fx ≠ 0, and the state unchanged when step reports DIANA_ERR_ARG or DIANA_ERR_SINGULAR. No
      assumed contract.
    acsl: src/newton_step.c
  - id: NEWTON-C3
    layer: C
    informal: >
      ACSL contract in src/newton_result.c, Frama-C WP float model with RTE: memory safety, no
      UB, separation of the outputs from the state, and the iterate and the last correction
      written to non-NULL root and dx. No assumed contract.
    acsl: src/newton_result.c
  - id: NEWTON-C4
    layer: C
    informal: >
      diana_newton_result writes the iterate and the last correction to non-NULL root and dx
      (VST, AArch64 macOS Clight AST). The NULL output paths are NEWTON-C3.
    rocq: Diana.VST.NewtonResult.body_diana_newton_result
  - id: NEWTON-C5
    layer: C
    informal: >
      diana_newton_init computes c_init, the model of every exit in the C's evaluation order
      (VST, AArch64 macOS Clight AST): for s pointing to a writable state with any contents, it
      returns the c_init status (DIANA_ERR_ARG or DIANA_CONTINUE), writes x0, dx = 0, tol,
      iter = 0 and max_iter on DIANA_CONTINUE, and leaves *s unchanged on DIANA_ERR_ARG. The NULL
      path is NEWTON-C1.
    rocq: Diana.VST.NewtonInit.body_diana_newton_init
  - id: NEWTON-C6
    layer: C
    informal: >
      diana_newton_step computes c_step (VST, AArch64 macOS Clight AST): for s pointing to a
      writable state, it returns the c_step status (DIANA_ERR_ARG for a non-finite fx, dfx,
      correction or iterate, DIANA_ERR_SINGULAR for a zero dfx, DIANA_OK for a zero fx, the
      tolerance and the stagnation stops, DIANA_ERR_MAXITER, DIANA_CONTINUE) and writes the
      c_step state, which is *s unchanged on DIANA_ERR_ARG and DIANA_ERR_SINGULAR and otherwise
      has iter incremented as unsigned C arithmetic. The NULL path is NEWTON-C2.
    rocq: Diana.VST.NewtonStep.body_diana_newton_step
  - id: NEWTON-C7
    layer: C
    informal: >
      c_step agrees with the binary64 model: when fx and dfx are finite and non-zero and the
      correction and the iterate are finite, the state c_step writes has x = fstep x fx dfx and
      dx = fdiv fx dfx at CompCert's NaN-payload functions, so by NEWTON-C6 the iterate
      diana_newton_step writes is the layer-B fstep and NEWTON-B2/B3 apply to it.
    rocq: Diana.VST.Newton.c_step_fstep
  - id: NEWTON-C8
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of newton_init implements its IEEE
      semantics, as BISECTION-C5 for the copy in bisection_init (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.NewtonInit.body_diana_fp_finite
  - id: NEWTON-C9
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of newton_step implements its IEEE
      semantics, as BISECTION-C5 for the copy in bisection_init (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.NewtonStep.body_diana_fp_finite
  - id: NEWTON-C10
    layer: C
    informal: >
      the copy of diana_fp_abs in the Clight AST of newton_step returns, for finite input, the
      conditional negation the C performs, as BISECTION-C6 for the copy in bisection_init (VST,
      AArch64 macOS Clight AST).
    rocq: Diana.VST.NewtonStep.body_diana_fp_abs
---
# newton

Reverse-communication Newton's method. The C kernel never calls `f` or `f′`; the caller supplies
`f(x)` and `f′(x)` for the requested `x`. The mathematical model is the usual Newton sequence on
reals; the float model replaces the correction by `fl(f/f′)` and the iterate by `fl(x − fl(f/f′))`
in binary64 round-to-nearest-even, and checks each for finiteness.

## Operation order

1. a `NULL` state, or a NaN or infinite `fx` or `dfx`, is `DIANA_ERR_ARG`, state unchanged;
2. `fx = 0` is tested next: an exact zero converges with `dx = 0` and `iter + 1`, whatever the
   finite `f′(x)`;
3. `dfx = 0` (either sign) is `DIANA_ERR_SINGULAR`, state unchanged: the step is undefined;
4. `dx = fl(fx / dfx)`, rejected (`DIANA_ERR_ARG`, state unchanged) when not finite, which
   covers a subnormal `dfx` against a large `fx`;
5. `x′ = fl(x − dx)`, rejected the same way when not finite;
6. the state is updated (`iter + 1`, `dx`, `x′`), then `DIANA_OK` if `x′ = x` or `|dx| ≤ tol`,
   `DIANA_ERR_MAXITER` if `iter ≥ max_iter`, else `DIANA_CONTINUE`.

## Proof sketch

- **A1**: with `d = r − x`, the functions `ψ(s) = f′(x + s·d) − f′(x)` and
  `φ(s) = f(x + s·d) − f(x) − f′(x)·s·d` on `s ∈ [0, 1]` vanish at 0, `|ψ′| ≤ M·|d|` gives
  `|ψ(s)| ≤ M·|d|·s`, and `φ′(s) = ψ(s)·d` gives `|φ(1)| ≤ M·d²/2`, both by the mean-value bound
  `bound_of_deriv`/`bound_of_derive` of `Diana.Real.Quadrature` (`taylor_bound`); the
  parameterisation by `s` covers `r < x` and `r > x` at once. With `f(r) = 0`,
  `x − f(x)/f′(x) − r = −φ(1)/f′(x)` and `|f′(x)| ≥ m`.
- **A2**: induction on `n` with `K = M/(2m)` and `q = K·δ`: `|eₙ| ≤ δ·q^(2ⁿ−1) ≤ δ` keeps `xₙ` in
  `I`, A1 gives `|eₙ₊₁| ≤ K·eₙ² ≤ K·δ²·q^(2ⁿ⁺¹−2) = δ·q^(2ⁿ⁺¹−1)`.
- **B1**: `Bminus` and `Bdiv` return a non-finite value for a non-finite first operand and on
  overflow (`fsub_finite_inv`, `fdiv_finite_inv`); `fsub_value`/`fdiv_value` are the rounded
  exact values. Proof: `finite_result` in `verification/rocq/theory/Float/Newton.v`.
- **B2**: the quotient is `fl(f/f′) = (f/f′)(1 + e₁) + d₁` with `|e₁| ≤ u`, `|d₁| ≤ η`
  (`round_error`), and the difference of two binary64 values has relative error at most `u` even
  below the normal range (`sub_error`, from `add_error` of `Diana.Float.Sum` with the negated
  operand); the algebra is that of EULER-B2 with the product replaced by the quotient. Proof:
  `forward_error`.
- **B3**: `|round(y) − y| ≤ ulp(y)/2` (`error_le_half_ulp`) with `y = x − dx` and `round(y) = x`,
  and `ulp(y) ≤ ulp(round(y))` (`ulp_le_ulp_round`: by `ulp_round`, either the ulps agree or
  `round(y)` is the power of two above `y`, whose ulp is at least `ulp(y)` since `fexp` is
  monotone). Proof: `stagnation`.
- **C1 to C3**: the `/*@ ... */` annotations in `src/newton_init.c`, `src/newton_step.c` and
  `src/newton_result.c`, one WP run per file, with the predicates `newton_state` and
  `newton_unchanged` shared from `src/newton_acsl.h`. The value of `x′` is not an ACSL
  post-condition (see "Why the functional contract is not in ACSL" in `spec/trapezoidal.md`); it
  is the VST theorem C7 through C6. `|dx| ≤ tol` and `x′ = x` are post-conditions because WP
  decides the C comparisons on finite doubles exactly, with `diana_fp_abs` specified by `\abs`.
- **C4 to C6**: as BISECTION-C7 to C9: `c_init` and `c_step` are total models over `cstate` (the
  five fields with `iter` and `max_iter` as CompCert `int`) in the C's evaluation order, the
  funspecs take the state as `data_at` of a concrete field tuple, each short-circuit temporary is
  joined by `forward_if` on its value, and before each `return` the postcondition is rewritten to
  the concrete status and state (`init_post`, `step_post`). `init` keeps the caller's contents
  until the error exits have passed. The `src/fp.h` helpers are re-specified for each AST that
  calls them (`diana_fp_finite` for `init` and `step`, `diana_fp_abs` for `step`) with the lemmas
  of `verification/rocq/theory/VST/Bisection.v`.
- **C7**: CompCert's `Float.div` and `Float.sub` are Flocq's `Bdiv` and `Bminus` at
  `Float.binop_nan`, so after the error exits `c_step`'s `x` and `dx` are `fstep` and `fdiv` of
  `Diana.Float.Newton` by unfolding.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/Newton.lean`,
  `verification/rocq/theory/Real/Newton.v`): `step f f′ x = x − f x / f′ x` and `iter` its
  `n`-fold application, the kernel's correction and iterate evaluated exactly; the kernel's exact
  zero and stagnation stops are not modelled, since they only shorten a run.
- **Layer B** (`verification/rocq/theory/Float/Newton.v`): `fsub` and `fdiv` are `Bminus` and
  `Bdiv` in `mode_NE`, parameterised by the NaN-payload functions; `fstep x fx dfx` is
  `fsub x (fdiv fx dfx)`, the C's two operations in order. `finite_result` and `forward_error`
  are about `fstep`, `stagnation` about `fsub` with an arbitrary finite correction.
- **Layer C, VST** (one file per source, `verification/rocq/theory/VST/NewtonInit.v`,
  `NewtonStep.v` and `NewtonResult.v`, against the Clight ASTs
  `verification/clight/newton_<function>_aarch64_macos.v`, CompCert target AArch64 macOS; the
  models are in `VST/Newton.v`): `cstate` is
  `diana_newton_state`; `c_init` and `c_step` use CompCert's `Float.cmp`, `Float.div`,
  `Float.sub`, the conditional negation `c_abs` of `Diana.VST.Bisection` for `diana_fp_abs`,
  unsigned `iter + 1u`, and `iter >= max_iter` as `negb (Int.ltu iter max_iter)`.

## What the theorems do not say

- Nothing about termination from an arbitrary `x₀`: A2 needs `x₀` within `δ` of a root with
  `M·δ/(2m) < 1`, in exact arithmetic. In binary64 the iteration near a simple root commonly
  ends in a two-cycle of adjacent doubles, which only `tol > 0` or `max_iter` stops
  (note TEST-028); `max_iter` is the only bound on the step count.
- A multiple root (`m = 0`) is outside H2: convergence is then linear, as the double root of `x²`
  in the tests shows, and the quadratic bound does not apply.
- The errors of the caller's `f(x)` and `f′(x)` evaluations are the caller's; B2 is about the
  kernel's two operations on the values it is given.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| NEWTON-A1 | proved | proved | – |
| NEWTON-A2 | proved | proved | – |
| NEWTON-B1 | – | proved | – |
| NEWTON-B2 | – | proved | – |
| NEWTON-B3 | – | proved | – |
| NEWTON-C1 | – | – | 36/36 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| NEWTON-C2 | – | – | 66/66 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| NEWTON-C3 | – | – | 13/13 goals (Frama-C 32.1, Alt-Ergo 2.6.4), no assumed contract |
| NEWTON-C4 | – | proved | – |
| NEWTON-C5 | – | proved | – |
| NEWTON-C6 | – | proved | – |
| NEWTON-C7 | – | proved | – |
| NEWTON-C8 | – | proved | – |
| NEWTON-C9 | – | proved | – |
| NEWTON-C10 | – | proved | – |
