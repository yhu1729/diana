module

public import Diana.Real.Cholesky

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.Substitution

open Finset

/-- Row `i` of forward substitution, from the entries `x k`, `k < i`. -/
noncomputable def row (L : ℕ → ℕ → ℝ) (b x : ℕ → ℝ) (i : ℕ) : ℝ :=
  (b i - ∑ k ∈ range i, L i k * x k) / L i i

/-- The solution after rows `0, …, m - 1`; later entries are zero. -/
noncomputable def solve (L : ℕ → ℕ → ℝ) (b : ℕ → ℝ) : ℕ → ℕ → ℝ
  | 0 => fun _ => 0
  | m + 1 => fun i => if i = m then row L b (solve L b m) m else solve L b m i

/-- Forward substitution, the solution of `L·x = b` for a lower-triangular `L`: entry `i` is
computed from the entries before it. Only the entries `L i k` with `k ≤ i` are read. -/
noncomputable def fwd (L : ℕ → ℕ → ℝ) (b : ℕ → ℝ) (i : ℕ) : ℝ :=
  solve L b (i + 1) i

/-- The mirrored matrix `L (n - 1 - q) (n - 1 - p)`: the transpose with both indices reversed,
lower triangular when `L` is. -/
def mirror (L : ℕ → ℕ → ℝ) (n p q : ℕ) : ℝ :=
  L (n - 1 - q) (n - 1 - p)

/-- The vector with its indices reversed. -/
def mirrorv (b : ℕ → ℝ) (n p : ℕ) : ℝ :=
  b (n - 1 - p)

/-- Back substitution, the solution of `Lᵀ·x = b` for a lower-triangular `L`: forward
substitution on the mirrored system, so entry `i` is computed from the entries after it. -/
noncomputable def bwd (L : ℕ → ℕ → ℝ) (b : ℕ → ℝ) (n i : ℕ) : ℝ :=
  fwd (mirror L n) (mirrorv b n) (n - 1 - i)

/-- The comparison matrix: `|L i i|` on the diagonal, `-|L i k|` off it. -/
noncomputable def cmp (L : ℕ → ℕ → ℝ) (i k : ℕ) : ℝ :=
  if k = i then |L i i| else -|L i k|

theorem solve_eq {L : ℕ → ℕ → ℝ} {b : ℕ → ℝ} : ∀ {m i : ℕ}, i < m → solve L b m i = fwd L b i
  | 0, _, h => absurd h (Nat.not_lt_zero _)
  | m + 1, i, h => by
    by_cases hi : i = m
    · subst hi
      rfl
    · have : i < m := by omega
      simp only [solve, hi, ↓reduceIte]
      exact solve_eq this

theorem row_congr {L : ℕ → ℕ → ℝ} {b x x' : ℕ → ℝ} {i : ℕ} (h : ∀ k < i, x k = x' k) :
    row L b x i = row L b x' i := by
  unfold row
  rw [sum_congr rfl fun k hk => by rw [h k (mem_range.mp hk)]]

theorem fwd_eq (L : ℕ → ℕ → ℝ) (b : ℕ → ℝ) (i : ℕ) : fwd L b i = row L b (fwd L b) i := by
  show solve L b (i + 1) i = _
  simp only [solve, ↓reduceIte]
  exact row_congr fun k hk => solve_eq hk

