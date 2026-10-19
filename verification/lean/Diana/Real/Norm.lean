module

public import Mathlib.Analysis.Real.Sqrt

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.Norm

/-- The 1-norm `|x₀| + ⋯ + |xₙ₋₁|`. -/
def norm1 (x : List ℝ) : ℝ := (x.map fun a => |a|).sum

/-- The sum of squares `x₀² + ⋯ + xₙ₋₁²`. -/
def sumsq (x : List ℝ) : ℝ := (x.map fun a => a ^ 2).sum

/-- The Euclidean norm `√(x₀² + ⋯ + xₙ₋₁²)`. -/
noncomputable def norm2 (x : List ℝ) : ℝ := √(sumsq x)

/-- The maximum norm `max |xᵢ|`, `0` for the empty vector. -/
def normInf (x : List ℝ) : ℝ := x.foldr (fun a m => max |a| m) 0

@[simp] theorem norm1_nil : norm1 [] = 0 := by simp [norm1]

@[simp] theorem norm1_cons (a : ℝ) (x : List ℝ) : norm1 (a :: x) = |a| + norm1 x := by
  simp [norm1]

@[simp] theorem sumsq_nil : sumsq [] = 0 := by simp [sumsq]

@[simp] theorem sumsq_cons (a : ℝ) (x : List ℝ) : sumsq (a :: x) = a ^ 2 + sumsq x := by
  simp [sumsq]

@[simp] theorem normInf_nil : normInf [] = 0 := rfl

@[simp] theorem normInf_cons (a : ℝ) (x : List ℝ) : normInf (a :: x) = max |a| (normInf x) :=
  rfl

theorem norm1_nonneg : ∀ x : List ℝ, 0 ≤ norm1 x
  | [] => by simp
  | a :: x => by simpa using add_nonneg (abs_nonneg a) (norm1_nonneg x)

theorem sumsq_nonneg : ∀ x : List ℝ, 0 ≤ sumsq x
  | [] => by simp
  | a :: x => by simpa using add_nonneg (sq_nonneg a) (sumsq_nonneg x)

theorem norm2_nonneg (x : List ℝ) : 0 ≤ norm2 x := Real.sqrt_nonneg _

theorem normInf_nonneg : ∀ x : List ℝ, 0 ≤ normInf x
  | [] => le_rfl
  | a :: _ => (abs_nonneg a).trans (le_max_left _ _)

theorem abs_le_normInf {a : ℝ} : ∀ {x : List ℝ}, a ∈ x → |a| ≤ normInf x
  | [], h => by simp at h
  | b :: x, h => by
    rcases List.mem_cons.mp h with rfl | h
    · exact le_max_left _ _
    · exact (abs_le_normInf h).trans (le_max_right _ _)

theorem normInf_le {M : ℝ} (hM : 0 ≤ M) : ∀ {x : List ℝ}, (∀ a ∈ x, |a| ≤ M) → normInf x ≤ M
  | [], _ => hM
  | a :: x, h => max_le (h a (by simp)) (normInf_le hM fun b hb => h b (by simp [hb]))

theorem sq_le_sumsq {a : ℝ} : ∀ {x : List ℝ}, a ∈ x → a ^ 2 ≤ sumsq x
  | [], h => by simp at h
  | b :: x, h => by
    rw [sumsq_cons]
    rcases List.mem_cons.mp h with rfl | h
    · linarith [sumsq_nonneg x]
    · linarith [sq_le_sumsq h, sq_nonneg b]

theorem sum_map_le {f : ℝ → ℝ} {M : ℝ} :
    ∀ {x : List ℝ}, (∀ a ∈ x, f a ≤ M) → (x.map f).sum ≤ x.length * M
  | [], _ => by simp
  | a :: x, h => by
    have ih := sum_map_le (x := x) fun b hb => h b (by simp [hb])
    simp only [List.map_cons, List.sum_cons, List.length_cons, Nat.cast_succ]
    linarith [h a (by simp)]

/-- Cauchy–Schwarz in two dimensions. -/
theorem cs2 (p q u v : ℝ) : p * q + u * v ≤ √(p ^ 2 + u ^ 2) * √(q ^ 2 + v ^ 2) := by
  rw [← Real.sqrt_mul (by positivity)]
  exact (le_abs_self _).trans (Real.abs_le_sqrt (by nlinarith [sq_nonneg (p * v - q * u)]))

theorem cs2_sqrt (p q : ℝ) {U V : ℝ} (hU : 0 ≤ U) (hV : 0 ≤ V) :
    p * q + √U * √V ≤ √(p ^ 2 + U) * √(q ^ 2 + V) := by
  simpa [Real.sq_sqrt hU, Real.sq_sqrt hV] using cs2 p q √U √V

