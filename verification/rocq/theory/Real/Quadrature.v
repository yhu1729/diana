From Stdlib Require Import Reals Lra Lia Psatz.
From Coquelicot Require Import Coquelicot.
Open Scope R_scope.

Lemma Derive_of (f : R -> R) (t l : R) : is_derive f t l -> Derive (fun s => f s) t = l.
Proof. exact (is_derive_unique f t l). Qed.

Lemma nondecreasing_of_derive (G dG : R -> R) (x y : R) :
  x <= y ->
  (forall t, x <= t <= y -> is_derive G t (dG t)) ->
  (forall t, x <= t <= y -> 0 <= dG t) ->
  G x <= G y.
Proof.
  intros Hxy HG Hd.
  assert (H1 : forall t, Rmin x y < t < Rmax x y -> is_derive G t (dG t)).
  { rewrite Rmin_left, Rmax_right by exact Hxy. intros t Ht. apply HG; lra. }
  assert (H2 : forall t, Rmin x y <= t <= Rmax x y -> continuity_pt G t).
  { rewrite Rmin_left, Rmax_right by exact Hxy. intros t Ht.
    apply derivable_continuous_pt. exists (dG t).
    exact (proj1 (is_derive_Reals G t (dG t)) (HG t Ht)). }
  destruct (MVT_gen G x y dG H1 H2) as [c [Hc Heq]].
  rewrite Rmin_left, Rmax_right in Hc by exact Hxy.
  pose proof (Hd c Hc). nra.
Qed.

Lemma bound_of_derive (F dF B dB : R -> R) (x y : R) :
  x <= y ->
  (forall t, x <= t <= y -> is_derive F t (dF t)) ->
  (forall t, x <= t <= y -> is_derive B t (dB t)) ->
  (forall t, x <= t <= y -> Rabs (dF t) <= dB t) ->
  Rabs (F x) <= B x ->
  Rabs (F y) <= B y.
Proof.
  intros Hxy HF HB Hd H0.
  assert (Hm : B x - F x <= B y - F y).
  { apply (nondecreasing_of_derive (fun t => B t - F t) (fun t => dB t - dF t) x y Hxy).
    - intros t Ht. auto_derive.
      + split; [exists (dB t); exact (HB t Ht) |].
        split; [exists (dF t); exact (HF t Ht) | exact I].
      + rewrite (Derive_of _ _ _ (HB t Ht)), (Derive_of _ _ _ (HF t Ht)). ring.
    - intros t Ht. pose proof (Hd t Ht). split_Rabs; lra. }
  assert (Hp : B x + F x <= B y + F y).
  { apply (nondecreasing_of_derive (fun t => B t + F t) (fun t => dB t + dF t) x y Hxy).
    - intros t Ht. auto_derive.
      + split; [exists (dB t); exact (HB t Ht) |].
        split; [exists (dF t); exact (HF t Ht) | exact I].
      + rewrite (Derive_of _ _ _ (HB t Ht)), (Derive_of _ _ _ (HF t Ht)). ring.
    - intros t Ht. pose proof (Hd t Ht). split_Rabs; lra. }
  split_Rabs; lra.
Qed.

Definition clamp (lo hi s : R) : R := Rmax lo (Rmin s hi).

Lemma clamp_lipschitz (lo hi u v : R) : Rabs (clamp lo hi u - clamp lo hi v) <= Rabs (u - v).
Proof.
  unfold clamp. apply Rle_trans with (Rabs (Rmin u hi - Rmin v hi)).
  - generalize (Rmin u hi) (Rmin v hi). intros p q.
    unfold Rmax. destruct (Rle_dec lo p), (Rle_dec lo q); split_Rabs; lra.
  - unfold Rmin. destruct (Rle_dec u hi), (Rle_dec v hi); split_Rabs; lra.
Qed.

Lemma clamp_continuous (lo hi t : R) : continuity_pt (clamp lo hi) t.
Proof.
  apply continuity_pt_locally. intros eps. exists eps. intros u Hu.
  eapply Rle_lt_trans; [apply clamp_lipschitz | exact Hu].
Qed.

Lemma clamp_range (lo hi s : R) : lo <= hi -> lo <= clamp lo hi s <= hi.
Proof.
  intro H. unfold clamp. split; [apply Rmax_l |]. apply Rmax_lub; [lra | apply Rmin_r].
Qed.

Lemma clamp_id (lo hi s : R) : lo <= s <= hi -> clamp lo hi s = s.
Proof. intro H. unfold clamp. rewrite Rmin_left by lra. apply Rmax_right; lra. Qed.

