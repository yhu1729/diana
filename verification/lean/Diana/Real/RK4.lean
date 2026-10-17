module

public import Mathlib.Analysis.Calculus.Deriv.Comp
public import Mathlib.Analysis.Calculus.Deriv.Mul
public import Mathlib.Analysis.Calculus.Deriv.Prod
public import Mathlib.Analysis.Complex.Exponential
public import Diana.Real.OneStep
public import Diana.Real.Taylor

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.RK4

open Set Diana.Real.OneStep Diana.Real.Taylor

variable {E : Type*} [NormedAddCommGroup E] [NormedSpace ℝ E]

noncomputable def slope₁ (F : ℝ → E → E) (t : ℝ) (y : E) : E := F t y

noncomputable def slope₂ (F : ℝ → E → E) (t : ℝ) (y : E) (h : ℝ) : E :=
  F (t + h / 2) (y + (h / 2) • slope₁ F t y)

noncomputable def slope₃ (F : ℝ → E → E) (t : ℝ) (y : E) (h : ℝ) : E :=
  F (t + h / 2) (y + (h / 2) • slope₂ F t y h)

noncomputable def slope₄ (F : ℝ → E → E) (t : ℝ) (y : E) (h : ℝ) : E :=
  F (t + h) (y + h • slope₃ F t y h)

noncomputable def incT (F : ℝ → E → E) (t : ℝ) (y : E) (h : ℝ) : E :=
  (6 : ℝ)⁻¹ • (slope₁ F t y + (2 : ℝ) • slope₂ F t y h + (2 : ℝ) • slope₃ F t y h +
    slope₄ F t y h)

noncomputable def rk4 (F : ℝ → E → E) (t₀ h : ℝ) (y₀ : E) : ℕ → E :=
  iterate (fun t y => incT F t y h) t₀ h y₀

noncomputable def inc (G : E → E) (y : E) (h : ℝ) : E := incT (fun _ => G) 0 y h

def auto (F : ℝ → E → E) (p : ℝ × E) : ℝ × E := ((1 : ℝ), F p.1 p.2)

theorem inc_autonomous (F : ℝ → E → E) (t : ℝ) (y : E) (h : ℝ) :
    inc (auto F) (t, y) h = ((1 : ℝ), incT F t y h) := by
  simp only [inc, incT, auto, slope₁, slope₂, slope₃, slope₄, Prod.smul_mk, Prod.mk_add_mk,
    smul_eq_mul, mul_one, Prod.mk.injEq, and_true]
  norm_num

theorem norm_step_sub (y z a b : E) {c : ℝ} (hc : 0 ≤ c) :
    ‖(y + c • a) - (z + c • b)‖ ≤ ‖y - z‖ + c * ‖a - b‖ := by
  calc ‖(y + c • a) - (z + c • b)‖ = ‖(y - z) + c • (a - b)‖ := by
        congr 1; rw [smul_sub]; abel
    _ ≤ ‖y - z‖ + ‖c • (a - b)‖ := norm_add_le _ _
    _ = ‖y - z‖ + c * ‖a - b‖ := by rw [norm_smul, Real.norm_of_nonneg hc]

