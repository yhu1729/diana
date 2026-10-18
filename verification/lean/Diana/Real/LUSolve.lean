module

public import Diana.Real.LU

import Mathlib.Tactic

@[expose] public section

namespace Diana.Real.LUSolve

open Finset
open Cholesky (sum_trunc)
open Substitution (bwd fwd back_solve forward_solve)
open LU (ops tau tau_tau tau_lt perm iperm pivot state rops lu prow ptop lo up lo_diag lo_upper
  up_lower up_upper pivot_product lu_diag_nonzero)

/-- Row `i` of `P_k b` is entry `pperm p k i` of `b`: `P_k` interchanges rows `k'` and `p k'`
for `k' = 0, …, k - 1`, in that order. -/
def pperm (p : ℕ → ℕ) : ℕ → ℕ → ℕ
  | 0, i => i
  | k + 1, i => pperm p k (tau k (p k) i)

/-- The inverse of `pperm`. -/
def ipperm (p : ℕ → ℕ) : ℕ → ℕ → ℕ
  | 0, i => i
  | k + 1, i => tau k (p k) (ipperm p k i)

/-- The solution of `A·x = b` from a packed factor `F` of `P·A = L·U` (`L` strictly below the
diagonal with an implicit unit diagonal, `U` on and above it) and its pivot rows `p`: the
interchanges give `P·b`, forward substitution solves `L·y = P·b` and back substitution
`U·x = y`, `U` read as the transpose of the lower-triangular `fun k i => F i k`. -/
noncomputable def solution (F : ℕ → ℕ → ℝ) (p : ℕ → ℕ) (b : ℕ → ℝ) (n : ℕ) : ℕ → ℝ :=
  bwd (fun k i => F i k) (fwd (lo F) (fun i => b (pperm p n i))) n

/-- The pivot rows of the factorization of `A` in exact arithmetic. -/
noncomputable def pivots (A : ℕ → ℕ → ℝ) (n k : ℕ) : ℕ := pivot rops n k (state rops n A k)

