From Stdlib Require Import Reals Lra Lia Psatz.
From Diana.Real Require Import Cholesky Substitution.
Open Scope R_scope.

(* The operations of the factorization over a number type: the real ones below, the binary64
   ones of the C in Diana.Float.LU. omag is the magnitude the pivot search compares with ogt
   (x > y), starting from ozero. *)
Record ops (T : Type) := {
  osub : T -> T -> T;
  omul : T -> T -> T;
  odiv : T -> T -> T;
  omag : T -> T;
  ogt : T -> T -> bool;
  ozero : T
}.

Arguments osub {T}.
Arguments omul {T}.
Arguments odiv {T}.
Arguments omag {T}.
Arguments ogt {T}.
Arguments ozero {T}.

Section Generic.

Context {T : Type} (o : ops T).

(* The C's pivot search over rows k, ..., k + t - 1 of column k: the first row of largest
   magnitude and that magnitude; (k, ozero) while no magnitude exceeds ozero. *)
Fixpoint search (B : nat -> nat -> T) (k t : nat) : nat * T :=
  match t with
  | O => (k, ozero o)
  | S t' =>
      let pm := search B k t' in
      if ogt o (omag o (B (k + t')%nat k)) (snd pm) then ((k + t')%nat, omag o (B (k + t')%nat k))
      else pm
  end.

(* The pivot row of step k and the magnitude the C tests against zero. *)
Definition pivot (n k : nat) (B : nat -> nat -> T) : nat := fst (search B k (n - k)).
Definition top (n k : nat) (B : nat -> nat -> T) : T := snd (search B k (n - k)).

(* Rows r and s interchanged, across every column. *)
Definition swap (r s : nat) (B : nat -> nat -> T) (i j : nat) : T :=
  if (i =? r)%nat then B s j else if (i =? s)%nat then B r j else B i j.

(* Elimination step k: the multipliers B i k / B k k below the pivot, then
   B i j - (B i k / B k k) * B k j right of them; every other entry is kept. *)
Definition elim (k : nat) (B : nat -> nat -> T) (i j : nat) : T :=
  if (k <? i)%nat then
    if (j =? k)%nat then odiv o (B i k) (B k k)
    else if (k <? j)%nat then osub o (B i j) (omul o (odiv o (B i k) (B k k)) (B k j))
    else B i j
  else B i j.

(* The working matrix of the C after steps 0, ..., k - 1 with partial pivoting: step k' swaps
   row k' with the pivot row, then eliminates. A i j is a[i + j*n]. *)
Fixpoint state (n : nat) (A : nat -> nat -> T) (k : nat) : nat -> nat -> T :=
  match k with
  | O => A
  | S k' => let B := state n A k' in elim k' (swap k' (pivot n k' B) B)
  end.

(* The same steps without pivoting (Doolittle). *)
Fixpoint nstate (B : nat -> nat -> T) (k : nat) : nat -> nat -> T :=
  match k with
  | O => B
  | S k' => elim k' (nstate B k')
  end.

(* The transposition of r and s. *)
Definition tau (r s i : nat) : nat := if (i =? r)%nat then s else if (i =? s)%nat then r else i.

(* Row i of P_k A is row perm n A k i of A, P_k the product of the first k interchanges. *)
Fixpoint perm (n : nat) (A : nat -> nat -> T) (k i : nat) : nat :=
  match k with
  | O => i
  | S k' => perm n A k' (tau k' (pivot n k' (state n A k')) i)
  end.

(* Its inverse. *)
Fixpoint iperm (n : nat) (A : nat -> nat -> T) (k i : nat) : nat :=
  match k with
  | O => i
  | S k' => tau k' (pivot n k' (state n A k')) (iperm n A k' i)
  end.

Definition permute (p : nat -> nat) (A : nat -> nat -> T) (i j : nat) : T := A (p i) j.

(* B i j - L i 0 * U 0 j - ... - L i (k-1) * U (k-1) j, each product formed first, subtracted
   in order, with the multipliers L i t = nstate B (t + 1) i t and the pivot rows
   U t j = nstate B t t j. *)
Fixpoint dot (B : nat -> nat -> T) (i j k : nat) : T :=
  match k with
  | O => B i j
  | S k' => osub o (dot B i j k') (omul o (nstate B (S k') i k') (nstate B k' k' j))
  end.

Lemma swap_congr (r s : nat) (B C : nat -> nat -> T) :
  (forall i j, B i j = C i j) -> forall i j, swap r s B i j = swap r s C i j.
Proof. intros H i j. unfold swap. rewrite !H. reflexivity. Qed.

Lemma elim_congr (k : nat) (B C : nat -> nat -> T) :
  (forall i j, B i j = C i j) -> forall i j, elim k B i j = elim k C i j.
Proof. intros H i j. unfold elim. rewrite !H. reflexivity. Qed.

Lemma nstate_congr (B C : nat -> nat -> T) (k : nat) :
  (forall i j, B i j = C i j) -> forall i j, nstate B k i j = nstate C k i j.
Proof.
  intro H. induction k as [| k IH]; intros i j; [apply H |].
  simpl. apply elim_congr. exact IH.
Qed.

Lemma search_range (B : nat -> nat -> T) (k t : nat) :
  (k <= fst (search B k t))%nat /\ (fst (search B k t) = k \/ (fst (search B k t) < k + t)%nat).
Proof.
  induction t as [| t IH]; simpl; [lia |].
  destruct (ogt o _ _); simpl; lia.
Qed.

Lemma search_congr (B C : nat -> nat -> T) (k t : nat) :
  (forall i, (k <= i < k + t)%nat -> B i k = C i k) -> search B k t = search C k t.
Proof.
  induction t as [| t IH]; intro H; [reflexivity |].
  simpl. rewrite IH by (intros; apply H; lia). rewrite H by lia. reflexivity.
Qed.

Lemma pivot_range (n k : nat) (B : nat -> nat -> T) :
  (k < n)%nat -> (k <= pivot n k B < n)%nat.
Proof. intro H. unfold pivot. pose proof (search_range B k (n - k)). lia. Qed.

Lemma pivot_ge (n k : nat) (B : nat -> nat -> T) : (k <= pivot n k B)%nat.
Proof. unfold pivot. apply search_range. Qed.

Lemma pivot_congr (n k : nat) (B C : nat -> nat -> T) :
  (forall i j, B i j = C i j) -> pivot n k B = pivot n k C /\ top n k B = top n k C.
Proof.
  intro H. unfold pivot, top. rewrite (search_congr B C) by (intros; apply H). split; reflexivity.
Qed.

Lemma tau_ge (r s i m : nat) : (m <= r)%nat -> (m <= s)%nat -> (m <= i)%nat -> (m <= tau r s i)%nat.
Proof. intros. unfold tau. destruct (i =? r)%nat, (i =? s)%nat; lia. Qed.

Lemma tau_lt (r s i n : nat) : (r < n)%nat -> (s < n)%nat -> (i < n)%nat -> (tau r s i < n)%nat.
Proof. intros. unfold tau. destruct (i =? r)%nat, (i =? s)%nat; lia. Qed.

Lemma tau_low (r s i : nat) : (i < r)%nat -> (i < s)%nat -> tau r s i = i.
Proof.
  intros. unfold tau.
  replace (i =? r)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
  replace (i =? s)%nat with false by (symmetry; apply Nat.eqb_neq; lia). reflexivity.
Qed.

Lemma tau_tau (r s i : nat) : tau r s (tau r s i) = i.
Proof.
  unfold tau. destruct (Nat.eqb_spec i r); destruct (Nat.eqb_spec i s); simpl;
    repeat (match goal with |- context [(?x =? ?y)%nat] => destruct (Nat.eqb_spec x y) end;
            simpl); lia.
Qed.

Lemma swap_tau (r s : nat) (B : nat -> nat -> T) (i j : nat) : swap r s B i j = B (tau r s i) j.
Proof. unfold swap, tau. destruct (i =? r)%nat, (i =? s)%nat; reflexivity. Qed.

(* Elimination step k treats each row below k on its own, with row k as the pivot row, so it
   commutes with interchanging two rows below k. *)
Lemma elim_swap (k r s : nat) (B : nat -> nat -> T) :
  (k < r)%nat -> (k < s)%nat ->
  forall i j, elim k (swap r s B) i j = swap r s (elim k B) i j.
Proof.
  intros Hr Hs i j. rewrite (swap_tau r s (elim k B)).
  unfold elim. rewrite !swap_tau. rewrite (tau_low r s k) by lia.
  assert (E : (k <? tau r s i)%nat = (k <? i)%nat).
  { unfold tau. destruct (Nat.eqb_spec i r) as [-> | ]; [| destruct (Nat.eqb_spec i s) as [-> | ]].
    - rewrite !(proj2 (Nat.ltb_lt _ _)) by lia. reflexivity.
    - rewrite !(proj2 (Nat.ltb_lt _ _)) by lia. reflexivity.
    - reflexivity. }
  rewrite E. destruct (k <? i)%nat eqn:Hki; [reflexivity |].
  apply Nat.ltb_ge in Hki. rewrite tau_low by lia. reflexivity.
Qed.

Lemma nstate_swap (r s : nat) (B : nat -> nat -> T) (k : nat) :
  (k <= r)%nat -> (k <= s)%nat ->
  forall i j, nstate (swap r s B) k i j = swap r s (nstate B k) i j.
Proof.
  induction k as [| k IH]; intros Hr Hs i j; [reflexivity |].
  simpl. rewrite (elim_congr k _ (swap r s (nstate B k))) by (apply IH; lia).
  apply elim_swap; lia.
Qed.

Lemma swap_permute (r s : nat) (p : nat -> nat) (A : nat -> nat -> T) (i j : nat) :
  swap r s (permute p A) i j = permute (fun i' => p (tau r s i')) A i j.
Proof. rewrite swap_tau. reflexivity. Qed.

(* The pivoted factorization is the unpivoted one of P_k A, with P_k the interchanges it chose:
   rows interchanged later are untouched by the earlier steps. *)
Theorem state_nstate (n : nat) (A : nat -> nat -> T) (k : nat) :
  forall i j, state n A k i j = nstate (permute (perm n A k) A) k i j.
Proof.
  induction k as [| k IH]; intros i j; [reflexivity |].
  cbn [state nstate]. set (p := pivot n k (state n A k)).
  rewrite (elim_congr k _ (swap k p (nstate (permute (perm n A k) A) k)))
    by (apply swap_congr; exact IH).
  rewrite <- (elim_congr k _ _ (nstate_swap k p _ k (le_n k) (pivot_ge n k _))).
  apply elim_congr. apply nstate_congr. intros i' j'. rewrite swap_permute. reflexivity.
Qed.

(* Row i is final after step i. *)
Lemma nstate_row (B : nat -> nat -> T) (k i j : nat) :
  (i <= k)%nat -> nstate B k i j = nstate B i i j.
Proof.
  induction k as [| k IH]; intro H.
  - replace i with O by lia. reflexivity.
  - destruct (Nat.eq_dec i (S k)) as [-> | Hne]; [reflexivity |].
    simpl. unfold elim. replace (k <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
    apply IH. lia.
Qed.

(* Column j below the diagonal is final after step j. *)
Lemma nstate_col (B : nat -> nat -> T) (k i j : nat) :
  (j < i)%nat -> (j < k)%nat -> nstate B k i j = nstate B (S j) i j.
Proof.
  induction k as [| k IH]; intros Hji Hjk; [lia |].
  destruct (Nat.eq_dec k j) as [-> | Hne]; [reflexivity |].
  simpl. unfold elim.
  replace (j =? k)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
  replace (k <? j)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
  destruct (k <? i)%nat; apply IH; lia.
Qed.

(* An entry not yet final is its dot: B i j minus the products of the steps so far. *)
Lemma nstate_dot (B : nat -> nat -> T) (k i j : nat) :
  (k <= i)%nat -> (k <= j)%nat -> nstate B k i j = dot B i j k.
Proof.
  induction k as [| k IH]; intros Hi Hj; [reflexivity |].
  simpl. unfold elim at 1.
  replace (k <? i)%nat with true by (symmetry; apply Nat.ltb_lt; lia).
  replace (j =? k)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
  replace (k <? j)%nat with true by (symmetry; apply Nat.ltb_lt; lia).
  rewrite IH by lia. f_equal. f_equal. unfold elim.
  replace (k <? i)%nat with true by (symmetry; apply Nat.ltb_lt; lia).
  rewrite Nat.eqb_refl. reflexivity.
Qed.

(* The multiplier of row i > j at step j. *)
Lemma nstate_mult (B : nat -> nat -> T) (i j : nat) :
  (j < i)%nat -> nstate B (S j) i j = odiv o (dot B i j j) (dot B j j j).
Proof.
  intro H. simpl. unfold elim.
  replace (j <? i)%nat with true by (symmetry; apply Nat.ltb_lt; lia).
  rewrite Nat.eqb_refl. rewrite !nstate_dot by lia. reflexivity.
Qed.

(* Rows above k are final in the pivoted factorization too. *)
Lemma state_row (n : nat) (A : nat -> nat -> T) (k m i j : nat) :
  (i < k)%nat -> (k <= m)%nat -> state n A m i j = state n A k i j.
Proof.
  intros Hik. induction m as [| m IH]; intro Hkm; [lia |].
  destruct (Nat.eq_dec k (S m)) as [-> | Hne]; [reflexivity |].
  simpl. unfold elim. replace (m <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
  rewrite swap_tau. rewrite tau_low; [apply IH; lia | lia |].
  pose proof (pivot_ge n m (state n A m)). lia.
Qed.

(* The value at (k, k) after step k is the pivot the search chose. *)
Lemma state_diag (n : nat) (A : nat -> nat -> T) (k : nat) :
  state n A (S k) k k = state n A k (pivot n k (state n A k)) k.
Proof.
  simpl. unfold elim. rewrite Nat.ltb_irrefl. unfold swap. rewrite Nat.eqb_refl. reflexivity.
Qed.

Lemma perm_iperm (n : nat) (A : nat -> nat -> T) (k i : nat) : perm n A k (iperm n A k i) = i.
Proof.
  revert i. induction k as [| k IH]; intro i; [reflexivity |].
  simpl. rewrite tau_tau. apply IH.
Qed.

Lemma perm_range (n : nat) (A : nat -> nat -> T) (k i : nat) :
  (k <= n)%nat -> (i < n)%nat -> (perm n A k i < n)%nat.
Proof.
  revert i. induction k as [| k IH]; intros i Hk Hi; [exact Hi |].
  simpl. apply IH; [lia |]. apply tau_lt; [lia | apply pivot_range; lia | exact Hi].
Qed.

Lemma iperm_range (n : nat) (A : nat -> nat -> T) (k i : nat) :
  (k <= n)%nat -> (i < n)%nat -> (iperm n A k i < n)%nat.
Proof.
  revert i. induction k as [| k IH]; intros i Hk Hi; [exact Hi |].
  simpl. apply tau_lt; [lia | apply pivot_range; lia | apply IH; lia].
Qed.

Lemma perm_inj (n : nat) (A : nat -> nat -> T) (k i j : nat) :
  perm n A k i = perm n A k j -> i = j.
Proof.
  revert i j. induction k as [| k IH]; intros i j H; [exact H |].
  simpl in H. apply IH in H.
  rewrite <- (tau_tau k (pivot n k (state n A k)) i), H. apply tau_tau.
Qed.

End Generic.

(* Layer A, the pivot rows form a permutation, for any number type: each pivot row of step k
   is in [k, n), and row i of P A is row perm n A n i of A, a bijection of [0, n). *)
Theorem permutation {T : Type} (o : ops T) (A : nat -> nat -> T) (n : nat) :
  (forall k, (k < n)%nat -> (k <= pivot o n k (state o n A k) < n)%nat) /\
  (forall i, (i < n)%nat -> (perm o n A n i < n)%nat) /\
  (forall i j, perm o n A n i = perm o n A n j -> i = j) /\
  (forall i, (i < n)%nat -> exists j, (j < n)%nat /\ perm o n A n j = i).
Proof.
  split; [| split; [| split]].
  - intros k Hk. apply pivot_range. exact Hk.
  - intros i Hi. apply perm_range; [lia | exact Hi].
  - intros i j. apply perm_inj.
  - intros i Hi. exists (iperm o n A n i). split; [apply iperm_range; lia |].
    apply perm_iperm.
Qed.

(* The real operations: exact arithmetic, magnitudes compared with <. *)
Definition rgt (x y : R) : bool := if Rlt_dec y x then true else false.

Definition rops : ops R :=
  {| osub := Rminus; omul := Rmult; odiv := Rdiv; omag := Rabs; ogt := rgt; ozero := 0 |}.

(* The factorization of A with partial pivoting in exact arithmetic, packed: L strictly below
   the diagonal, U on and above it. *)
Definition lu (A : nat -> nat -> R) (n : nat) : nat -> nat -> R := state rops n A n.

(* Row i of P A is row prow A n i of A. *)
Definition prow (A : nat -> nat -> R) (n : nat) : nat -> nat := perm rops n A n.

(* The magnitude of the pivot of step k, which the C tests against zero. *)
Definition ptop (A : nat -> nat -> R) (n k : nat) : R := top rops n k (state rops n A k).

(* The unit lower-triangular and the upper-triangular factor of a packed matrix F. *)
Definition lo (F : nat -> nat -> R) (i t : nat) : R :=
  if (t <? i)%nat then F i t else if (t =? i)%nat then 1 else 0.

Definition up (F : nat -> nat -> R) (t j : nat) : R := if (t <=? j)%nat then F t j else 0.

Lemma rdot_sum (B : nat -> nat -> R) (i j k : nat) :
  dot rops B i j k = B i j - sum k (fun t => nstate rops B (S t) i t * nstate rops B t t j).
Proof.
  induction k as [| k IH]; [cbn [dot sum]; ring |].
  change (dot rops B i j (S k))
    with (dot rops B i j k - nstate rops B (S k) i k * nstate rops B k k j).
  rewrite IH. cbn [sum]. ring.
Qed.

(* The products of the steps before k, read from the final matrix. *)
Lemma rdot_final (B : nat -> nat -> R) (n i j k : nat) :
  (k <= i)%nat -> (k <= j)%nat -> (k <= n)%nat ->
  dot rops B i j k = B i j - sum k (fun t => nstate rops B n i t * nstate rops B n t j).
Proof.
  intros Hi Hj Hn. rewrite rdot_sum. f_equal. apply sum_ext. intros t Ht.
  rewrite (nstate_col rops B n i t), (nstate_row rops B n t j) by lia. reflexivity.
Qed.

(* Layer A, correctness of the unpivoted factorization: once the pivots U k k, k < n, are
   nonzero, L U = B on the indices below n. *)
Theorem product (B : nat -> nat -> R) (n : nat) :
  (forall k, (k < n)%nat -> nstate rops B k k k <> 0) ->
  forall i j, (i < n)%nat -> (j < n)%nat ->
  sum n (fun t => lo (nstate rops B n) i t * up (nstate rops B n) t j) = B i j.
Proof.
  intros Hp i j Hi Hj. set (F := nstate rops B n).
  destruct (Nat.le_gt_cases i j) as [Hij | Hji].
  - rewrite (sum_trunc _ (S i) n) by
      (lia || (intros t Ht1 Ht2; unfold lo;
               replace (t <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia);
               replace (t =? i)%nat with false by (symmetry; apply Nat.eqb_neq; lia); ring)).
    cbn [sum]. unfold lo at 2, up at 2. rewrite Nat.ltb_irrefl, Nat.eqb_refl.
    replace (i <=? j)%nat with true by (symmetry; apply Nat.leb_le; exact Hij).
    assert (HF : F i j = B i j - sum i (fun t => F i t * F t j)).
    { unfold F. rewrite (nstate_row rops B n i j) by lia.
      rewrite nstate_dot by lia. apply rdot_final; lia. }
    rewrite HF. rewrite (sum_ext i _ (fun t => F i t * F t j)); [ring |].
    intros t Ht. unfold lo, up.
    replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Ht).
    replace (t <=? j)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity.
  - rewrite (sum_trunc _ (S j) n) by
      (lia || (intros t Ht1 Ht2; unfold up;
               replace (t <=? j)%nat with false by (symmetry; apply Nat.leb_gt; lia); ring)).
    cbn [sum]. unfold lo at 2, up at 2.
    replace (j <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Hji).
    rewrite Nat.leb_refl.
    assert (Hd : F j j = dot rops B j j j).
    { unfold F. rewrite (nstate_row rops B n j j) by lia. apply nstate_dot; lia. }
    assert (Hnz : F j j <> 0).
    { unfold F. rewrite (nstate_row rops B n j j) by lia. apply Hp. exact Hj. }
    assert (HF : F i j * F j j = B i j - sum j (fun t => F i t * F t j)).
    { unfold F at 1. rewrite (nstate_col rops B n i j) by lia. rewrite nstate_mult by lia.
      rewrite <- Hd. change (odiv rops ?x ?y) with (x / y).
      rewrite (rdot_final B n i j j) by lia. fold F. field. exact Hnz. }
    rewrite HF. rewrite (sum_ext j _ (fun t => F i t * F t j)); [ring |].
    intros t Ht. unfold lo, up.
    replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; lia).
    replace (t <=? j)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity.
Qed.

Lemma rsearch_spec (B : nat -> nat -> R) (k t : nat) :
  0 <= snd (search rops B k t) /\
  (forall i, (k <= i < k + t)%nat -> Rabs (B i k) <= snd (search rops B k t)) /\
  ((snd (search rops B k t) = 0 /\ fst (search rops B k t) = k) \/
   snd (search rops B k t) = Rabs (B (fst (search rops B k t)) k)).
Proof.
  induction t as [| t IH].
  - cbn. split; [lra |]. split; [intros; lia | left; split; reflexivity].
  - destruct IH as [H0 [Hle Hv]]. cbn [search].
    change (omag rops) with Rabs. change (ogt rops) with rgt.
    unfold rgt. destruct (Rlt_dec (snd (search rops B k t)) (Rabs (B (k + t)%nat k))) as [Hlt | Hge];
      cbn [fst snd].
    + split; [apply Rabs_pos |]. split; [| right; reflexivity].
      intros i Hi. destruct (Nat.eq_dec i (k + t)) as [-> | Hne]; [lra |].
      pose proof (Hle i ltac:(lia)). lra.
    + split; [exact H0 |]. split; [| exact Hv].
      intros i Hi. destruct (Nat.eq_dec i (k + t)) as [-> | Hne]; [lra |]. apply Hle. lia.
Qed.

(* The pivot has the largest magnitude in its column, and that magnitude is the one tested. *)
Lemma rtop_spec (B : nat -> nat -> R) (n k : nat) :
  (k < n)%nat ->
  top rops n k B = Rabs (B (pivot rops n k B) k) /\
  forall i, (k <= i < n)%nat -> Rabs (B i k) <= top rops n k B.
Proof.
  intro Hk. unfold top, pivot. destruct (rsearch_spec B k (n - k)) as [H0 [Hle Hv]].
  split; [| intros i Hi; apply Hle; lia].
  destruct Hv as [[Hz Hp] | Hv]; [| exact Hv].
  rewrite Hz, Hp. pose proof (Hle k ltac:(lia)). pose proof (Rabs_pos (B k k)). lra.
Qed.

(* The pivot U k k of the factorization is the pivot entry of step k. *)
Lemma lu_diag (A : nat -> nat -> R) (n k : nat) :
  (k < n)%nat -> lu A n k k = state rops n A k (pivot rops n k (state rops n A k)) k.
Proof.
  intro Hk. unfold lu. rewrite (state_row rops n A (S k) n k k) by lia. apply state_diag.
Qed.

Lemma lu_diag_nonzero (A : nat -> nat -> R) (n k : nat) :
  (k < n)%nat -> ptop A n k <> 0 -> lu A n k k <> 0.
Proof.
  intros Hk Ht. rewrite lu_diag by exact Hk. intro E. apply Ht. unfold ptop.
  rewrite (proj1 (rtop_spec _ n k Hk)), E. apply Rabs_R0.
Qed.

(* Layer A, correctness with partial pivoting: when every pivot is nonzero (the C's test),
   P A = L U on the indices below n, L unit lower triangular and U upper triangular from the
   packed lu A n. *)
Theorem pivot_product (A : nat -> nat -> R) (n : nat) :
  (forall k, (k < n)%nat -> ptop A n k <> 0) ->
  forall i j, (i < n)%nat -> (j < n)%nat ->
  sum n (fun t => lo (lu A n) i t * up (lu A n) t j) = A (prow A n i) j.
Proof.
  intros Ht i j Hi Hj.
  set (B := permute (perm rops n A n) A).
  assert (E : forall i' j', lu A n i' j' = nstate rops B n i' j') by apply state_nstate.
  rewrite (sum_ext n _ (fun t => lo (nstate rops B n) i t * up (nstate rops B n) t j)).
  2: { intros t Ht'. unfold lo, up. rewrite !E. reflexivity. }
  apply (product B n); [| exact Hi | exact Hj].
  intros k Hk. rewrite <- (nstate_row rops B n k k) by lia. rewrite <- E.
  apply lu_diag_nonzero; [exact Hk | apply Ht; exact Hk].
Qed.

Lemma div_le_1 (x d : R) : Rabs x <= Rabs d -> Rabs (x / d) <= 1.
Proof.
  intro H. destruct (Req_dec d 0) as [-> | Hd].
  - unfold Rdiv. rewrite Rinv_0, Rmult_0_r, Rabs_R0. lra.
  - unfold Rdiv. rewrite Rabs_mult, Rabs_inv.
    pose proof (Rabs_pos_lt d Hd).
    apply (Rmult_le_reg_r (Rabs d)); [lra |].
    rewrite Rmult_assoc, Rinv_l by lra. lra.
Qed.

(* Layer A, partial pivoting bounds the multipliers: |L i j| <= 1. *)
Theorem multiplier_bound (A : nat -> nat -> R) (n : nat) :
  forall i j, (j < i)%nat -> (i < n)%nat -> Rabs (lu A n i j) <= 1.
Proof.
  intros i j Hji Hin.
  assert (Hm : forall d, (S j + d <= n)%nat ->
             forall r, (j < r)%nat -> (r < n)%nat -> Rabs (state rops n A (S j + d) r j) <= 1).
  { induction d as [| d IH]; intros Hd r Hr Hrn.
    - rewrite Nat.add_0_r. cbn [state]. set (S0 := state rops n A j).
      set (p := pivot rops n j S0).
      assert (Hp : (j <= p < n)%nat) by (apply pivot_range; lia).
      unfold elim. replace (j <? r)%nat with true by (symmetry; apply Nat.ltb_lt; exact Hr).
      rewrite Nat.eqb_refl. change (odiv rops ?x ?y) with (x / y).
      rewrite !swap_tau. unfold tau at 2. rewrite Nat.eqb_refl.
      destruct (rtop_spec S0 n j ltac:(lia)) as [Htop Hle].
      apply div_le_1. fold p in Htop. rewrite <- Htop. apply Hle.
      pose proof (tau_ge j p r j (le_n j) ltac:(lia) ltac:(lia)).
      pose proof (tau_lt j p r n ltac:(lia) ltac:(lia) Hrn). lia.
    - replace (S j + S d)%nat with (S (S j + d)) by lia. cbn [state].
      set (m := (S j + d)%nat) in *. set (Sm := state rops n A m).
      set (p := pivot rops n m Sm).
      assert (Hp : (m <= p < n)%nat) by (apply pivot_range; lia).
      unfold elim.
      replace (j =? m)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
      replace (m <? j)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
      assert (Hs : swap m p Sm r j = Sm (tau m p r) j) by apply swap_tau.
      destruct (m <? r)%nat; rewrite Hs; apply IH; try lia.
      + unfold tau. destruct (r =? m)%nat, (r =? p)%nat; lia.
      + apply tau_lt; lia.
      + unfold tau. destruct (r =? m)%nat, (r =? p)%nat; lia.
      + apply tau_lt; lia. }
  unfold lu. replace n with (S j + (n - S j))%nat at 2 by lia. apply Hm; lia.
Qed.

(* Layer A, a matrix whose pivots are all nonzero is nonsingular: A x = 0 on the indices below
   n only for x = 0 there. *)
Theorem nonsingular (A : nat -> nat -> R) (n : nat) :
  (forall k, (k < n)%nat -> ptop A n k <> 0) ->
  forall x : nat -> R, (forall i, (i < n)%nat -> sum n (fun j => A i j * x j) = 0) ->
  forall j, (j < n)%nat -> x j = 0.
Proof.
  intros Ht x Hx.
  set (F := lu A n).
  set (y := fun t => sum n (fun j => up F t j * x j)).
  assert (Hy : forall i, (i < n)%nat -> sum (S i) (fun t => lo F i t * y t) = 0).
  { intros i Hi.
    rewrite <- (sum_trunc (fun t => lo F i t * y t) (S i) n).
    2: lia.
    2: { intros t H1 H2. unfold lo.
         replace (t <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
         replace (t =? i)%nat with false by (symmetry; apply Nat.eqb_neq; lia). ring. }
    transitivity (sum n (fun j => sum n (fun t => lo F i t * up F t j) * x j)).
    { unfold y.
      rewrite (sum_ext n _ (fun t => sum n (fun j => lo F i t * up F t j * x j))).
      2: { intros t Ht'. rewrite <- sum_scal_l. apply sum_ext. intros; ring. }
      rewrite sum_comm. apply sum_ext. intros j Hj. rewrite <- sum_scal_r. reflexivity. }
    rewrite (sum_ext n _ (fun j => A (prow A n i) j * x j)).
    2: { intros j Hj. unfold F. rewrite pivot_product by assumption. reflexivity. }
    apply Hx. apply (permutation rops A n). exact Hi. }
  assert (Hy0 : forall i, (i < n)%nat -> y i = 0).
  { intros i Hi.
    rewrite (forward_unique (lo F) (fun _ => 0) y n); [apply fwd_zero | | exact Hy | exact Hi].
    intros i' Hi'. unfold lo. rewrite Nat.ltb_irrefl, Nat.eqb_refl. lra. }
  intros j Hj.
  rewrite (back_unique (fun a b => up F b a) (fun _ => 0) x n); [exact (fwd_zero _ _) | | | exact Hj].
  - intros i Hi. unfold up. rewrite Nat.leb_refl. apply lu_diag_nonzero; [exact Hi |].
    apply Ht. exact Hi.
  - intros i Hi. cbv beta. transitivity (y i); [| apply Hy0; exact Hi]. unfold y.
    rewrite (sum_split i n) by lia.
    rewrite (sum_zero i) by (intros t Ht'; unfold up;
                         replace (i <=? t)%nat with false by (symmetry; apply Nat.leb_gt; lia); ring).
    rewrite Rplus_0_l. reflexivity.
Qed.

(* The unit lower-triangular and the upper-triangular factor of the unpivoted steps of B, read
   at the step each entry is final. *)
Definition nlo (B : nat -> nat -> R) (i t : nat) : R :=
  if (t <? i)%nat then nstate rops B (S t) i t else if (t =? i)%nat then 1 else 0.

Definition nup (B : nat -> nat -> R) (t j : nat) : R :=
  if (t <=? j)%nat then nstate rops B t t j else 0.

(* Column j < m of B is the combination of the first m columns of nlo B: the first m steps
   factor the first m columns, for every row. *)
Lemma column_product (B : nat -> nat -> R) (m i j : nat) :
  (forall t, (t < m)%nat -> nstate rops B t t t <> 0) -> (j < m)%nat ->
  B i j = sum m (fun t => nlo B i t * nup B t j).
Proof.
  intros Hd Hj. destruct (Nat.le_gt_cases i j) as [Hij | Hji].
  - rewrite (sum_trunc _ (S i) m) by
      (lia || (intros t Ht1 Ht2; unfold nlo;
               replace (t <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia);
               replace (t =? i)%nat with false by (symmetry; apply Nat.eqb_neq; lia); ring)).
    cbn [sum]. unfold nlo at 2, nup at 2. rewrite Nat.ltb_irrefl, Nat.eqb_refl.
    replace (i <=? j)%nat with true by (symmetry; apply Nat.leb_le; exact Hij).
    rewrite (nstate_dot rops B i i j) by lia. rewrite rdot_sum.
    rewrite (sum_ext i (fun t => nlo B i t * nup B t j)
               (fun t => nstate rops B (S t) i t * nstate rops B t t j)); [ring |].
    intros t Ht. unfold nlo, nup.
    replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Ht).
    replace (t <=? j)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity.
  - rewrite (sum_trunc _ (S j) m) by
      (lia || (intros t Ht1 Ht2; unfold nup;
               replace (t <=? j)%nat with false by (symmetry; apply Nat.leb_gt; lia); ring)).
    cbn [sum]. unfold nlo at 2, nup at 2.
    replace (j <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Hji).
    rewrite Nat.leb_refl.
    assert (Hnz : nstate rops B j j j <> 0) by (apply Hd; exact Hj).
    rewrite nstate_mult by exact Hji.
    rewrite <- (nstate_dot rops B j j j) by lia.
    change (odiv rops ?x ?y) with (x / y).
    rewrite rdot_sum.
    rewrite (sum_ext j (fun t => nlo B i t * nup B t j)
               (fun t => nstate rops B (S t) i t * nstate rops B t t j)).
    2: { intros t Ht. unfold nlo, nup.
         replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; lia).
         replace (t <=? j)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity. }
    field. exact Hnz.
Qed.

(* Layer A, a zero pivot means a singular matrix: if the pivots of the steps before k are
   nonzero and every candidate of step k is zero, then A x = 0 for some x with x k = 1 and
   x j = 0 for j > k. With nonsingular, exact partial pivoting succeeds exactly on the
   nonsingular matrices. *)
Theorem singular (A : nat -> nat -> R) (n k : nat) :
  (k < n)%nat -> (forall k', (k' < k)%nat -> ptop A n k' <> 0) -> ptop A n k = 0 ->
  exists x : nat -> R, x k = 1 /\ (forall j, (k < j)%nat -> x j = 0) /\
    forall i, (i < n)%nat -> sum n (fun j => A i j * x j) = 0.
Proof.
  intros Hk Ht Hz.
  set (B := permute (perm rops n A k) A).
  set (N := nstate rops B).
  assert (HS : forall i j, state rops n A k i j = N k i j) by apply state_nstate.
  assert (Hcol : forall i, (k <= i < n)%nat -> N k i k = 0).
  { intros i Hi. rewrite <- HS.
    destruct (rtop_spec (state rops n A k) n k Hk) as [_ Hle].
    pose proof (Hle i Hi) as H. unfold ptop in Hz. rewrite Hz in H.
    pose proof (Rabs_pos (state rops n A k i k)).
    destruct (Req_dec (state rops n A k i k) 0) as [E | E]; [exact E |].
    pose proof (Rabs_pos_lt _ E). lra. }
  assert (Hd : forall t, (t < k)%nat -> N t t t <> 0).
  { intros t Ht'. unfold N. rewrite <- (nstate_row rops B k t t) by lia. fold N.
    rewrite <- HS. rewrite (state_row rops n A (S t) k t t) by lia. rewrite state_diag.
    intro E. apply (Ht t Ht'). unfold ptop.
    rewrite (proj1 (rtop_spec _ n t ltac:(lia))), E. apply Rabs_R0. }
  assert (Hlast : forall i, (i < n)%nat -> B i k = sum k (fun t => nlo B i t * N t t k)).
  { intros i Hi. destruct (Nat.lt_ge_cases i k) as [Hik | Hki].
    - rewrite (sum_trunc _ (S i) k) by
        (lia || (intros t Ht1 Ht2; unfold nlo;
                 replace (t <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia);
                 replace (t =? i)%nat with false by (symmetry; apply Nat.eqb_neq; lia); ring)).
      cbn [sum]. unfold nlo at 2. rewrite Nat.ltb_irrefl, Nat.eqb_refl.
      unfold N. rewrite (nstate_dot rops B i i k) by lia. rewrite rdot_sum.
      rewrite (sum_ext i (fun t => nlo B i t * nstate rops B t t k)
                 (fun t => nstate rops B (S t) i t * nstate rops B t t k)); [ring |].
      intros t Ht'. unfold nlo.
      replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Ht'). reflexivity.
    - pose proof (Hcol i ltac:(lia)) as H0. unfold N in H0.
      rewrite (nstate_dot rops B k i k) in H0 by lia. rewrite rdot_sum in H0.
      rewrite (sum_ext k (fun t => nlo B i t * N t t k)
                 (fun t => nstate rops B (S t) i t * nstate rops B t t k)); [lra |].
      intros t Ht'. unfold nlo.
      replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; lia). reflexivity. }
  set (y := bwd (fun a b => N b b a) (fun t => N t t k) k).
  assert (Hback : forall t, (t < k)%nat -> sum k (fun j => nup B t j * y j) = N t t k).
  { intros t Ht'. rewrite (sum_split t k) by lia.
    rewrite sum_zero by (intros j Hj; unfold nup;
                         replace (t <=? j)%nat with false by (symmetry; apply Nat.leb_gt; lia); ring).
    rewrite Rplus_0_l.
    rewrite <- (back_solve (fun a b => N b b a) (fun t => N t t k) k t Ht' (Hd t Ht')).
    apply sum_ext. intros s Hs. unfold nup.
    replace (t <=? t + s)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity. }
  exists (fun j => if (j <? k)%nat then - y j else if (j =? k)%nat then 1 else 0).
  split; [rewrite Nat.ltb_irrefl, Nat.eqb_refl; reflexivity |].
  split.
  { intros j Hj. replace (j <? k)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
    replace (j =? k)%nat with false by (symmetry; apply Nat.eqb_neq; lia). reflexivity. }
  intros i Hi.
  set (i0 := iperm rops n A k i).
  assert (Hi0 : (i0 < n)%nat) by (apply iperm_range; lia).
  assert (HA : forall j, A i j = B i0 j).
  { intro j. unfold B, permute, i0. rewrite perm_iperm. reflexivity. }
  rewrite (sum_trunc _ (S k) n).
  2: lia.
  2: { intros j H1 H2. replace (j <? k)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
       replace (j =? k)%nat with false by (symmetry; apply Nat.eqb_neq; lia). ring. }
  cbn [sum]. rewrite Nat.ltb_irrefl, Nat.eqb_refl. rewrite HA, Hlast by exact Hi0.
  assert (E : sum k (fun j => B i0 j * - y j) = - sum k (fun t => nlo B i0 t * N t t k)).
  { transitivity (sum k (fun j => sum k (fun t => nlo B i0 t * (nup B t j * - y j)))).
    { apply sum_ext. intros j Hj. rewrite (column_product B k i0 j Hd Hj).
      rewrite <- sum_scal_r. apply sum_ext. intros; ring. }
    rewrite sum_comm.
    transitivity (sum k (fun t => nlo B i0 t * - N t t k)).
    { apply sum_ext. intros t Ht'. rewrite sum_scal_l. f_equal.
      rewrite <- (Hback t Ht'). rewrite <- (Rmult_1_l (sum k (fun j => nup B t j * y j))).
      rewrite Ropp_mult_distr_l, <- sum_scal_l. apply sum_ext. intros; ring. }
    rewrite <- (Rmult_1_l (sum k (fun t => nlo B i0 t * N t t k))).
    rewrite Ropp_mult_distr_l, <- sum_scal_l. apply sum_ext. intros; ring. }
  rewrite (sum_ext k _ (fun j => B i0 j * - y j)).
  2: { intros j Hj. rewrite HA. replace (j <? k)%nat with true by (symmetry; apply Nat.ltb_lt; exact Hj).
       reflexivity. }
  rewrite E. ring.
Qed.