theorem lipschitz {F : ℝ → E → E} {t h L : ℝ} (hh : 0 ≤ h) (hL : 0 ≤ L)
    (hlip : ∀ s ∈ Icc t (t + h), ∀ y z, ‖F s y - F s z‖ ≤ L * ‖y - z‖) (y z : E) :
    ‖incT F t y h - incT F t z h‖ ≤
      L * (1 + h * L / 2 + (h * L) ^ 2 / 6 + (h * L) ^ 3 / 24) * ‖y - z‖ := by
  have t₁ : t ∈ Icc t (t + h) := ⟨le_rfl, by linarith⟩
  have tm : t + h / 2 ∈ Icc t (t + h) := ⟨by linarith, by linarith⟩
  have t₂ : t + h ∈ Icc t (t + h) := ⟨by linarith, le_rfl⟩
  have hh2 : 0 ≤ h / 2 := by linarith
  set e := ‖y - z‖ with he
  have he0 : 0 ≤ e := norm_nonneg _
  have d₁ : ‖slope₁ F t y - slope₁ F t z‖ ≤ L * e := hlip t t₁ y z
  have d₂ : ‖slope₂ F t y h - slope₂ F t z h‖ ≤ L * (e + h / 2 * (L * e)) := by
    calc _ ≤ L * ‖(y + (h / 2) • slope₁ F t y) - (z + (h / 2) • slope₁ F t z)‖ :=
          hlip _ tm _ _
      _ ≤ L * (e + h / 2 * ‖slope₁ F t y - slope₁ F t z‖) := by
          gcongr; exact norm_step_sub _ _ _ _ hh2
      _ ≤ L * (e + h / 2 * (L * e)) := by gcongr
  have d₃ : ‖slope₃ F t y h - slope₃ F t z h‖ ≤
      L * (e + h / 2 * (L * (e + h / 2 * (L * e)))) := by
    calc _ ≤ L * ‖(y + (h / 2) • slope₂ F t y h) - (z + (h / 2) • slope₂ F t z h)‖ :=
          hlip _ tm _ _
      _ ≤ L * (e + h / 2 * ‖slope₂ F t y h - slope₂ F t z h‖) := by
          gcongr; exact norm_step_sub _ _ _ _ hh2
      _ ≤ _ := by gcongr
  have d₄ : ‖slope₄ F t y h - slope₄ F t z h‖ ≤
      L * (e + h * (L * (e + h / 2 * (L * (e + h / 2 * (L * e)))))) := by
    calc _ ≤ L * ‖(y + h • slope₃ F t y h) - (z + h • slope₃ F t z h)‖ := hlip _ t₂ _ _
      _ ≤ L * (e + h * ‖slope₃ F t y h - slope₃ F t z h‖) := by
          gcongr; exact norm_step_sub _ _ _ _ hh
      _ ≤ _ := by gcongr
  have hsum : incT F t y h - incT F t z h = (6 : ℝ)⁻¹ • ((slope₁ F t y - slope₁ F t z) +
      (2 : ℝ) • (slope₂ F t y h - slope₂ F t z h) + (2 : ℝ) • (slope₃ F t y h - slope₃ F t z h) +
      (slope₄ F t y h - slope₄ F t z h)) := by
    simp only [incT, smul_sub, smul_add]
    abel
  rw [hsum, norm_smul, Real.norm_of_nonneg (by norm_num)]
  calc (6 : ℝ)⁻¹ * ‖(slope₁ F t y - slope₁ F t z) +
        (2 : ℝ) • (slope₂ F t y h - slope₂ F t z h) +
        (2 : ℝ) • (slope₃ F t y h - slope₃ F t z h) + (slope₄ F t y h - slope₄ F t z h)‖
      ≤ (6 : ℝ)⁻¹ * (‖slope₁ F t y - slope₁ F t z‖ +
          2 * ‖slope₂ F t y h - slope₂ F t z h‖ + 2 * ‖slope₃ F t y h - slope₃ F t z h‖ +
          ‖slope₄ F t y h - slope₄ F t z h‖) := by
        gcongr
        refine (norm_add_le _ _).trans ?_
        gcongr
        refine (norm_add_le _ _).trans ?_
        gcongr
        · refine (norm_add_le _ _).trans ?_
          rw [norm_smul, Real.norm_of_nonneg (by norm_num)]
        · rw [norm_smul, Real.norm_of_nonneg (by norm_num)]
    _ ≤ (6 : ℝ)⁻¹ * (L * e + 2 * (L * (e + h / 2 * (L * e))) +
          2 * (L * (e + h / 2 * (L * (e + h / 2 * (L * e))))) +
          L * (e + h * (L * (e + h / 2 * (L * (e + h / 2 * (L * e))))))) := by
        gcongr
    _ = L * (1 + h * L / 2 + (h * L) ^ 2 / 6 + (h * L) ^ 3 / 24) * e := by ring

theorem grid {t₀ h : ℝ} {N k : ℕ} (hh : 0 ≤ h) (hk : k < N) :
    Icc (t₀ + k * h) (t₀ + k * h + h) ⊆ Icc t₀ (t₀ + N * h) := by
  intro s hs
  have hk' : (k : ℝ) + 1 ≤ N := by exact_mod_cast hk
  have h1 : 0 ≤ (k : ℝ) * h := mul_nonneg (Nat.cast_nonneg k) hh
  have h2 : ((k : ℝ) + 1) * h ≤ N * h := mul_le_mul_of_nonneg_right hk' hh
  constructor <;> nlinarith [hs.1, hs.2]

