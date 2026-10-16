import Mathlib.Analysis.Calculus.Deriv.Pow
import Mathlib.Analysis.Calculus.MeanValue
import Diana.Real.OneStep

namespace Diana.Real.Euler

open Set Diana.Real.OneStep

variable {E : Type*} [NormedAddCommGroup E] [NormedSpace ℝ E]

theorem local_error {F : ℝ → E → E} {Y Y₂ : ℝ → E} {t h M₂ : ℝ} (hh : 0 ≤ h)
    (hY : ∀ s ∈ Icc t (t + h), HasDerivAt Y (F s (Y s)) s)
    (hF : ∀ s ∈ Icc t (t + h), HasDerivAt (fun r => F r (Y r)) (Y₂ s) s)
    (hM : ∀ s ∈ Icc t (t + h), ‖Y₂ s‖ ≤ M₂) :
    ‖Y (t + h) - Y t - h • F t (Y t)‖ ≤ M₂ * h ^ 2 / 2 := by
  have hth : t ≤ t + h := by linarith
  have hDd : ∀ r ∈ Icc t (t + h),
      HasDerivAt (fun r => F r (Y r) - F t (Y t)) (Y₂ r) r := fun r hr =>
    (hF r hr).sub_const _
  have hD : ∀ s ∈ Icc t (t + h), ‖F s (Y s) - F t (Y t)‖ ≤ M₂ * (s - t) := by
    intro s hs
    exact image_norm_le_of_norm_deriv_right_le_deriv_boundary
      (f := fun r => F r (Y r) - F t (Y t)) (f' := Y₂) (B := fun r => M₂ * (r - t))
      (B' := fun _ => M₂)
      (fun r hr => (hDd r hr).continuousAt.continuousWithinAt)
      (fun r hr => (hDd r (Ico_subset_Icc_self hr)).hasDerivWithinAt)
      (by simp)
      (fun r => by
        have := ((hasDerivAt_id r).sub_const t).const_mul M₂
        refine this.congr_deriv ?_
        ring)
      (fun r hr => hM r (Ico_subset_Icc_self hr))
      hs
  have hGd : ∀ r ∈ Icc t (t + h),
      HasDerivAt (fun r => Y r - Y t - (r - t) • F t (Y t)) (F r (Y r) - F t (Y t)) r := by
    intro r hr
    have := ((hY r hr).sub_const (Y t)).sub
      (((hasDerivAt_id r).sub_const t).smul_const (F t (Y t)))
    refine this.congr_deriv ?_
    simp
  have hG := image_norm_le_of_norm_deriv_right_le_deriv_boundary
    (f := fun r => Y r - Y t - (r - t) • F t (Y t)) (f' := fun r => F r (Y r) - F t (Y t))
    (B := fun r => M₂ * (r - t) ^ 2 / 2) (B' := fun r => M₂ * (r - t))
    (fun r hr => (hGd r hr).continuousAt.continuousWithinAt)
    (fun r hr => (hGd r (Ico_subset_Icc_self hr)).hasDerivWithinAt)
    (by simp)
    (fun r => by
      have := ((((hasDerivAt_id r).sub_const t).fun_pow 2).const_mul M₂).div_const 2
      refine this.congr_deriv ?_
      simp only [id]
      ring)
    (fun r hr => hD r (Ico_subset_Icc_self hr))
    (right_mem_Icc.mpr hth)
  simpa only [add_sub_cancel_left] using hG

theorem global_error {F : ℝ → E → E} {Y Y₂ : ℝ → E} {t₀ h L M₂ : ℝ} {N : ℕ}
    (hh : 0 < h) (hL : 0 < L)
    (hY : ∀ s ∈ Icc t₀ (t₀ + N * h), HasDerivAt Y (F s (Y s)) s)
    (hF : ∀ s ∈ Icc t₀ (t₀ + N * h), HasDerivAt (fun r => F r (Y r)) (Y₂ s) s)
    (hM : ∀ s ∈ Icc t₀ (t₀ + N * h), ‖Y₂ s‖ ≤ M₂)
    (hlip : ∀ s ∈ Icc t₀ (t₀ + N * h), ∀ y z, ‖F s y - F s z‖ ≤ L * ‖y - z‖) :
    ∀ k ≤ N, ‖iterate F t₀ h (Y t₀) k - Y (t₀ + k * h)‖ ≤
      M₂ * h / (2 * L) * (Real.exp (L * (k * h)) - 1) := by
  have hNh : 0 ≤ (N : ℝ) * h := mul_nonneg (Nat.cast_nonneg N) hh.le
  have hM0 : 0 ≤ M₂ := (norm_nonneg _).trans (hM t₀ ⟨le_rfl, by linarith⟩)
  have hgrid : ∀ k < N, Icc (t₀ + k * h) (t₀ + k * h + h) ⊆ Icc t₀ (t₀ + N * h) := by
    intro k hk s hs
    have hk' : (k : ℝ) + 1 ≤ N := by exact_mod_cast hk
    have h1 : 0 ≤ (k : ℝ) * h := mul_nonneg (Nat.cast_nonneg k) hh.le
    have h2 : ((k : ℝ) + 1) * h ≤ N * h := mul_le_mul_of_nonneg_right hk' hh.le
    constructor <;> nlinarith [hs.1, hs.2]
  have htr : ∀ k < N, ‖Y (t₀ + (k + 1) * h) - Y (t₀ + k * h) -
      h • F (t₀ + k * h) (Y (t₀ + k * h))‖ ≤ M₂ * h ^ 2 / 2 := by
    intro k hk
    have e : t₀ + ((k : ℝ) + 1) * h = t₀ + k * h + h := by ring
    rw [e]
    exact local_error hh.le (fun s hs => hY s (hgrid k hk hs))
      (fun s hs => hF s (hgrid k hk hs)) (fun s hs => hM s (hgrid k hk hs))
  have hlip' : ∀ k < N, ∀ y z, ‖F (t₀ + k * h) y - F (t₀ + k * h) z‖ ≤ L * ‖y - z‖ :=
    fun k hk => hlip _ (hgrid k hk ⟨le_rfl, by linarith⟩)
  intro k hk
  have hτ : 0 ≤ M₂ * h ^ 2 / 2 := div_nonneg (mul_nonneg hM0 (sq_nonneg h)) zero_le_two
  have := one_step_error hh hL hτ hlip' htr k hk
  have hh0 := hh.ne'
  have hL0 := hL.ne'
  calc _ ≤ M₂ * h ^ 2 / 2 / (h * L) * (Real.exp (L * (k * h)) - 1) := this
    _ = M₂ * h / (2 * L) * (Real.exp (L * (k * h)) - 1) := by field_simp

end Diana.Real.Euler
