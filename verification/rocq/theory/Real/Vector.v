From Stdlib Require Import Reals Lra Lia.
Open Scope R_scope.

Fixpoint vnorm (d : nat) (x : nat -> R) : R :=
  match d with
  | O => 0
  | S d' => Rmax (vnorm d' x) (Rabs (x d'))
  end.

Lemma vnorm_nonneg (d : nat) (x : nat -> R) : 0 <= vnorm d x.
Proof.
  induction d as [| d IH]; simpl; [lra |].
  eapply Rle_trans; [exact IH | apply Rmax_l].
Qed.

Lemma vnorm_ge (d : nat) (x : nat -> R) (i : nat) : (i < d)%nat -> Rabs (x i) <= vnorm d x.
Proof.
  induction d as [| d IH]; intro Hi; [lia |]. simpl.
  destruct (Nat.eq_dec i d) as [-> | Hne].
  - apply Rmax_r.
  - eapply Rle_trans; [apply IH; lia | apply Rmax_l].
Qed.

Lemma vnorm_le (d : nat) (x : nat -> R) (c : R) :
  0 <= c -> (forall i, (i < d)%nat -> Rabs (x i) <= c) -> vnorm d x <= c.
Proof.
  induction d as [| d IH]; intros Hc Hx; simpl; [exact Hc |].
  apply Rmax_lub.
  - apply IH; [exact Hc |]. intros i Hi. apply Hx. lia.
  - apply Hx. lia.
Qed.

Lemma vnorm_triang (d : nat) (x y : nat -> R) :
  vnorm d (fun i => x i + y i) <= vnorm d x + vnorm d y.
Proof.
  pose proof (vnorm_nonneg d x). pose proof (vnorm_nonneg d y).
  apply vnorm_le; [lra |]. intros i Hi.
  eapply Rle_trans; [apply Rabs_triang |].
  pose proof (vnorm_ge d x i Hi). pose proof (vnorm_ge d y i Hi). lra.
Qed.

Lemma vnorm_scal (d : nat) (c : R) (x : nat -> R) :
  vnorm d (fun i => c * x i) <= Rabs c * vnorm d x.
Proof.
  apply vnorm_le; [apply Rmult_le_pos; [apply Rabs_pos | apply vnorm_nonneg] |].
  intros i Hi. rewrite Rabs_mult.
  apply Rmult_le_compat_l; [apply Rabs_pos | apply vnorm_ge; exact Hi].
Qed.
