module

public import Diana.Real.Substitution

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.LU

open Finset
open Cholesky (sum_trunc)
open Substitution (bwd back_solve back_unique forward_unique fwd_zero)

/-- The operations of the factorization over a number type: the real ones `rops` below, the
binary64 ones of the C in the Rocq `Diana.Float.LU`. `omag` is the magnitude the pivot search
compares with `ogt` (`x > y`), starting from `ozero`. -/
structure ops (T : Type*) where
  osub : T → T → T
  omul : T → T → T
  odiv : T → T → T
  omag : T → T
  ogt : T → T → Bool
  ozero : T

section Generic

variable {T : Type*} (o : ops T)

/-- The C's pivot search over rows `k, …, k + t - 1` of column `k`: the first row of largest
magnitude and that magnitude; `(k, ozero)` while no magnitude exceeds `ozero`. -/
def search (B : ℕ → ℕ → T) (k : ℕ) : ℕ → ℕ × T
  | 0 => (k, o.ozero)
  | t + 1 =>
    let pm := search B k t
    if o.ogt (o.omag (B (k + t) k)) pm.2 then (k + t, o.omag (B (k + t) k)) else pm

/-- The pivot row of step `k`. -/
def pivot (n k : ℕ) (B : ℕ → ℕ → T) : ℕ := (search o B k (n - k)).1

/-- The magnitude of the pivot of step `k`, which the C tests against zero. -/
def top (n k : ℕ) (B : ℕ → ℕ → T) : T := (search o B k (n - k)).2

/-- Rows `r` and `s` interchanged, across every column. -/
def swap (r s : ℕ) (B : ℕ → ℕ → T) (i j : ℕ) : T :=
  if i = r then B s j else if i = s then B r j else B i j

/-- Elimination step `k`: the multipliers `B i k / B k k` below the pivot, then
`B i j - (B i k / B k k) * B k j` right of them; every other entry is kept. -/
def elim (k : ℕ) (B : ℕ → ℕ → T) (i j : ℕ) : T :=
  if k < i then
    if j = k then o.odiv (B i k) (B k k)
    else if k < j then o.osub (B i j) (o.omul (o.odiv (B i k) (B k k)) (B k j))
    else B i j
  else B i j

/-- The working matrix of the C after steps `0, …, k - 1` with partial pivoting: step `k'` swaps
row `k'` with the pivot row, then eliminates. `A i j` is `a[i + j*n]`. -/
def state (n : ℕ) (A : ℕ → ℕ → T) : ℕ → ℕ → ℕ → T
  | 0 => A
  | k + 1 =>
    let B := state n A k
    elim o k (swap k (pivot o n k B) B)

/-- The same steps without pivoting (Doolittle). -/
def nstate (B : ℕ → ℕ → T) : ℕ → ℕ → ℕ → T
  | 0 => B
  | k + 1 => elim o k (nstate B k)

/-- The transposition of `r` and `s`. -/
def tau (r s i : ℕ) : ℕ := if i = r then s else if i = s then r else i

/-- Row `i` of `P_k A` is row `perm n A k i` of `A`, `P_k` the product of the first `k`
interchanges. -/
def perm (n : ℕ) (A : ℕ → ℕ → T) : ℕ → ℕ → ℕ
  | 0, i => i
  | k + 1, i => perm n A k (tau k (pivot o n k (state o n A k)) i)

/-- The inverse of `perm`. -/
def iperm (n : ℕ) (A : ℕ → ℕ → T) : ℕ → ℕ → ℕ
  | 0, i => i
  | k + 1, i => tau k (pivot o n k (state o n A k)) (iperm n A k i)

/-- The rows of `A` in the order `p`: row `i` is row `p i` of `A`. -/
def permute (p : ℕ → ℕ) (A : ℕ → ℕ → T) (i j : ℕ) : T := A (p i) j

/-- `B i j - L i 0 * U 0 j - … - L i (k-1) * U (k-1) j`, each product formed first, subtracted
in order, with the multipliers `L i t = nstate B (t + 1) i t` and the pivot rows
`U t j = nstate B t t j`. -/
def dot (B : ℕ → ℕ → T) (i j : ℕ) : ℕ → T
  | 0 => B i j
  | k + 1 => o.osub (dot B i j k) (o.omul (nstate o B (k + 1) i k) (nstate o B k k j))

theorem swap_congr (r s : ℕ) {B C : ℕ → ℕ → T} (h : ∀ i j, B i j = C i j) (i j : ℕ) :
    swap r s B i j = swap r s C i j := by
  simp only [swap, h]

theorem elim_congr (k : ℕ) {B C : ℕ → ℕ → T} (h : ∀ i j, B i j = C i j) (i j : ℕ) :
    elim o k B i j = elim o k C i j := by
  simp only [elim, h]

theorem nstate_congr {B C : ℕ → ℕ → T} (k : ℕ) (h : ∀ i j, B i j = C i j) (i j : ℕ) :
    nstate o B k i j = nstate o C k i j := by
  rw [funext₂ h]

