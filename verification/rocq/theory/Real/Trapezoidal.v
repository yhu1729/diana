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

Lemma clamp_lipschitz (x y u v : R) :
  Rabs (Rmax x (Rmin u y) - Rmax x (Rmin v y)) <= Rabs (u - v).
Proof.
  apply Rle_trans with (Rabs (Rmin u y - Rmin v y)).
  - generalize (Rmin u y) (Rmin v y). intros p q.
    unfold Rmax. destruct (Rle_dec x p), (Rle_dec x q); split_Rabs; lra.
  - unfold Rmin. destruct (Rle_dec u y), (Rle_dec v y); split_Rabs; lra.
Qed.

Lemma clamp_continuous (x y t : R) : continuity_pt (fun s => Rmax x (Rmin s y)) t.
Proof.
  apply continuity_pt_locally. intros eps. exists eps. intros u Hu.
  eapply Rle_lt_trans; [apply clamp_lipschitz | exact Hu].
Qed.

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
  set (c := fun s => Rmax x (Rmin s (x + h))).
  set (g := fun s => f (c s)).
  assert (Hc : forall s, x <= c s <= x + h).
  { intro s. unfold c. split; [apply Rmax_l |].
    apply Rmax_lub; [lra | apply Rmin_r]. }
  assert (Hcid : forall s, x <= s <= x + h -> c s = s).
  { intros s Hs. unfold c. rewrite Rmin_left by lra. apply Rmax_right; lra. }
  assert (Hgc : forall s, continuous g s).
  { intro s. apply continuity_pt_filterlim. apply (continuity_pt_comp c f s).
    - apply clamp_continuous.
    - apply derivable_continuous_pt. exists (f' (c s)).
      exact (proj1 (is_derive_Reals f (c s) (f' (c s))) (Hf (c s) (Hc s))). }
  assert (HI : forall t, is_derive (fun s => RInt g x s) t (g t)).
  { intro t. apply (is_derive_RInt g _ x t); [| apply Hgc].
    apply filter_forall. intro s.
    exact (RInt_correct g x s (ex_RInt_continuous g x s (fun z _ => Hgc z))). }
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
    - unfold g, D. rewrite (Hcid t Ht). field. }
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
  rewrite (RInt_ext g f x (x + h)) in HEb.
  - exact HEb.
  - rewrite Rmin_left, Rmax_right by lra. intros s Hs. unfold g. rewrite Hcid by lra.
    reflexivity.
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
  set (xk := fun k : nat => a + INR k * h).
  assert (Hx0 : xk O = a) by (unfold xk; simpl; ring).
  assert (Hxs : forall k, xk (S k) = xk k + h) by (intro k; unfold xk; rewrite S_INR; ring).
  assert (Hsub : forall k, (S k <= m)%nat -> forall t, xk k <= t <= xk k + h -> a <= t <= b).
  { intros k Hk t Ht. unfold xk in Ht.
    assert (Hk' : INR k + 1 <= INR m) by (rewrite <- S_INR; apply le_INR; exact Hk).
    assert (0 <= INR k * h) by (apply Rmult_le_pos; [apply pos_INR | exact Hh0]).
    assert ((INR k + 1) * h <= INR m * h) by (apply Rmult_le_compat_r; assumption).
    lra. }
  assert (Hex : forall k, (S k <= m)%nat -> ex_RInt f (xk k) (xk (S k))).
  { intros k Hk.
    assert (Hcont : forall z, Rmin (xk k) (xk (S k)) <= z <= Rmax (xk k) (xk (S k)) ->
                              continuous f z).
    { rewrite Hxs, Rmin_left, Rmax_right by lra. intros z Hz.
      apply continuity_pt_filterlim, derivable_continuous_pt. exists (f' z).
      exact (proj1 (is_derive_Reals f z (f' z)) (Hf z (Hsub k Hk z Hz))). }
    exact (ex_RInt_continuous f _ _ Hcont). }
  set (q := fun k => h * (f (xk k) + f (xk (S k))) / 2).
  assert (Hloc : forall k, (S k <= m)%nat ->
            Rabs (RInt f (xk k) (xk (S k)) - q k) <= M2 * h ^ 3 / 12).
  { intros k Hk. unfold q. rewrite Hxs.
    apply (local_error f f' f'' (xk k) h M2 Hh0); intros t Ht.
    - exact (Hf t (Hsub k Hk t Ht)).
    - exact (Hf' t (Hsub k Hk t Ht)).
    - exact (HM t (Hsub k Hk t Ht)). }
  assert (Hind : forall n, (S n <= m)%nat ->
            ex_RInt f a (xk (S n)) /\
            Rabs (RInt f a (xk (S n)) - sum_n q n) <= INR (S n) * (M2 * h ^ 3 / 12)).
  { induction n as [| n IH]; intros Hn.
    - rewrite <- Hx0, sum_O. split; [exact (Hex O Hn) |].
      simpl INR. rewrite Rmult_1_l. exact (Hloc O Hn).
    - destruct (IH ltac:(lia)) as [Hex' Hb].
      split; [exact (ex_RInt_Chasles f a _ _ Hex' (Hex (S n) Hn)) |].
      replace (RInt f a (xk (S (S n))))
        with (RInt f a (xk (S n)) + RInt f (xk (S n)) (xk (S (S n))))
        by exact (RInt_Chasles f a _ _ Hex' (Hex (S n) Hn)).
      rewrite sum_Sn.
      change (plus (sum_n q n) (q (S n))) with (sum_n q n + q (S n)).
      replace (RInt f a (xk (S n)) + RInt f (xk (S n)) (xk (S (S n))) - (sum_n q n + q (S n)))
        with ((RInt f a (xk (S n)) - sum_n q n)
              + (RInt f (xk (S n)) (xk (S (S n))) - q (S n))) by ring.
      eapply Rle_trans; [apply Rabs_triang |].
      pose proof (Hloc (S n) Hn). rewrite (S_INR (S n)). lra. }
  destruct m as [| n]; [lia |].
  destruct (Hind n (le_n _)) as [_ Hb].
  assert (Hxm : xk (S n) = b) by (unfold xk; lra).
  replace (S n - 1)%nat with n by lia.
  replace (h * ((f a + f b) / 2 + sum_n_m (fun i => f (a + INR i * h)) 1 n)) with (sum_n q n).
  - rewrite Hxm in Hb. eapply Rle_trans; [exact Hb |].
    right. rewrite <- Hmh. field.
  - unfold q. rewrite (sum_pair (fun i => f (xk i)) h n), Hx0, Hxm. reflexivity.
Qed.