theorem sumsq_le_norm1_sq : ∀ x : List ℝ, sumsq x ≤ norm1 x ^ 2
  | [] => by simp
  | a :: x => by
    simp only [sumsq_cons, norm1_cons]
    nlinarith [sq_abs a, mul_nonneg (abs_nonneg a) (norm1_nonneg x), sumsq_le_norm1_sq x]

theorem norm1_le_sqrt_length : ∀ x : List ℝ, norm1 x ≤ √(x.length : ℝ) * norm2 x
  | [] => by simp
  | a :: x => by
    have ih := norm1_le_sqrt_length x
    have h := cs2_sqrt 1 |a| (Nat.cast_nonneg' x.length) (sumsq_nonneg x)
    simp only [norm2, sq_abs, one_pow, one_mul] at ih h
    simp only [norm1_cons, norm2, sumsq_cons, List.length_cons, Nat.cast_succ, add_comm _ (1 : ℝ)]
    linarith

theorem sumsq_add_le : ∀ x y : List ℝ, x.length = y.length →
    sumsq (List.zipWith (· + ·) x y) ≤ (norm2 x + norm2 y) ^ 2
  | [], [], _ => by simp only [List.zipWith_nil_left, sumsq_nil]; positivity
  | [], _ :: _, h => by simp at h
  | _ :: _, [], h => by simp at h
  | a :: x, b :: y, h => by
    have ih := sumsq_add_le x y (by simpa using h)
    have hx := sumsq_nonneg x
    have hy := sumsq_nonneg y
    have h2 := cs2_sqrt a b hx hy
    simp only [norm2] at ih ⊢
    simp only [List.zipWith_cons_cons, sumsq_cons]
    nlinarith [Real.sq_sqrt hx, Real.sq_sqrt hy, Real.sq_sqrt (by positivity : 0 ≤ a ^ 2 + sumsq x),
      Real.sq_sqrt (by positivity : 0 ≤ b ^ 2 + sumsq y)]

theorem norm1_add_le : ∀ x y : List ℝ, norm1 (List.zipWith (· + ·) x y) ≤ norm1 x + norm1 y
  | [], y => by simp [norm1_nonneg]
  | a :: x, [] => by simpa using norm1_nonneg (a :: x)
  | a :: x, b :: y => by
    simp only [List.zipWith_cons_cons, norm1_cons]
    linarith [abs_add_le a b, norm1_add_le x y]

theorem normInf_add_le :
    ∀ x y : List ℝ, normInf (List.zipWith (· + ·) x y) ≤ normInf x + normInf y
  | [], y => by simp [normInf_nonneg]
  | _ :: _, [] => by simp [normInf_nonneg]
  | a :: x, b :: y => by
    simp only [List.zipWith_cons_cons, normInf_cons]
    exact max_le ((abs_add_le a b).trans (add_le_add (le_max_left _ _) (le_max_left _ _)))
      ((normInf_add_le x y).trans (add_le_add (le_max_right _ _) (le_max_right _ _)))

theorem sumsq_eraseIdx : ∀ (x : List ℝ) (k : ℕ) (hk : k < x.length),
    sumsq x = x[k] ^ 2 + sumsq (x.eraseIdx k)
  | [], _, hk => by simp at hk
  | a :: x, 0, _ => by simp
  | a :: x, k + 1, hk => by
    simp only [List.getElem_cons_succ, List.eraseIdx_cons_succ, sumsq_cons]
    rw [sumsq_eraseIdx x k (by simpa using hk)]
    ring

theorem sumsq_map_div (m : ℝ) : ∀ x : List ℝ, sumsq (x.map fun a => a / m) = sumsq x / m ^ 2
  | [] => by simp
  | a :: x => by simp [sumsq_map_div m x, div_pow, add_div]

theorem sumsq_map_mul (c : ℝ) : ∀ x : List ℝ, sumsq (x.map (c * ·)) = c ^ 2 * sumsq x
  | [] => by simp
  | a :: x => by simp [sumsq_map_mul c x, mul_pow, mul_add]

theorem norm1_map_mul (c : ℝ) : ∀ x : List ℝ, norm1 (x.map (c * ·)) = |c| * norm1 x
  | [] => by simp
  | a :: x => by simp [norm1_map_mul c x, abs_mul, mul_add]

theorem normInf_map_mul (c : ℝ) : ∀ x : List ℝ, normInf (x.map (c * ·)) = |c| * normInf x
  | [] => by simp
  | a :: x => by
    simp only [List.map_cons, normInf_cons, normInf_map_mul c x, abs_mul]
    exact (mul_max_of_nonneg _ _ (abs_nonneg c)).symm

/-- The scaled 2-norm: with `m = |x[k]| ≠ 0`, `m·√(1 + Σ_{i≠k} (xᵢ/m)²)` is the 2-norm. -/
theorem scale (x : List ℝ) (k : ℕ) (hk : k < x.length) (h0 : x[k] ≠ 0) :
    |x[k]| * √(1 + sumsq ((x.eraseIdx k).map fun a => a / |x[k]|)) = norm2 x := by
  have hm : 0 < |x[k]| := abs_pos.mpr h0
  have key : x[k] ^ 2 + sumsq (x.eraseIdx k) =
      |x[k]| ^ 2 * (1 + sumsq (x.eraseIdx k) / |x[k]| ^ 2) := by
    rw [sq_abs]
    field_simp
  rw [sumsq_map_div, norm2, sumsq_eraseIdx x k hk, key, Real.sqrt_mul (sq_nonneg _),
    Real.sqrt_sq hm.le]

/-- The equivalence of the three norms: `‖x‖∞ ≤ ‖x‖₂ ≤ ‖x‖₁ ≤ n·‖x‖∞`. -/
theorem equiv (x : List ℝ) :
    normInf x ≤ norm2 x ∧ norm2 x ≤ norm1 x ∧ norm1 x ≤ x.length * normInf x :=
  ⟨normInf_le (norm2_nonneg x) fun _ ha => Real.abs_le_sqrt (sq_le_sumsq ha),
    (Real.sqrt_le_sqrt (sumsq_le_norm1_sq x)).trans_eq (Real.sqrt_sq (norm1_nonneg x)),
    sum_map_le fun _ ha => abs_le_normInf ha⟩

/-- The Cauchy–Schwarz bounds: `‖x‖₁ ≤ √n·‖x‖₂` and `‖x‖₂ ≤ √n·‖x‖∞`. -/
theorem cauchy (x : List ℝ) :
    norm1 x ≤ √(x.length : ℝ) * norm2 x ∧ norm2 x ≤ √(x.length : ℝ) * normInf x := by
  refine ⟨norm1_le_sqrt_length x, ?_⟩
  have h : sumsq x ≤ x.length * normInf x ^ 2 := sum_map_le fun a ha =>
    (sq_abs a).symm.trans_le ((sq_le_sq₀ (abs_nonneg a) (normInf_nonneg x)).mpr (abs_le_normInf ha))
  calc norm2 x ≤ √(x.length * normInf x ^ 2) := Real.sqrt_le_sqrt h
    _ = √(x.length : ℝ) * normInf x := by
      rw [Real.sqrt_mul (Nat.cast_nonneg' _), Real.sqrt_sq (normInf_nonneg x)]

/-- The triangle inequality of the three norms for vectors of equal length. -/
theorem triangle (x y : List ℝ) (h : x.length = y.length) :
    norm1 (List.zipWith (· + ·) x y) ≤ norm1 x + norm1 y ∧
      norm2 (List.zipWith (· + ·) x y) ≤ norm2 x + norm2 y ∧
      normInf (List.zipWith (· + ·) x y) ≤ normInf x + normInf y :=
  ⟨norm1_add_le x y,
    (Real.sqrt_le_sqrt (sumsq_add_le x y h)).trans_eq
      (Real.sqrt_sq (add_nonneg (norm2_nonneg x) (norm2_nonneg y))),
    normInf_add_le x y⟩

/-- The absolute homogeneity of the three norms. -/
theorem homogeneous (c : ℝ) (x : List ℝ) :
    norm1 (x.map (c * ·)) = |c| * norm1 x ∧ norm2 (x.map (c * ·)) = |c| * norm2 x ∧
      normInf (x.map (c * ·)) = |c| * normInf x := by
  refine ⟨norm1_map_mul c x, ?_, normInf_map_mul c x⟩
  rw [norm2, norm2, sumsq_map_mul, Real.sqrt_mul (sq_nonneg c), Real.sqrt_sq_eq_abs]

/-- The definiteness of the three norms: each is zero exactly for the zero vector. -/
theorem definite (x : List ℝ) :
    (norm1 x = 0 ↔ ∀ a ∈ x, a = 0) ∧ (norm2 x = 0 ↔ ∀ a ∈ x, a = 0) ∧
      (normInf x = 0 ↔ ∀ a ∈ x, a = 0) := by
  obtain ⟨hi2, h21, h1i⟩ := equiv x
  have hn := normInf_nonneg x
  have hInf : normInf x = 0 ↔ ∀ a ∈ x, a = 0 := by
    refine ⟨fun h a ha => ?_, fun h => le_antisymm (normInf_le le_rfl fun a ha => ?_) hn⟩
    · have := abs_le_normInf ha
      rw [h] at this
      exact abs_nonpos_iff.mp this
    · simp [h a ha]
  have h1 : (∀ a ∈ x, a = 0) → norm1 x = 0 := fun h => by
    rw [hInf.mpr h, mul_zero] at h1i
    exact le_antisymm h1i (norm1_nonneg x)
  refine ⟨⟨fun h => hInf.mp ?_, h1⟩, ⟨fun h => hInf.mp ?_, fun h => ?_⟩, hInf⟩
  · linarith
  · linarith
  · linarith [h1 h, norm2_nonneg x]
