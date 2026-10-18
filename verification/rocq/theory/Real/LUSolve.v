From Stdlib Require Import Reals Lra Lia Psatz.
From Diana.Real Require Import Cholesky Substitution LU.
Open Scope R_scope.

(* Row i of P_k b is entry pperm p k i of b: P_k interchanges rows k' and p k' for
   k' = 0, ..., k - 1, in that order. *)
Fixpoint pperm (p : nat -> nat) (k i : nat) : nat :=
  match k with
  | O => i
  | S k' => pperm p k' (tau k' (p k') i)
  end.

(* Its inverse. *)
Fixpoint ipperm (p : nat -> nat) (k i : nat) : nat :=
  match k with
  | O => i
  | S k' => tau k' (p k') (ipperm p k' i)
  end.

(* The solution of A x = b from a packed factor F of P A = L U (L strictly below the diagonal
   with an implicit unit diagonal, U on and above it) and its pivot rows p: the interchanges
   give P b, forward substitution solves L y = P b and back substitution U x = y, U read as the
   transpose of the lower-triangular fun k i => F i k. *)
Definition solution (F : nat -> nat -> R) (p : nat -> nat) (b : nat -> R) (n : nat) : nat -> R :=
  bwd (fun k i => F i k) (fwd (lo F) (fun i => b (pperm p n i))) n.

(* The pivot rows of the factorization of A in exact arithmetic. *)
Definition pivots (A : nat -> nat -> R) (n k : nat) : nat := pivot rops n k (state rops n A k).

(* The row order of the factorization is the interchanges of its pivot rows, for any number
   type. *)