theorem search_range (B : ℕ → ℕ → T) (k : ℕ) :
    ∀ t, k ≤ (search o B k t).1 ∧ ((search o B k t).1 = k ∨ (search o B k t).1 < k + t)
  | 0 => ⟨le_rfl, Or.inl rfl⟩
  | t + 1 => by
    have ih := search_range B k t
    simp only [search]
    split
    · dsimp only
      omega
    · omega

theorem search_congr {B C : ℕ → ℕ → T} (k : ℕ) :
    ∀ t, (∀ i, k ≤ i → i < k + t → B i k = C i k) → search o B k t = search o C k t
  | 0, _ => rfl
  | t + 1, h => by
    simp only [search]
    rw [search_congr k t fun i h1 h2 => h i h1 (by omega), h (k + t) (by omega) (by omega)]

theorem pivot_range (n k : ℕ) (B : ℕ → ℕ → T) (h : k < n) :
    k ≤ pivot o n k B ∧ pivot o n k B < n := by
  have := search_range o B k (n - k)
  unfold pivot
  omega

theorem pivot_ge (n k : ℕ) (B : ℕ → ℕ → T) : k ≤ pivot o n k B :=
  (search_range o B k (n - k)).1

theorem pivot_congr (n k : ℕ) {B C : ℕ → ℕ → T} (h : ∀ i j, B i j = C i j) :
    pivot o n k B = pivot o n k C ∧ top o n k B = top o n k C := by
  unfold pivot top
  rw [search_congr o k (n - k) fun i _ _ => h i k]
  exact ⟨rfl, rfl⟩

theorem tau_ge {r s i m : ℕ} (hr : m ≤ r) (hs : m ≤ s) (hi : m ≤ i) : m ≤ tau r s i := by
  unfold tau
  split_ifs <;> omega

theorem tau_lt {r s i n : ℕ} (hr : r < n) (hs : s < n) (hi : i < n) : tau r s i < n := by
  unfold tau
  split_ifs <;> omega

theorem tau_low {r s i : ℕ} (hr : i < r) (hs : i < s) : tau r s i = i := by
  unfold tau
  split_ifs <;> omega

theorem tau_left (r s : ℕ) : tau r s r = s := ite_eq_left rfl

theorem tau_tau (r s i : ℕ) : tau r s (tau r s i) = i := by
  unfold tau
  split_ifs <;> omega

theorem swap_tau (r s : ℕ) (B : ℕ → ℕ → T) (i j : ℕ) : swap r s B i j = B (tau r s i) j := by
  unfold swap tau
  split_ifs <;> rfl

/-- Elimination step `k` treats each row below `k` on its own, with row `k` as the pivot row, so
it commutes with interchanging two rows below `k`. -/
theorem elim_swap (k r s : ℕ) (B : ℕ → ℕ → T) (hr : k < r) (hs : k < s) :
    elim o k (swap r s B) = swap r s (elim o k B) := by
  funext i j
  have hk : tau r s k = k := tau_low hr hs
  have hi : k < tau r s i ↔ k < i := by
    unfold tau
    split_ifs <;> omega
  simp only [elim, swap_tau, hk, hi]

theorem nstate_swap (r s : ℕ) (B : ℕ → ℕ → T) :
    ∀ k, k ≤ r → k ≤ s → nstate o (swap r s B) k = swap r s (nstate o B k)
  | 0, _, _ => rfl
  | k + 1, hr, hs => by
    show elim o k (nstate o (swap r s B) k) = swap r s (elim o k (nstate o B k))
    rw [nstate_swap r s B k (by omega) (by omega), elim_swap o k r s _ (by omega) (by omega)]

theorem swap_permute (r s : ℕ) (p : ℕ → ℕ) (A : ℕ → ℕ → T) :
    swap r s (permute p A) = permute (fun i => p (tau r s i)) A := by
  funext i j
  rw [swap_tau]
  rfl

/-- The pivoted factorization is the unpivoted one of `P_k A`, with `P_k` the interchanges it
chose: rows interchanged later are untouched by the earlier steps. -/
theorem state_nstate (n : ℕ) (A : ℕ → ℕ → T) :
    ∀ k, state o n A k = nstate o (permute (perm o n A k) A) k
  | 0 => rfl
  | k + 1 => by
    have hp := pivot_ge o n k (state o n A k)
    show elim o k (swap k (pivot o n k (state o n A k)) (state o n A k)) =
      elim o k (nstate o
        (permute (fun i => perm o n A k (tau k (pivot o n k (state o n A k)) i)) A) k)
    rw [← swap_permute, nstate_swap o _ _ _ k le_rfl hp, ← state_nstate n A k]

/-- Row `i` is final after step `i`. -/
theorem nstate_row (B : ℕ → ℕ → T) (k i j : ℕ) (h : i ≤ k) :
    nstate o B k i j = nstate o B i i j := by
  induction k with
  | zero => rw [Nat.le_zero.mp h]
  | succ k ih =>
    rcases Nat.lt_or_ge i (k + 1) with hlt | hge
    · show elim o k (nstate o B k) i j = _
      rw [elim, ite_eq_right (by omega)]
      exact ih (by omega)
    · rw [show i = k + 1 by omega]

