import Mathlib.Analysis.Calculus.Deriv.Pow
import Diana.Real.Quadrature

namespace Diana.Real.Trapezoidal

open Set Diana.Real.Quadrature

theorem local_error {f f' f'' : ℝ → ℝ} {x h M₂ : ℝ} (hh : 0 ≤ h)
    (hf : ∀ t ∈ Icc x (x + h), HasDerivAt f (f' t) t)
    (hf' : ∀ t ∈ Icc x (x + h), HasDerivAt f' (f'' t) t)
    (hM : ∀ t ∈ Icc x (x + h), |f'' t| ≤ M₂) :
    |(∫ t in x..x + h, f t) - h * (f x + f (x + h)) / 2| ≤ M₂ * h ^ 3 / 12 := by
  have hxh : x ≤ x + h := by linarith
  have hfc : ContinuousOn f (Icc x (x + h)) := fun t ht =>
    (hf t ht).continuousAt.continuousWithinAt
  let g : ℝ → ℝ := fun t => f (clamp x (x + h) t)
  have hgc : Continuous g := continuous_extend hxh hfc
  let D : ℝ → ℝ := fun t => (f t - f x) / 2 - (t - x) * f' t / 2
  let E : ℝ → ℝ := fun t => (∫ u in x..t, g u) - (t - x) * (f x + f t) / 2
  have hD : ∀ t ∈ Icc x (x + h), HasDerivAt D (-((t - x) * f'' t) / 2) t := by
    intro t ht
    have := (((hf t ht).sub_const (f x)).div_const 2).sub
      ((((hasDerivAt_id t).sub_const x).mul (hf' t ht)).div_const 2)
    refine this.congr_deriv ?_
    simp only [id]
    ring
  have hE : ∀ t ∈ Icc x (x + h), HasDerivAt E (D t) t := by
    intro t ht
    have := (hgc.integral_hasStrictDerivAt x t).hasDerivAt.sub
      ((((hasDerivAt_id t).sub_const x).mul ((hf t ht).const_add (f x))).div_const 2)
    refine this.congr_deriv ?_
    simp only [D, g, id, clamp_eq ht]
    ring
  have hDb : ∀ t ∈ Icc x (x + h), |D t| ≤ M₂ * (t - x) ^ 2 / 4 :=
    bound_of_deriv (F' := fun t => -((t - x) * f'' t) / 2)
      (B := fun t => M₂ * (t - x) ^ 2 / 4) (B' := fun t => M₂ * (t - x) / 2) hD
      (fun t => by
        have := ((((hasDerivAt_id t).sub_const x).fun_pow 2).const_mul M₂).div_const 4
        refine this.congr_deriv ?_
        simp only [id]
        ring)
      (fun t ht => by
        have hx : 0 ≤ t - x := sub_nonneg.mpr ht.1
        have := mul_le_mul_of_nonneg_left (hM t (Ico_subset_Icc_self ht)) hx
        rw [abs_div, abs_neg, abs_mul, abs_of_nonneg hx, abs_two]
        linarith)
      (by simp [D])
  have hEb := bound_of_deriv (F' := D) (B := fun t => M₂ * (t - x) ^ 3 / 12)
    (B' := fun t => M₂ * (t - x) ^ 2 / 4) hE
    (fun t => by
      have := ((((hasDerivAt_id t).sub_const x).fun_pow 3).const_mul M₂).div_const 12
      refine this.congr_deriv ?_
      simp only [id]
      ring)
    (fun t ht => hDb t (Ico_subset_Icc_self ht))
    (by simp [E])
    (x + h) (right_mem_Icc.mpr hxh)
  have hint : (∫ u in x..x + h, g u) = ∫ u in x..x + h, f u :=
    integral_extend le_rfl hxh le_rfl
  simpa only [E, hint, add_sub_cancel_left] using hEb

theorem sum_pair (u : ℕ → ℝ) (n : ℕ) :
    ∑ k ∈ Finset.range (n + 1), (u k + u (k + 1)) / 2 =
      (u 0 + u (n + 1)) / 2 + ∑ i ∈ Finset.Ico 1 (n + 1), u i := by
  induction n with
  | zero => simp
  | succ n ih =>
    rw [Finset.sum_range_succ, ih, Finset.sum_Ico_succ_top (by omega : 1 ≤ n + 1)]
    ring

theorem composite_error {f f' f'' : ℝ → ℝ} {a b h M₂ : ℝ} {m : ℕ} (hab : a ≤ b) (hm : 1 ≤ m)
    (hh : h = (b - a) / m)
    (hf : ∀ t ∈ Icc a b, HasDerivAt f (f' t) t)
    (hf' : ∀ t ∈ Icc a b, HasDerivAt f' (f'' t) t)
    (hM : ∀ t ∈ Icc a b, |f'' t| ≤ M₂) :
    |(∫ t in a..b, f t) - h * ((f a + f b) / 2 + ∑ i ∈ Finset.Ico 1 m, f (a + i * h))| ≤
      (b - a) * h ^ 2 * M₂ / 12 := by
  have hm0 : (0 : ℝ) < m := by exact_mod_cast hm
  have hmh : (m : ℝ) * h = b - a := by rw [hh]; field_simp
  have hh0 : 0 ≤ h := by rw [hh]; exact div_nonneg (sub_nonneg.mpr hab) hm0.le
  have hb : a + m * h = b := by linarith
  let x : ℕ → ℝ := fun k => a + k * h
  have hx0 : x 0 = a := by simp [x]
  have hxm : x m = b := hb
  have hxs : ∀ k, x (k + 1) = x k + h := fun k => by simp only [x]; push_cast; ring
  have hsub : ∀ k < m, Icc (x k) (x k + h) ⊆ Icc a b := by
    intro k hk t ht
    have hk' : (k : ℝ) + 1 ≤ m := by exact_mod_cast hk
    have h1 : 0 ≤ (k : ℝ) * h := mul_nonneg (Nat.cast_nonneg k) hh0
    have h2 : ((k : ℝ) + 1) * h ≤ m * h := mul_le_mul_of_nonneg_right hk' hh0
    simp only [x] at ht
    constructor <;> nlinarith [ht.1, ht.2]
  have hfc : ContinuousOn f (Icc a b) := fun t ht => (hf t ht).continuousAt.continuousWithinAt
  have hT : h * ((f a + f b) / 2 + ∑ i ∈ Finset.Ico 1 m, f (a + i * h)) =
      ∑ k ∈ Finset.range m, h * (f (x k) + f (x (k + 1))) / 2 := by
    obtain ⟨n, rfl⟩ : ∃ n, m = n + 1 := ⟨m - 1, by omega⟩
    have := sum_pair (fun i => f (x i)) n
    simp only [mul_div_assoc, ← Finset.mul_sum, this, hx0, hxm]
    rfl
  have hloc : ∀ k < m,
      |(∫ t in x k..x (k + 1), f t) - h * (f (x k) + f (x (k + 1))) / 2| ≤ M₂ * h ^ 3 / 12 := by
    intro k hk
    rw [hxs]
    exact local_error hh0 (fun t ht => hf t (hsub k hk ht)) (fun t ht => hf' t (hsub k hk ht))
      (fun t ht => hM t (hsub k hk ht))
  have hp := panel_error (Q := fun k => h * (f (x k) + f (x (k + 1))) / 2) hh0
    (by rw [hb]; exact hfc) hloc
  rw [hb] at hp
  rw [hT]
  calc _ ≤ m * (M₂ * h ^ 3 / 12) := hp
    _ = (b - a) * h ^ 2 * M₂ / 12 := by rw [← hmh]; ring

end Diana.Real.Trapezoidal