Lemma pperm_perm {T : Type} (o : ops T) (n : nat) (A : nat -> nat -> T) (k i : nat) :
  perm o n A k i = pperm (fun k' => pivot o n k' (state o n A k')) k i.
Proof.
  revert i. induction k as [| k IH]; intro i; [reflexivity |]. simpl. apply IH.
Qed.

Lemma pperm_ipperm (p : nat -> nat) (k i : nat) : pperm p k (ipperm p k i) = i.
Proof.
  revert i. induction k as [| k IH]; intro i; [reflexivity |]. simpl. rewrite tau_tau. apply IH.
Qed.

Lemma pperm_range (p : nat -> nat) (n k i : nat) :
  (forall k', (k' < k)%nat -> (p k' < n)%nat) -> (k <= n)%nat -> (i < n)%nat ->
  (pperm p k i < n)%nat.
Proof.
  revert i. induction k as [| k IH]; intros i Hp Hk Hi; [exact Hi |].
  simpl. apply IH; [intros; apply Hp; lia | lia |].
  apply tau_lt; [lia | apply Hp; lia | exact Hi].
Qed.

Lemma ipperm_range (p : nat -> nat) (n k i : nat) :
  (forall k', (k' < k)%nat -> (p k' < n)%nat) -> (k <= n)%nat -> (i < n)%nat ->
  (ipperm p k i < n)%nat.
Proof.
  revert i. induction k as [| k IH]; intros i Hp Hk Hi; [exact Hi |].
  simpl. apply tau_lt; [lia | apply Hp; lia |].
  apply IH; [intros; apply Hp; lia | lia | exact Hi].
Qed.

Lemma pperm_inj (p : nat -> nat) (k i j : nat) : pperm p k i = pperm p k j -> i = j.
Proof.
  revert i j. induction k as [| k IH]; intros i j H; [exact H |].
  simpl in H. apply IH in H.
  rewrite <- (tau_tau k (p k) i), H. apply tau_tau.
Qed.

(* Layer A, the interchanges form a permutation: when every pivot row is below n, whatever its
   order, row i of P b is entry pperm p n i of b and i -> pperm p n i maps [0, n) onto [0, n)
   one to one. *)
Theorem interchange_permutation (p : nat -> nat) (n : nat) :
  (forall k, (k < n)%nat -> (p k < n)%nat) ->
  (forall i, (i < n)%nat -> (pperm p n i < n)%nat) /\
  (forall i j, pperm p n i = pperm p n j -> i = j) /\
  (forall i, (i < n)%nat -> exists j, (j < n)%nat /\ pperm p n j = i).
Proof.
  intro Hp. split; [| split].
  - intros i Hi. apply pperm_range; [exact Hp | lia | exact Hi].
  - intros i j. apply pperm_inj.
  - intros i Hi. exists (ipperm p n i). split; [apply ipperm_range; [exact Hp | lia | exact Hi] |].
    apply pperm_ipperm.
Qed.

(* Layer A, the solve with a packed factor: when the diagonal of U has no zero, the solution
   satisfies L U x = P b on the indices below n. *)
Theorem factor_solve (F : nat -> nat -> R) (p : nat -> nat) (b : nat -> R) (n : nat) :
  (forall i, (i < n)%nat -> F i i <> 0) ->
  forall i, (i < n)%nat ->
  sum n (fun t => lo F i t * sum n (fun j => up F t j * solution F p b n j)) = b (pperm p n i).
Proof.
  intros Hd i Hi.
  set (c := fun i => b (pperm p n i)).
  set (y := fwd (lo F) c).
  assert (Hux : forall t, (t < n)%nat -> sum n (fun j => up F t j * solution F p b n j) = y t).
  { intros t Ht. rewrite (sum_split t n) by lia.
    rewrite (sum_zero t) by (intros j Hj; unfold up;
                             replace (t <=? j)%nat with false by (symmetry; apply Nat.leb_gt; lia);
                             ring).
    rewrite Rplus_0_l.
    rewrite <- (back_solve (fun k i => F i k) y n t Ht (Hd t Ht)).
    apply sum_ext. intros s Hs. unfold up.
    replace (t <=? t + s)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity. }
  rewrite (sum_ext n _ (fun t => lo F i t * y t))
    by (intros t Ht; rewrite Hux by exact Ht; reflexivity).
  rewrite (sum_trunc _ (S i) n) by
    (lia || (intros t H1 H2; unfold lo;
             replace (t <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia);
             replace (t =? i)%nat with false by (symmetry; apply Nat.eqb_neq; lia); ring)).
  change (b (pperm p n i)) with (c i).
  apply forward_solve. unfold lo. rewrite Nat.ltb_irrefl, Nat.eqb_refl. lra.
Qed.

(* Layer A, solving with the factors of partial pivoting: when every pivot of A is nonzero
   (the C's test in diana_lu), the solution from lu A n and its pivot rows solves A x = b on the
   indices below n. *)
Theorem lu_solve (A : nat -> nat -> R) (n : nat) (b : nat -> R) :
  (forall k, (k < n)%nat -> ptop A n k <> 0) ->
  forall i, (i < n)%nat ->
  sum n (fun j => A i j * solution (lu A n) (pivots A n) b n j) = b i.
Proof.
  intros Ht i Hi.
  set (x := solution (lu A n) (pivots A n) b n).
  set (i0 := iperm rops n A n i).
  assert (Hi0 : (i0 < n)%nat) by (apply iperm_range; lia).
  assert (Hrow : prow A n i0 = i) by apply perm_iperm.
  transitivity (sum n (fun j => sum n (fun t => lo (lu A n) i0 t * up (lu A n) t j) * x j)).
  { apply sum_ext. intros j Hj. rewrite pivot_product by assumption. rewrite Hrow. reflexivity. }
  transitivity (sum n (fun t => lo (lu A n) i0 t * sum n (fun j => up (lu A n) t j * x j))).
  { rewrite (sum_ext n _ (fun j => sum n (fun t => lo (lu A n) i0 t * up (lu A n) t j * x j)))
      by (intros j Hj; rewrite <- sum_scal_r; reflexivity).
    rewrite sum_comm. apply sum_ext. intros t Ht'. rewrite <- sum_scal_l.
    apply sum_ext. intros; ring. }
  unfold x. rewrite factor_solve; [| intros k Hk; apply lu_diag_nonzero; auto | exact Hi0].
  f_equal. rewrite <- Hrow. unfold prow. symmetry. apply pperm_perm.
Qed.