/-- Column `j` is final after step `j`. -/
theorem nstate_col (B : ℕ → ℕ → T) (k i j : ℕ) (hjk : j < k) :
    nstate o B k i j = nstate o B (j + 1) i j := by
  induction k with
  | zero => exact absurd hjk (Nat.not_lt_zero _)
  | succ k ih =>
    rcases Nat.lt_or_ge j k with hlt | hge
    · show elim o k (nstate o B k) i j = _
      rw [elim, ite_eq_right (show j ≠ k by omega), ite_eq_right (show ¬k < j by omega),
        ite_self]
      exact ih hlt
    · rw [show k = j by omega]

/-- An entry not yet final is its `dot`: `B i j` minus the products of the steps so far. -/
theorem nstate_dot (B : ℕ → ℕ → T) (k i j : ℕ) (hi : k ≤ i) (hj : k ≤ j) :
    nstate o B k i j = dot o B i j k := by
  induction k with
  | zero => rfl
  | succ k ih =>
    have hm : elim o k (nstate o B k) i k = o.odiv (nstate o B k i k) (nstate o B k k k) := by
      rw [elim, ite_eq_left (show k < i by omega), ite_eq_left rfl]
    show elim o k (nstate o B k) i j =
      o.osub (dot o B i j k) (o.omul (elim o k (nstate o B k) i k) (nstate o B k k j))
    rw [hm, elim, ite_eq_left (show k < i by omega), ite_eq_right (show j ≠ k by omega),
      ite_eq_left (show k < j by omega), ih (by omega) (by omega)]

/-- The multiplier of row `i > j` at step `j`. -/
theorem nstate_mult (B : ℕ → ℕ → T) (i j : ℕ) (h : j < i) :
    nstate o B (j + 1) i j = o.odiv (dot o B i j j) (dot o B j j j) := by
  show elim o j (nstate o B j) i j = _
  rw [elim, ite_eq_left h, ite_eq_left rfl, nstate_dot o B j i j h.le le_rfl,
    nstate_dot o B j j j le_rfl le_rfl]

/-- Rows above `k` are final in the pivoted factorization too. -/
theorem state_row (n : ℕ) (A : ℕ → ℕ → T) (k m i j : ℕ) (hik : i < k) (hkm : k ≤ m) :
    state o n A m i j = state o n A k i j := by
  induction m with
  | zero => exact absurd hkm (by omega)
  | succ m ih =>
    rcases Nat.lt_or_ge k (m + 1) with hlt | hge
    · have hp := pivot_ge o n m (state o n A m)
      show elim o m (swap m (pivot o n m (state o n A m)) (state o n A m)) i j = _
      rw [elim, ite_eq_right (show ¬m < i by omega), swap_tau, tau_low (by omega) (by omega)]
      exact ih (by omega)
    · rw [show k = m + 1 by omega]

/-- The value at `(k, k)` after step `k` is the pivot the search chose. -/
theorem state_diag (n : ℕ) (A : ℕ → ℕ → T) (k : ℕ) :
    state o n A (k + 1) k k = state o n A k (pivot o n k (state o n A k)) k := by
  show elim o k (swap k (pivot o n k (state o n A k)) (state o n A k)) k k = _
  rw [elim, ite_eq_right (lt_irrefl k), swap_tau, tau_left]

theorem perm_iperm (n : ℕ) (A : ℕ → ℕ → T) : ∀ k i, perm o n A k (iperm o n A k i) = i
  | 0, _ => rfl
  | k + 1, i => by
    simp only [perm, iperm, tau_tau]
    exact perm_iperm n A k i

theorem perm_range (n : ℕ) (A : ℕ → ℕ → T) : ∀ k i, k ≤ n → i < n → perm o n A k i < n
  | 0, _, _, hi => hi
  | k + 1, i, hk, hi => by
    simp only [perm]
    exact perm_range n A k _ (by omega) (tau_lt (by omega) (pivot_range o n k _ (by omega)).2 hi)

theorem iperm_range (n : ℕ) (A : ℕ → ℕ → T) : ∀ k i, k ≤ n → i < n → iperm o n A k i < n
  | 0, _, _, hi => hi
  | k + 1, i, hk, hi => by
    simp only [iperm]
    exact tau_lt (by omega) (pivot_range o n k _ (by omega)).2 (iperm_range n A k i (by omega) hi)

theorem perm_inj (n : ℕ) (A : ℕ → ℕ → T) : ∀ k i j, perm o n A k i = perm o n A k j → i = j
  | 0, _, _, h => h
  | k + 1, i, j, h => by
    simp only [perm] at h
    rw [← tau_tau k (pivot o n k (state o n A k)) i, perm_inj n A k _ _ h, tau_tau]

end Generic