/-- The row order of the factorization is the interchanges of its pivot rows, for any number
type. -/
theorem pperm_perm {T : Type*} (o : ops T) (n : ℕ) (A : ℕ → ℕ → T) :
    ∀ k i, perm o n A k i = pperm (fun k' => pivot o n k' (state o n A k')) k i
  | 0, _ => rfl
  | k + 1, i => by
    simp only [perm, pperm]
    exact pperm_perm o n A k _

theorem pperm_ipperm (p : ℕ → ℕ) : ∀ k i, pperm p k (ipperm p k i) = i
  | 0, _ => rfl
  | k + 1, i => by
    simp only [pperm, ipperm, tau_tau]
    exact pperm_ipperm p k i

theorem pperm_range (p : ℕ → ℕ) (n : ℕ) :
    ∀ k i, (∀ k' < k, p k' < n) → k ≤ n → i < n → pperm p k i < n
  | 0, _, _, _, hi => hi
  | k + 1, i, hp, hk, hi => by
    simp only [pperm]
    exact pperm_range p n k _ (fun k' hk' => hp k' (by omega)) (by omega)
      (tau_lt (by omega) (hp k (by omega)) hi)

theorem ipperm_range (p : ℕ → ℕ) (n : ℕ) :
    ∀ k i, (∀ k' < k, p k' < n) → k ≤ n → i < n → ipperm p k i < n
  | 0, _, _, _, hi => hi
  | k + 1, i, hp, hk, hi => by
    simp only [ipperm]
    exact tau_lt (by omega) (hp k (by omega))
      (ipperm_range p n k i (fun k' hk' => hp k' (by omega)) (by omega) hi)

theorem pperm_inj (p : ℕ → ℕ) : ∀ k i j, pperm p k i = pperm p k j → i = j
  | 0, _, _, h => h
  | k + 1, i, j, h => by
    simp only [pperm] at h
    rw [← tau_tau k (p k) i, pperm_inj p k _ _ h, tau_tau]

/-- Layer A, the interchanges form a permutation: when every pivot row is below `n`, whatever
its order, row `i` of `P·b` is entry `pperm p n i` of `b` and `i ↦ pperm p n i` maps `[0, n)`
onto `[0, n)` one to one. -/
theorem interchange_permutation (p : ℕ → ℕ) (n : ℕ) (hp : ∀ k < n, p k < n) :
    (∀ i < n, pperm p n i < n) ∧ (∀ i j, pperm p n i = pperm p n j → i = j) ∧
    (∀ i < n, ∃ j < n, pperm p n j = i) :=
  ⟨fun i hi => pperm_range p n n i hp le_rfl hi, pperm_inj p n,
    fun i hi => ⟨ipperm p n i, ipperm_range p n n i hp le_rfl hi, pperm_ipperm p n i⟩⟩

/-- Layer A, the solve with a packed factor: when the diagonal of `U` has no zero, the solution
satisfies `L·U·x = P·b` on the indices below `n`. -/
theorem factor_solve {F : ℕ → ℕ → ℝ} {p : ℕ → ℕ} {b : ℕ → ℝ} {n : ℕ}
    (hd : ∀ i < n, F i i ≠ 0) :
    ∀ i < n, ∑ t ∈ range n, lo F i t * ∑ j ∈ range n, up F t j * solution F p b n j =
      b (pperm p n i) := by
  intro i hi
  have hux : ∀ t < n, ∑ j ∈ range n, up F t j * solution F p b n j =
      fwd (lo F) (fun i => b (pperm p n i)) t := by
    intro t ht
    rw [← sum_range_add_sum_Ico _ ht.le, sum_eq_zero (s := range t)
      (fun j hj => by rw [up_lower (mem_range.mp hj), zero_mul]), zero_add,
      ← back_solve (L := fun k i => F i k) (b := fwd (lo F) (fun i => b (pperm p n i))) ht
        (hd t ht)]
    exact sum_congr rfl fun j hj => by rw [up_upper (mem_Ico.mp hj).1]; rfl
  rw [sum_congr rfl fun t ht => by rw [hux t (mem_range.mp ht)],
    sum_trunc _ (by omega : i + 1 ≤ n) (fun t ht _ => by rw [lo_upper (by omega), zero_mul])]
  exact forward_solve (L := lo F) (b := fun i => b (pperm p n i))
    (by rw [lo_diag]; exact one_ne_zero)

/-- Layer A, solving with the factors of partial pivoting: when every pivot of `A` is nonzero
(the C's test in `diana_lu`), the solution from `lu A n` and its pivot rows solves `A·x = b` on
the indices below `n`. -/
theorem lu_solve (A : ℕ → ℕ → ℝ) (n : ℕ) (b : ℕ → ℝ) (ht : ∀ k < n, ptop A n k ≠ 0) :
    ∀ i < n, ∑ j ∈ range n, A i j * solution (lu A n) (pivots A n) b n j = b i := by
  intro i hi
  have hi0 := LU.iperm_range rops n A n i le_rfl hi
  have hrow : prow A n (iperm rops n A n i) = i := LU.perm_iperm rops n A n i
  have hp : pperm (pivots A n) n (iperm rops n A n i) = prow A n (iperm rops n A n i) :=
    (pperm_perm rops n A n _).symm
  calc ∑ j ∈ range n, A i j * solution (lu A n) (pivots A n) b n j
      = ∑ j ∈ range n, (∑ t ∈ range n, lo (lu A n) (iperm rops n A n i) t * up (lu A n) t j) *
          solution (lu A n) (pivots A n) b n j :=
        sum_congr rfl fun j hj => by rw [pivot_product A n ht _ hi0 j (mem_range.mp hj), hrow]
    _ = ∑ t ∈ range n, lo (lu A n) (iperm rops n A n i) t *
          ∑ j ∈ range n, up (lu A n) t j * solution (lu A n) (pivots A n) b n j := by
        simp only [mul_sum, sum_mul]
        rw [sum_comm]
        exact sum_congr rfl fun _ _ => sum_congr rfl fun _ _ => by ring
    _ = b (pperm (pivots A n) n (iperm rops n A n i)) :=
        factor_solve (fun k hk => lu_diag_nonzero A n k hk (ht k hk)) _ hi0
    _ = b i := by rw [hp, hrow]

end Diana.Real.LUSolve
