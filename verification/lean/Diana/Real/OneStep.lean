module

public import Mathlib.Analysis.SpecialFunctions.Exp
public import Mathlib.Analysis.Normed.Module.Basic

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.OneStep

theorem gronwall_pow {a : ℕ → ℝ} {c τ : ℝ} {N : ℕ} (hc : 0 < c) (h0 : a 0 ≤ 0)
    (hs : ∀ k < N, a (k + 1) ≤ (1 + c) * a k + τ) :
    ∀ k ≤ N, a k ≤ τ * ((1 + c) ^ k - 1) / c := by
  have hc0 : c ≠ 0 := hc.ne'
  intro k
  induction k with
  | zero => intro _; simpa using h0
  | succ k ih =>
    intro hk
    have hp : (1 + c) * a k ≤ (1 + c) * (τ * ((1 + c) ^ k - 1) / c) :=
      mul_le_mul_of_nonneg_left (ih (by omega)) (by linarith)
    calc a (k + 1) ≤ (1 + c) * a k + τ := hs k (by omega)
      _ ≤ (1 + c) * (τ * ((1 + c) ^ k - 1) / c) + τ := by linarith
      _ = τ * ((1 + c) ^ (k + 1) - 1) / c := by field_simp; ring

theorem pow_le_exp {c : ℝ} (hc : 0 ≤ c) (k : ℕ) : (1 + c) ^ k ≤ Real.exp (k * c) := by
  rw [Real.exp_nat_mul]
  exact pow_le_pow_left₀ (by linarith) (by linarith [Real.add_one_le_exp c]) k

variable {E : Type*} [NormedAddCommGroup E] [NormedSpace ℝ E]

noncomputable def iterate (Φ : ℝ → E → E) (t₀ h : ℝ) (y₀ : E) : ℕ → E
  | 0 => y₀
  | k + 1 => iterate Φ t₀ h y₀ k + h • Φ (t₀ + k * h) (iterate Φ t₀ h y₀ k)

theorem step_bound {e D T : E} {h L τ : ℝ} (hh : 0 ≤ h) (hD : ‖D‖ ≤ L * ‖e‖) (hT : ‖T‖ ≤ τ) :
    ‖e + h • D - T‖ ≤ (1 + h * L) * ‖e‖ + τ := by
  calc ‖e + h • D - T‖ ≤ ‖e + h • D‖ + ‖T‖ := norm_sub_le _ _
    _ ≤ ‖e‖ + ‖h • D‖ + ‖T‖ := by gcongr; exact norm_add_le _ _
    _ = ‖e‖ + h * ‖D‖ + ‖T‖ := by rw [norm_smul, Real.norm_of_nonneg hh]
    _ ≤ ‖e‖ + h * (L * ‖e‖) + τ := by gcongr
    _ = (1 + h * L) * ‖e‖ + τ := by ring

theorem one_step_error {Φ : ℝ → E → E} {Y : ℝ → E} {t₀ h L τ : ℝ} {N : ℕ}
    (hh : 0 < h) (hL : 0 < L) (hτ : 0 ≤ τ)
    (hlip : ∀ k < N, ∀ y z, ‖Φ (t₀ + k * h) y - Φ (t₀ + k * h) z‖ ≤ L * ‖y - z‖)
    (htr : ∀ k < N,
      ‖Y (t₀ + (k + 1) * h) - Y (t₀ + k * h) - h • Φ (t₀ + k * h) (Y (t₀ + k * h))‖ ≤ τ) :
    ∀ k ≤ N, ‖iterate Φ t₀ h (Y t₀) k - Y (t₀ + k * h)‖ ≤
      τ / (h * L) * (Real.exp (L * (k * h)) - 1) := by
  let a : ℕ → ℝ := fun k => ‖iterate Φ t₀ h (Y t₀) k - Y (t₀ + k * h)‖
  have h0 : a 0 ≤ 0 := by simp [a, iterate]
  have hs : ∀ k < N, a (k + 1) ≤ (1 + h * L) * a k + τ := by
    intro k hk
    have key := step_bound hh.le (hlip k hk (iterate Φ t₀ h (Y t₀) k) (Y (t₀ + k * h)))
      (htr k hk)
    have heq : iterate Φ t₀ h (Y t₀) (k + 1) - Y (t₀ + ((k + 1 : ℕ) : ℝ) * h) =
        (iterate Φ t₀ h (Y t₀) k - Y (t₀ + k * h)) +
          h • (Φ (t₀ + k * h) (iterate Φ t₀ h (Y t₀) k) - Φ (t₀ + k * h) (Y (t₀ + k * h))) -
          (Y (t₀ + (k + 1) * h) - Y (t₀ + k * h) - h • Φ (t₀ + k * h) (Y (t₀ + k * h))) := by
      simp only [iterate]
      push_cast
      rw [smul_sub]
      abel
    simp only [a]
    rw [heq]
    exact key
  intro k hk
  have hc : 0 < h * L := mul_pos hh hL
  have hg := gronwall_pow hc h0 hs k hk
  have hp := pow_le_exp hc.le k
  have hexp : Real.exp (k * (h * L)) = Real.exp (L * (k * h)) := by congr 1; ring
  rw [hexp] at hp
  calc ‖iterate Φ t₀ h (Y t₀) k - Y (t₀ + k * h)‖ = a k := rfl
    _ ≤ τ * ((1 + h * L) ^ k - 1) / (h * L) := hg
    _ = τ / (h * L) * ((1 + h * L) ^ k - 1) := by ring
    _ ≤ τ / (h * L) * (Real.exp (L * (k * h)) - 1) := by
        apply mul_le_mul_of_nonneg_left _ (div_nonneg hτ hc.le)
        linarith

end Diana.Real.OneStep