theorem global_error {F : ℝ → E → E} {Y : ℝ → E} {t₀ h L τ : ℝ} {N : ℕ}
    (hh : 0 < h) (hL : 0 < L) (hτ : 0 ≤ τ)
    (hlip : ∀ s ∈ Icc t₀ (t₀ + N * h), ∀ y z, ‖F s y - F s z‖ ≤ L * ‖y - z‖)
    (htr : ∀ k < N, ‖Y (t₀ + (k + 1) * h) - Y (t₀ + k * h) -
      h • incT F (t₀ + k * h) (Y (t₀ + k * h)) h‖ ≤ τ) :
    ∀ k ≤ N, ‖rk4 F t₀ h (Y t₀) k - Y (t₀ + k * h)‖ ≤
      τ / (h * L) * (Real.exp (L * (k * h)) - 1) := by
  set x := h * L with hx
  have hx0 : 0 < x := mul_pos hh hL
  set K := L * (1 + x / 2 + x ^ 2 / 6 + x ^ 3 / 24) with hK
  have hK0 : 0 < K := by positivity
  have hlip' : ∀ k < N, ∀ y z, ‖incT F (t₀ + k * h) y h - incT F (t₀ + k * h) z h‖ ≤
      K * ‖y - z‖ := by
    intro k hk y z
    have := lipschitz (t := t₀ + k * h) hh.le hL.le
      (fun s hs => hlip s (grid hh.le hk hs)) y z
    simpa [hK, hx, mul_comm h L] using this
  intro k hk
  have hp := one_step_pow (Φ := fun t y => incT F t y h) hh hK0 hlip' htr k hk
  have hT : 1 + h * K = ∑ i ∈ Finset.range 5, x ^ i / (i.factorial : ℝ) := by
    simp [Finset.sum_range_succ, Nat.factorial, hK, hx]
    ring
  have hexp : 1 + h * K ≤ Real.exp x := hT ▸ Real.sum_le_exp_of_nonneg hx0.le 5
  have hpow : (1 + h * K) ^ k ≤ Real.exp (L * (k * h)) := by
    have h1 : (0 : ℝ) ≤ 1 + h * K := by positivity
    calc (1 + h * K) ^ k ≤ Real.exp x ^ k := pow_le_pow_left₀ h1 hexp k
      _ = Real.exp (L * (k * h)) := by rw [← Real.exp_nat_mul]; congr 1; rw [hx]; ring
  have hxK : x ≤ h * K := by
    have : 1 ≤ 1 + x / 2 + x ^ 2 / 6 + x ^ 3 / 24 := by
      have : 0 ≤ x / 2 + x ^ 2 / 6 + x ^ 3 / 24 := by positivity
      linarith
    calc x = h * (L * 1) := by rw [hx]; ring
      _ ≤ h * K := by rw [hK]; gcongr
  have hnum : 0 ≤ Real.exp (L * (k * h)) - 1 := by
    have : 0 ≤ L * (k * h) := by positivity
    linarith [Real.add_one_le_exp (L * (k * h))]
  calc ‖rk4 F t₀ h (Y t₀) k - Y (t₀ + k * h)‖ ≤ τ * ((1 + h * K) ^ k - 1) / (h * K) := hp
    _ ≤ τ * (Real.exp (L * (k * h)) - 1) / (h * K) := by gcongr
    _ ≤ τ * (Real.exp (L * (k * h)) - 1) / x := by
        apply div_le_div_of_nonneg_left (mul_nonneg hτ hnum) hx0 hxK
    _ = τ / (h * L) * (Real.exp (L * (k * h)) - 1) := by rw [hx]; ring

structure Jet (E : Type*) where
  v : E
  d₁ : E
  d₂ : E
  d₃ : E

section Jet

variable (G : E → E) (G₁ : E → E →L[ℝ] E) (G₂ : E → E →L[ℝ] E →L[ℝ] E)
  (G₃ : E → E →L[ℝ] E →L[ℝ] E →L[ℝ] E)

