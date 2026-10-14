import Mathlib.Topology.Order.IntermediateValue
import Mathlib.Tactic

namespace Diana.Real.Bisect

open Set

noncomputable def step (f : ℝ → ℝ) (p : ℝ × ℝ) : ℝ × ℝ :=
  if f ((p.1 + p.2) / 2) = 0 then ((p.1 + p.2) / 2, (p.1 + p.2) / 2)
  else if (0 < f ((p.1 + p.2) / 2) ↔ 0 < f p.1) then ((p.1 + p.2) / 2, p.2)
  else (p.1, (p.1 + p.2) / 2)

noncomputable def iter (f : ℝ → ℝ) (a b : ℝ) : ℕ → ℝ × ℝ
  | 0 => (a, b)
  | n + 1 => step f (iter f a b n)

def SignChange (f : ℝ → ℝ) (a b : ℝ) : Prop :=
  f a * f b < 0 ∨ (a = b ∧ f a = 0)

def Bracket (f : ℝ → ℝ) (p : ℝ × ℝ) : Prop :=
  p.1 ≤ p.2 ∧ SignChange f p.1 p.2

theorem step_le {f : ℝ → ℝ} {p : ℝ × ℝ} (h : p.1 ≤ p.2) : (step f p).1 ≤ (step f p).2 := by
  unfold step
  split_ifs <;> dsimp only <;> linarith

theorem step_nested {f : ℝ → ℝ} {p : ℝ × ℝ} (h : p.1 ≤ p.2) :
    p.1 ≤ (step f p).1 ∧ (step f p).2 ≤ p.2 := by
  unfold step
  split_ifs <;> dsimp only <;> constructor <;> linarith

theorem step_width {f : ℝ → ℝ} {p : ℝ × ℝ} (h : p.1 ≤ p.2) :
    (step f p).2 - (step f p).1 ≤ (p.2 - p.1) / 2 := by
  unfold step
  split_ifs <;> dsimp only <;> linarith

theorem step_bracket {f : ℝ → ℝ} {p : ℝ × ℝ} (h : Bracket f p) : Bracket f (step f p) := by
  obtain ⟨hle, hs⟩ := h
  have hm1 : p.1 ≤ (p.1 + p.2) / 2 := by linarith
  have hm2 : (p.1 + p.2) / 2 ≤ p.2 := by linarith
  have hcol : p.1 = p.2 → f p.1 = 0 → f ((p.1 + p.2) / 2) = 0 := by
    intro heq hfa
    have : (p.1 + p.2) / 2 = p.1 := by rw [← heq]; ring
    rw [this, hfa]
  unfold step Bracket SignChange
  split_ifs with h0 hsg <;> dsimp only
  · exact ⟨le_rfl, Or.inr ⟨rfl, h0⟩⟩
  · refine ⟨hm2, Or.inl ?_⟩
    rcases hs with hs | ⟨heq, hfa⟩
    · have hfa0 : f p.1 ≠ 0 := fun e => by rw [e] at hs; simp at hs
      rcases lt_or_gt_of_ne h0 with hneg | hpos
      · have ha : f p.1 < 0 := by
          have : ¬ 0 < f p.1 := fun hc => absurd (hsg.mpr hc) (not_lt.mpr hneg.le)
          exact lt_of_le_of_ne (not_lt.mp this) hfa0
        have hb : 0 < f p.2 := by nlinarith
        nlinarith
      · have ha : 0 < f p.1 := hsg.mp hpos
        have hb : f p.2 < 0 := by nlinarith
        nlinarith
    · exact absurd (hcol heq hfa) h0
  · refine ⟨hm1, Or.inl ?_⟩
    rcases hs with hs | ⟨heq, hfa⟩
    · have hfa0 : f p.1 ≠ 0 := fun e => by rw [e] at hs; simp at hs
      rcases lt_or_gt_of_ne h0 with hneg | hpos
      · have ha : 0 < f p.1 := by
          by_contra hc
          exact hsg ⟨fun hm => absurd hm (not_lt.mpr hneg.le), fun hc' => absurd hc' hc⟩
        nlinarith
      · have ha : f p.1 < 0 := by
          have : ¬ 0 < f p.1 := fun hc => hsg ⟨fun _ => hc, fun _ => hpos⟩
          exact lt_of_le_of_ne (not_lt.mp this) hfa0
        nlinarith
    · exact absurd (hcol heq hfa) h0

