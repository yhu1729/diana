From Stdlib Require Import Reals Lra Lia Psatz.
From Coquelicot Require Import Coquelicot.
From Diana.Real Require Import Quadrature.
Open Scope R_scope.

Definition step (f df : R -> R) (x : R) : R := x - f x / df x.

Fixpoint iter (f df : R -> R) (x0 : R) (n : nat) : R :=
  match n with
  | O => x0
  | S k => step f df (iter f df x0 k)
  end.

Lemma taylor_bound (f df d2f : R -> R) (a b x r M : R) :
  a <= x <= b -> a <= r <= b ->
  (forall t, a <= t <= b -> is_derive f t (df t)) ->
  (forall t, a <= t <= b -> is_derive df t (d2f t)) ->
  (forall t, a <= t <= b -> Rabs (d2f t) <= M) ->
  Rabs (f r - f x - df x * (r - x)) <= M * (r - x) ^ 2 / 2.
Proof.
  intros Hx Hr Hf Hdf HM.
  assert (Hmem : forall s, 0 <= s <= 1 -> a <= x + s * (r - x) <= b).
  { intros s Hs. split; nra. }
  assert (HM0 : 0 <= M).
  { pose proof (HM x Hx). pose proof (Rabs_pos (d2f x)). lra. }
  assert (Hpsi : forall s, 0 <= s <= 1 ->
            Rabs (df (x + s * (r - x)) - df x) <= M * Rabs (r - x) * s).
  { intros s Hs.
    apply (bound_of_derive (fun s => df (x + s * (r - x)) - df x)
             (fun s => d2f (x + s * (r - x)) * (r - x))
             (fun s => M * Rabs (r - x) * s) (fun _ => M * Rabs (r - x)) 0 s).
    - lra.
    - intros t Ht. pose proof (Hdf _ (Hmem t ltac:(lra))) as A. auto_derive.
      + repeat split; try exact I; eexists; eassumption.
      + rewrite (Derive_of _ _ _ A). ring.
    - intros t _. auto_derive; [exact I | ring].
    - intros t Ht. rewrite Rabs_mult. apply Rmult_le_compat_r; [apply Rabs_pos |].
      apply HM. apply Hmem. lra.
    - replace (x + 0 * (r - x)) with x by ring. replace (df x - df x) with 0 by ring.
      rewrite Rabs_R0. lra. }
  pose proof (bound_of_derive (fun s => f (x + s * (r - x)) - f x - df x * (s * (r - x)))
                (fun s => (df (x + s * (r - x)) - df x) * (r - x))
                (fun s => M * (r - x) ^ 2 * s ^ 2 / 2) (fun s => M * (r - x) ^ 2 * s) 0 1)
    as HG.
  cbv beta in HG.
  rewrite !Rmult_1_l, pow1, Rmult_1_r in HG.
  replace (x + (r - x)) with r in HG by ring.
  apply HG.
  - lra.
  - intros t Ht. pose proof (Hf _ (Hmem t Ht)) as A. auto_derive.
    + repeat split; try exact I; eexists; eassumption.
    + rewrite (Derive_of _ _ _ A). ring.
  - intros t _. auto_derive; [exact I | cbv beta; field].
  - intros t Ht. rewrite Rabs_mult.
    pose proof (Rmult_le_compat_r (Rabs (r - x)) _ _ (Rabs_pos (r - x)) (Hpsi t Ht)) as H.
    rewrite <- (pow2_abs (r - x)). eapply Rle_trans; [exact H | right; ring].
  - replace (x + 0 * (r - x)) with x by ring.
    replace (f x - f x - df x * (0 * (r - x))) with 0 by ring. rewrite Rabs_R0.
    replace (M * (r - x) ^ 2 * 0 ^ 2 / 2) with 0 by (simpl; field). lra.
Qed.

Theorem step_error (f df d2f : R -> R) (a b x r M m : R) :
  a <= x <= b -> a <= r <= b ->
  (forall t, a <= t <= b -> is_derive f t (df t)) ->
  (forall t, a <= t <= b -> is_derive df t (d2f t)) ->
  (forall t, a <= t <= b -> Rabs (d2f t) <= M) ->
  0 < m -> m <= Rabs (df x) -> f r = 0 ->
  Rabs (step f df x - r) <= M / (2 * m) * (x - r) ^ 2.
