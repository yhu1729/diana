module

public import Mathlib.Analysis.Calculus.Deriv.Pow
public import Diana.Real.Quadrature

public section

namespace Diana.Real.Simpson

open Set Diana.Real.Quadrature

theorem sym_add {F F' : ℝ → ℝ} {c s : ℝ} (h₁ : HasDerivAt F (F' (c + s)) (c + s))
    (h₂ : HasDerivAt F (F' (c - s)) (c - s)) :
    HasDerivAt (fun s => F (c + s) + F (c - s)) (F' (c + s) - F' (c - s)) s := by
  have := (h₁.comp s ((hasDerivAt_id' s).const_add c)).add
    (h₂.comp s ((hasDerivAt_id' s).const_sub c))
  refine this.congr_deriv ?_
  ring

theorem sym_sub {F F' : ℝ → ℝ} {c s : ℝ} (h₁ : HasDerivAt F (F' (c + s)) (c + s))
    (h₂ : HasDerivAt F (F' (c - s)) (c - s)) :
    HasDerivAt (fun s => F (c + s) - F (c - s)) (F' (c + s) + F' (c - s)) s := by
  have := (h₁.comp s ((hasDerivAt_id' s).const_add c)).sub
    (h₂.comp s ((hasDerivAt_id' s).const_sub c))
  refine this.congr_deriv ?_
  ring

theorem symmetric_error {f f' f'' f''' f'''' : ℝ → ℝ} {c h M₄ : ℝ} (hh : 0 ≤ h)
    (hf : ∀ t ∈ Icc (c - h) (c + h), HasDerivAt f (f' t) t)
    (hf' : ∀ t ∈ Icc (c - h) (c + h), HasDerivAt f' (f'' t) t)
    (hf'' : ∀ t ∈ Icc (c - h) (c + h), HasDerivAt f'' (f''' t) t)
    (hf''' : ∀ t ∈ Icc (c - h) (c + h), HasDerivAt f''' (f'''' t) t)
    (hM : ∀ t ∈ Icc (c - h) (c + h), |f'''' t| ≤ M₄) :
    |(∫ t in (c - h)..(c + h), f t) - h / 3 * (f (c - h) + 4 * f c + f (c + h))| ≤
      M₄ * h ^ 5 / 90 := by
  have hlo : c - h ≤ c + h := by linarith
  have hp : ∀ s ∈ Icc 0 h, c + s ∈ Icc (c - h) (c + h) := fun s hs =>
    ⟨by linarith [hs.1], by linarith [hs.2]⟩
  have hm : ∀ s ∈ Icc 0 h, c - s ∈ Icc (c - h) (c + h) := fun s hs =>
    ⟨by linarith [hs.2], by linarith [hs.1]⟩
  have hfc : ContinuousOn f (Icc (c - h) (c + h)) := fun t ht =>
    (hf t ht).continuousAt.continuousWithinAt
  let g : ℝ → ℝ := fun t => f (clamp (c - h) (c + h) t)
  have hgc : Continuous g := continuous_extend hlo hfc
  let G : ℝ → ℝ := fun t => ∫ u in (c - h)..t, g u
  have hG : ∀ t, HasDerivAt G (g t) t := fun t =>
    (hgc.integral_hasStrictDerivAt (c - h) t).hasDerivAt
  let E3 : ℝ → ℝ := fun s => -(s / 3 * (f''' (c + s) - f''' (c - s)))
  let E2 : ℝ → ℝ := fun s => (f' (c + s) - f' (c - s)) / 3 - s / 3 * (f'' (c + s) + f'' (c - s))
  let E1 : ℝ → ℝ := fun s =>
    2 / 3 * (f (c + s) + f (c - s)) - 4 / 3 * f c - s / 3 * (f' (c + s) - f' (c - s))
  let E : ℝ → ℝ := fun s =>
    (G (c + s) - G (c - s)) - s / 3 * (f (c + s) + f (c - s) + 4 * f c)
  have hD : ∀ s ∈ Icc 0 h, HasDerivAt (fun s => f''' (c + s) - f''' (c - s))
      (f'''' (c + s) + f'''' (c - s)) s := fun s hs =>
    sym_sub (hf''' _ (hp s hs)) (hf''' _ (hm s hs))
  have hE2 : ∀ s ∈ Icc 0 h, HasDerivAt E2 (E3 s) s := by
    intro s hs
    have := ((sym_sub (hf' _ (hp s hs)) (hf' _ (hm s hs))).div_const 3).sub
      (((hasDerivAt_id' s).div_const 3).mul (sym_add (hf'' _ (hp s hs)) (hf'' _ (hm s hs))))
    refine this.congr_deriv ?_
    simp only [E3]
    ring
  have hE1 : ∀ s ∈ Icc 0 h, HasDerivAt E1 (E2 s) s := by
    intro s hs
    have := (((sym_add (hf _ (hp s hs)) (hf _ (hm s hs))).const_mul (2 / 3)).sub_const
      (4 / 3 * f c)).sub
      (((hasDerivAt_id' s).div_const 3).mul (sym_sub (hf' _ (hp s hs)) (hf' _ (hm s hs))))
    refine this.congr_deriv ?_
    simp only [E2]
    ring
  have hE : ∀ s ∈ Icc 0 h, HasDerivAt E (E1 s) s := by
    intro s hs
    have := (sym_sub (F := G) (F' := g) (hG (c + s)) (hG (c - s))).sub
      (((hasDerivAt_id' s).div_const 3).mul
        ((sym_add (hf _ (hp s hs)) (hf _ (hm s hs))).add_const (4 * f c)))
    refine this.congr_deriv ?_
    simp only [E1, g, clamp_eq (hp s hs), clamp_eq (hm s hs)]
    ring
  have hDb : ∀ s ∈ Icc 0 h, |f''' (c + s) - f''' (c - s)| ≤ 2 * M₄ * s :=
    bound_of_deriv (F' := fun s => f'''' (c + s) + f'''' (c - s)) (B := fun s => 2 * M₄ * s)
      (B' := fun _ => 2 * M₄) hD
      (fun t => ((hasDerivAt_id' t).const_mul (2 * M₄)).congr_deriv (mul_one _))
      (fun s hs => by
        have h1 := hM _ (hp s (Ico_subset_Icc_self hs))
        have h2 := hM _ (hm s (Ico_subset_Icc_self hs))
        calc |f'''' (c + s) + f'''' (c - s)| ≤ |f'''' (c + s)| + |f'''' (c - s)| :=
              abs_add_le _ _
          _ ≤ 2 * M₄ := by linarith)
      (by simp)
  have hE3b : ∀ s ∈ Icc 0 h, |E3 s| ≤ 2 / 3 * M₄ * s ^ 2 := by
    intro s hs
    have hs0 : 0 ≤ s / 3 := by linarith [hs.1]
    have := mul_le_mul_of_nonneg_left (hDb s hs) hs0
    simp only [E3, abs_neg, abs_mul, abs_of_nonneg hs0]
    nlinarith
  have hE2b : ∀ s ∈ Icc 0 h, |E2 s| ≤ 2 / 9 * M₄ * s ^ 3 :=
    bound_of_deriv (F' := E3) (B := fun s => 2 / 9 * M₄ * s ^ 3)
      (B' := fun s => 2 / 3 * M₄ * s ^ 2) hE2
      (fun t => by
        have := ((hasDerivAt_id t).fun_pow 3).const_mul (2 / 9 * M₄)
        refine this.congr_deriv ?_
        simp only [id]
        ring)
      (fun s hs => hE3b s (Ico_subset_Icc_self hs))
      (by simp [E2])
  have hE1b : ∀ s ∈ Icc 0 h, |E1 s| ≤ M₄ * s ^ 4 / 18 :=
    bound_of_deriv (F' := E2) (B := fun s => M₄ * s ^ 4 / 18)
      (B' := fun s => 2 / 9 * M₄ * s ^ 3) hE1
      (fun t => by
        have := (((hasDerivAt_id t).fun_pow 4).const_mul M₄).div_const 18
        refine this.congr_deriv ?_
        simp only [id]
        ring)
      (fun s hs => hE2b s (Ico_subset_Icc_self hs))
      (by
        have : E1 0 = 0 := by
          simp only [E1, add_zero, sub_zero]
          ring
        rw [this]
        simp)
  have hEb : ∀ s ∈ Icc 0 h, |E s| ≤ M₄ * s ^ 5 / 90 :=
    bound_of_deriv (F' := E1) (B := fun s => M₄ * s ^ 5 / 90)
      (B' := fun s => M₄ * s ^ 4 / 18) hE
      (fun t => by
        have := (((hasDerivAt_id t).fun_pow 5).const_mul M₄).div_const 90
        refine this.congr_deriv ?_
        simp only [id]
        ring)
      (fun s hs => hE1b s (Ico_subset_Icc_self hs))
      (by simp [E])
  have hint : G (c + h) - G (c - h) = ∫ t in (c - h)..(c + h), f t := by
    simp only [G, intervalIntegral.integral_same, sub_zero]
    exact integral_extend le_rfl hlo le_rfl
  have hfin := hEb h ⟨hh, le_rfl⟩
  simp only [E] at hfin
  rw [hint] at hfin
  have hsum : f (c - h) + 4 * f c + f (c + h) = f (c + h) + f (c - h) + 4 * f c := by ring
  rw [hsum]
  exact hfin

theorem local_error {f f' f'' f''' f'''' : ℝ → ℝ} {x h M₄ : ℝ} (hh : 0 ≤ h)
    (hf : ∀ t ∈ Icc x (x + 2 * h), HasDerivAt f (f' t) t)
    (hf' : ∀ t ∈ Icc x (x + 2 * h), HasDerivAt f' (f'' t) t)
    (hf'' : ∀ t ∈ Icc x (x + 2 * h), HasDerivAt f'' (f''' t) t)
    (hf''' : ∀ t ∈ Icc x (x + 2 * h), HasDerivAt f''' (f'''' t) t)
    (hM : ∀ t ∈ Icc x (x + 2 * h), |f'''' t| ≤ M₄) :
    |(∫ t in x..x + 2 * h, f t) - h / 3 * (f x + 4 * f (x + h) + f (x + 2 * h))| ≤
      M₄ * h ^ 5 / 90 := by
  have e1 : x + h - h = x := by ring
  have e2 : x + h + h = x + 2 * h := by ring
  have := symmetric_error (c := x + h) (M₄ := M₄) hh (by rw [e1, e2]; exact hf)
    (by rw [e1, e2]; exact hf') (by rw [e1, e2]; exact hf'') (by rw [e1, e2]; exact hf''')
    (by rw [e1, e2]; exact hM)
  rw [e1, e2] at this
  exact this

theorem sum_triple (u : ℕ → ℝ) (n : ℕ) :
    ∑ k ∈ Finset.range (n + 1), (u (2 * k) + 4 * u (2 * k + 1) + u (2 * k + 2)) =
      u 0 + u (2 * n + 2) + 4 * ∑ k ∈ Finset.range (n + 1), u (2 * k + 1) +
        2 * ∑ k ∈ Finset.Ico 1 (n + 1), u (2 * k) := by
  induction n with
  | zero =>
    simp
    ring
  | succ n ih =>
    rw [Finset.sum_range_succ, ih, Finset.sum_range_succ (fun k => u (2 * k + 1)) (n + 1),
      Finset.sum_Ico_succ_top (by omega : 1 ≤ n + 1)]
    have e : 2 * n + 2 = 2 * (n + 1) := by ring
    rw [e]
    ring

theorem composite_error {f f' f'' f''' f'''' : ℝ → ℝ} {a b h M₄ : ℝ} {p : ℕ} (hab : a ≤ b)
    (hp : 1 ≤ p) (hh : h = (b - a) / (2 * p))
    (hf : ∀ t ∈ Icc a b, HasDerivAt f (f' t) t)
    (hf' : ∀ t ∈ Icc a b, HasDerivAt f' (f'' t) t)
    (hf'' : ∀ t ∈ Icc a b, HasDerivAt f'' (f''' t) t)
    (hf''' : ∀ t ∈ Icc a b, HasDerivAt f''' (f'''' t) t)
    (hM : ∀ t ∈ Icc a b, |f'''' t| ≤ M₄) :
    |(∫ t in a..b, f t) - h / 3 * (f a + f b + 4 * ∑ k ∈ Finset.range p, f (a + (2 * k + 1) * h) +
        2 * ∑ k ∈ Finset.Ico 1 p, f (a + 2 * k * h))| ≤ (b - a) * h ^ 4 * M₄ / 180 := by
  have hp0 : (0 : ℝ) < p := by exact_mod_cast hp
  have hph : 2 * (p : ℝ) * h = b - a := by rw [hh]; field_simp
  have hh0 : 0 ≤ h := by rw [hh]; exact div_nonneg (sub_nonneg.mpr hab) (by positivity)
  have hw : 0 ≤ 2 * h := by linarith
  have hb : a + p * (2 * h) = b := by linarith
  let x : ℕ → ℝ := fun k => a + k * (2 * h)
  have hsub : ∀ k < p, Icc (x k) (x k + 2 * h) ⊆ Icc a b := by
    intro k hk t ht
    have hk' : (k : ℝ) + 1 ≤ p := by exact_mod_cast hk
    have h1 : 0 ≤ (k : ℝ) * (2 * h) := mul_nonneg (Nat.cast_nonneg k) hw
    have h2 : ((k : ℝ) + 1) * (2 * h) ≤ p * (2 * h) := mul_le_mul_of_nonneg_right hk' hw
    simp only [x] at ht
    constructor <;> nlinarith [ht.1, ht.2]
  have hfc : ContinuousOn f (Icc a b) := fun t ht => (hf t ht).continuousAt.continuousWithinAt
  have hloc : ∀ k < p, |(∫ t in (a + k * (2 * h))..(a + ↑(k + 1) * (2 * h)), f t) -
      h / 3 * (f (x k) + 4 * f (x k + h) + f (x k + 2 * h))| ≤ M₄ * h ^ 5 / 90 := by
    intro k hk
    have hx1 : a + ↑(k + 1) * (2 * h) = x k + 2 * h := by simp only [x]; push_cast; ring
    rw [hx1]
    exact local_error hh0 (fun t ht => hf t (hsub k hk ht)) (fun t ht => hf' t (hsub k hk ht))
      (fun t ht => hf'' t (hsub k hk ht)) (fun t ht => hf''' t (hsub k hk ht))
      (fun t ht => hM t (hsub k hk ht))
  have hpe := panel_error (Q := fun k => h / 3 * (f (x k) + 4 * f (x k + h) + f (x k + 2 * h)))
    hw (by rw [hb]; exact hfc) hloc
  rw [hb] at hpe
  have hT : h / 3 * (f a + f b + 4 * ∑ k ∈ Finset.range p, f (a + (2 * k + 1) * h) +
        2 * ∑ k ∈ Finset.Ico 1 p, f (a + 2 * k * h)) =
      ∑ k ∈ Finset.range p, h / 3 * (f (x k) + 4 * f (x k + h) + f (x k + 2 * h)) := by
    obtain ⟨n, rfl⟩ : ∃ n, p = n + 1 := ⟨p - 1, by omega⟩
    have e0 : ∀ k : ℕ, x k = a + ((2 * k : ℕ) : ℝ) * h := fun k => by
      simp only [x]; push_cast; ring
    have e1 : ∀ k : ℕ, x k + h = a + ((2 * k + 1 : ℕ) : ℝ) * h := fun k => by
      simp only [x]; push_cast; ring
    have e2 : ∀ k : ℕ, x k + 2 * h = a + ((2 * k + 2 : ℕ) : ℝ) * h := fun k => by
      simp only [x]; push_cast; ring
    have hbn : a + ((2 * n + 2 : ℕ) : ℝ) * h = b := by rw [← hb]; push_cast; ring
    have es : ∀ k : ℕ, h / 3 * (f (x k) + 4 * f (x k + h) + f (x k + 2 * h)) =
        h / 3 * (f (a + ((2 * k : ℕ) : ℝ) * h) + 4 * f (a + ((2 * k + 1 : ℕ) : ℝ) * h) +
          f (a + ((2 * k + 2 : ℕ) : ℝ) * h)) := fun k => by rw [e1, e2, e0]
    simp only [es]
    rw [← Finset.mul_sum, sum_triple (fun i : ℕ => f (a + i * h)) n, hbn]
    push_cast
    simp only [zero_mul, add_zero]
  rw [hT]
  calc _ ≤ p * (M₄ * h ^ 5 / 90) := hpe
    _ = (b - a) * h ^ 4 * M₄ / 180 := by rw [← hph]; ring

end Diana.Real.Simpson
