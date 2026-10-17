module

public import Mathlib.Analysis.Real.Sqrt
public import Mathlib.Algebra.BigOperators.Group.Finset.Basic

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.Cholesky

open Finset

/-- The pivot of column `j`, from the entries `L j k`, `k < j`. -/
noncomputable def pivot (A L : ℕ → ℕ → ℝ) (j : ℕ) : ℝ :=
  A j j - ∑ k ∈ range j, L j k ^ 2

/-- Entry `i` of column `j`, from the columns `k < j` of `L`. -/
noncomputable def column (A L : ℕ → ℕ → ℝ) (j i : ℕ) : ℝ :=
  if i < j then 0
  else if i = j then √(pivot A L j)
  else (A i j - ∑ k ∈ range j, L i k * L j k) / √(pivot A L j)

/-- The factor after columns `0, …, m - 1`; later columns are zero. -/
noncomputable def factor (A : ℕ → ℕ → ℝ) : ℕ → ℕ → ℕ → ℝ
  | 0 => fun _ _ => 0
  | m + 1 => fun i k => if k = m then column A (factor A m) m i else factor A m i k

/-- The Cholesky factor of `A`: column `k` computed from columns `0, …, k - 1`. Only the
entries `A i j` with `j ≤ i` are read. -/
noncomputable def chol (A : ℕ → ℕ → ℝ) (i k : ℕ) : ℝ :=
  factor A (k + 1) i k

/-- The pivot of column `j` of the factorization. -/
noncomputable def piv (A : ℕ → ℕ → ℝ) (j : ℕ) : ℝ :=
  pivot A (chol A) j

theorem factor_eq {A : ℕ → ℕ → ℝ} : ∀ {m i k : ℕ}, k < m → factor A m i k = chol A i k
  | 0, _, _, h => absurd h (Nat.not_lt_zero _)
  | m + 1, i, k, h => by
    by_cases hk : k = m
    · subst hk
      rfl
    · have : k < m := by omega
      simp only [factor, hk, ↓reduceIte]
      exact factor_eq this

theorem column_congr {A L L' : ℕ → ℕ → ℝ} {j : ℕ} (h : ∀ i k, k < j → L i k = L' i k) (i : ℕ) :
    column A L j i = column A L' j i := by
  have hp : pivot A L j = pivot A L' j := by
    unfold pivot
    congr 1
    exact sum_congr rfl fun k hk => by rw [h j k (mem_range.mp hk)]
  have hs : ∑ k ∈ range j, L i k * L j k = ∑ k ∈ range j, L' i k * L' j k :=
    sum_congr rfl fun k hk => by rw [h i k (mem_range.mp hk), h j k (mem_range.mp hk)]
  unfold column
  rw [hp, hs]

theorem chol_eq (A : ℕ → ℕ → ℝ) (i j : ℕ) : chol A i j = column A (chol A) j i := by
  show factor A (j + 1) i j = _
  simp only [factor, ↓reduceIte]
  exact column_congr (fun i k hk => factor_eq hk) i

theorem chol_upper {A : ℕ → ℕ → ℝ} {i j : ℕ} (h : i < j) : chol A i j = 0 := by
  rw [chol_eq]
  simp [column, h]

theorem chol_diag (A : ℕ → ℕ → ℝ) (j : ℕ) : chol A j j = √(piv A j) := by
  rw [chol_eq]
  simp [column, piv]