noncomputable def Jet.app (g : Jet E) : Jet E :=
  ⟨G g.v, G₁ g.v g.d₁, G₂ g.v g.d₁ g.d₁ + G₁ g.v g.d₂,
    G₃ g.v g.d₁ g.d₁ g.d₁ + G₂ g.v g.d₂ g.d₁ + (2 : ℝ) • G₂ g.v g.d₁ g.d₂ + G₁ g.v g.d₃⟩

noncomputable def Jet.lin (y : E) (c s : ℝ) (K : Jet E) : Jet E :=
  ⟨y + (c * s) • K.v, c • K.v + (c * s) • K.d₁, (2 * c) • K.d₁ + (c * s) • K.d₂,
    (3 * c) • K.d₂ + (c * s) • K.d₃⟩

noncomputable def jet₁ (y : E) : Jet E := ⟨G y, 0, 0, 0⟩

noncomputable def jet₂ (y : E) (s : ℝ) : Jet E :=
  (Jet.lin y (1 / 2) s (jet₁ G y)).app G G₁ G₂ G₃

noncomputable def jet₃ (y : E) (s : ℝ) : Jet E :=
  (Jet.lin y (1 / 2) s (jet₂ G G₁ G₂ G₃ y s)).app G G₁ G₂ G₃

noncomputable def jet₄ (y : E) (s : ℝ) : Jet E :=
  (Jet.lin y 1 s (jet₃ G G₁ G₂ G₃ y s)).app G G₁ G₂ G₃

noncomputable def incJet (y : E) (s : ℝ) : Jet E :=
  ⟨(6 : ℝ)⁻¹ • ((jet₁ G y).v + (2 : ℝ) • (jet₂ G G₁ G₂ G₃ y s).v +
      (2 : ℝ) • (jet₃ G G₁ G₂ G₃ y s).v + (jet₄ G G₁ G₂ G₃ y s).v),
    (6 : ℝ)⁻¹ • ((jet₁ G y).d₁ + (2 : ℝ) • (jet₂ G G₁ G₂ G₃ y s).d₁ +
      (2 : ℝ) • (jet₃ G G₁ G₂ G₃ y s).d₁ + (jet₄ G G₁ G₂ G₃ y s).d₁),
    (6 : ℝ)⁻¹ • ((jet₁ G y).d₂ + (2 : ℝ) • (jet₂ G G₁ G₂ G₃ y s).d₂ +
      (2 : ℝ) • (jet₃ G G₁ G₂ G₃ y s).d₂ + (jet₄ G G₁ G₂ G₃ y s).d₂),
    (6 : ℝ)⁻¹ • ((jet₁ G y).d₃ + (2 : ℝ) • (jet₂ G G₁ G₂ G₃ y s).d₃ +
      (2 : ℝ) • (jet₃ G G₁ G₂ G₃ y s).d₃ + (jet₄ G G₁ G₂ G₃ y s).d₃)⟩

noncomputable def E₂ (y : E) : E := G₁ y (G y)

noncomputable def E₃ (y : E) : E := G₂ y (G y) (G y) + G₁ y (E₂ G G₁ y)

noncomputable def E₄ (y : E) : E :=
  G₃ y (G y) (G y) (G y) + G₂ y (E₂ G G₁ y) (G y) + (2 : ℝ) • G₂ y (G y) (E₂ G G₁ y) +
    G₁ y (E₃ G G₁ G₂ y)

def Chain (J : ℝ → Jet E) (s : ℝ) : Prop :=
  HasDerivAt (fun r => (J r).v) (J s).d₁ s ∧ HasDerivAt (fun r => (J r).d₁) (J s).d₂ s ∧
    HasDerivAt (fun r => (J r).d₂) (J s).d₃ s

variable {G G₁ G₂ G₃}

