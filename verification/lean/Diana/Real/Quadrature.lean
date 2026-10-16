module

public import Mathlib.Analysis.Calculus.MeanValue
public import Mathlib.MeasureTheory.Integral.IntervalIntegral.FundThmCalculus

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.Quadrature

open Set

theorem bound_of_deriv {F F' B B' : ℝ → ℝ} {x y : ℝ}
    (hF : ∀ t ∈ Icc x y, HasDerivAt F (F' t) t)
    (hB : ∀ t, HasDerivAt B (B' t) t)
    (hd : ∀ t ∈ Ico x y, |F' t| ≤ B' t)
    (h0 : |F x| ≤ B x) :
    ∀ t ∈ Icc x y, |F t| ≤ B t := by
  intro t ht
  have := image_norm_le_of_norm_deriv_right_le_deriv_boundary
    (f' := F') (B := B) (B' := B')
    (fun t ht => (hF t ht).continuousAt.continuousWithinAt)
    (fun t ht => (hF t (Ico_subset_Icc_self ht)).hasDerivWithinAt)
    (by simpa only [Real.norm_eq_abs] using h0)
    hB
    (fun t ht => by simpa only [Real.norm_eq_abs] using hd t ht)
    ht
  simpa only [Real.norm_eq_abs] using this

noncomputable def clamp (lo hi t : ℝ) : ℝ := max lo (min t hi)

theorem continuous_clamp (lo hi : ℝ) : Continuous (clamp lo hi) :=
  continuous_const.max (continuous_id.min continuous_const)

theorem clamp_mem {lo hi : ℝ} (h : lo ≤ hi) (t : ℝ) : clamp lo hi t ∈ Icc lo hi :=
  ⟨le_max_left _ _, max_le h (min_le_right _ _)⟩

theorem clamp_eq {lo hi t : ℝ} (ht : t ∈ Icc lo hi) : clamp lo hi t = t := by
  simp only [clamp, min_eq_left ht.2, max_eq_right ht.1]

theorem continuous_extend {f : ℝ → ℝ} {lo hi : ℝ} (h : lo ≤ hi)
    (hf : ContinuousOn f (Icc lo hi)) : Continuous fun t => f (clamp lo hi t) :=
  hf.comp_continuous (continuous_clamp lo hi) (clamp_mem h)

theorem integral_extend {f : ℝ → ℝ} {lo hi x y : ℝ} (hx : lo ≤ x) (hxy : x ≤ y) (hy : y ≤ hi) :
    (∫ t in x..y, f (clamp lo hi t)) = ∫ t in x..y, f t := by
  refine intervalIntegral.integral_congr fun t ht => ?_
  rw [uIcc_of_le hxy] at ht
  simp only [clamp_eq ⟨hx.trans ht.1, ht.2.trans hy⟩]

theorem panel_error {f : ℝ → ℝ} {Q : ℕ → ℝ} {a w c : ℝ} {m : ℕ} (hw : 0 ≤ w)
    (hf : ContinuousOn f (Icc a (a + m * w)))
    (hQ : ∀ k < m, |(∫ t in (a + k * w)..(a + ↑(k + 1) * w), f t) - Q k| ≤ c) :
    |(∫ t in a..a + m * w, f t) - ∑ k ∈ Finset.range m, Q k| ≤ m * c := by
  let x : ℕ → ℝ := fun k => a + k * w
  have hx0 : x 0 = a := by simp [x]
  have hxm : x m = a + m * w := rfl
  have hsub : ∀ k < m, Icc (x k) (x (k + 1)) ⊆ Icc a (a + m * w) := by
    intro k hk t ht
    have hk' : (k : ℝ) + 1 ≤ m := by exact_mod_cast hk
    have h1 : 0 ≤ (k : ℝ) * w := mul_nonneg (Nat.cast_nonneg k) hw
    have h2 : ((k : ℝ) + 1) * w ≤ m * w := mul_le_mul_of_nonneg_right hk' hw
    simp only [x] at ht
    push_cast at ht
    constructor <;> nlinarith [ht.1, ht.2]
  have hint : ∀ k < m, IntervalIntegrable f MeasureTheory.volume (x k) (x (k + 1)) := by
    intro k hk
    apply ContinuousOn.intervalIntegrable
    have hle : x k ≤ x (k + 1) := by simp only [x]; push_cast; nlinarith
    rw [uIcc_of_le hle]
    exact hf.mono (hsub k hk)
  have hsplit := intervalIntegral.sum_integral_adjacent_intervals hint
  rw [hx0, hxm] at hsplit
  calc |(∫ t in a..a + m * w, f t) - ∑ k ∈ Finset.range m, Q k|
      = |∑ k ∈ Finset.range m, ((∫ t in x k..x (k + 1), f t) - Q k)| := by
        rw [Finset.sum_sub_distrib, hsplit]
    _ ≤ ∑ k ∈ Finset.range m, |(∫ t in x k..x (k + 1), f t) - Q k| :=
        Finset.abs_sum_le_sum_abs _ _
    _ ≤ ∑ _k ∈ Finset.range m, c :=
        Finset.sum_le_sum fun k hk => hQ k (Finset.mem_range.mp hk)
    _ = m * c := by rw [Finset.sum_const, Finset.card_range, nsmul_eq_mul]

end Diana.Real.Quadrature
