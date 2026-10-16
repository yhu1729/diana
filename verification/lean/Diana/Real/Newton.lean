module

public import Mathlib.Analysis.Calculus.Deriv.Pow
public import Diana.Real.Quadrature

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.Newton

open Set Diana.Real.Quadrature

noncomputable def step (f f' : ℝ → ℝ) (x : ℝ) : ℝ := x - f x / f' x

noncomputable def iter (f f' : ℝ → ℝ) (x₀ : ℝ) : ℕ → ℝ
  | 0 => x₀
  | n + 1 => step f f' (iter f f' x₀ n)

theorem taylor_bound {f f' f'' : ℝ → ℝ} {a b x r M : ℝ} (hx : x ∈ Icc a b) (hr : r ∈ Icc a b)
    (hf : ∀ t ∈ Icc a b, HasDerivAt f (f' t) t)
    (hf' : ∀ t ∈ Icc a b, HasDerivAt f' (f'' t) t)
    (hM : ∀ t ∈ Icc a b, |f'' t| ≤ M) :
    |f r - f x - f' x * (r - x)| ≤ M * (r - x) ^ 2 / 2 := by
  set d := r - x with hd
  have hmem : ∀ s ∈ Icc (0 : ℝ) 1, x + s * d ∈ Icc a b := by
    intro s hs
    obtain ⟨hs0, hs1⟩ := hs
    constructor <;> nlinarith [hx.1, hx.2, hr.1, hr.2]
  have hM0 : 0 ≤ M := (abs_nonneg _).trans (hM x hx)
  have hlin : ∀ s : ℝ, HasDerivAt (fun s : ℝ => x + s * d) d s := fun s => by
    simpa using ((hasDerivAt_id s).mul_const d).const_add x
  have hψ : ∀ s ∈ Icc (0 : ℝ) 1,
      HasDerivAt (fun s => f' (x + s * d) - f' x) (f'' (x + s * d) * d) s := fun s hs =>
    ((hf' _ (hmem s hs)).comp s (hlin s)).sub_const (f' x)
  have hψb : ∀ s ∈ Icc (0 : ℝ) 1, |f' (x + s * d) - f' x| ≤ M * |d| * s := by
    intro s hs
    refine bound_of_deriv (F := fun s => f' (x + s * d) - f' x)
      (F' := fun s => f'' (x + s * d) * d) (B := fun s => M * |d| * s) (B' := fun _ => M * |d|)
      hψ (fun t => by simpa using (hasDerivAt_id t).const_mul (M * |d|)) ?_ (by simp) s hs
    intro t ht
    rw [abs_mul]
    exact mul_le_mul_of_nonneg_right (hM _ (hmem t (Ico_subset_Icc_self ht))) (abs_nonneg d)
  have hφ : ∀ s ∈ Icc (0 : ℝ) 1,
      HasDerivAt (fun s => f (x + s * d) - f x - f' x * (s * d)) ((f' (x + s * d) - f' x) * d) s := by
    intro s hs
    have h2 := ((hf _ (hmem s hs)).comp s (hlin s)).sub_const (f x)
    have h3 : HasDerivAt (fun s : ℝ => f' x * (s * d)) (f' x * d) s := by
      simpa using ((hasDerivAt_id s).mul_const d).const_mul (f' x)
    refine (h2.sub h3).congr_deriv ?_
    ring
  have hφb := bound_of_deriv (F := fun s => f (x + s * d) - f x - f' x * (s * d))
    (F' := fun s => (f' (x + s * d) - f' x) * d) (B := fun s => M * d ^ 2 * s ^ 2 / 2)
    (B' := fun s => M * d ^ 2 * s) hφ
    (fun t => by
      have := (((hasDerivAt_id t).fun_pow 2).const_mul (M * d ^ 2)).div_const 2
      refine this.congr_deriv ?_
      simp only [id]
      ring)
    (fun t ht => by
      have h1 := hψb t (Ico_subset_Icc_self ht)
      have h2 : |(f' (x + t * d) - f' x) * d| ≤ M * |d| * t * |d| := by
        rw [abs_mul]
        exact mul_le_mul_of_nonneg_right h1 (abs_nonneg d)
      calc |(f' (x + t * d) - f' x) * d| ≤ M * |d| * t * |d| := h2
        _ = M * d ^ 2 * t := by rw [show M * |d| * t * |d| = M * (|d| * |d|) * t by ring,
                                   abs_mul_abs_self]; ring)
    (by simp) 1 ⟨zero_le_one, le_rfl⟩
  simpa [hd] using hφb

theorem step_error {f f' f'' : ℝ → ℝ} {a b x r M m : ℝ} (hx : x ∈ Icc a b) (hr : r ∈ Icc a b)
    (hf : ∀ t ∈ Icc a b, HasDerivAt f (f' t) t)
    (hf' : ∀ t ∈ Icc a b, HasDerivAt f' (f'' t) t)
    (hM : ∀ t ∈ Icc a b, |f'' t| ≤ M)
    (hm : 0 < m) (hfx : m ≤ |f' x|) (hroot : f r = 0) :
    |step f f' x - r| ≤ M / (2 * m) * (x - r) ^ 2 := by
  have ht := taylor_bound hx hr hf hf' hM
  rw [hroot] at ht
  have hM0 : 0 ≤ M := (abs_nonneg _).trans (hM x hx)
  have hne : f' x ≠ 0 := by
    intro h
    rw [h, abs_zero] at hfx
    linarith
  have hpos : 0 < |f' x| := abs_pos.mpr hne
  have e : step f f' x - r = (0 - f x - f' x * (r - x)) / f' x := by
    unfold step
    field_simp
    ring
  rw [e, abs_div, div_le_iff₀ hpos]
  calc |0 - f x - f' x * (r - x)| ≤ M * (r - x) ^ 2 / 2 := ht
    _ = M / (2 * m) * (x - r) ^ 2 * m := by field_simp; ring
    _ ≤ M / (2 * m) * (x - r) ^ 2 * |f' x| := by
        apply mul_le_mul_of_nonneg_left hfx
        positivity

theorem converge {f f' f'' : ℝ → ℝ} {r δ M m x₀ : ℝ} (hδ : 0 ≤ δ) (hm : 0 < m)
    (hf : ∀ t ∈ Icc (r - δ) (r + δ), HasDerivAt f (f' t) t)
    (hf' : ∀ t ∈ Icc (r - δ) (r + δ), HasDerivAt f' (f'' t) t)
    (hM : ∀ t ∈ Icc (r - δ) (r + δ), |f'' t| ≤ M)
    (hfm : ∀ t ∈ Icc (r - δ) (r + δ), m ≤ |f' t|)
    (hroot : f r = 0) (hq : M / (2 * m) * δ < 1) (hx₀ : |x₀ - r| ≤ δ) :
    ∀ n, |iter f f' x₀ n - r| ≤ δ * (M / (2 * m) * δ) ^ (2 ^ n - 1) := by
  set K := M / (2 * m) with hK
  set q := K * δ with hqdef
  have hM0 : 0 ≤ M := (abs_nonneg _).trans (hM r ⟨by linarith, by linarith⟩)
  have hK0 : 0 ≤ K := by positivity
  have hq0 : 0 ≤ q := by positivity
  have hpow : ∀ k : ℕ, q ^ k ≤ 1 := fun k => pow_le_one₀ hq0 hq.le
  intro n
  induction n with
  | zero => simpa [iter] using hx₀
  | succ n ih =>
    have hle : |iter f f' x₀ n - r| ≤ δ := by
      calc |iter f f' x₀ n - r| ≤ δ * q ^ (2 ^ n - 1) := ih
        _ ≤ δ * 1 := mul_le_mul_of_nonneg_left (hpow _) hδ
        _ = δ := mul_one δ
    have hxmem : iter f f' x₀ n ∈ Icc (r - δ) (r + δ) := by
      obtain ⟨h1, h2⟩ := abs_le.mp hle
      exact ⟨by linarith, by linarith⟩
    have hrmem : r ∈ Icc (r - δ) (r + δ) := ⟨by linarith, by linarith⟩
    have hs := step_error hxmem hrmem hf hf' hM hm (hfm _ hxmem) hroot
    have hk : 2 ^ (n + 1) - 1 = 2 * (2 ^ n - 1) + 1 := by
      have := Nat.one_le_two_pow (n := n)
      rw [pow_succ]
      omega
    calc |iter f f' x₀ (n + 1) - r| = |step f f' (iter f f' x₀ n) - r| := rfl
      _ ≤ K * (iter f f' x₀ n - r) ^ 2 := hs
      _ = K * |iter f f' x₀ n - r| ^ 2 := by rw [sq_abs]
      _ ≤ K * (δ * q ^ (2 ^ n - 1)) ^ 2 := by gcongr
      _ = δ * q ^ (2 ^ (n + 1) - 1) := by
          rw [hk, show q ^ (2 * (2 ^ n - 1) + 1) = (q ^ (2 ^ n - 1)) ^ 2 * q by
            rw [pow_succ, pow_mul']]
          rw [hqdef]
          ring

end Diana.Real.Newton