/-- Layer A, the pivot rows form a permutation, for any number type: each pivot row of step `k`
is in `[k, n)`, and row `i` of `P A` is row `perm n A n i` of `A`, a bijection of `[0, n)`. -/
theorem permutation {T : Type*} (o : ops T) (A : ℕ → ℕ → T) (n : ℕ) :
    (∀ k < n, k ≤ pivot o n k (state o n A k) ∧ pivot o n k (state o n A k) < n) ∧
    (∀ i < n, perm o n A n i < n) ∧
    (∀ i j, perm o n A n i = perm o n A n j → i = j) ∧
    (∀ i < n, ∃ j < n, perm o n A n j = i) :=
  ⟨fun k hk => pivot_range o n k _ hk, fun i hi => perm_range o n A n i le_rfl hi,
    perm_inj o n A n,
    fun i hi => ⟨iperm o n A n i, iperm_range o n A n i le_rfl hi, perm_iperm o n A n i⟩⟩

/-- `x > y` on the reals, as a `Bool`. -/
noncomputable def rgt (x y : ℝ) : Bool := decide (y < x)

/-- The real operations: exact arithmetic, magnitudes compared with `<`. -/
noncomputable def rops : ops ℝ where
  osub x y := x - y
  omul x y := x * y
  odiv x y := x / y
  omag x := |x|
  ogt := rgt
  ozero := 0

/-- The factorization of `A` with partial pivoting in exact arithmetic, packed: `L` strictly
below the diagonal, `U` on and above it. -/
noncomputable def lu (A : ℕ → ℕ → ℝ) (n : ℕ) : ℕ → ℕ → ℝ := state rops n A n

/-- Row `i` of `P A` is row `prow A n i` of `A`. -/
noncomputable def prow (A : ℕ → ℕ → ℝ) (n : ℕ) : ℕ → ℕ := perm rops n A n

/-- The magnitude of the pivot of step `k`, which the C tests against zero. -/
noncomputable def ptop (A : ℕ → ℕ → ℝ) (n k : ℕ) : ℝ := top rops n k (state rops n A k)

/-- The unit lower-triangular factor of a packed matrix `F`. -/
def lo (F : ℕ → ℕ → ℝ) (i t : ℕ) : ℝ :=
  if t < i then F i t else if t = i then 1 else 0

/-- The upper-triangular factor of a packed matrix `F`. -/
def up (F : ℕ → ℕ → ℝ) (t j : ℕ) : ℝ := if t ≤ j then F t j else 0

theorem rops_div (x y : ℝ) : rops.odiv x y = x / y := rfl

theorem lo_lower {F : ℕ → ℕ → ℝ} {i t : ℕ} (h : t < i) : lo F i t = F i t := ite_eq_left h

theorem lo_diag (F : ℕ → ℕ → ℝ) (i : ℕ) : lo F i i = 1 := by simp [lo]

