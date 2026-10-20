module

public import Diana.Real.Norm

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.Axpy

open Diana.Real.Norm

/-- `a·x + y` entrywise, as long as the shorter of `x` and `y`: the exact value of `diana_axpy`. -/
def axpy (a : ℝ) (x y : List ℝ) : List ℝ := List.zipWith (· + ·) (x.map (a * ·)) y

theorem axpy_zero : ∀ x y : List ℝ, x.length = y.length → axpy 0 x y = y
  | [], [], _ => rfl
  | [], _ :: _, h => by simp at h
  | _ :: _, [], h => by simp at h
  | p :: x, q :: y, h => by
    have ih := axpy_zero x y (by simpa using h)
    simp only [axpy, List.map_cons, List.zipWith_cons_cons, zero_mul, zero_add] at ih ⊢
    rw [ih]

/-- The update is bounded in each norm: `‖a·x + y‖ ≤ |a|·‖x‖ + ‖y‖`. -/
theorem bound (a : ℝ) (x y : List ℝ) (h : x.length = y.length) :
    norm1 (axpy a x y) ≤ |a| * norm1 x + norm1 y ∧
      norm2 (axpy a x y) ≤ |a| * norm2 x + norm2 y ∧
      normInf (axpy a x y) ≤ |a| * normInf x + normInf y := by
  obtain ⟨h1, h2, h3⟩ := triangle (x.map (a * ·)) y (by simpa using h)
  obtain ⟨e1, e2, e3⟩ := homogeneous a x
  rw [e1] at h1
  rw [e2] at h2
  rw [e3] at h3
  exact ⟨h1, h2, h3⟩

/-- Two updates along the same `x` compose: `axpy a x (axpy b x y) = axpy (a + b) x y`. -/
theorem compose (a b : ℝ) : ∀ x y : List ℝ, axpy a x (axpy b x y) = axpy (a + b) x y
  | [], _ => rfl
  | _ :: _, [] => rfl
  | p :: x, q :: y => by
    have ih := compose a b x y
    simp only [axpy, List.map_cons, List.zipWith_cons_cons] at ih ⊢
    rw [ih]
    congr 1
    ring

/-- A zero coefficient leaves `y`, so the update by `-a` undoes the update by `a`. -/
theorem inverse (a : ℝ) (x y : List ℝ) (h : x.length = y.length) :
    axpy 0 x y = y ∧ axpy (-a) x (axpy a x y) = y :=
  ⟨axpy_zero x y h, by rw [compose, neg_add_cancel, axpy_zero x y h]⟩

end Diana.Real.Axpy
