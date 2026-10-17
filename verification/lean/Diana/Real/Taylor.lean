module

public import Mathlib.Analysis.Calculus.MeanValue
public import Mathlib.Analysis.Calculus.Deriv.Pow

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.Taylor

open Set Finset

variable {E : Type*} [NormedAddCommGroup E] [NormedSpace ℝ E]

noncomputable def poly (c : ℕ → E) (a x : ℝ) (n : ℕ) : E :=
  ∑ j ∈ range n, ((x - a) ^ j / (j.factorial : ℝ)) • c j

theorem poly_self (c : ℕ → E) (a : ℝ) (n : ℕ) : poly c a a (n + 1) = c 0 := by
  simp [poly, sum_range_succ']

theorem hasDerivAt_poly (c : ℕ → E) (a x : ℝ) (n : ℕ) :
    HasDerivAt (fun x => poly c a x (n + 1)) (poly (fun j => c (j + 1)) a x n) x := by
  induction n with
  | zero => simpa [poly] using hasDerivAt_const x (c 0)
  | succ n ih =>
    have h1 : HasDerivAt (fun x => ((x - a) ^ (n + 1) / ((n + 1).factorial : ℝ)) • c (n + 1))
        (((x - a) ^ n / (n.factorial : ℝ)) • c (n + 1)) x := by
      have h := ((((hasDerivAt_id' x).sub_const a).fun_pow (n + 1)).div_const
        ((n + 1).factorial : ℝ)).smul_const (c (n + 1))
      convert h using 2
      show (x - a) ^ n / (n.factorial : ℝ) =
        ((n + 1 : ℕ) : ℝ) * (x - a) ^ (n + 1 - 1) * 1 / ((n + 1).factorial : ℝ)
      rw [Nat.add_sub_cancel, Nat.factorial_succ]
      push_cast
      have hn : (n.factorial : ℝ) ≠ 0 := by positivity
      field_simp
    have h2 := ih.add h1
    convert h2 using 1
    · funext y
      simp [poly, sum_range_succ _ (n + 1)]
    · simp [poly, sum_range_succ _ n]

theorem taylor_bound {a b M : ℝ} (n : ℕ) {f : ℕ → ℝ → E}
    (hf : ∀ j < n, ∀ x ∈ Icc a b, HasDerivAt (f j) (f (j + 1) x) x)
    (hM : ∀ x ∈ Icc a b, ‖f n x - f n a‖ ≤ M * (x - a)) :
    ∀ x ∈ Icc a b,
      ‖f 0 x - poly (fun j => f j a) a x (n + 1)‖ ≤ M * (x - a) ^ (n + 1) / (n + 1).factorial := by
  induction n generalizing f with
  | zero =>
    intro x hx
    simpa [poly] using hM x hx
  | succ n ih =>
    have ih' := ih (f := fun j => f (j + 1)) (fun j hj x hx => hf (j + 1) (by omega) x hx) hM
    have hg : ∀ x ∈ Icc a b, HasDerivAt (fun x => f 0 x - poly (fun j => f j a) a x (n + 2))
        (f 1 x - poly (fun j => f (j + 1) a) a x (n + 1)) x :=
      fun x hx => (hf 0 (by omega) x hx).sub (hasDerivAt_poly _ a x (n + 1))
    have hB : ∀ r : ℝ, HasDerivAt (fun r => M * (r - a) ^ (n + 2) / ((n + 2).factorial : ℝ))
        (M * (r - a) ^ (n + 1) / ((n + 1).factorial : ℝ)) r := by
      intro r
      have h := ((((hasDerivAt_id' r).sub_const a).fun_pow (n + 2)).const_mul M).div_const
        ((n + 2).factorial : ℝ)
      convert h using 1
      show M * (r - a) ^ (n + 1) / ((n + 1).factorial : ℝ) =
        M * (((n + 1 + 1 : ℕ) : ℝ) * (r - a) ^ (n + 1 + 1 - 1) * 1) / ((n + 1 + 1).factorial : ℝ)
      rw [Nat.add_sub_cancel, Nat.factorial_succ (n + 1)]
      push_cast
      have hn : ((n + 1).factorial : ℝ) ≠ 0 := by positivity
      field_simp
    intro x hx
    exact image_norm_le_of_norm_deriv_right_le_deriv_boundary
      (f := fun x => f 0 x - poly (fun j => f j a) a x (n + 2))
      (f' := fun x => f 1 x - poly (fun j => f (j + 1) a) a x (n + 1))
      (B := fun r => M * (r - a) ^ (n + 2) / ((n + 2).factorial : ℝ))
      (B' := fun r => M * (r - a) ^ (n + 1) / ((n + 1).factorial : ℝ))
      (fun r hr => (hg r hr).continuousAt.continuousWithinAt)
      (fun r hr => (hg r (Ico_subset_Icc_self hr)).hasDerivWithinAt)
      (by simp [poly_self (fun j => f j a) a (n + 1)])
      hB
      (fun r hr => ih' r (Ico_subset_Icc_self hr))
      hx

end Diana.Real.Taylor
