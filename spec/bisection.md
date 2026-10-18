---
method: bisection
kernel: [src/bisection_mid.c, src/bisection_init.c, src/bisection_step.c, src/bisection_result.c]
model: >
  bisection f a b n : ℝ×ℝ. Starting from [a₀,b₀] = [a,b], step n replaces the endpoint whose f-value has
  the same strict sign as f(mₙ), mₙ = (aₙ+bₙ)/2; if f(mₙ) = 0 the bracket collapses to [mₙ,mₙ].
hypothesis:
  - "H1: f continuous on [a, b] (Lean: ContinuousOn on Icc a b; Rocq: continuity_pt at every point of [a, b])"
  - "H2: a ≤ b and f(a)·f(b) < 0, or a = b and f(a) = 0; diana_bisection_init reduces f(a)·f(b) ≤ 0 to this by collapsing onto a zero endpoint"
  - "H3 (float layers): |a|, |b| ≤ DBL_MAX/2; f(a), f(b), and every supplied f(x) finite; tol ≥ 0"
theorem:
  - id: BISECTION-A1
    layer: A
    informal: "bracket invariant: ∀n, aₙ ≤ bₙ, f(aₙ)·f(bₙ) < 0 or aₙ = bₙ with f(aₙ) = 0, and bₙ − aₙ ≤ (b − a)/2ⁿ"
    lean: Diana.Real.Bisection.bracket_width
    rocq: Diana.Real.Bisection.bracket_width
  - id: BISECTION-A2
    layer: A
    informal: "∃ x* ∈ [aₙ, bₙ] with f(x*) = 0, hence |mₙ − x*| ≤ (b − a)/2ⁿ⁺¹"
    lean: Diana.Real.Bisection.converge
    rocq: Diana.Real.Bisection.converge
  - id: BISECTION-B1
    layer: B
    informal: >
      binary64 model: with |a|,|b| ≤ DBL_MAX/2 and a ≤ b, the midpoint fl(0.5·fl(a+b)) is finite
      and lies in [a, b] (round-to-nearest-even; parameterised by the NaN-payload functions so it
      instantiates to CompCert's Float.add/Float.mul).
    rocq: Diana.Float.Bisection.mid_in_bracket
  - id: BISECTION-B2
    layer: B
    informal: >
      the float bracket invariant of A1 holds for every step of the binary64 model: from a state
      satisfying Bracket and Next (x finite and strictly inside the bracket), one step of fstep
      with a finite fx preserves finiteness, a <= b, |a|,|b| <= DBL_MAX/2 and the
      strict-sign-change-or-collapsed-root condition, and nests the bracket.
    rocq: Diana.Float.Bisection.step_in_bracket
  - id: BISECTION-B3
    layer: B
    informal: >
      with tol = 0 the iteration stops once the endpoints are adjacent doubles: when succ a = b the
      binary64 midpoint equals an endpoint, which is the kernel's DIANA_OK stop.
    rocq: Diana.Float.Bisection.mid_adjacent
  - id: BISECTION-B4
    layer: B
    informal: >
      termination: a run of n consecutive DIANA_CONTINUE steps from a state satisfying Bracket
      satisfies n <= lattice of the initial state, the number of doubles the bracket spans (by
      step_width_le, the width is non-increasing, and step_lattice_lt, lattice strictly decreases
      on every continuing step).
    rocq: Diana.Float.Bisection.step_count_bound
  - id: BISECTION-C1
    layer: C
    informal: "diana_bisection_mid computes the model midpoint: Float.mul 0.5 (Float.add a b) = mid a b (VST, AArch64 macOS Clight AST)"
    rocq: Diana.VST.BisectionMid.body_diana_bisection_mid
  - id: BISECTION-C2
    layer: C
    informal: >
      ACSL contract in src/bisection_init.c, Frama-C WP float model with RTE: memory safety, no
      UB, the bracket predicate (strict sign change or collapsed root) on DIANA_OK and
      DIANA_CONTINUE with Next as well on DIANA_CONTINUE, the status field equal to the result on
      DIANA_OK and DIANA_CONTINUE, and the state, status field included, unchanged when init
      reports an error. The only assumed contract is diana_bisection_mid (src/bisection_mid.h,
      -wp-skip-fct), discharged by BISECTION-B1.
    acsl: src/bisection_init.c
  - id: BISECTION-C3
    layer: C
    informal: >
      ACSL contract in src/bisection_step.c, Frama-C WP float model with RTE, for a valid state
      that satisfies the bracket predicate, Next and iter < max_iter whenever its status field is
      DIANA_CONTINUE: memory safety, no UB, the bracket predicate preserved and nested, iter
      increments, Next and iter < max_iter on DIANA_CONTINUE, every result other than
      DIANA_ERR_ARG only from the status DIANA_CONTINUE and with the status field equal to it (so
      any other status gives DIANA_ERR_ARG), and the state, status field included, unchanged
      when step reports DIANA_ERR_ARG (a step that reports DIANA_ERR_MAXITER has halved the
      bracket and incremented iter). The only assumed contract is diana_bisection_mid,
      discharged by BISECTION-B1.
    acsl: src/bisection_step.c
  - id: BISECTION-C4
    layer: C
    informal: >
      ACSL contract in src/bisection_result.c, Frama-C WP float model with RTE: memory safety, no
      UB, separation of the outputs from the state, the root inside the bracket and the width the
      rounded difference. The only assumed contract is diana_bisection_mid, discharged by
      BISECTION-B1.
    acsl: src/bisection_result.c
  - id: BISECTION-C5
    layer: C
    informal: >
      diana_fp_finite implements its IEEE semantics (VST, AArch64 macOS Clight AST):
      it returns 1 exactly when its argument is finite.
    rocq: Diana.VST.BisectionInit.body_diana_fp_finite
  - id: BISECTION-C6
    layer: C
    informal: >
      diana_fp_abs returns, for finite input, the conditional negation the C performs (VST, AArch64
      macOS Clight AST); c_abs_B2R identifies it with Rabs.
    rocq: Diana.VST.BisectionInit.body_diana_fp_abs
  - id: BISECTION-C7
    layer: C
    informal: >
      diana_bisection_result writes the model midpoint and the rounded width to non-NULL root and
      width, whatever the status field holds (VST, AArch64 macOS Clight AST). The NULL output
      paths are BISECTION-C4.
    rocq: Diana.VST.BisectionResult.body_diana_bisection_result
  - id: BISECTION-C8
    layer: C
    informal: >
      diana_bisection_init computes c_init, the model of every exit in the C's evaluation order
      (VST, AArch64 macOS Clight AST): for s pointing to a writable state with any contents, it
      returns the c_init status (DIANA_ERR_ARG, DIANA_ERR_BRACKET, DIANA_OK or DIANA_CONTINUE),
      writes the c_init state (iter = 0; x the model midpoint, or the endpoint a zero f-value
      collapses onto) with the status field set to the returned status on DIANA_OK and
      DIANA_CONTINUE, and leaves *s unchanged on an error. The NULL path is BISECTION-C2.
    rocq: Diana.VST.BisectionInit.body_diana_bisection_init
  - id: BISECTION-C9
    layer: C
    informal: >
      diana_bisection_step computes c_step (VST, AArch64 macOS Clight AST): for s pointing to a
      writable state whose status field is not DIANA_CONTINUE, it returns DIANA_ERR_ARG with *s
      unchanged; when the status field is DIANA_CONTINUE, it returns the c_step status
      (DIANA_ERR_ARG for a non-finite fx, DIANA_OK for a zero fx, the tolerance and the stagnation
      exits, DIANA_ERR_MAXITER, DIANA_CONTINUE) and writes the c_step state, which is *s unchanged
      on DIANA_ERR_ARG and otherwise has iter incremented as unsigned C arithmetic and the status
      field set to the returned status. The NULL path is BISECTION-C3.
    rocq: Diana.VST.BisectionStep.body_diana_bisection_step
  - id: BISECTION-C10
    layer: C
    informal: >
      c_step agrees with the binary64 model: for finite fx and fa, the state it writes is fstep of
      the old state (BISECTION-B2) with iter + 1 and max_iter unchanged, so by BISECTION-C9 the
      bracket after diana_bisection_step is the layer-B fstep.
    rocq: Diana.VST.Bisection.c_step_fstep
  - id: BISECTION-C11
    layer: C
    informal: >
      c_init establishes the layer-B invariant: whenever it writes a state, the status is DIANA_OK
      or DIANA_CONTINUE, the state satisfies Bracket, and Next as well on DIANA_CONTINUE (the
      hypotheses of BISECTION-B2); iter = 0 and max_iter is the nonzero argument.
    rocq: Diana.VST.Bisection.c_init_bracket
  - id: BISECTION-C12
    layer: C
    informal: >
      a continuing step keeps the layer-B invariant: from a state satisfying Bracket and Next, a
      c_step that returns DIANA_CONTINUE writes a state satisfying Bracket and Next with
      iter < max_iter, so BISECTION-B2 applies again to the next step.
    rocq: Diana.VST.Bisection.c_step_next
  - id: BISECTION-C13
    layer: C
    informal: >
      the copy of diana_fp_finite in the Clight AST of bisection_step implements its IEEE
      semantics, as BISECTION-C5 for the copy in bisection_init (VST, AArch64 macOS Clight AST).
    rocq: Diana.VST.BisectionStep.body_diana_fp_finite
---
# bisection

Reverse-communication bisection. The C kernel never calls `f`; the caller supplies `f(x)` for the
requested `x`. The mathematical model is the usual bisection sequence on reals; the float model
replaces the midpoint by `0.5 * (a + b)` in binary64 round-to-nearest-even.

## Proof sketch

- **A1**: induction on n. The sign test `(fx > 0) == (fa > 0)` keeps a sign change in the kept
  half; the width exactly halves in reals.
- **A2**: intermediate value theorem on `[aₙ, bₙ]` (Mathlib `intermediate_value_Icc`; Rocq Stdlib `IVT_interv`).
- **B1**: `|a + b| ≤ DBL_MAX`, which is representable, so the sum does not overflow; `2a` and `2b`
  are representable (doubling a binary64 value keeps it in format), and rounding is monotone, so
  `fl(a+b) ∈ [2a, 2b]`; halving then rounding is again monotone with representable endpoints `a`,
  `b`, so the midpoint lies in `[a, b]`. Proof: `mid_in_bracket` in `verification/rocq/theory/Float/Bisection.v`.
- **B2**: case analysis on the sign test. `fstep` is the binary64 state machine of
  `diana_bisection_step`, carrying `fa` in the state as the C does (the real model recomputes the
  sign from `f a`, which is why layer B needs its own `step`). The kept half inherits a strict sign
  change from the discarded one, `mid_in_bracket` (B1) places the new midpoint inside the bracket,
  and the `fx = 0` branch collapses to the exact root.
- **B3**: if `succ a = b` there is no double strictly between them, so the midpoint — which B1 puts
  in `[a, b]` — is `a` or `b`, and `succ_le_lt` rules out any value in between. That is exactly the
  kernel's `s->x <= s->a || s->x >= s->b` stop.
- **B4**: every binary64 value is an integer multiple of `2^-1074` (`format_multiple_emin`), so
  `lattice s = (b - a) / 2^-1074` is a natural number, and a continuing step strictly shrinks the
  bracket, hence strictly decreases it. `step_count_bound` turns that into `n <= lattice s` for any
  run of `n` consecutive continuing steps.

  **What B4 does not say.** `lattice` is a sound but loose bound (up to `2^1075`); it proves
  termination, not the `max_iter = 2100` default. Three tighter routes were tried and refuted: the
  width does not halve (`max(x-a, b-x) <= (b-a)/2` holds only when `2x = a + b` exactly, so a
  rounded midpoint overshoots), `mag` of the width can stall for one step
  (`0x1.ff8p-1065 -> 0x1p-1065`), and `w' <= w/2 + ulp(x)/2` fails when the endpoints straddle zero
  with very different magnitudes. The attained worst case is **2098** steps (root at `DBL_TRUE_MIN`
  in `[-DBL_MAX/2, DBL_MAX/2]`), pinned by `test_worst_case_step_count` in `test/c/test_bisection.c`
  and by `test/python/test_bisection.py`; an adversary choosing the branch that keeps the wider
  lattice gap also attains exactly 2098. Exhaustive dynamic programming over every bracket of twelve
  scaled-down binary formats (p in 3..5, several exponent ranges) gives the closed form
  `emax - emin + p + 1`, with `emin` the least *normal* exponent. For binary64 restricted to
  `|a|, |b| <= DBL_MAX/2` the top exponent is 1022, so this is `1022 - (-1022) + 53 + 1 = 2098`.
  That is evidence, not a theorem: the explicit constant is future work.
- **C1**: `diana_bisection_mid` returns `Float.mul 0.5 (Float.add a b)`, identified with the Flocq
  model `mid` by `c_mid_model`; the literal `0.5` emitted by clightgen is shown equal to the model's
  `half` by computation (`c_half_eq`).
- **C2 to C4**: the `/*@ ... */` annotations in `src/bisection_init.c`, `src/bisection_step.c` and
  `src/bisection_result.c`, one WP run per file, with the predicates `bisection_bracket`,
  `bisection_next` and `bisection_unchanged` shared from `src/bisection_acsl.h` so the
  postcondition of `init` and `step` is literally the precondition of `step` and `result`.
  `bisection_unchanged` covers the `status` field too, and the precondition of `step` asks the
  bracket, Next and `iter < max_iter` only of a state whose `status` is `DIANA_CONTINUE`, the
  status `init` and `step` write when they return it; any other state, finished or
  zero-initialized, takes the `DIANA_ERR_ARG` exit. Each call to `diana_bisection_mid` uses its
  contract in `src/bisection_mid.h`, the only assumed one (`-wp-skip-fct` where it is defined, so
  `src/bisection_mid.c` has no WP goal and no expectation row). The kernel calls no libm
  function: finiteness and absolute value are implemented in `src/fp.h` with IEEE arithmetic
  (`x == x && x - x == 0`, conditional negation) and verified by WP from `\is_finite`.
- **C5/C6**: the `src/fp.h` helpers. `clightgen` does not inline them despite `static inline`, so
  each is a real Clight function with its own funspec in the AST of every source that calls it
  (`bisection_init`: both, `bisection_step`: `diana_fp_finite`), and each VST file proves the
  copies in its AST. A caller's `semax_body` depends on the helper's funspec, not on its body
  lemma, so every copy is a listed theorem of its own: C5/C6 for `bisection_init`, C13 for
  `bisection_step`, and NEWTON-C8 to C10, EULER-C3, RK4-C7/C8, TRAPEZOIDAL-C3 and SIMPSON-C3 for
  the other kernels, so that the spec gate sees an admitted copy. `diana_fp_finite` is
  `x == x && x - x == 0`: `x == x` tests only non-NaN (`+inf == +inf` is true), and `x - x == 0` is
  what excludes the infinities, so the two together characterise finiteness (`cmp_eq_self`,
  `cmp_sub_self_zero`). `diana_fp_abs` is specified as the conditional negation the C performs, not
  as `Float.abs`, because the C returns `-0.0` for `-0.0`; `c_abs_B2R` identifies it with `Rabs`
  on finite input.
- **C7**: `diana_bisection_result` over `data_at` on the state, with the two output pointers and the
  separation the ACSL `\separated` preconditions require. The kernel is loop-free (no `Sloop` in
  the Clight AST), so the proof is `forward`/`forward_if`/`forward_call` with no loop invariant.
- **C7 to C9, the midpoint call**: `diana_bisection_mid` is an external function in the ASTs of
  `init`, `step` and `result`; their proofs take its funspec from `Diana.VST.BisectionMid.mid_spec`,
  the funspec C1 proves of its body, so caller and callee use one definition. As for every
  function here, the `semax_body` results are not linked into a whole-program `semax_prog`.
- **C8/C9**: `c_init` and `c_step` are total models over `cstate` (the Flocq `state` plus `iter`
  and `max_iter` as CompCert `int`), written as the C evaluates: CompCert `Float.cmp` for every
  comparison, the short-circuit `||`/`&&` chains in source order, unsigned `iter + 1u`, and
  `iter >= max_iter` as `negb (Int.ltu iter max_iter)`. The funspecs take the state as
  `data_at` of a concrete field tuple (`cstate_repr c st`, the model state `c` and the status
  field `st`, destructed at the start of the proof), so field reads and stores stay concrete
  instead of unfolding into nested projections. The models leave the status field out: `init`'s
  postcondition stores the `c_init` status in it on success (`init_repr`), and `step`'s
  funspec, over any `st`, returns `step_result st c fx` with the state `step_repr st c fx`, which
  are `-1` and `cstate_repr c st` unless `st` is 1, and otherwise the `c_step` result and state
  with the result in the status field unless it is `-1`; the proof first branches on
  `Int.eq st Int.one`. Each short-circuit temporary is joined by `forward_if` on its value, and
  the branch obligations are closed by case analysis on the finiteness and comparison bits
  (`bool_solve`). Before each `return` the postcondition is rewritten to the concrete status and
  state (`init_post`, `step_post`): left to VST's `forward`, the entailment simplifies the
  unreduced model and does not terminate. `c_keep`, `c_mid` and `c_abs` stay `Opaque` during
  symbolic execution. `init` keeps the caller's contents until every error exit has passed, then
  weakens `data_at` to `data_at_` for the stores, so an error leaves `*s` unchanged.
- **C10**: `c_step` and `fstep` take the same branches once `fx` and `fa` are finite:
  `Float.cmp Ceq fx 0` is `B2R fx = 0`, `Float.cmp Cgt x 0` is `fpos x`, `Float.cmp Cle` is `fle`,
  and `Float.sub`/`c_mid` are `fwidth`/`mid` at CompCert's NaN-payload function.
- **C11/C12**: the comparisons that do not take an error exit become real inequalities on finite
  operands (`cmp_real`); `|a|, |b| <= DBL_MAX/2` comes from `c_abs_B2R` and the exact value of the
  constant `DBL_MAX / 2.0` (`c_max_B2R`), the strict sign change from excluding equal strict signs
  and zero f-values, and `a < x < b` from the stagnation test once `mid_in_bracket` (B1) makes `x`
  finite. C12 obtains `Bracket` from C10 and B2. Together, C8, C9 and C11/C12 put every state that
  a run of `init` then `step` reaches while the status is `DIANA_CONTINUE` under B2–B4.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/Bisection.lean`,
  `verification/rocq/theory/Real/Bisection.v`, Rocq standard library only): `step` is the functional
  model of the bisection kernel over ℝ with the same sign test as the C code, `(fx > 0) == (fa > 0)`
  moves `a`, otherwise `b`, and an exact zero collapses the bracket; `iter` is the bracket after `n`
  steps. `SignChange` is a strict sign change or a bracket collapsed onto an exact root, which is
  the state the C kernel can be in after `diana_bisection_init`; a weak sign change
  (`f a * f b ≤ 0`) is not invariant under that sign test when `f a = 0`. A collapsed bracket has
  its midpoint at the root, so `step` takes the zero branch.
- **Layer B** (`verification/rocq/theory/Float/Bisection.v`): `mid` is `0.5 * (a + b)` in binary64
  round-to-nearest-even, parameterised by the NaN-payload functions so that it instantiates to
  CompCert's `Float.add`/`Float.mul`. `half` is `2^52 · 2^-53`; `DBL_MAX = 2^1024 − 2^971`, and
  `2^e − 2^(e−53)` is the largest binary64 with exponent `e − 53` (`pow_diff_format`). Doubling
  keeps a binary64 value representable when the caller bounds it separately (`format_double`), and
  rounding a value bounded by a representable number stays bounded by it (`round_abs_le`). `state`
  is the binary64 analogue of `diana_bisection_state` without `iter`/`max_iter` (those are integers
  the float layer says nothing about); `fstep` mirrors `diana_bisection_step` in the C's operation
  order, with `fpos` for the C's `> 0.0` sign test and `fle` for `<=` via `Bcompare`. `Bracket` and
  `Next` are the ACSL predicates `bisection_bracket` and `bisection_next` of `src/bisection_acsl.h`
  restated over Flocq values, and `lattice` counts the doubles the bracket spans.
- **Layer C, VST** (one file per source, `verification/rocq/theory/VST/BisectionMid.v`,
  `BisectionInit.v`, `BisectionStep.v` and `BisectionResult.v`, against the Clight ASTs
  `verification/clight/bisection_<function>_aarch64_macos.v`, CompCert target AArch64 macOS; the
  models and the AST-independent lemmas they share are in `VST/Bisection.v`): CompCert's
  `Float.add`/`Float.mul` are Flocq's `Bplus`/`Bmult` with CompCert's NaN-payload function, so the
  model instantiates directly. `c_half` is the literal `0.5` as emitted by clightgen, and `c_mid` is
  the C midpoint `Float.mul c_half (Float.add a b)`. `c_max` is `DBL_MAX / 2.0` as the C computes
  it, a run-time division of two literals. `cstate` is `diana_bisection_state` without its
  `status` field: the layer-B `state` with `iter` and `max_iter` as CompCert `int`, laid out with
  the status `st` by `cstate_repr c st` (`cstate_repr_state_repr` relates it to the `state_repr`
  of C7, which takes the status as a `Z`). `c_keep` is the C's sign test
  `(fx > 0.0) == (s->fa > 0.0)` and the endpoint it replaces, the analogue of `fkeep`.

## Tolerance rationale

`b − a ≤ tol` is an absolute width criterion; the estimate `0.5·(a+b)` is then within `tol/2` of
a root in reals and within `tol/2 + 1 ulp` in binary64.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| BISECTION-A1 | proved | proved | – |
| BISECTION-A2 | proved | proved | – |
| BISECTION-B1 | – | proved | – |
| BISECTION-B2 | – | proved | – |
| BISECTION-B3 | – | proved | – |
| BISECTION-B4 | – | proved | – |
| BISECTION-C1 | – | proved | – |
| BISECTION-C2 | – | – | 93/93 goals (Frama-C 32.1, Alt-Ergo 2.6.4), diana_bisection_mid assumed |
| BISECTION-C3 | – | – | 81/81 goals (Frama-C 32.1, Alt-Ergo 2.6.4), diana_bisection_mid assumed |
| BISECTION-C4 | – | – | 19/19 goals (Frama-C 32.1, Alt-Ergo 2.6.4), diana_bisection_mid assumed |
| BISECTION-C5 | – | proved | – |
| BISECTION-C6 | – | proved | – |
| BISECTION-C7 | – | proved | – |
| BISECTION-C8 | – | proved | – |
| BISECTION-C9 | – | proved | – |
| BISECTION-C10 | – | proved | – |
| BISECTION-C11 | – | proved | – |
| BISECTION-C12 | – | proved | – |
| BISECTION-C13 | – | proved | – |