theorem chain_app (hG : ∀ x, HasFDerivAt G (G₁ x) x) (hG₁ : ∀ x, HasFDerivAt G₁ (G₂ x) x)
    (hG₂ : ∀ x, HasFDerivAt G₂ (G₃ x) x) {J : ℝ → Jet E} {s : ℝ} (hJ : Chain J s) :
    Chain (fun r => (J r).app G G₁ G₂ G₃) s := by
  obtain ⟨h₀, h₁, h₂⟩ := hJ
  have c₁ := HasFDerivAt.comp_hasDerivAt (l := G₁) s (hG₁ (J s).v) h₀
  have c₂ := HasFDerivAt.comp_hasDerivAt (l := G₂) s (hG₂ (J s).v) h₀
  refine ⟨(hG (J s).v).comp_hasDerivAt s h₀, c₁.clm_apply h₁, ?_⟩
  have := ((c₂.clm_apply h₁).clm_apply h₁).add (c₁.clm_apply h₂)
  refine this.congr_deriv ?_
  simp only [Jet.app, add_apply, Function.comp_apply]
  rw [two_smul]
  abel

theorem chain_lin {K : ℝ → Jet E} {s : ℝ} (y : E) (c : ℝ) (hK : Chain K s) :
    Chain (fun r => Jet.lin y c r (K r)) s := by
  obtain ⟨h₀, h₁, h₂⟩ := hK
  have hc : HasDerivAt (fun r : ℝ => c * r) c s := by
    simpa using (hasDerivAt_id' s).const_mul c
  refine ⟨?_, ?_, ?_⟩
  · refine ((hc.smul h₀).const_add y).congr_deriv ?_
    simp only [Jet.lin]
    abel
  · refine ((h₀.const_smul c).add (hc.smul h₁)).congr_deriv ?_
    simp only [Jet.lin]
    module
  · refine ((h₁.const_smul (2 * c)).add (hc.smul h₂)).congr_deriv ?_
    simp only [Jet.lin]
    module

theorem chain_jet₁ (y : E) (s : ℝ) : Chain (fun _ => jet₁ G y) s :=
  ⟨hasDerivAt_const s _, hasDerivAt_const s _, hasDerivAt_const s _⟩

theorem chain_inc (hG : ∀ x, HasFDerivAt G (G₁ x) x) (hG₁ : ∀ x, HasFDerivAt G₁ (G₂ x) x)
    (hG₂ : ∀ x, HasFDerivAt G₂ (G₃ x) x) (y : E) (s : ℝ) :
    Chain (incJet G G₁ G₂ G₃ y) s := by
  have ha := chain_jet₁ (G := G) y s
  have hb : Chain (jet₂ G G₁ G₂ G₃ y) s :=
    chain_app hG hG₁ hG₂ (chain_lin (K := fun _ => jet₁ G y) y (1 / 2) ha)
  have hc : Chain (jet₃ G G₁ G₂ G₃ y) s :=
    chain_app hG hG₁ hG₂ (chain_lin y (1 / 2) hb)
  have he : Chain (jet₄ G G₁ G₂ G₃ y) s :=
    chain_app hG hG₁ hG₂ (chain_lin y 1 hc)
  obtain ⟨a₀, a₁, a₂⟩ := ha
  obtain ⟨b₀, b₁, b₂⟩ := hb
  obtain ⟨c₀, c₁, c₂⟩ := hc
  obtain ⟨e₀, e₁, e₂⟩ := he
  exact ⟨(((a₀.add (b₀.const_smul (2 : ℝ))).add (c₀.const_smul (2 : ℝ))).add e₀).const_smul _,
    (((a₁.add (b₁.const_smul (2 : ℝ))).add (c₁.const_smul (2 : ℝ))).add e₁).const_smul _,
    (((a₂.add (b₂.const_smul (2 : ℝ))).add (c₂.const_smul (2 : ℝ))).add e₂).const_smul _⟩

theorem incJet_v (y : E) (s : ℝ) : (incJet G G₁ G₂ G₃ y s).v = inc G y s := by
  simp only [incJet, jet₁, jet₂, jet₃, jet₄, Jet.app, Jet.lin, inc, incT, slope₁, slope₂,
    slope₃, slope₄]
  ring_nf

theorem inc_deriv (hG : ∀ x, HasFDerivAt G (G₁ x) x) (hG₁ : ∀ x, HasFDerivAt G₁ (G₂ x) x)
    (hG₂ : ∀ x, HasFDerivAt G₂ (G₃ x) x) (y : E) (s : ℝ) :
    HasDerivAt (fun r => inc G y r) (incJet G G₁ G₂ G₃ y s).d₁ s ∧
    HasDerivAt (fun r => (incJet G G₁ G₂ G₃ y r).d₁) (incJet G G₁ G₂ G₃ y s).d₂ s ∧
    HasDerivAt (fun r => (incJet G G₁ G₂ G₃ y r).d₂) (incJet G G₁ G₂ G₃ y s).d₃ s := by
  obtain ⟨h₀, h₁, h₂⟩ := chain_inc hG hG₁ hG₂ y s
  refine ⟨?_, h₁, h₂⟩
  simpa only [incJet_v] using h₀

theorem order_conditions (y : E) :
    (incJet G G₁ G₂ G₃ y 0).v = G y ∧
    (incJet G G₁ G₂ G₃ y 0).d₁ = (2 : ℝ)⁻¹ • E₂ G G₁ y ∧
    (incJet G G₁ G₂ G₃ y 0).d₂ = (3 : ℝ)⁻¹ • E₃ G G₁ G₂ y ∧
    (incJet G G₁ G₂ G₃ y 0).d₃ = (4 : ℝ)⁻¹ • E₄ G G₁ G₂ G₃ y := by
  simp only [incJet, jet₁, jet₂, jet₃, jet₄, Jet.app, Jet.lin, E₂, E₃, E₄, mul_zero, zero_smul,
    add_zero, map_smul, map_add, map_zero, smul_apply, zero_apply, smul_zero, zero_add]
  refine ⟨by module, by module, by module, by module⟩

theorem local_error (hG : ∀ x, HasFDerivAt G (G₁ x) x) (hG₁ : ∀ x, HasFDerivAt G₁ (G₂ x) x)
    (hG₂ : ∀ x, HasFDerivAt G₂ (G₃ x) x) {Y : ℝ → E} {t h M₅ N₄ : ℝ} (hh : 0 ≤ h)
    (hY : ∀ s ∈ Icc t (t + h), HasDerivAt Y (G (Y s)) s)
    (hM : ∀ s ∈ Icc t (t + h), ‖E₄ G G₁ G₂ G₃ (Y s) - E₄ G G₁ G₂ G₃ (Y t)‖ ≤ M₅ * (s - t))
    (hN : ∀ s ∈ Icc 0 h,
      ‖(incJet G G₁ G₂ G₃ (Y t) s).d₃ - (incJet G G₁ G₂ G₃ (Y t) 0).d₃‖ ≤ N₄ * s) :
    ‖Y (t + h) - Y t - h • inc G (Y t) h‖ ≤ (M₅ / 120 + N₄ / 24) * h ^ 5 := by
  have hY₁ : ∀ s ∈ Icc t (t + h), HasDerivAt (fun r => G (Y r)) (E₂ G G₁ (Y s)) s :=
    fun s hs => (hG (Y s)).comp_hasDerivAt s (hY s hs)
  have hY₂ : ∀ s ∈ Icc t (t + h),
      HasDerivAt (fun r => E₂ G G₁ (Y r)) (E₃ G G₁ G₂ (Y s)) s := fun s hs =>
    (HasFDerivAt.comp_hasDerivAt (l := G₁) s (hG₁ (Y s)) (hY s hs)).clm_apply (hY₁ s hs)
  have hY₃ : ∀ s ∈ Icc t (t + h),
      HasDerivAt (fun r => E₃ G G₁ G₂ (Y r)) (E₄ G G₁ G₂ G₃ (Y s)) s := by
    intro s hs
    have hJ : Chain (fun r => (⟨Y r, G (Y r), E₂ G G₁ (Y r), E₃ G G₁ G₂ (Y r)⟩ : Jet E)) s :=
      ⟨hY s hs, hY₁ s hs, hY₂ s hs⟩
    exact (chain_app hG hG₁ hG₂ hJ).2.2
  let fY : ℕ → ℝ → E := fun j => match j with
    | 0 => Y
    | 1 => fun r => G (Y r)
    | 2 => fun r => E₂ G G₁ (Y r)
    | 3 => fun r => E₃ G G₁ G₂ (Y r)
    | _ => fun r => E₄ G G₁ G₂ G₃ (Y r)
  have hfY : ∀ j < 4, ∀ x ∈ Icc t (t + h), HasDerivAt (fY j) (fY (j + 1) x) x := by
    intro j hj x hx
    interval_cases j
    exacts [hY x hx, hY₁ x hx, hY₂ x hx, hY₃ x hx]
  have TY := taylor_bound 4 hfY hM (t + h) ⟨by linarith, le_rfl⟩
  have hc := chain_inc hG hG₁ hG₂ (Y t)
  let fΦ : ℕ → ℝ → E := fun j => match j with
    | 0 => fun s => (incJet G G₁ G₂ G₃ (Y t) s).v
    | 1 => fun s => (incJet G G₁ G₂ G₃ (Y t) s).d₁
    | 2 => fun s => (incJet G G₁ G₂ G₃ (Y t) s).d₂
    | _ => fun s => (incJet G G₁ G₂ G₃ (Y t) s).d₃
  have hfΦ : ∀ j < 3, ∀ x ∈ Icc 0 h, HasDerivAt (fΦ j) (fΦ (j + 1) x) x := by
    intro j hj x _
    interval_cases j
    exacts [(hc x).1, (hc x).2.1, (hc x).2.2]
  have hNΦ : ∀ x ∈ Icc 0 h, ‖fΦ 3 x - fΦ 3 0‖ ≤ N₄ * (x - 0) := by
    intro x hx
    rw [sub_zero]
    exact hN x hx
  have TΦ := taylor_bound 3 hfΦ hNΦ h ⟨hh, le_rfl⟩
  obtain ⟨o₀, o₁, o₂, o₃⟩ := order_conditions (G := G) (G₁ := G₁) (G₂ := G₂) (G₃ := G₃) (Y t)
  set PY := poly (fun j => fY j t) t (t + h) (4 + 1) with hPY
  set PΦ := poly (fun j => fΦ j 0) 0 h (3 + 1) with hPΦ
  have hzero : PY - Y t - h • PΦ = 0 := by
    simp only [hPY, hPΦ, poly, Finset.sum_range_succ, Finset.sum_range_zero, fY, fΦ, o₀, o₁, o₂,
      o₃, add_sub_cancel_left, sub_zero, Nat.factorial, Nat.cast_one, Nat.cast_ofNat, zero_add,
      pow_zero, pow_one, div_one, one_smul, Nat.succ_eq_add_one, Nat.reduceAdd, Nat.reduceMul]
    module
  have key : Y (t + h) - Y t - h • inc G (Y t) h =
      (Y (t + h) - PY) - h • ((incJet G G₁ G₂ G₃ (Y t) h).v - PΦ) + (PY - Y t - h • PΦ) := by
    rw [incJet_v, smul_sub]
    abel
  rw [key, hzero, add_zero]
  have hf5 : ((4 + 1).factorial : ℝ) = 120 := by norm_num [Nat.factorial]
  have hf4 : ((3 + 1).factorial : ℝ) = 24 := by norm_num [Nat.factorial]
  rw [add_sub_cancel_left, hf5] at TY
  rw [sub_zero, hf4] at TΦ
  calc ‖Y (t + h) - PY - h • ((incJet G G₁ G₂ G₃ (Y t) h).v - PΦ)‖
      ≤ ‖Y (t + h) - PY‖ + ‖h • ((incJet G G₁ G₂ G₃ (Y t) h).v - PΦ)‖ := norm_sub_le _ _
    _ = ‖Y (t + h) - PY‖ + h * ‖(incJet G G₁ G₂ G₃ (Y t) h).v - PΦ‖ := by
        rw [norm_smul, Real.norm_of_nonneg hh]
    _ ≤ M₅ * h ^ (4 + 1) / 120 + h * (N₄ * h ^ (3 + 1) / 24) := by gcongr; exacts [TY, TΦ]
    _ = (M₅ / 120 + N₄ / 24) * h ^ 5 := by ring

end Jet

theorem convergence {F : ℝ → E → E} {G₁ : ℝ × E → ℝ × E →L[ℝ] ℝ × E}
    {G₂ : ℝ × E → ℝ × E →L[ℝ] ℝ × E →L[ℝ] ℝ × E}
    {G₃ : ℝ × E → ℝ × E →L[ℝ] ℝ × E →L[ℝ] ℝ × E →L[ℝ] ℝ × E}
    {Y : ℝ → E} {t₀ h L M₅ N₄ : ℝ} {N : ℕ} (hh : 0 < h) (hL : 0 < L)
    (hG : ∀ p, HasFDerivAt (auto F) (G₁ p) p) (hG₁ : ∀ p, HasFDerivAt G₁ (G₂ p) p)
    (hG₂ : ∀ p, HasFDerivAt G₂ (G₃ p) p)
    (hY : ∀ s ∈ Icc t₀ (t₀ + N * h), HasDerivAt Y (F s (Y s)) s)
    (hlip : ∀ s ∈ Icc t₀ (t₀ + N * h), ∀ y z, ‖F s y - F s z‖ ≤ L * ‖y - z‖)
    (hM : ∀ k < N, ∀ s ∈ Icc (t₀ + k * h) (t₀ + k * h + h),
      ‖E₄ (auto F) G₁ G₂ G₃ (s, Y s) - E₄ (auto F) G₁ G₂ G₃ (t₀ + k * h, Y (t₀ + k * h))‖ ≤
        M₅ * (s - (t₀ + k * h)))
    (hN : ∀ k < N, ∀ s ∈ Icc 0 h,
      ‖(incJet (auto F) G₁ G₂ G₃ (t₀ + k * h, Y (t₀ + k * h)) s).d₃ -
        (incJet (auto F) G₁ G₂ G₃ (t₀ + k * h, Y (t₀ + k * h)) 0).d₃‖ ≤ N₄ * s) :
    ∀ k ≤ N, ‖rk4 F t₀ h (Y t₀) k - Y (t₀ + k * h)‖ ≤
      (M₅ / 120 + N₄ / 24) * h ^ 4 / L * (Real.exp (L * (k * h)) - 1) := by
  rcases Nat.eq_zero_or_pos N with rfl | hNpos
  · intro k hk
    obtain rfl : k = 0 := Nat.le_zero.mp hk
    simp [rk4, iterate]
  have hM0 : 0 ≤ M₅ := by
    have h1 := hM 0 hNpos (t₀ + ((0 : ℕ) : ℝ) * h + h) ⟨by linarith, le_rfl⟩
    have h2 : 0 ≤ M₅ * h := by
      refine (norm_nonneg _).trans (h1.trans_eq ?_)
      ring
    exact nonneg_of_mul_nonneg_left h2 hh
  have hN0 : 0 ≤ N₄ := by
    have h1 := hN 0 hNpos h ⟨hh.le, le_rfl⟩
    exact nonneg_of_mul_nonneg_left ((norm_nonneg _).trans h1) hh
  have hτ : 0 ≤ (M₅ / 120 + N₄ / 24) * h ^ 5 := by positivity
  have htr : ∀ k < N, ‖Y (t₀ + (k + 1) * h) - Y (t₀ + k * h) -
      h • incT F (t₀ + k * h) (Y (t₀ + k * h)) h‖ ≤ (M₅ / 120 + N₄ / 24) * h ^ 5 := by
    intro k hk
    have hYa : ∀ s ∈ Icc (t₀ + k * h) (t₀ + k * h + h),
        HasDerivAt (fun r => ((r, Y r) : ℝ × E)) (auto F (s, Y s)) s :=
      fun s hs => (hasDerivAt_id' s).prodMk (hY s (grid hh.le hk hs))
    have hloc := local_error hG hG₁ hG₂ (Y := fun r => ((r, Y r) : ℝ × E)) (t := t₀ + k * h)
      hh.le hYa (hM k hk) (hN k hk)
    rw [inc_autonomous] at hloc
    have e : t₀ + ((k : ℝ) + 1) * h = t₀ + k * h + h := by ring
    rw [e]
    refine le_trans (le_of_eq ?_) hloc
    simp only [Prod.mk_sub_mk, Prod.smul_mk, smul_eq_mul, mul_one, Prod.norm_mk,
      add_sub_cancel_left, sub_self, norm_zero]
    exact (max_eq_right (norm_nonneg _)).symm
  intro k hk
  have := global_error hh hL hτ hlip htr k hk
  calc _ ≤ (M₅ / 120 + N₄ / 24) * h ^ 5 / (h * L) * (Real.exp (L * (k * h)) - 1) := this
    _ = (M₅ / 120 + N₄ / 24) * h ^ 4 / L * (Real.exp (L * (k * h)) - 1) := by
        field_simp

end Diana.Real.RK4