theorem lo_upper {F : ℕ → ℕ → ℝ} {i t : ℕ} (h : i < t) : lo F i t = 0 := by
  simp [lo, not_lt.mpr h.le, h.ne']

theorem up_upper {F : ℕ → ℕ → ℝ} {t j : ℕ} (h : t ≤ j) : up F t j = F t j := ite_eq_left h

theorem up_lower {F : ℕ → ℕ → ℝ} {t j : ℕ} (h : j < t) : up F t j = 0 := ite_eq_right (not_le.mpr h)

theorem rdot_sum (B : ℕ → ℕ → ℝ) (i j : ℕ) :
    ∀ k, dot rops B i j k =
      B i j - ∑ t ∈ range k, nstate rops B (t + 1) i t * nstate rops B t t j
  | 0 => by simp [dot]
  | k + 1 => by
    rw [sum_range_succ, ← sub_sub, ← rdot_sum B i j k]
    rfl

/-- The products of the steps before `k`, read from the final matrix. -/
theorem rdot_final (B : ℕ → ℕ → ℝ) (n i j k : ℕ) (hn : k ≤ n) :
    dot rops B i j k = B i j - ∑ t ∈ range k, nstate rops B n i t * nstate rops B n t j := by
  rw [rdot_sum]
  congr 1
  refine sum_congr rfl fun t ht => ?_
  have := mem_range.mp ht
  rw [nstate_col rops B n i t (by omega), nstate_row rops B n t j (by omega)]

/-- Layer A, correctness of the unpivoted factorization: once the pivots `U k k`, `k < n`, are
nonzero, `L U = B` on the indices below `n`. -/
theorem product (B : ℕ → ℕ → ℝ) (n : ℕ) (hp : ∀ k < n, nstate rops B k k k ≠ 0) :
    ∀ i < n, ∀ j < n,
      ∑ t ∈ range n, lo (nstate rops B n) i t * up (nstate rops B n) t j = B i j := by
  intro i hi j hj
  rcases le_or_gt i j with hij | hji
  · rw [sum_trunc _ (by omega : i + 1 ≤ n) (fun t ht _ => by rw [lo_upper (by omega), zero_mul]),
      sum_range_succ, lo_diag, one_mul, up_upper hij, nstate_row rops B n i j hi.le,
      nstate_dot rops B i i j le_rfl hij, rdot_final B n i j i hi.le]
    have hs : ∑ t ∈ range i, lo (nstate rops B n) i t * up (nstate rops B n) t j =
        ∑ t ∈ range i, nstate rops B n i t * nstate rops B n t j :=
      sum_congr rfl fun t ht => by
        have := mem_range.mp ht
        rw [lo_lower this, up_upper (by omega)]
    rw [hs]
    ring
  · rw [sum_trunc _ (by omega : j + 1 ≤ n) (fun t ht _ => by rw [up_lower (by omega), mul_zero]),
      sum_range_succ, lo_lower hji, up_upper le_rfl]
    have hd : nstate rops B n j j = dot rops B j j j := by
      rw [nstate_row rops B n j j hj.le, nstate_dot rops B j j j le_rfl le_rfl]
    have hnz : nstate rops B n j j ≠ 0 := by
      rw [nstate_row rops B n j j hj.le]
      exact hp j hj
    have hm : nstate rops B n i j * nstate rops B n j j =
        B i j - ∑ t ∈ range j, nstate rops B n i t * nstate rops B n t j := by
      rw [nstate_col rops B n i j hj, nstate_mult rops B i j hji, rops_div, ← hd,
        div_mul_cancel₀ _ hnz, rdot_final B n i j j hj.le]
    have hs : ∑ t ∈ range j, lo (nstate rops B n) i t * up (nstate rops B n) t j =
        ∑ t ∈ range j, nstate rops B n i t * nstate rops B n t j :=
      sum_congr rfl fun t ht => by
        have := mem_range.mp ht
        rw [lo_lower (by omega), up_upper this.le]
    rw [hs, hm]
    ring

theorem rsearch_spec (B : ℕ → ℕ → ℝ) (k : ℕ) :
    ∀ t, 0 ≤ (search rops B k t).2 ∧
      (∀ i, k ≤ i → i < k + t → |B i k| ≤ (search rops B k t).2) ∧
      ((search rops B k t).2 = 0 ∧ (search rops B k t).1 = k ∨
        (search rops B k t).2 = |B (search rops B k t).1 k|)
  | 0 => ⟨le_rfl, fun _ _ h => absurd h (by omega), Or.inl ⟨rfl, rfl⟩⟩
  | t + 1 => by
    obtain ⟨h0, hle, hv⟩ := rsearch_spec B k t
    have hs : search rops B k (t + 1) =
        if (search rops B k t).2 < |B (k + t) k| then (k + t, |B (k + t) k|)
        else search rops B k t := by
      by_cases hlt : (search rops B k t).2 < |B (k + t) k|
      · rw [ite_eq_left hlt]
        exact ite_eq_left (decide_eq_true hlt)
      · rw [ite_eq_right hlt]
        exact ite_eq_right fun h => hlt (of_decide_eq_true h)
    rw [hs]
    split_ifs with hlt
    · refine ⟨abs_nonneg _, fun i h1 h2 => ?_, Or.inr rfl⟩
      rcases Nat.lt_or_ge i (k + t) with h | h
      · exact (hle i h1 h).trans hlt.le
      · obtain rfl : i = k + t := by omega
        exact le_rfl
    · refine ⟨h0, fun i h1 h2 => ?_, hv⟩
      rcases Nat.lt_or_ge i (k + t) with h | h
      · exact hle i h1 h
      · obtain rfl : i = k + t := by omega
        exact not_lt.mp hlt

/-- The pivot has the largest magnitude in its column, and that magnitude is the one tested. -/
theorem rtop_spec (B : ℕ → ℕ → ℝ) (n k : ℕ) (hk : k < n) :
    top rops n k B = |B (pivot rops n k B) k| ∧
      ∀ i, k ≤ i → i < n → |B i k| ≤ top rops n k B := by
  obtain ⟨_, hle, hv⟩ := rsearch_spec B k (n - k)
  refine ⟨?_, fun i h1 h2 => hle i h1 (by omega)⟩
  unfold top pivot
  rcases hv with ⟨hz, hp⟩ | hv
  · have h := hle k le_rfl (by omega)
    rw [hz] at h
    rw [hz, hp]
    exact (le_antisymm h (abs_nonneg _)).symm
  · exact hv

/-- The pivot `U k k` of the factorization is the pivot entry of step `k`. -/
theorem lu_diag (A : ℕ → ℕ → ℝ) (n k : ℕ) (hk : k < n) :
    lu A n k k = state rops n A k (pivot rops n k (state rops n A k)) k := by
  unfold lu
  rw [state_row rops n A (k + 1) n k k (by omega) hk, state_diag]

theorem lu_diag_nonzero (A : ℕ → ℕ → ℝ) (n k : ℕ) (hk : k < n) (ht : ptop A n k ≠ 0) :
    lu A n k k ≠ 0 := by
  rw [lu_diag A n k hk]
  intro E
  apply ht
  unfold ptop
  rw [(rtop_spec _ n k hk).1, E, abs_zero]

/-- Layer A, correctness with partial pivoting: when every pivot is nonzero (the C's test),
`P A = L U` on the indices below `n`, `L` unit lower triangular and `U` upper triangular from
the packed `lu A n`. -/
theorem pivot_product (A : ℕ → ℕ → ℝ) (n : ℕ) (ht : ∀ k < n, ptop A n k ≠ 0) :
    ∀ i < n, ∀ j < n, ∑ t ∈ range n, lo (lu A n) i t * up (lu A n) t j = A (prow A n i) j := by
  intro i hi j hj
  have E : lu A n = nstate rops (permute (prow A n) A) n := state_nstate rops n A n
  rw [E]
  refine product _ n (fun k hk => ?_) i hi j hj
  rw [← nstate_row rops _ n k k hk.le, ← E]
  exact lu_diag_nonzero A n k hk (ht k hk)

theorem div_le_1 {x d : ℝ} (h : |x| ≤ |d|) : |x / d| ≤ 1 := by
  rcases eq_or_ne d 0 with rfl | hd
  · simp
  · rw [abs_div, div_le_one (abs_pos.mpr hd)]
    exact h

/-- Layer A, partial pivoting bounds the multipliers: `|L i j| ≤ 1`. -/
theorem multiplier_bound (A : ℕ → ℕ → ℝ) (n : ℕ) :
    ∀ i j, j < i → i < n → |lu A n i j| ≤ 1 := by
  intro i j hji hin
  have hm : ∀ m, j < m → m ≤ n → ∀ r, j < r → r < n → |state rops n A m r j| ≤ 1 := by
    intro m
    induction m with
    | zero => exact fun h => absurd h (Nat.not_lt_zero _)
    | succ m ih =>
      intro hjm hmn r hr hrn
      have hp := pivot_range rops n m (state rops n A m) (by omega)
      show |elim rops m (swap m (pivot rops n m (state rops n A m)) (state rops n A m)) r j| ≤ 1
      rcases Nat.lt_or_ge j m with hlt | hge
      · rw [elim, ite_eq_right (show j ≠ m by omega), ite_eq_right (show ¬m < j by omega), ite_self,
          swap_tau]
        refine ih hlt (by omega) _ ?_ (tau_lt (by omega) hp.2 hrn)
        unfold tau
        split_ifs <;> omega
      · rw [show m = j by omega] at hp ⊢
        rw [elim, ite_eq_left hr, ite_eq_left rfl, rops_div, swap_tau, swap_tau, tau_left]
        obtain ⟨htop, hle⟩ := rtop_spec (state rops n A j) n j (by omega)
        exact div_le_1 ((hle _ (tau_ge le_rfl hp.1 hr.le) (tau_lt (by omega) hp.2 hrn)).trans_eq
          htop)
  exact hm n (by omega) le_rfl i hji hin

/-- Layer A, a matrix whose pivots are all nonzero is nonsingular: `A x = 0` on the indices
below `n` only for `x = 0` there. -/
theorem nonsingular (A : ℕ → ℕ → ℝ) (n : ℕ) (ht : ∀ k < n, ptop A n k ≠ 0) :
    ∀ x : ℕ → ℝ, (∀ i < n, ∑ j ∈ range n, A i j * x j = 0) → ∀ j < n, x j = 0 := by
  intro x hx
  obtain ⟨y, hy⟩ : ∃ y : ℕ → ℝ, y = fun t => ∑ j ∈ range n, up (lu A n) t j * x j := ⟨_, rfl⟩
  have hfwd : ∀ i < n, ∑ t ∈ range (i + 1), lo (lu A n) i t * y t = 0 := by
    intro i hi
    rw [← sum_trunc (fun t => lo (lu A n) i t * y t) (by omega : i + 1 ≤ n)
      (fun t ht _ => by rw [lo_upper (by omega), zero_mul])]
    calc ∑ t ∈ range n, lo (lu A n) i t * y t
        = ∑ j ∈ range n, (∑ t ∈ range n, lo (lu A n) i t * up (lu A n) t j) * x j := by
          simp only [hy, mul_sum, sum_mul]
          rw [sum_comm]
          exact sum_congr rfl fun _ _ => sum_congr rfl fun _ _ => by ring
      _ = ∑ j ∈ range n, A (prow A n i) j * x j :=
          sum_congr rfl fun j hj => by rw [pivot_product A n ht i hi j (mem_range.mp hj)]
      _ = 0 := hx _ ((permutation rops A n).2.1 i hi)
  have hy0 : ∀ i < n, y i = 0 := fun i hi => by
    rw [forward_unique (L := lo (lu A n)) (b := fun _ => 0)
      (fun i _ => by rw [lo_diag]; exact one_ne_zero) hfwd i hi, fwd_zero]
  have hd : ∀ i < n, up (lu A n) i i ≠ 0 := fun i hi => by
    rw [up_upper le_rfl]
    exact lu_diag_nonzero A n i hi (ht i hi)
  have hb : ∀ i < n, ∑ k ∈ Ico i n, up (lu A n) i k * x k = 0 := fun i hi => by
    rw [← hy0 i hi, hy]
    dsimp only
    rw [← sum_range_add_sum_Ico _ hi.le, sum_eq_zero (s := range i)
      (fun k hk => by rw [up_lower (mem_range.mp hk), zero_mul]), zero_add]
  intro j hj
  rw [back_unique (L := fun a b => up (lu A n) b a) (b := fun _ => 0) hd hb j hj]
  exact fwd_zero _ _

/-- The unit lower-triangular factor of the unpivoted steps of `B`, read at the step each entry
is final. -/
noncomputable def nlo (B : ℕ → ℕ → ℝ) (i t : ℕ) : ℝ :=
  if t < i then nstate rops B (t + 1) i t else if t = i then 1 else 0

/-- The upper-triangular factor of the unpivoted steps of `B`, read at the step each entry is
final. -/
noncomputable def nup (B : ℕ → ℕ → ℝ) (t j : ℕ) : ℝ :=
  if t ≤ j then nstate rops B t t j else 0

theorem nlo_lower {B : ℕ → ℕ → ℝ} {i t : ℕ} (h : t < i) :
    nlo B i t = nstate rops B (t + 1) i t := ite_eq_left h

theorem nlo_diag (B : ℕ → ℕ → ℝ) (i : ℕ) : nlo B i i = 1 := by simp [nlo]

theorem nlo_upper {B : ℕ → ℕ → ℝ} {i t : ℕ} (h : i < t) : nlo B i t = 0 := by
  simp [nlo, not_lt.mpr h.le, h.ne']

theorem nup_upper {B : ℕ → ℕ → ℝ} {t j : ℕ} (h : t ≤ j) : nup B t j = nstate rops B t t j :=
  ite_eq_left h

theorem nup_lower {B : ℕ → ℕ → ℝ} {t j : ℕ} (h : j < t) : nup B t j = 0 :=
  ite_eq_right (not_le.mpr h)

/-- Column `j < m` of `B` is the combination of the first `m` columns of `nlo B`: the first `m`
steps factor the first `m` columns, for every row. -/
theorem column_product (B : ℕ → ℕ → ℝ) (m i j : ℕ) (hd : ∀ t < m, nstate rops B t t t ≠ 0)
    (hj : j < m) : B i j = ∑ t ∈ range m, nlo B i t * nup B t j := by
  rcases le_or_gt i j with hij | hji
  · rw [sum_trunc _ (by omega : i + 1 ≤ m) (fun t ht _ => by rw [nlo_upper (by omega), zero_mul]),
      sum_range_succ, nlo_diag, one_mul, nup_upper hij, nstate_dot rops B i i j le_rfl hij,
      rdot_sum]
    have hs : ∑ t ∈ range i, nlo B i t * nup B t j =
        ∑ t ∈ range i, nstate rops B (t + 1) i t * nstate rops B t t j :=
      sum_congr rfl fun t ht => by
        have := mem_range.mp ht
        rw [nlo_lower this, nup_upper (by omega)]
    rw [hs]
    ring
  · rw [sum_trunc _ (by omega : j + 1 ≤ m) (fun t ht _ => by rw [nup_lower (by omega), mul_zero]),
      sum_range_succ, nlo_lower hji, nup_upper le_rfl, nstate_mult rops B i j hji,
      ← nstate_dot rops B j j j le_rfl le_rfl, rops_div, div_mul_cancel₀ _ (hd j hj), rdot_sum]
    have hs : ∑ t ∈ range j, nlo B i t * nup B t j =
        ∑ t ∈ range j, nstate rops B (t + 1) i t * nstate rops B t t j :=
      sum_congr rfl fun t ht => by
        have := mem_range.mp ht
        rw [nlo_lower (by omega), nup_upper this.le]
    rw [hs]
    ring

/-- Layer A, a zero pivot means a singular matrix: if the pivots of the steps before `k` are
nonzero and every candidate of step `k` is zero, then `A x = 0` for some `x` with `x k = 1` and
`x j = 0` for `j > k`. With `nonsingular`, exact partial pivoting succeeds exactly on the
nonsingular matrices. -/
theorem singular (A : ℕ → ℕ → ℝ) (n k : ℕ) (hk : k < n) (ht : ∀ k' < k, ptop A n k' ≠ 0)
    (hz : ptop A n k = 0) :
    ∃ x : ℕ → ℝ, x k = 1 ∧ (∀ j, k < j → x j = 0) ∧
      ∀ i < n, ∑ j ∈ range n, A i j * x j = 0 := by
  obtain ⟨B, hB⟩ : ∃ B : ℕ → ℕ → ℝ, B = permute (perm rops n A k) A := ⟨_, rfl⟩
  have HS : state rops n A k = nstate rops B k := by
    rw [hB]
    exact state_nstate rops n A k
  have hcol : ∀ i, k ≤ i → i < n → nstate rops B k i k = 0 := by
    intro i h1 h2
    rw [← HS]
    have h := (rtop_spec (state rops n A k) n k hk).2 i h1 h2
    rw [show top rops n k (state rops n A k) = 0 from hz] at h
    exact abs_nonpos_iff.mp h
  have hd : ∀ t < k, nstate rops B t t t ≠ 0 := by
    intro t htk
    rw [← nstate_row rops B k t t htk.le, ← HS, state_row rops n A (t + 1) k t t (by omega) htk,
      state_diag]
    intro E
    apply ht t htk
    unfold ptop
    rw [(rtop_spec _ n t (by omega)).1, E, abs_zero]
  have hlast : ∀ i < n, B i k = ∑ t ∈ range k, nlo B i t * nstate rops B t t k := by
    intro i hi
    rcases Nat.lt_or_ge i k with hik | hki
    · rw [sum_trunc _ (by omega : i + 1 ≤ k)
        (fun t ht _ => by rw [nlo_upper (by omega), zero_mul]),
        sum_range_succ, nlo_diag, one_mul, nstate_dot rops B i i k le_rfl hik.le, rdot_sum]
      have hs : ∑ t ∈ range i, nlo B i t * nstate rops B t t k =
          ∑ t ∈ range i, nstate rops B (t + 1) i t * nstate rops B t t k :=
        sum_congr rfl fun t ht => by rw [nlo_lower (mem_range.mp ht)]
      rw [hs]
      ring
    · have h0 := hcol i hki hi
      rw [nstate_dot rops B k i k hki le_rfl, rdot_sum] at h0
      have hs : ∑ t ∈ range k, nlo B i t * nstate rops B t t k =
          ∑ t ∈ range k, nstate rops B (t + 1) i t * nstate rops B t t k :=
        sum_congr rfl fun t ht => by
          have := mem_range.mp ht
          rw [nlo_lower (by omega)]
      rw [hs]
      linarith
  obtain ⟨y, hy⟩ : ∃ y : ℕ → ℝ,
      y = bwd (fun a b => nstate rops B b b a) (fun t => nstate rops B t t k) k := ⟨_, rfl⟩
  have hback : ∀ t < k, ∑ j ∈ range k, nup B t j * y j = nstate rops B t t k := by
    intro t htk
    have hs := back_solve (L := fun a b => nstate rops B b b a)
      (b := fun t => nstate rops B t t k) htk (hd t htk)
    rw [← hy] at hs
    rw [← sum_range_add_sum_Ico _ htk.le, sum_eq_zero (s := range t)
      (fun j hj => by rw [nup_lower (mem_range.mp hj), zero_mul]), zero_add]
    refine Eq.trans (sum_congr rfl fun j hj => ?_) hs
    rw [nup_upper (mem_Ico.mp hj).1]
  refine ⟨fun j => if j < k then -y j else if j = k then 1 else 0, by simp,
    fun j hj => by simp [not_lt.mpr hj.le, hj.ne'], fun i hi => ?_⟩
  have hi0 : iperm rops n A k i < n := iperm_range rops n A k i hk.le hi
  have hA : ∀ j, A i j = B (iperm rops n A k i) j := fun j => by
    rw [hB]
    show A i j = A (perm rops n A k (iperm rops n A k i)) j
    rw [perm_iperm]
  have E : ∑ j ∈ range k, B (iperm rops n A k i) j * -y j =
      -∑ t ∈ range k, nlo B (iperm rops n A k i) t * nstate rops B t t k := by
    calc ∑ j ∈ range k, B (iperm rops n A k i) j * -y j
        = ∑ j ∈ range k, ∑ t ∈ range k,
            nlo B (iperm rops n A k i) t * (nup B t j * -y j) :=
          sum_congr rfl fun j hj => by
            rw [column_product B k _ j hd (mem_range.mp hj), sum_mul]
            exact sum_congr rfl fun t _ => by ring
      _ = ∑ t ∈ range k, nlo B (iperm rops n A k i) t * ∑ j ∈ range k, nup B t j * -y j := by
          rw [sum_comm]
          exact sum_congr rfl fun t _ => (mul_sum _ _ _).symm
      _ = ∑ t ∈ range k, nlo B (iperm rops n A k i) t * -nstate rops B t t k :=
          sum_congr rfl fun t ht => by
            rw [← hback t (mem_range.mp ht), ← sum_neg_distrib]
            simp only [mul_neg]
      _ = -∑ t ∈ range k, nlo B (iperm rops n A k i) t * nstate rops B t t k := by
          rw [← sum_neg_distrib]
          simp only [mul_neg]
  have hs : ∑ j ∈ range k, A i j * (if j < k then -y j else if j = k then 1 else 0) =
      ∑ j ∈ range k, B (iperm rops n A k i) j * -y j :=
    sum_congr rfl fun j hj => by rw [ite_eq_left (mem_range.mp hj), hA]
  rw [sum_trunc _ (by omega : k + 1 ≤ n) (fun j hj _ => by
      simp [not_lt.mpr (show k ≤ j by omega), show j ≠ k by omega]),
    sum_range_succ, hs]
  beta_reduce
  rw [ite_eq_right (lt_irrefl k), ite_eq_left rfl, mul_one, hA k, hlast _ hi0, E]
  ring

end Diana.Real.LU
