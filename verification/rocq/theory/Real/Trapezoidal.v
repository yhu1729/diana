From Stdlib Require Import Reals Lra Lia Psatz.
From Coquelicot Require Import Coquelicot.
From Diana.Real Require Import Quadrature.
Open Scope R_scope.

Lemma E_derive (F f : R -> R) (x t dF df : R) :
  is_derive F t dF -> is_derive f t df ->
  is_derive (fun s => F s - (s - x) * (f x + f s) / 2) t
    (dF - ((f x + f t) / 2 + (t - x) * df / 2)).
Proof.
  intros HF Hf. auto_derive.
  - split; [exists dF; exact HF |]. split; [exists df; exact Hf | exact I].
  - rewrite (Derive_of _ _ _ HF), (Derive_of _ _ _ Hf). field.
Qed.

Theorem local_error (f f' f'' : R -> R) (x h M2 : R) :
  0 <= h ->
  (forall t, x <= t <= x + h -> is_derive f t (f' t)) ->
  (forall t, x <= t <= x + h -> is_derive f' t (f'' t)) ->
  (forall t, x <= t <= x + h -> Rabs (f'' t) <= M2) ->
  Rabs (RInt f x (x + h) - h * (f x + f (x + h)) / 2) <= M2 * h ^ 3 / 12.
Proof.
  intros Hh Hf Hf' HM.
  assert (Hxh : x <= x + h) by lra.
  set (g := fun s => f (clamp x (x + h) s)).
  assert (HI : forall t, is_derive (fun s => RInt g x s) t (g t))
    by exact (extend_RInt_derive f f' x (x + h) x Hxh Hf).
  set (D := fun t => (f t - f x) / 2 - (t - x) * f' t / 2).
  set (E := fun t => RInt g x t - (t - x) * (f x + f t) / 2).
  assert (HD : forall t, x <= t <= x + h -> is_derive D t (- ((t - x) * f'' t) / 2)).
  { intros t Ht. unfold D. auto_derive.
    - split; [exists (f' t); exact (Hf t Ht) |].
      split; [exists (f'' t); exact (Hf' t Ht) | exact I].
    - rewrite (Derive_of _ _ _ (Hf t Ht)), (Derive_of _ _ _ (Hf' t Ht)). field. }
  assert (HE : forall t, x <= t <= x + h -> is_derive E t (D t)).
  { intros t Ht.
    replace (D t) with (g t - ((f x + f t) / 2 + (t - x) * f' t / 2)).
    - exact (E_derive (fun s => RInt g x s) f x t (g t) (f' t) (HI t) (Hf t Ht)).
    - unfold g, D. rewrite (clamp_id x (x + h) t Ht). field. }
  assert (HDb : forall t, x <= t <= x + h -> Rabs (D t) <= M2 * (t - x) ^ 2 / 4).
  { intros t Ht.
    apply (bound_of_derive D (fun s => - ((s - x) * f'' s) / 2)
             (fun s => M2 * (s - x) ^ 2 / 4) (fun s => M2 * (s - x) / 2) x t).
    - lra.
    - intros s Hs. apply HD. lra.
    - intros s _. auto_derive; [exact I | field].
    - intros s Hs. pose proof (HM s ltac:(lra)). split_Rabs; nra.
    - unfold D. replace ((f x - f x) / 2 - (x - x) * f' x / 2) with 0 by field.
      rewrite Rabs_R0. right. field. }
  assert (HEb : Rabs (E (x + h)) <= M2 * (x + h - x) ^ 3 / 12).
  { apply (bound_of_derive E D (fun s => M2 * (s - x) ^ 3 / 12)
             (fun s => M2 * (s - x) ^ 2 / 4) x (x + h)).
    - lra.
    - exact HE.
    - intros s _. auto_derive; [exact I | field].
    - exact HDb.
    - unfold E. replace (RInt g x x) with 0 by (rewrite RInt_point; reflexivity).
      replace (0 - (x - x) * (f x + f x) / 2) with 0 by field.
      rewrite Rabs_R0. right. field. }
  unfold E in HEb.
  replace (x + h - x) with h in HEb by ring.
  unfold g in HEb. rewrite (extend_RInt f x (x + h) x (x + h)) in HEb by lra.
  exact HEb.
Qed.

Lemma sum_pair (u : nat -> R) (c : R) (n : nat) :
  sum_n (fun k => c * (u k + u (S k)) / 2) n = c * ((u O + u (S n)) / 2 + sum_n_m u 1 n).
Proof.
  induction n as [| n IH].
  - rewrite sum_O, sum_n_m_zero by lia. unfold zero; simpl; field.
  - rewrite sum_Sn, IH, (sum_n_Sm u 1 n) by lia. unfold plus; simpl; field.
Qed.

Theorem composite_error (f f' f'' : R -> R) (a b h M2 : R) (m : nat) :
  a <= b -> (1 <= m)%nat -> h = (b - a) / INR m ->
  (forall t, a <= t <= b -> is_derive f t (f' t)) ->
  (forall t, a <= t <= b -> is_derive f' t (f'' t)) ->
  (forall t, a <= t <= b -> Rabs (f'' t) <= M2) ->
  Rabs (RInt f a b - h * ((f a + f b) / 2 + sum_n_m (fun i => f (a + INR i * h)) 1 (m - 1)))
    <= (b - a) * h ^ 2 * M2 / 12.
Proof.
  intros Hab Hm Hh Hf Hf' HM.
  assert (Hm0 : 0 < INR m) by (apply lt_0_INR; lia).
  assert (Hmh : INR m * h = b - a) by (rewrite Hh; field; lra).
  assert (Hh0 : 0 <= h) by nra.
  destruct m as [| n]; [lia |].
  assert (Hb : a + INR (S n) * h = b) by lra.
  assert (Hsub : forall k, (k <= n)%nat -> forall t,
            a + INR k * h <= t <= a + INR k * h + h -> a <= t <= b).
  { intros k Hk t Ht.
    assert (Hk' : INR k + 1 <= INR (S n)) by (rewrite <- S_INR; apply le_INR; lia).
    assert (0 <= INR k * h) by (apply Rmult_le_pos; [apply pos_INR | exact Hh0]).
    assert ((INR k + 1) * h <= INR (S n) * h) by (apply Rmult_le_compat_r; assumption).
    lra. }
  set (q := fun k => h * (f (a + INR k * h) + f (a + INR (S k) * h)) / 2).
  assert (Hcont : forall t, a <= t <= a + INR (S n) * h -> continuous f t).
  { rewrite Hb. intros t Ht. apply continuity_pt_filterlim, derivable_continuous_pt.
    exists (f' t). exact (proj1 (is_derive_Reals f t (f' t)) (Hf t Ht)). }
  assert (Hloc : forall k, (k <= n)%nat ->
            Rabs (RInt f (a + INR k * h) (a + INR (S k) * h) - q k) <= M2 * h ^ 3 / 12).
  { intros k Hk. unfold q.
    replace (a + INR (S k) * h) with (a + INR k * h + h) by (rewrite S_INR; ring).
    apply (local_error f f' f'' (a + INR k * h) h M2 Hh0); intros t Ht.
    - exact (Hf t (Hsub k Hk t Ht)).
    - exact (Hf' t (Hsub k Hk t Ht)).
    - exact (HM t (Hsub k Hk t Ht)). }
  pose proof (panel_error f q a h (M2 * h ^ 3 / 12) n Hh0 Hcont Hloc) as Hp.
  rewrite Hb in Hp.
  replace (S n - 1)%nat with n by lia.
  replace (h * ((f a + f b) / 2 + sum_n_m (fun i => f (a + INR i * h)) 1 n)) with (sum_n q n).
  - eapply Rle_trans; [exact Hp |]. right. rewrite <- Hmh. field.
  - unfold q. rewrite (sum_pair (fun i => f (a + INR i * h)) h n), Hb.
    replace (a + INR 0 * h) with a by (simpl; ring). reflexivity.
Qed.