theorem iter_le_sub {f : ℝ → ℝ} {a b : ℝ} (hab : a ≤ b) (n : ℕ) :
    a ≤ (iter f a b n).1 ∧ (iter f a b n).1 ≤ (iter f a b n).2 ∧ (iter f a b n).2 ≤ b := by
  induction n with
  | zero => exact ⟨le_rfl, hab, le_rfl⟩
  | succ n ih =>
    obtain ⟨h1, h2, h3⟩ := ih
    have hn := step_nested (f := f) h2
    have hl := step_le (f := f) h2
    simp only [iter]
    exact ⟨le_trans h1 hn.1, hl, le_trans hn.2 h3⟩

theorem bracket_width {f : ℝ → ℝ} {a b : ℝ} (hab : a ≤ b) (hs : SignChange f a b) (n : ℕ) :
    Bracket f (iter f a b n) ∧ (iter f a b n).2 - (iter f a b n).1 ≤ (b - a) / 2 ^ n := by
  induction n with
  | zero => exact ⟨⟨hab, hs⟩, by simp [iter]⟩
  | succ n ih =>
    obtain ⟨hb, hw⟩ := ih
    refine ⟨step_bracket hb, ?_⟩
    have hsw := step_width (f := f) hb.1
    simp only [iter]
    calc (step f (iter f a b n)).2 - (step f (iter f a b n)).1
        ≤ ((iter f a b n).2 - (iter f a b n).1) / 2 := hsw
      _ ≤ (b - a) / 2 ^ n / 2 := by gcongr
      _ = (b - a) / 2 ^ (n + 1) := by rw [pow_succ]; ring

theorem converge {f : ℝ → ℝ} {a b : ℝ} (hab : a ≤ b) (hf : ContinuousOn f (Icc a b))
    (hs : SignChange f a b) (n : ℕ) :
    ∃ x ∈ Icc (iter f a b n).1 (iter f a b n).2, f x = 0 ∧
      |((iter f a b n).1 + (iter f a b n).2) / 2 - x| ≤ (b - a) / 2 ^ (n + 1) := by
  obtain ⟨⟨hle, hsc⟩, hw⟩ := bracket_width hab hs n
  obtain ⟨hsub1, _, hsub2⟩ := iter_le_sub (f := f) hab n
  set p := iter f a b n with hp
  have hfc : ContinuousOn f (Icc p.1 p.2) := hf.mono (Icc_subset_Icc hsub1 hsub2)
  have hzero : ∃ x ∈ Icc p.1 p.2, f x = 0 := by
    rcases hsc with hsc | ⟨heq, hfa⟩
    · rcases lt_or_ge (f p.1) 0 with h1 | h1
      · have h2 : 0 ≤ f p.2 := by nlinarith
        exact intermediate_value_Icc hle hfc ⟨h1.le, h2⟩
      · have h1' : 0 < f p.1 := by
          rcases lt_or_eq_of_le h1 with h | h
          · exact h
          · rw [← h] at hsc; simp at hsc
        have h2 : f p.2 ≤ 0 := by nlinarith
        exact intermediate_value_Icc' hle hfc ⟨h2, h1'.le⟩
    · exact ⟨p.1, ⟨le_rfl, hle⟩, hfa⟩
  obtain ⟨x, ⟨hx1, hx2⟩, hfx⟩ := hzero
  refine ⟨x, ⟨hx1, hx2⟩, hfx, ?_⟩
  have e : (b - a) / 2 ^ (n + 1) = (b - a) / 2 ^ n / 2 := by rw [pow_succ]; ring
  rw [e, abs_le]
  constructor <;> linarith

end Diana.Real.Bisect