Lemma extend_continuous (f f' : R -> R) (lo hi : R) :
  lo <= hi ->
  (forall t, lo <= t <= hi -> is_derive f t (f' t)) ->
  forall s, continuous (fun z => f (clamp lo hi z)) s.
Proof.
  intros Hle Hf s. apply continuity_pt_filterlim.
  apply (continuity_pt_comp (clamp lo hi) f s); [apply clamp_continuous |].
  apply derivable_continuous_pt. exists (f' (clamp lo hi s)).
  exact (proj1 (is_derive_Reals f _ _) (Hf _ (clamp_range lo hi s Hle))).
Qed.

Lemma extend_RInt_derive (f f' : R -> R) (lo hi c : R) :
  lo <= hi ->
  (forall t, lo <= t <= hi -> is_derive f t (f' t)) ->
  forall t, is_derive (fun s => RInt (fun z => f (clamp lo hi z)) c s) t (f (clamp lo hi t)).
Proof.
  intros Hle Hf t. pose proof (extend_continuous f f' lo hi Hle Hf) as Hgc.
  apply (is_derive_RInt (fun z => f (clamp lo hi z)) _ c t); [| apply Hgc].
  apply filter_forall. intro s.
  exact (RInt_correct _ c s (ex_RInt_continuous _ c s (fun z _ => Hgc z))).
Qed.

Lemma extend_RInt (f : R -> R) (lo hi x y : R) :
  lo <= x -> x <= y -> y <= hi ->
  RInt (fun z => f (clamp lo hi z)) x y = RInt f x y.
Proof.
  intros Hx Hxy Hy. apply RInt_ext.
  rewrite Rmin_left, Rmax_right by exact Hxy. intros s Hs.
  rewrite clamp_id by lra. reflexivity.
Qed.

Lemma panel_error (f : R -> R) (Q : nat -> R) (a w c : R) (n : nat) :
  0 <= w ->
  (forall t, a <= t <= a + INR (S n) * w -> continuous f t) ->
  (forall k, (k <= n)%nat -> Rabs (RInt f (a + INR k * w) (a + INR (S k) * w) - Q k) <= c) ->
  Rabs (RInt f a (a + INR (S n) * w) - sum_n Q n) <= INR (S n) * c.
Proof.
  intros Hw Hf HQ.
  set (xk := fun k : nat => a + INR k * w).
  assert (Hx0 : xk O = a) by (unfold xk; simpl; ring).
  assert (Hxs : forall k, xk (S k) = xk k + w) by (intro k; unfold xk; rewrite S_INR; ring).
  assert (Hrange : forall k, (k <= S n)%nat -> a <= xk k <= a + INR (S n) * w).
  { intros k Hk. unfold xk.
    assert (0 <= INR k * w) by (apply Rmult_le_pos; [apply pos_INR | exact Hw]).
    assert (INR k * w <= INR (S n) * w) by (apply Rmult_le_compat_r; [exact Hw | apply le_INR; exact Hk]).
    lra. }
  assert (Hex : forall k, (k <= n)%nat -> ex_RInt f (xk k) (xk (S k))).
  { intros k Hk.
    assert (Hcont : forall z, Rmin (xk k) (xk (S k)) <= z <= Rmax (xk k) (xk (S k)) ->
                              continuous f z).
    { rewrite Hxs, Rmin_left, Rmax_right by lra. intros z Hz. apply Hf.
      pose proof (Hrange k ltac:(lia)). pose proof (Hrange (S k) ltac:(lia)). rewrite Hxs in *.
      lra. }
    exact (ex_RInt_continuous f _ _ Hcont). }
  assert (Hind : forall j, (j <= n)%nat ->
            ex_RInt f a (xk (S j)) /\
            Rabs (RInt f a (xk (S j)) - sum_n Q j) <= INR (S j) * c).
  { induction j as [| j IH]; intros Hj.
    - rewrite <- Hx0, sum_O. split; [exact (Hex O Hj) |].
      simpl INR. rewrite Rmult_1_l. exact (HQ O Hj).
    - destruct (IH ltac:(lia)) as [Hex' Hb].
      split; [exact (ex_RInt_Chasles f a _ _ Hex' (Hex (S j) Hj)) |].
      replace (RInt f a (xk (S (S j))))
        with (RInt f a (xk (S j)) + RInt f (xk (S j)) (xk (S (S j))))
        by exact (RInt_Chasles f a _ _ Hex' (Hex (S j) Hj)).
      rewrite sum_Sn.
      change (plus (sum_n Q j) (Q (S j))) with (sum_n Q j + Q (S j)).
      replace (RInt f a (xk (S j)) + RInt f (xk (S j)) (xk (S (S j))) - (sum_n Q j + Q (S j)))
        with ((RInt f a (xk (S j)) - sum_n Q j)
              + (RInt f (xk (S j)) (xk (S (S j))) - Q (S j))) by ring.
      eapply Rle_trans; [apply Rabs_triang |].
      assert (Hq : Rabs (RInt f (xk (S j)) (xk (S (S j))) - Q (S j)) <= c)
        by exact (HQ (S j) Hj).
      rewrite (S_INR (S j)). lra. }
  exact (proj2 (Hind n (le_n n))).
Qed.
