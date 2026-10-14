---
method: bisect
kernel: src/bisect.c
model: >
  bisect f a b n : ℝ×ℝ. Starting from [a₀,b₀] = [a,b], step n replaces the endpoint whose f-value has
  the same strict sign as f(mₙ), mₙ = (aₙ+bₙ)/2; if f(mₙ) = 0 the bracket collapses to [mₙ,mₙ].
hypothesis:
  - "H1: f continuous on [a, b] (Lean: ContinuousOn on Icc a b; Rocq: continuity_pt at every point of [a, b])"
  - "H2: a ≤ b and f(a)·f(b) < 0, or a = b and f(a) = 0; diana_bisect_init reduces f(a)·f(b) ≤ 0 to this by collapsing onto a zero endpoint"
  - "H3 (float layers): |a|, |b| ≤ DBL_MAX/2; f(a), f(b), and every supplied f(x) finite; tol ≥ 0"
theorem:
  - id: BIS-A1
    layer: A
    informal: "bracket invariant: ∀n, aₙ ≤ bₙ, f(aₙ)·f(bₙ) < 0 or aₙ = bₙ with f(aₙ) = 0, and bₙ − aₙ ≤ (b − a)/2ⁿ"
    lean: Diana.Real.Bisect.bracket_width
    rocq: Diana.Real.Bisect.bracket_width
  - id: BIS-A2
    layer: A
    informal: "∃ x* ∈ [aₙ, bₙ] with f(x*) = 0, hence |mₙ − x*| ≤ (b − a)/2ⁿ⁺¹"
    lean: Diana.Real.Bisect.converge
    rocq: Diana.Real.Bisect.converge
  - id: BIS-B1
    layer: B
    informal: >
      binary64 model: with |a|,|b| ≤ DBL_MAX/2 and a ≤ b, the midpoint fl(0.5·fl(a+b)) is finite
      and lies in [a, b] (round-to-nearest-even; parameterised by the NaN-payload functions so it
      instantiates to CompCert's Float.add/Float.mul).
    rocq: Diana.Float.Bisect.mid_in_bracket
  - id: BIS-B2
    layer: B
    informal: >
      the float bracket invariant of A1 holds for every step of the binary64 model: one step of
      fstep preserves finiteness, a <= b, |a|,|b| <= DBL_MAX/2 and the strict-sign-change-or-
      collapsed-root condition, and nests the bracket.
    rocq: Diana.Float.Bisect.step_in_bracket
  - id: BIS-B3
    layer: B
    informal: >
      with tol = 0 the iteration stops once the endpoints are adjacent doubles: when succ a = b the
      binary64 midpoint equals an endpoint, which is the kernel's DIANA_OK stop.
    rocq: Diana.Float.Bisect.mid_adjacent
  - id: BIS-B4
    layer: B
    informal: >
      termination: the bracket width is non-increasing, and the number of doubles it spans
      (lattice) strictly decreases on every continuing step, so a run of n consecutive
      DIANA_CONTINUE steps satisfies n <= lattice of the initial state.
    rocq: Diana.Float.Bisect.step_count_bound
  - id: BIS-C1
    layer: C
    informal: "bisect_mid computes the model midpoint: Float.mul 0.5 (Float.add a b) = mid a b (VST, AArch64 macOS Clight AST)"
    rocq: Diana.VST.Bisect.body_bisect_mid
  - id: BIS-C2
    layer: C
    informal: >
      ACSL contracts in src/bisect.c, Frama-C WP float model with RTE: memory safety, no UB,
      separation of outputs from the state, bracket predicate (strict sign change or collapsed
      root) preserved by init/step, iter increments, width is the rounded difference, and the state
      is unchanged when init or step reports an error. The only assumed contract is bisect_mid
      (-wp-skip-fct), discharged by BIS-B1.
    acsl: src/bisect.c
  - id: BIS-C3
    layer: C
    informal: >
      diana_fp_finite implements its IEEE semantics (VST, AArch64 macOS Clight AST):
      it returns 1 exactly when its argument is finite.
    rocq: Diana.VST.Bisect.body_diana_fp_finite
  - id: BIS-C4
    layer: C
    informal: >
      diana_fp_abs returns the conditional negation the C performs (VST, AArch64 macOS Clight AST);
      c_abs_B2R identifies it with Rabs on finite input.
    rocq: Diana.VST.Bisect.body_diana_fp_abs
  - id: BIS-C5
    layer: C
    informal: "diana_bisect_result writes the model midpoint and the rounded width (VST, AArch64 macOS Clight AST)"
    rocq: Diana.VST.Bisect.body_diana_bisect_result
---
# bisect

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
  `b`, so the midpoint lies in `[a, b]`. Proof: `mid_in_bracket` in `verification/rocq/theory/Float/Bisect.v`.
- **B2**: case analysis on the sign test. `fstep` is the binary64 state machine of
  `diana_bisect_step`, carrying `fa` in the state as the C does (the real model recomputes the sign
  from `f a`, which is why layer B needs its own `step`). The kept half inherits a strict sign
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
  termination, not the `max_iter = 2100` default. Three tighter routes were tried and refuted:
  the width does not halve (`max(x-a, b-x) <= (b-a)/2` holds only when `2x = a + b` exactly, so a
  rounded midpoint overshoots), `mag` of the width can stall for one step
  (`0x1.ff8p-1065 -> 0x1p-1065`), and `w' <= w/2 + ulp(x)/2` fails when the endpoints straddle
  zero with very different magnitudes. The attained worst case is **2098** steps (root at
  `DBL_TRUE_MIN` in `[-DBL_MAX/2, DBL_MAX/2]`), pinned by `test_worst_case_step_count` in
  `test/c/test_bisect.c` and by `test/python/test_bisect.py`; an adversary choosing the branch that
  keeps the wider lattice gap also attains exactly 2098. Exhaustive dynamic programming over every
  bracket of twelve scaled-down binary formats (p in 3..5, several exponent ranges) gives the
  closed form `emax - emin + p + 1`, with `emin` the least *normal* exponent. For binary64
  restricted to `|a|, |b| <= DBL_MAX/2` the top exponent is 1022, so this is
  `1022 - (-1022) + 53 + 1 = 2098`. That is evidence, not a theorem: the explicit constant is
  future work.
- **C1**: `bisect_mid` returns `Float.mul 0.5 (Float.add a b)`, identified with the Flocq model
  `mid` by `c_mid_model`; the literal `0.5` emitted by clightgen is shown equal to the model's
  `half` by computation (`c_half_eq`).
- **C2**: the `/*@ ... */` annotations in `src/bisect.c`. The kernel calls no libm function:
  finiteness and absolute value are implemented in `src/fp.h` with IEEE arithmetic
  (`x == x && x - x == 0`, conditional negation) and verified by WP from `\is_finite`.
- **C3/C4**: the `src/fp.h` helpers. `clightgen` does not inline them despite `static inline`, so
  each is a real Clight function with its own funspec. `diana_fp_finite` is `x == x && x - x == 0`:
  `x == x` tests only non-NaN (`+inf == +inf` is true), and `x - x == 0` is what excludes the
  infinities, so the two together characterise finiteness (`cmp_eq_self`, `cmp_sub_self_zero`).
  `diana_fp_abs` is specified as the conditional negation the C performs, not as `Float.abs`,
  because the C returns `-0.0` for `-0.0`; `c_abs_B2R` identifies it with `Rabs` on finite input.
- **C5**: `diana_bisect_result` over `data_at` on the state, with the two output pointers and the
  separation the ACSL `\separated` preconditions require. The kernel is loop-free (no `Sloop` in
  the Clight AST), so the proof is `forward`/`forward_if`/`forward_call` with no loop invariant.
- **`diana_bisect_init` and `diana_bisect_step` are not yet proved under VST.** Frama-C WP covers
  them (BIS-C2: memory safety, no UB, and the bracket invariant), so layer C is not empty for
  them, but no VST theorem yet says their post-state is the layer-B model. `init` has 21 Clight
  temporaries from the short-circuit `||` chains and `step` nine branches; both need a funspec
  shape that keeps `data_at` field reads from unfolding into nested `let` projections, which is
  what blocked the first attempt.

## Model correspondence

- **Layer A** (`verification/lean/Diana/Real/Bisect.lean`, `verification/rocq/theory/Real/Bisect.v`,
  Rocq standard library only): `step` is the functional model of `src/bisect.c` over ℝ with the
  same sign test as the C code, `(fx > 0) == (fa > 0)` moves `a`, otherwise `b`, and an exact zero
  collapses the bracket; `iter` is the bracket after `n` steps. `SignChange` is a strict sign change
  or a bracket collapsed onto an exact root, which is the state the C kernel can be in after
  `diana_bisect_init`; a weak sign change (`f a * f b ≤ 0`) is not invariant under that sign test
  when `f a = 0`. A collapsed bracket has its midpoint at the root, so `step` takes the zero branch.
- **Layer B** (`verification/rocq/theory/Float/Bisect.v`): `mid` is `0.5 * (a + b)` in binary64
  round-to-nearest-even, parameterised by the NaN-payload functions so that it instantiates to
  CompCert's `Float.add`/`Float.mul`. `half` is `2^52 · 2^-53`; `DBL_MAX = 2^1024 − 2^971`, and
  `2^e − 2^(e−53)` is the largest binary64 with exponent `e − 53` (`pow_diff_format`). Doubling
  keeps a binary64 value representable when the caller bounds it separately (`format_double`), and
  rounding a value bounded by a representable number stays bounded by it (`round_abs_le`).
  `state` is the binary64 analogue of `diana_bisect_state` without `iter`/`max_iter` (those are
  integers the float layer says nothing about); `fstep` mirrors `diana_bisect_step` in the C's
  operation order, with `fpos` for the C's `> 0.0` sign test and `fle` for `<=` via `Bcompare`.
  `Bracket` and `Next` are the ACSL predicates `bisect_bracket` and `bisect_next` of `src/bisect.c`
  restated over Flocq values, and `lattice` counts the doubles the bracket spans.
- **Layer C, VST** (`verification/rocq/theory/VST/Bisect.v`, against the Clight AST
  `verification/clight/bisect_aarch64_macos.v`, CompCert target AArch64 macOS): CompCert's `Float.add`/`Float.mul` are Flocq's `Bplus`/`Bmult`
  with CompCert's NaN-payload function, so the model instantiates directly. `c_half` is the literal
  `0.5` as emitted by clightgen, and `c_mid` is the C midpoint `Float.mul c_half (Float.add a b)`.

## Tolerance rationale

`b − a ≤ tol` is an absolute width criterion; the estimate `0.5·(a+b)` is then within `tol/2` of
a root in reals and within `tol/2 + 1 ulp` in binary64.

## Status

| ID | Lean | Rocq | Frama-C |
|---|---|---|---|
| BIS-A1 | proved | proved | – |
| BIS-A2 | proved | proved | – |
| BIS-B1 | – | proved | – |
| BIS-B2 | – | proved | – |
| BIS-B3 | – | proved | – |
| BIS-B4 | – | proved | – |
| BIS-C1 | – | proved | – |
| BIS-C2 | – | – | 162/162 goals (Frama-C 33.0, Alt-Ergo 2.6.4), bisect_mid assumed |
| BIS-C3 | – | proved | – |
| BIS-C4 | – | proved | – |
| BIS-C5 | – | proved | – |

`diana_bisect_init` and `diana_bisect_step` have no VST theorem yet; their layer-C guarantee is
BIS-C2 (Frama-C WP) only.
