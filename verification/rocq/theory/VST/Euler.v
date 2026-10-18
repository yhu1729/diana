From VST.floyd Require Import proofauto.
From Diana.Float Require Euler.

Definition c_step (h y f : float) : float := Float.add y (Float.mul h f).

Fixpoint c_euler (h : float) (ys fs : list float) : list float :=
  match ys, fs with
  | y :: ys', f :: fs' => c_step h y f :: c_euler h ys' fs'
  | _, _ => nil
  end.

Definition euler_status (h : float) (ys fs : list float) : Z :=
  if forallb (Binary.is_finite 53 1024) (c_euler h ys fs) then 0
  else if (Binary.is_finite 53 1024 h && forallb (Binary.is_finite 53 1024) ys &&
           forallb (Binary.is_finite 53 1024) fs)%bool
  then -5 else -1.

Lemma c_euler_model (h : float) (ys fs : list float) :
  c_euler h ys fs = Diana.Float.Euler.feuler Float.binop_nan Float.binop_nan h ys fs.
Proof.
  revert fs. induction ys as [| y ys IH]; intros [| f fs]; try reflexivity.
  cbn [c_euler]. unfold Diana.Float.Euler.feuler. cbn [combine map fst snd].
  f_equal. apply IH.
Qed.

Lemma Zlength_c_euler (h : float) (ys fs : list float) :
  Zlength fs = Zlength ys -> Zlength (c_euler h ys fs) = Zlength ys.
Proof.
  revert fs. induction ys as [| y ys IH]; intros [| f fs] Hl; cbn [c_euler]; try reflexivity.
  - rewrite Zlength_nil, Zlength_cons in Hl. pose proof (Zlength_nonneg ys). lia.
  - rewrite !Zlength_cons in *. rewrite IH by lia. reflexivity.
Qed.

Lemma Znth_c_euler (h : float) (ys fs : list float) (i : Z) :
  Zlength fs = Zlength ys -> 0 <= i < Zlength ys ->
  Znth i (c_euler h ys fs) = c_step h (Znth i ys) (Znth i fs).
Proof.
  revert fs i. induction ys as [| y ys IH]; intros [| f fs] i Hl Hi.
  - rewrite Zlength_nil in Hi. lia.
  - rewrite Zlength_nil in Hi. lia.
  - rewrite Zlength_nil, Zlength_cons in Hl. pose proof (Zlength_nonneg ys). lia.
  - cbn [c_euler]. pose proof (Zlength_cons y ys). pose proof (Zlength_cons f fs).
    destruct (Z.eq_dec i 0) as [-> | Hne].
    + rewrite !Znth_0_cons. reflexivity.
    + rewrite !Znth_pos_cons by lia. apply IH; lia.
Qed.

Lemma forallb_sublist_succ (L : list float) (i : Z) :
  0 <= i < Zlength L ->
  forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) L)
  = andb (forallb (Binary.is_finite 53 1024) (sublist 0 i L))
         (Binary.is_finite 53 1024 (Znth i L)).
Proof.
  intro Hi. rewrite (sublist_split 0 i (i + 1)) by lia.
  rewrite forallb_app, sublist_len_1 by lia. simpl. rewrite andb_true_r. reflexivity.
Qed.

Lemma forallb_false (L : list float) (i : Z) :
  0 <= i < Zlength L -> Binary.is_finite 53 1024 (Znth i L) = false ->
  forallb (Binary.is_finite 53 1024) L = false.
Proof.
  intros Hi Hf. destruct (forallb (Binary.is_finite 53 1024) L) eqn:Hb; [| reflexivity].
  rewrite forallb_forall in Hb. rewrite Hb in Hf; [discriminate |]. apply Znth_In. exact Hi.
Qed.