Proof.
  intros Hx Hr Hf Hdf HM Hm Hfx Hroot.
  pose proof (taylor_bound f df d2f a b x r M Hx Hr Hf Hdf HM) as Ht. rewrite Hroot in Ht.
  assert (HM0 : 0 <= M).
  { pose proof (HM x Hx). pose proof (Rabs_pos (d2f x)). lra. }
  assert (Hne : df x <> 0). { intro E. rewrite E, Rabs_R0 in Hfx. lra. }
  assert (Hpos : 0 < Rabs (df x)) by (apply Rabs_pos_lt; exact Hne).
  unfold step.
  replace (x - f x / df x - r) with ((0 - f x - df x * (r - x)) / df x)
    by (field; exact Hne).
  rewrite Rabs_div by exact Hne.
  apply (Rmult_le_reg_r (Rabs (df x)) _ _ Hpos).
  unfold Rdiv at 1. rewrite Rmult_assoc, Rinv_l, Rmult_1_r by lra.
  eapply Rle_trans; [exact Ht |].
  replace (M * (r - x) ^ 2 / 2) with (M / (2 * m) * (x - r) ^ 2 * m) by (field; lra).
  apply Rmult_le_compat_l; [| exact Hfx].
  apply Rmult_le_pos; [| apply pow2_ge_0].
  unfold Rdiv. apply Rmult_le_pos; [exact HM0 | left; apply Rinv_0_lt_compat; lra].
Qed.

Theorem converge (f df d2f : R -> R) (r delta M m x0 : R) :
  0 <= delta -> 0 < m ->
  (forall t, r - delta <= t <= r + delta -> is_derive f t (df t)) ->
  (forall t, r - delta <= t <= r + delta -> is_derive df t (d2f t)) ->
  (forall t, r - delta <= t <= r + delta -> Rabs (d2f t) <= M) ->
  (forall t, r - delta <= t <= r + delta -> m <= Rabs (df t)) ->
  f r = 0 -> M / (2 * m) * delta < 1 -> Rabs (x0 - r) <= delta ->
  forall n, Rabs (iter f df x0 n - r) <= delta * (M / (2 * m) * delta) ^ (2 ^ n - 1).
Proof.
  intros Hd Hm Hf Hdf HM Hfm Hroot Hq Hx0.
  set (K := M / (2 * m)) in *. set (q := K * delta) in *.
  assert (HM0 : 0 <= M).
  { pose proof (HM r ltac:(lra)). pose proof (Rabs_pos (d2f r)). lra. }
  assert (HK0 : 0 <= K).
  { unfold K, Rdiv. apply Rmult_le_pos; [exact HM0 | left; apply Rinv_0_lt_compat; lra]. }
  assert (Hq0 : 0 <= q) by (unfold q; apply Rmult_le_pos; assumption).
  assert (Hpow : forall k, q ^ k <= 1).
  { intro k. induction k as [| k IH]; simpl; [lra | nra]. }
  induction n as [| n IH].
  - simpl. rewrite Rmult_1_r. exact Hx0.
  - assert (Hle : Rabs (iter f df x0 n - r) <= delta).
    { eapply Rle_trans; [exact IH |]. rewrite <- (Rmult_1_r delta) at 2.
      apply Rmult_le_compat_l; [exact Hd | apply Hpow]. }
    assert (Hxmem : r - delta <= iter f df x0 n <= r + delta).
    { pose proof Hle as H. unfold Rabs in H. destruct (Rcase_abs _) in H; lra. }
    pose proof (step_error f df d2f (r - delta) (r + delta) (iter f df x0 n) r M m Hxmem
                  ltac:(lra) Hf Hdf HM Hm (Hfm _ Hxmem) Hroot) as Hs.
    fold K in Hs.
    assert (Hk : (2 ^ S n - 1 = S ((2 ^ n - 1) * 2))%nat).
    { pose proof (Nat.pow_le_mono_r 2 0 n ltac:(lia) ltac:(lia)) as H1.
      change (2 ^ 0)%nat with 1%nat in H1. rewrite Nat.pow_succ_r'. lia. }
    simpl iter. rewrite Hk, <- tech_pow_Rmult, pow_mult.
    eapply Rle_trans; [exact Hs |].
    rewrite <- (pow2_abs (iter f df x0 n - r)).
    eapply Rle_trans.
    { apply Rmult_le_compat_l; [exact HK0 |].
      apply pow_incr. split; [apply Rabs_pos | exact IH]. }
    right. unfold q. ring.
Qed.