theorem chol_lower {A : ℕ → ℕ → ℝ} {i j : ℕ} (h : j < i) :
    chol A i j = (A i j - ∑ k ∈ range j, chol A i k * chol A j k) / √(piv A j) := by
  rw [chol_eq]
  simp [column, piv, not_lt.mpr h.le, h.ne']

theorem sum_trunc (f : ℕ → ℝ) {m n : ℕ} (hmn : m ≤ n) (hf : ∀ k, m ≤ k → k < n → f k = 0) :
    ∑ k ∈ range n, f k = ∑ k ∈ range m, f k := by
  induction n with
  | zero => rw [Nat.le_zero.mp hmn]
  | succ n ih =>
    rcases Nat.lt_or_ge n m with h | h
    · rw [show m = n + 1 by omega]
    · rw [sum_range_succ, ih h (fun k hk hkn => hf k hk (by omega)), hf n h (by omega), add_zero]

/-- Entry `(i, j)`, `j ≤ i`, of `L·Lᵀ` is `A i j` once the pivot of column `j` is positive. -/
theorem entry {A : ℕ → ℕ → ℝ} {i j : ℕ} (hji : j ≤ i) (hp : 0 < piv A j) :
    ∑ k ∈ range (j + 1), chol A i k * chol A j k = A i j := by
  have hs : 0 < √(piv A j) := Real.sqrt_pos.mpr hp
  rw [sum_range_succ, chol_diag]
  rcases hji.lt_or_eq with h | h
  · rw [chol_lower h]
    field_simp
    ring
  · subst h
    rw [chol_diag, Real.mul_self_sqrt hp.le]
    simp only [piv, pivot, sq]
    ring

/-- Layer A, correctness: when every pivot is positive, `L·Lᵀ = A` on the lower triangle. -/
theorem product {A : ℕ → ℕ → ℝ} {n : ℕ} (hp : ∀ j < n, 0 < piv A j) {i j : ℕ} (hji : j ≤ i)
    (hi : i < n) : ∑ k ∈ range n, chol A i k * chol A j k = A i j := by
  rw [sum_trunc _ (by omega : j + 1 ≤ n)
    (fun k hk _ => by rw [chol_upper (by omega : j < k), mul_zero])]
  exact entry hji (hp j (by omega))

theorem sum_update (f x : ℕ → ℝ) (m : ℕ) (c : ℝ) {N : ℕ} (hm : m < N) :
    ∑ i ∈ range N, f i * (if i = m then x i - c else x i) =
      ∑ i ∈ range N, f i * x i - c * f m := by
  have : ∀ i ∈ range N, f i * (if i = m then x i - c else x i) =
      f i * x i - (if i = m then c * f i else 0) := fun i _ => by
    split_ifs with h
    · ring
    · ring
  rw [sum_congr rfl this, sum_sub_distrib, sum_ite_eq' (range N) m]
  simp [mem_range.mpr hm]

/-- Back substitution: a vector with `x j = 1`, zero after `j`, and `Lᵀx = 0` in rows `m < j`. -/
theorem back {L : ℕ → ℕ → ℝ} {j : ℕ} (hu : ∀ i k, i < k → L i k = 0)
    (hd : ∀ m < j, L m m ≠ 0) :
    ∀ s ≤ j, ∃ x : ℕ → ℝ, x j = 1 ∧ (∀ i, j < i → x i = 0) ∧
      ∀ m, j - s ≤ m → m < j → ∑ i ∈ range (j + 1), L i m * x i = 0 := by
  intro s
  induction s with
  | zero =>
    intro _
    exact ⟨fun i => if i = j then 1 else 0, by simp, fun i hi => by simp [hi.ne'],
      fun m hm hmj => by omega⟩
  | succ s ih =>
    intro hs
    obtain ⟨x, hx1, hx0, hxe⟩ := ih (by omega)
    set m₀ := j - (s + 1) with hm₀
    have hm₀j : m₀ < j := by omega
    set c := (∑ i ∈ range (j + 1), L i m₀ * x i) / L m₀ m₀
    refine ⟨fun i => if i = m₀ then x i - c else x i, ?_, ?_, ?_⟩
    · simp only [hm₀j.ne', ↓reduceIte]
      exact hx1
    · intro i hi
      simp only [show i ≠ m₀ by omega, ↓reduceIte]
      exact hx0 i hi
    · intro m hm hmj
      rw [sum_update _ _ _ _ (by omega : m₀ < j + 1)]
      rcases Nat.lt_or_ge m₀ m with h | h
      · rw [hxe m (by omega) hmj, hu m₀ m h, mul_zero, sub_zero]
      · have hmm : m = m₀ := by omega
        rw [hmm]
        simp only [c]
        rw [div_mul_cancel₀ _ (hd m₀ hm₀j), sub_self]

/-- The quadratic form of a vector supported on `0, …, j` once the pivots before `j` are
positive: the squares of `Lᵀx` in rows `m < j` plus the pivot of column `j`. -/
theorem quad {A : ℕ → ℕ → ℝ} {n j : ℕ} (hjn : j < n) (hs : ∀ i < n, ∀ k < n, A i k = A k i)
    (hp : ∀ k < j, 0 < piv A k) {x : ℕ → ℝ} (hx : ∀ i, j < i → x i = 0) :
    ∑ i ∈ range n, ∑ k ∈ range n, x i * A i k * x k =
      ∑ m ∈ range j, (∑ i ∈ range (j + 1), chol A i m * x i) ^ 2 + piv A j * x j ^ 2 := by
  set G : ℕ → ℕ → ℝ := fun i k => ∑ m ∈ range j, chol A i m * chol A k m
  have hG : ∀ i ≤ j, ∀ k ≤ j, ¬(i = j ∧ k = j) → A i k = G i k := by
    have low : ∀ i ≤ j, ∀ k ≤ i, k < j → A i k = G i k := by
      intro i hi k hki hkj
      rw [← entry hki (hp k hkj)]
      exact (sum_trunc _ (by omega)
        (fun m hm _ => by rw [chol_upper (by omega : k < m), mul_zero])).symm
    intro i hi k hk hne
    rcases le_total k i with h | h
    · exact low i hi k h (by omega)
    · rw [hs i (by omega) k (by omega), low k hk i h (by omega)]
      exact sum_congr rfl fun m _ => mul_comm _ _
  have hjj : A j j = G j j + piv A j := by
    simp only [G, piv, pivot, sq]
    ring
  have lhs : ∑ i ∈ range n, ∑ k ∈ range n, x i * A i k * x k =
      ∑ i ∈ range (j + 1), ∑ k ∈ range (j + 1), x i * A i k * x k := by
    rw [sum_trunc (m := j + 1) _ (by omega) (fun i hi _ => sum_eq_zero fun k _ => by
      rw [hx i (by omega)]; ring)]
    exact sum_congr rfl fun i _ =>
      sum_trunc (m := j + 1) _ (by omega) (fun k hk _ => by rw [hx k (by omega)]; ring)
  have rhs : ∑ m ∈ range j, (∑ i ∈ range (j + 1), chol A i m * x i) ^ 2 =
      ∑ i ∈ range (j + 1), ∑ k ∈ range (j + 1), x i * G i k * x k := by
    calc ∑ m ∈ range j, (∑ i ∈ range (j + 1), chol A i m * x i) ^ 2
        = ∑ m ∈ range j, ∑ i ∈ range (j + 1), ∑ k ∈ range (j + 1),
            x i * chol A i m * chol A k m * x k := by
          refine sum_congr rfl fun m _ => ?_
          rw [sq, sum_mul_sum]
          exact sum_congr rfl fun i _ => sum_congr rfl fun k _ => by ring
      _ = ∑ i ∈ range (j + 1), ∑ m ∈ range j, ∑ k ∈ range (j + 1),
            x i * chol A i m * chol A k m * x k := sum_comm
      _ = ∑ i ∈ range (j + 1), ∑ k ∈ range (j + 1), ∑ m ∈ range j,
            x i * chol A i m * chol A k m * x k := sum_congr rfl fun i _ => sum_comm
      _ = ∑ i ∈ range (j + 1), ∑ k ∈ range (j + 1), x i * G i k * x k := by
          refine sum_congr rfl fun i _ => sum_congr rfl fun k _ => ?_
          simp only [G, mul_sum, sum_mul]
          exact sum_congr rfl fun m _ => by ring
  have diff : ∑ i ∈ range (j + 1), ∑ k ∈ range (j + 1), x i * A i k * x k -
      ∑ i ∈ range (j + 1), ∑ k ∈ range (j + 1), x i * G i k * x k = piv A j * x j ^ 2 := by
    rw [← sum_sub_distrib]
    have inner : ∀ i ∈ range (j + 1), ∑ k ∈ range (j + 1), x i * A i k * x k -
        ∑ k ∈ range (j + 1), x i * G i k * x k =
        if i = j then piv A j * x j ^ 2 else 0 := by
      intro i hi
      rw [← sum_sub_distrib]
      have hi' := Nat.lt_succ_iff.mp (mem_range.mp hi)
      split_ifs with hij
      · subst hij
        rw [sum_eq_single i]
        · rw [hjj]; ring
        · intro k hk hki
          rw [hG i hi' k (Nat.lt_succ_iff.mp (mem_range.mp hk)) (fun h => hki h.2)]; ring
        · intro h; exact absurd (mem_range.mpr (Nat.lt_succ_self i)) h
      · exact sum_eq_zero fun k hk => by
          rw [hG i hi' k (Nat.lt_succ_iff.mp (mem_range.mp hk)) (fun h => hij h.1)]; ring
    rw [sum_congr rfl inner, sum_ite_eq' (range (j + 1)) j]
    simp
  rw [lhs, rhs]
  linarith

/-- Layer A, existence: every pivot of a symmetric positive definite matrix is positive, so the
factorization succeeds in exact arithmetic. -/
theorem pivot_pos {A : ℕ → ℕ → ℝ} {n : ℕ} (hs : ∀ i < n, ∀ k < n, A i k = A k i)
    (hpd : ∀ x : ℕ → ℝ, (∃ i < n, x i ≠ 0) →
      0 < ∑ i ∈ range n, ∑ k ∈ range n, x i * A i k * x k) :
    ∀ j < n, 0 < piv A j := by
  intro j
  induction j using Nat.strong_induction_on with
  | _ j ih =>
    intro hjn
    have hp : ∀ k < j, 0 < piv A k := fun k hk => ih k hk (by omega)
    obtain ⟨x, hx1, hx0, hxe⟩ := back (L := chol A) (j := j)
      (fun i k h => chol_upper h)
      (fun m hm => by rw [chol_diag]; exact (Real.sqrt_pos.mpr (hp m hm)).ne') j le_rfl
    have hq := quad hjn hs hp hx0
    have hz : ∑ m ∈ range j, (∑ i ∈ range (j + 1), chol A i m * x i) ^ 2 = 0 :=
      sum_eq_zero fun m hm => by rw [hxe m (by omega) (mem_range.mp hm)]; ring
    have := hpd x ⟨j, hjn, by rw [hx1]; norm_num⟩
    rw [hq, hz, hx1] at this
    linarith

/-- Layer A, converse: a symmetric matrix whose pivots are all positive is positive definite,
so the factorization succeeds in exact arithmetic exactly on symmetric positive definite
matrices. -/
theorem pos_def {A : ℕ → ℕ → ℝ} {n : ℕ} (hs : ∀ i < n, ∀ k < n, A i k = A k i)
    (hp : ∀ j < n, 0 < piv A j) (x : ℕ → ℝ) (hx : ∃ i < n, x i ≠ 0) :
    0 < ∑ i ∈ range n, ∑ k ∈ range n, x i * A i k * x k := by
  have hA : ∀ i < n, ∀ k < n, A i k = ∑ m ∈ range n, chol A i m * chol A k m := by
    intro i hi k hk
    rcases le_total k i with h | h
    · exact (product hp h hi).symm
    · rw [hs i hi k hk, ← product hp h hk]
      exact sum_congr rfl fun m _ => mul_comm _ _
  have hq : ∑ i ∈ range n, ∑ k ∈ range n, x i * A i k * x k =
      ∑ m ∈ range n, (∑ i ∈ range n, chol A i m * x i) ^ 2 := by
    have : ∀ i ∈ range n, ∑ k ∈ range n, x i * A i k * x k =
        ∑ k ∈ range n, ∑ m ∈ range n, x i * chol A i m * chol A k m * x k :=
      fun i hi => sum_congr rfl fun k hk => by
        rw [hA i (mem_range.mp hi) k (mem_range.mp hk), mul_sum, sum_mul]
        exact sum_congr rfl fun m _ => by ring
    rw [sum_congr rfl this]
    symm
    calc ∑ m ∈ range n, (∑ i ∈ range n, chol A i m * x i) ^ 2
        = ∑ m ∈ range n, ∑ i ∈ range n, ∑ k ∈ range n,
            x i * chol A i m * chol A k m * x k := by
          refine sum_congr rfl fun m _ => ?_
          rw [sq, sum_mul_sum]
          exact sum_congr rfl fun i _ => sum_congr rfl fun k _ => by ring
      _ = ∑ i ∈ range n, ∑ m ∈ range n, ∑ k ∈ range n,
            x i * chol A i m * chol A k m * x k := sum_comm
      _ = ∑ i ∈ range n, ∑ k ∈ range n, ∑ m ∈ range n,
            x i * chol A i m * chol A k m * x k := sum_congr rfl fun i _ => sum_comm
  set S := (range n).filter (fun i => x i ≠ 0)
  have hS : S.Nonempty := by
    obtain ⟨i, hi, hxi⟩ := hx
    exact ⟨i, mem_filter.mpr ⟨mem_range.mpr hi, hxi⟩⟩
  set t := S.max' hS
  have ht : t ∈ S := S.max'_mem hS
  have htn : t < n := mem_range.mp (mem_filter.mp ht).1
  have hxt : x t ≠ 0 := (mem_filter.mp ht).2
  have hbig : ∀ i, t < i → i < n → x i = 0 := fun i hti hin => by
    by_contra hne
    have := S.le_max' i (mem_filter.mpr ⟨mem_range.mpr hin, hne⟩)
    omega
  have hv : ∑ i ∈ range n, chol A i t * x i = chol A t t * x t := by
    rw [sum_eq_single t]
    · intro i hi hit
      rcases Nat.lt_or_gt_of_ne hit with h | h
      · rw [chol_upper h, zero_mul]
      · rw [hbig i h (mem_range.mp hi), mul_zero]
    · intro h; exact absurd (mem_range.mpr htn) h
  have hdiag : chol A t t ≠ 0 := by
    rw [chol_diag]; exact (Real.sqrt_pos.mpr (hp t htn)).ne'
  rw [hq]
  refine lt_of_lt_of_le ?_ (single_le_sum (f := fun m => (∑ i ∈ range n, chol A i m * x i) ^ 2)
    (fun m _ => sq_nonneg _) (mem_range.mpr htn))
  simp only [hv]
  exact pow_pos (abs_pos.mpr (mul_ne_zero hdiag hxt)) 2 |>.trans_eq (by rw [sq_abs])

end Diana.Real.Cholesky