theorem fwd_congr {L L' : ℕ → ℕ → ℝ} {b b' : ℕ → ℝ} {m : ℕ}
    (hL : ∀ p q, q ≤ p → p < m → L p q = L' p q) (hb : ∀ p < m, b p = b' p) :
    ∀ i < m, fwd L b i = fwd L' b' i := by
  intro i
  induction i using Nat.strong_induction_on with
  | _ i ih =>
    intro hi
    rw [fwd_eq, fwd_eq L']
    unfold row
    rw [hb i hi, hL i i le_rfl hi]
    congr 2
    exact sum_congr rfl fun k hk => by
      have hk' := mem_range.mp hk
      rw [hL i k hk'.le hi, ih k hk' (by omega)]

theorem fwd_zero (L : ℕ → ℕ → ℝ) (i : ℕ) : fwd L (fun _ => 0) i = 0 := by
  induction i using Nat.strong_induction_on with
  | _ i ih =>
    rw [fwd_eq]
    unfold row
    rw [sum_eq_zero fun k hk => by rw [ih k (mem_range.mp hk), mul_zero]]
    simp

/-- Layer A, forward substitution solves each row: once `L i i ≠ 0`,
`∑_{k ≤ i} L i k · x k = b i` for `x = fwd L b`. -/
theorem forward_solve {L : ℕ → ℕ → ℝ} {b : ℕ → ℝ} {i : ℕ} (hd : L i i ≠ 0) :
    ∑ k ∈ range (i + 1), L i k * fwd L b k = b i := by
  rw [sum_range_succ, fwd_eq L b i]
  unfold row
  rw [mul_div_cancel₀ _ hd]
  ring

/-- Layer A, forward error from the residual: if `y` leaves residuals bounded by `ρ`, then
`|x i - y i|` is at most the forward substitution of `ρ` with the comparison matrix. -/
theorem forward_perturb {L : ℕ → ℕ → ℝ} {b y ρ : ℕ → ℝ} {n : ℕ} (hd : ∀ i < n, L i i ≠ 0)
    (hr : ∀ i < n, |b i - ∑ k ∈ range (i + 1), L i k * y k| ≤ ρ i) :
    ∀ i < n, |fwd L b i - y i| ≤ fwd (cmp L) ρ i := by
  intro i
  induction i using Nat.strong_induction_on with
  | _ i ih =>
    intro hi
    have hdi := hd i hi
    have hrow : L i i * (fwd L b i - y i) =
        (b i - ∑ k ∈ range (i + 1), L i k * y k) -
          ∑ k ∈ range i, L i k * (fwd L b k - y k) := by
      have hs := forward_solve (b := b) hdi
      rw [sum_range_succ] at hs ⊢
      simp only [mul_sub, sum_sub_distrib] at hs ⊢
      linarith
    have hz : fwd (cmp L) ρ i = (ρ i + ∑ k ∈ range i, |L i k| * fwd (cmp L) ρ k) / |L i i| := by
      rw [fwd_eq]
      unfold row
      have hc : cmp L i i = |L i i| := by simp [cmp]
      rw [hc]
      congr 1
      rw [sub_eq_add_neg, ← sum_neg_distrib]
      congr 1
      exact sum_congr rfl fun k hk => by
        have hk' : k ≠ i := (mem_range.mp hk).ne
        simp [cmp, hk']
    have hbound : |L i i| * |fwd L b i - y i| ≤
        ρ i + ∑ k ∈ range i, |L i k| * fwd (cmp L) ρ k := by
      rw [← abs_mul, hrow]
      calc |(b i - ∑ k ∈ range (i + 1), L i k * y k) - ∑ k ∈ range i, L i k * (fwd L b k - y k)|
          ≤ |b i - ∑ k ∈ range (i + 1), L i k * y k| +
              |∑ k ∈ range i, L i k * (fwd L b k - y k)| := abs_sub _ _
        _ ≤ ρ i + ∑ k ∈ range i, |L i k| * |fwd L b k - y k| := by
          gcongr
          · exact hr i hi
          · exact (abs_sum_le_sum_abs _ _).trans_eq (sum_congr rfl fun k _ => abs_mul _ _)
        _ ≤ ρ i + ∑ k ∈ range i, |L i k| * fwd (cmp L) ρ k := by
          gcongr with k hk
          exact ih k (mem_range.mp hk) (by have := mem_range.mp hk; omega)
    rw [hz, le_div_iff₀ (abs_pos.mpr hdi)]
    linarith [mul_comm |L i i| |fwd L b i - y i|]

/-- Layer A, uniqueness: forward substitution gives the only solution of `L·x = b` on the
indices below `n` when the diagonal has no zero. -/
theorem forward_unique {L : ℕ → ℕ → ℝ} {b y : ℕ → ℝ} {n : ℕ} (hd : ∀ i < n, L i i ≠ 0)
    (hy : ∀ i < n, ∑ k ∈ range (i + 1), L i k * y k = b i) : ∀ i < n, y i = fwd L b i := by
  intro i hi
  have h := forward_perturb (ρ := fun _ => 0) hd (fun i hi => by rw [hy i hi, sub_self, abs_zero])
    i hi
  rw [fwd_zero] at h
  linarith [abs_nonpos_iff.mp h]

theorem sum_mirror (g : ℕ → ℝ) {i n : ℕ} (hi : i < n) :
    ∑ q ∈ range (n - 1 - i + 1), g (n - 1 - q) = ∑ k ∈ Ico i n, g k := by
  rw [sum_Ico_eq_sum_range, show n - 1 - i + 1 = n - i by omega]
  rw [← sum_range_reflect]
  exact sum_congr rfl fun t ht => by
    have := mem_range.mp ht
    congr 1
    omega

/-- Layer A, back substitution solves each row: once `L i i ≠ 0`,
`∑_{i ≤ k < n} L k i · x k = b i` for `x = bwd L b n`, that is `Lᵀ·x = b` in row `i`. -/
theorem back_solve {L : ℕ → ℕ → ℝ} {b : ℕ → ℝ} {n i : ℕ} (hi : i < n) (hd : L i i ≠ 0) :
    ∑ k ∈ Ico i n, L k i * bwd L b n k = b i := by
  have hp : n - 1 - (n - 1 - i) = i := by omega
  have hdm : mirror L n (n - 1 - i) (n - 1 - i) ≠ 0 := by
    unfold mirror
    rw [hp]
    exact hd
  have hb : mirrorv b n (n - 1 - i) = b i := by
    unfold mirrorv
    rw [hp]
  have h := forward_solve (b := mirrorv b n) hdm
  rw [hb] at h
  rw [← h, ← sum_mirror _ hi]
  exact sum_congr rfl fun q hq => by
    have hq' := mem_range.mp hq
    show L (n - 1 - q) i * fwd (mirror L n) (mirrorv b n) (n - 1 - (n - 1 - q)) =
      L (n - 1 - q) (n - 1 - (n - 1 - i)) * fwd (mirror L n) (mirrorv b n) q
    rw [hp, show n - 1 - (n - 1 - q) = q by omega]

theorem mirror_back {L : ℕ → ℕ → ℝ} {y : ℕ → ℝ} {n p : ℕ} (hp : p < n) :
    ∑ q ∈ range (p + 1), mirror L n p q * y (n - 1 - q) =
      ∑ k ∈ Ico (n - 1 - p) n, L k (n - 1 - p) * y k := by
  have hp' : n - 1 - (n - 1 - p) = p := by omega
  rw [← sum_mirror (fun k => L k (n - 1 - p) * y k) (by omega : n - 1 - p < n), hp']
  rfl

theorem cmp_mirror {L : ℕ → ℕ → ℝ} {n : ℕ} :
    ∀ p q, q ≤ p → p < n → cmp (mirror L n) p q = mirror (cmp L) n p q := by
  intro p q _ hp
  unfold cmp mirror
  by_cases h : q = p
  · subst h
    simp
  · have : n - 1 - p ≠ n - 1 - q := by omega
    simp [h, this]

/-- Layer A, back-substitution forward error from the residual, as `forward_perturb`:
`|x i - y i|` is at most the back substitution of `ρ` with the comparison matrix. -/
theorem back_perturb {L : ℕ → ℕ → ℝ} {b y ρ : ℕ → ℝ} {n : ℕ} (hd : ∀ i < n, L i i ≠ 0)
    (hr : ∀ i < n, |b i - ∑ k ∈ Ico i n, L k i * y k| ≤ ρ i) :
    ∀ i < n, |bwd L b n i - y i| ≤ bwd (cmp L) ρ n i := by
  intro i hi
  have hdm : ∀ p < n, mirror L n p p ≠ 0 := fun p hp => hd _ (by omega)
  have hrm : ∀ p < n, |mirrorv b n p - ∑ q ∈ range (p + 1), mirror L n p q * mirrorv y n q| ≤
      mirrorv ρ n p := fun p hp => by
    unfold mirrorv
    rw [mirror_back hp]
    exact hr _ (by omega)
  have h := forward_perturb hdm hrm (n - 1 - i) (by omega)
  have hy : mirrorv y n (n - 1 - i) = y i := by
    unfold mirrorv
    rw [show n - 1 - (n - 1 - i) = i by omega]
  rw [hy] at h
  unfold bwd
  rw [← fwd_congr cmp_mirror (fun p _ => rfl) (n - 1 - i) (by omega)]
  exact h

/-- Layer A, uniqueness of the back-substitution solution of `Lᵀ·x = b`. -/
theorem back_unique {L : ℕ → ℕ → ℝ} {b y : ℕ → ℝ} {n : ℕ} (hd : ∀ i < n, L i i ≠ 0)
    (hy : ∀ i < n, ∑ k ∈ Ico i n, L k i * y k = b i) : ∀ i < n, y i = bwd L b n i := by
  intro i hi
  have h := back_perturb (ρ := fun _ => 0) hd (fun i hi => by rw [hy i hi, sub_self, abs_zero])
    i hi
  have h0 : bwd (cmp L) (fun _ => 0) n i = 0 := fwd_zero _ _
  rw [h0] at h
  linarith [abs_nonpos_iff.mp h]

/-- Layer A, solving with the Cholesky factor: for a symmetric `A` whose pivots are positive,
`x = bwd L (fwd L b) n` with `L = chol A` solves `A·x = b`. -/
theorem cholesky_solve {A : ℕ → ℕ → ℝ} {n : ℕ} (hs : ∀ i < n, ∀ k < n, A i k = A k i)
    (hp : ∀ j < n, 0 < Cholesky.piv A j) (b : ℕ → ℝ) :
    ∀ i < n, ∑ k ∈ range n,
      A i k * bwd (Cholesky.chol A) (fwd (Cholesky.chol A) b) n k = b i := by
  intro i hi
  set L := Cholesky.chol A
  set y := fwd L b
  set x := bwd L y n
  have hu : ∀ i k, i < k → L i k = 0 := fun _ _ h => Cholesky.chol_upper h
  have hd : ∀ j < n, L j j ≠ 0 := fun j hj => by
    simp only [L]
    rw [Cholesky.chol_diag]
    exact (Real.sqrt_pos.mpr (hp j hj)).ne'
  have hA : ∀ i < n, ∀ k < n, A i k = ∑ m ∈ range n, L i m * L k m := by
    intro i hi k hk
    rcases le_total k i with h | h
    · exact (Cholesky.product hp h hi).symm
    · rw [hs i hi k hk, ← Cholesky.product hp h hk]
      exact sum_congr rfl fun m _ => mul_comm _ _
  have hcol : ∀ m < n, ∑ k ∈ range n, L k m * x k = y m := by
    intro m hm
    rw [← sum_range_add_sum_Ico _ hm.le, sum_eq_zero fun k hk => by
      rw [hu k m (mem_range.mp hk), zero_mul], zero_add]
    exact back_solve hm (hd m hm)
  calc ∑ k ∈ range n, A i k * x k
      = ∑ k ∈ range n, ∑ m ∈ range n, L i m * (L k m * x k) := by
        refine sum_congr rfl fun k hk => ?_
        rw [hA i hi k (mem_range.mp hk), sum_mul]
        exact sum_congr rfl fun m _ => by ring
    _ = ∑ m ∈ range n, L i m * ∑ k ∈ range n, L k m * x k := by
        rw [sum_comm]
        exact sum_congr rfl fun m _ => (mul_sum _ _ _).symm
    _ = ∑ m ∈ range n, L i m * y m :=
        sum_congr rfl fun m hm => by rw [hcol m (mem_range.mp hm)]
    _ = ∑ m ∈ range (i + 1), L i m * y m := by
        rw [← sum_range_add_sum_Ico _ (by omega : i + 1 ≤ n), add_eq_left]
        exact sum_eq_zero fun m hm => by
          rw [hu i m (by have := mem_Ico.mp hm; omega), zero_mul]
    _ = b i := forward_solve (hd i hi)

end Diana.Real.Substitution
