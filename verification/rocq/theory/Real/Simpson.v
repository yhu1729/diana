From Stdlib Require Import Reals Lra Lia Psatz.
From Coquelicot Require Import Coquelicot.
From Diana.Real Require Import Quadrature.
Open Scope R_scope.

Lemma zero_R : (zero : R) = 0.
Proof. reflexivity. Qed.

Lemma sym_add (F F' : R -> R) (c s : R) :
  is_derive F (c + s) (F' (c + s)) -> is_derive F (c - s) (F' (c - s)) ->
  is_derive (fun s => F (c + s) + F (c - s)) s (F' (c + s) - F' (c - s)).
Proof.
  intros H1 H2. unfold Rminus in H2 |- *. auto_derive.
  - split; [exists (F' (c + s)); exact H1 |]. split; [exists (F' (c + - s)); exact H2 | exact I].
  - rewrite (Derive_of _ _ _ H1), (Derive_of _ _ _ H2). ring.
Qed.

Lemma sym_sub (F F' : R -> R) (c s : R) :
  is_derive F (c + s) (F' (c + s)) -> is_derive F (c - s) (F' (c - s)) ->
  is_derive (fun s => F (c + s) - F (c - s)) s (F' (c + s) + F' (c - s)).
Proof.
  intros H1 H2. unfold Rminus in H2 |- *. auto_derive.
  - split; [exists (F' (c + s)); exact H1 |]. split; [exists (F' (c + - s)); exact H2 | exact I].
  - rewrite (Derive_of _ _ _ H1), (Derive_of _ _ _ H2). ring.
Qed.

Theorem symmetric_error (f f' f'' f''' f'''' : R -> R) (c h M4 : R) :
  0 <= h ->
  (forall t, c - h <= t <= c + h -> is_derive f t (f' t)) ->
  (forall t, c - h <= t <= c + h -> is_derive f' t (f'' t)) ->
  (forall t, c - h <= t <= c + h -> is_derive f'' t (f''' t)) ->
  (forall t, c - h <= t <= c + h -> is_derive f''' t (f'''' t)) ->
  (forall t, c - h <= t <= c + h -> Rabs (f'''' t) <= M4) ->
  Rabs (RInt f (c - h) (c + h) - h / 3 * (f (c - h) + 4 * f c + f (c + h)))
    <= M4 * h ^ 5 / 90.
Proof.
  intros Hh Hf Hf1 Hf2 Hf3 HM.
  assert (Hlo : c - h <= c + h) by lra.
  assert (Hp : forall s, 0 <= s <= h -> c - h <= c + s <= c + h) by (intros; lra).
  assert (Hm : forall s, 0 <= s <= h -> c - h <= c - s <= c + h) by (intros; lra).
  set (g := fun z => f (clamp (c - h) (c + h) z)).
  set (G := fun t => RInt g (c - h) t).
  assert (HG : forall t, is_derive G t (g t))
    by exact (extend_RInt_derive f f' (c - h) (c + h) (c - h) Hlo Hf).
  assert (Hint : G (c + h) - G (c - h) = RInt f (c - h) (c + h)).
  { unfold G. replace (RInt g (c - h) (c - h)) with 0 by (rewrite RInt_point; reflexivity).
    unfold g. rewrite (extend_RInt f (c - h) (c + h) (c - h) (c + h)) by lra. ring. }
  clearbody G.
  set (E3 := fun s => - (s / 3 * (f''' (c + s) - f''' (c - s)))).
  set (E2 := fun s => (f' (c + s) - f' (c - s)) / 3 - s / 3 * (f'' (c + s) + f'' (c - s))).
  set (E1 := fun s =>
    2 / 3 * (f (c + s) + f (c - s)) - 4 / 3 * f c - s / 3 * (f' (c + s) - f' (c - s))).
  set (E := fun s => (G (c + s) - G (c - s)) - s / 3 * (f (c + s) + f (c - s) + 4 * f c)).
  assert (HD : forall s, 0 <= s <= h ->
            is_derive (fun s => f''' (c + s) - f''' (c - s)) s (f'''' (c + s) + f'''' (c - s))).
  { intros s Hs. exact (sym_sub f''' f'''' c s (Hf3 _ (Hp s Hs)) (Hf3 _ (Hm s Hs))). }
  assert (HE2 : forall s, 0 <= s <= h -> is_derive E2 s (E3 s)).
  { intros s Hs. unfold E2, E3.
    pose proof (Hf1 _ (Hp s Hs)) as A1. pose proof (Hf1 _ (Hm s Hs)) as A2.
    pose proof (Hf2 _ (Hp s Hs)) as A3. pose proof (Hf2 _ (Hm s Hs)) as A4.
    unfold Rminus in A2, A4 |- *.
    auto_derive.
    - repeat split; try exact I; eexists; eassumption.
    - rewrite (Derive_of _ _ _ A1), (Derive_of _ _ _ A2), (Derive_of _ _ _ A3),
        (Derive_of _ _ _ A4). field. }
  assert (HE1 : forall s, 0 <= s <= h -> is_derive E1 s (E2 s)).
  { intros s Hs. unfold E1, E2.
    pose proof (Hf _ (Hp s Hs)) as A1. pose proof (Hf _ (Hm s Hs)) as A2.
    pose proof (Hf1 _ (Hp s Hs)) as A3. pose proof (Hf1 _ (Hm s Hs)) as A4.
    unfold Rminus in A2, A4 |- *.
    auto_derive.
    - repeat split; try exact I; eexists; eassumption.
    - rewrite (Derive_of _ _ _ A1), (Derive_of _ _ _ A2), (Derive_of _ _ _ A3),
        (Derive_of _ _ _ A4). field. }
  assert (HE : forall s, 0 <= s <= h -> is_derive E s (E1 s)).
  { intros s Hs. unfold E, E1.
    pose proof (HG (c + s)) as A1. pose proof (HG (c - s)) as A2.
    pose proof (Hf _ (Hp s Hs)) as A3. pose proof (Hf _ (Hm s Hs)) as A4.
    unfold Rminus in A2, A4 |- *.
    auto_derive.
    - repeat split; try exact I; eexists; eassumption.
    - rewrite (Derive_of _ _ _ A1), (Derive_of _ _ _ A2), (Derive_of _ _ _ A3),
        (Derive_of _ _ _ A4).
      unfold g. cbv beta.
      rewrite (clamp_id (c - h) (c + h) (c + s) (Hp s Hs)),
        (clamp_id (c - h) (c + h) (c + - s) (Hm s Hs)). field. }
  assert (HDb : forall s, 0 <= s <= h -> Rabs (f''' (c + s) - f''' (c - s)) <= 2 * M4 * s).
  { intros s Hs.
    apply (bound_of_derive (fun s => f''' (c + s) - f''' (c - s))
             (fun s => f'''' (c + s) + f'''' (c - s)) (fun s => 2 * M4 * s) (fun _ => 2 * M4) 0 s).
    - lra.
    - intros t Ht. apply HD. lra.
    - intros t _. auto_derive; [exact I | cbv beta; field].
    - intros t Ht. cbv beta.
      pose proof (HM _ (Hp t ltac:(lra))). pose proof (HM _ (Hm t ltac:(lra))).
      eapply Rle_trans; [apply Rabs_triang | lra].
    - cbv beta. rewrite Rplus_0_r, Rminus_0_r.
      replace (f''' c - f''' c) with 0 by ring. rewrite Rabs_R0. right. cbv beta. field. }
  assert (HE3b : forall s, 0 <= s <= h -> Rabs (E3 s) <= 2 / 3 * M4 * s ^ 2).
  { intros s Hs. unfold E3. cbv beta. rewrite Rabs_Ropp, Rabs_mult, (Rabs_pos_eq (s / 3)) by lra.
    apply Rle_trans with (s / 3 * (2 * M4 * s)).
    - apply Rmult_le_compat_l; [lra | exact (HDb s Hs)].
    - right. field. }
  assert (HE2b : forall s, 0 <= s <= h -> Rabs (E2 s) <= 2 / 9 * M4 * s ^ 3).
  { intros s Hs.
    apply (bound_of_derive E2 E3 (fun s => 2 / 9 * M4 * s ^ 3) (fun s => 2 / 3 * M4 * s ^ 2) 0 s).
    - lra.
    - intros t Ht. apply HE2. lra.
    - intros t _. auto_derive; [exact I | cbv beta; field].
    - intros t Ht. apply HE3b. lra.
    - unfold E2. cbv beta. rewrite Rplus_0_r, Rminus_0_r.
      replace ((f' c - f' c) / 3 - 0 / 3 * (f'' c + f'' c)) with 0 by field.
      rewrite Rabs_R0. right. cbv beta. field. }
  assert (HE1b : forall s, 0 <= s <= h -> Rabs (E1 s) <= M4 * s ^ 4 / 18).
  { intros s Hs.
    apply (bound_of_derive E1 E2 (fun s => M4 * s ^ 4 / 18) (fun s => 2 / 9 * M4 * s ^ 3) 0 s).
    - lra.
    - intros t Ht. apply HE1. lra.
    - intros t _. auto_derive; [exact I | cbv beta; field].
    - intros t Ht. apply HE2b. lra.
    - unfold E1. cbv beta. rewrite Rplus_0_r, Rminus_0_r.
      replace (2 / 3 * (f c + f c) - 4 / 3 * f c - 0 / 3 * (f' c - f' c)) with 0 by field.
      rewrite Rabs_R0. right. cbv beta. field. }
  assert (HEb : Rabs (E h) <= M4 * h ^ 5 / 90).
  { apply (bound_of_derive E E1 (fun s => M4 * s ^ 5 / 90) (fun s => M4 * s ^ 4 / 18) 0 h).
    - exact Hh.
    - exact HE.
    - intros t _. auto_derive; [exact I | cbv beta; field].
    - exact HE1b.
    - unfold E. cbv beta. rewrite Rplus_0_r, Rminus_0_r.
      replace (G c - G c - 0 / 3 * (f c + f c + 4 * f c)) with 0 by field.
      rewrite Rabs_R0. right. cbv beta. field. }
  unfold E in HEb. cbv beta in HEb. rewrite Hint in HEb.
  replace (h / 3 * (f (c - h) + 4 * f c + f (c + h)))
    with (h / 3 * (f (c + h) + f (c - h) + 4 * f c)) by ring.
  exact HEb.
Qed.

Theorem local_error (f f' f'' f''' f'''' : R -> R) (x h M4 : R) :
  0 <= h ->
  (forall t, x <= t <= x + 2 * h -> is_derive f t (f' t)) ->
  (forall t, x <= t <= x + 2 * h -> is_derive f' t (f'' t)) ->
  (forall t, x <= t <= x + 2 * h -> is_derive f'' t (f''' t)) ->
  (forall t, x <= t <= x + 2 * h -> is_derive f''' t (f'''' t)) ->
  (forall t, x <= t <= x + 2 * h -> Rabs (f'''' t) <= M4) ->
  Rabs (RInt f x (x + 2 * h) - h / 3 * (f x + 4 * f (x + h) + f (x + 2 * h)))
    <= M4 * h ^ 5 / 90.
Proof.
  intros Hh Hf Hf1 Hf2 Hf3 HM.
  pose proof (symmetric_error f f' f'' f''' f'''' (x + h) h M4 Hh) as H.
  replace (x + h - h) with x in H by ring.
  replace (x + h + h) with (x + 2 * h) in H by ring.
  exact (H Hf Hf1 Hf2 Hf3 HM).
Qed.

Lemma sum_triple (u : nat -> R) (c : R) (n : nat) :
  sum_n (fun k => c * (u (2 * k)%nat + 4 * u (2 * k + 1)%nat + u (2 * k + 2)%nat)) n
  = c * (u O + u (2 * n + 2)%nat + 4 * sum_n (fun k => u (2 * k + 1)%nat) n
         + 2 * sum_n_m (fun k => u (2 * k)%nat) 1 n).
Proof.
  induction n as [| n IH].
  - rewrite !sum_O, sum_n_m_zero, zero_R by lia.
    change (2 * 0)%nat with 0%nat. change (2 * 0 + 1)%nat with 1%nat.
    change (2 * 0 + 2)%nat with 2%nat.
    match goal with |- @eq _ ?x ?y => change (@eq R x y) end. ring.
  - rewrite sum_Sn, IH, (sum_Sn (fun k => u (2 * k + 1)%nat)), (sum_n_Sm _ 1 n) by lia.
    repeat match goal with |- context [plus ?x ?y] => change (plus x y) with (x + y) end.
    cbv beta.
    replace (2 * S n)%nat with (2 * n + 2)%nat by lia.
    replace (2 * S n + 1)%nat with (2 * n + 3)%nat by lia.
    replace (2 * S n + 2)%nat with (2 * n + 4)%nat by lia.
    match goal with |- @eq _ ?x ?y => change (@eq R x y) end. ring.
Qed.

Theorem composite_error (f f' f'' f''' f'''' : R -> R) (a b h M4 : R) (p : nat) :
  a <= b -> (1 <= p)%nat -> h = (b - a) / (2 * INR p) ->
  (forall t, a <= t <= b -> is_derive f t (f' t)) ->
  (forall t, a <= t <= b -> is_derive f' t (f'' t)) ->
  (forall t, a <= t <= b -> is_derive f'' t (f''' t)) ->
  (forall t, a <= t <= b -> is_derive f''' t (f'''' t)) ->
  (forall t, a <= t <= b -> Rabs (f'''' t) <= M4) ->
  Rabs (RInt f a b - h / 3 * (f a + f b + 4 * sum_n (fun k => f (a + INR (2 * k + 1) * h)) (p - 1)
                              + 2 * sum_n_m (fun k => f (a + INR (2 * k) * h)) 1 (p - 1)))
    <= (b - a) * h ^ 4 * M4 / 180.
Proof.
  intros Hab Hp Hh Hf Hf1 Hf2 Hf3 HM.
  assert (Hp0 : 0 < INR p) by (apply lt_0_INR; lia).
  assert (Hph : 2 * INR p * h = b - a) by (rewrite Hh; field; lra).
  assert (Hh0 : 0 <= h) by nra.
  assert (Hw : 0 <= 2 * h) by lra.
  destruct p as [| n]; [lia |].
  replace (S n - 1)%nat with n by lia.
  assert (Hb : a + INR (S n) * (2 * h) = b) by lra.
  assert (Hsub : forall k, (k <= n)%nat -> forall t,
            a + INR k * (2 * h) <= t <= a + INR k * (2 * h) + 2 * h -> a <= t <= b).
  { intros k Hk t Ht.
    assert (Hk' : INR k + 1 <= INR (S n)) by (rewrite <- S_INR; apply le_INR; lia).
    assert (0 <= INR k * (2 * h)) by (apply Rmult_le_pos; [apply pos_INR | exact Hw]).
    assert ((INR k + 1) * (2 * h) <= INR (S n) * (2 * h)) by (apply Rmult_le_compat_r; assumption).
    lra. }
  set (Q := fun k => h / 3 * (f (a + INR k * (2 * h)) + 4 * f (a + INR k * (2 * h) + h)
                              + f (a + INR k * (2 * h) + 2 * h))).
  assert (Hcont : forall t, a <= t <= a + INR (S n) * (2 * h) -> continuous f t).
  { rewrite Hb. intros t Ht. apply continuity_pt_filterlim, derivable_continuous_pt.
    exists (f' t). exact (proj1 (is_derive_Reals f t (f' t)) (Hf t Ht)). }
  assert (Hloc : forall k, (k <= n)%nat ->
            Rabs (RInt f (a + INR k * (2 * h)) (a + INR (S k) * (2 * h)) - Q k)
              <= M4 * h ^ 5 / 90).
  { intros k Hk. unfold Q.
    replace (a + INR (S k) * (2 * h)) with (a + INR k * (2 * h) + 2 * h) by (rewrite S_INR; ring).
    apply (local_error f f' f'' f''' f'''' (a + INR k * (2 * h)) h M4 Hh0); intros t Ht.
    - exact (Hf t (Hsub k Hk t Ht)).
    - exact (Hf1 t (Hsub k Hk t Ht)).
    - exact (Hf2 t (Hsub k Hk t Ht)).
    - exact (Hf3 t (Hsub k Hk t Ht)).
    - exact (HM t (Hsub k Hk t Ht)). }
  pose proof (panel_error f Q a (2 * h) (M4 * h ^ 5 / 90) n Hw Hcont Hloc) as Hpe.
  rewrite Hb in Hpe.
  assert (HT : sum_n Q n
               = h / 3 * (f a + f b + 4 * sum_n (fun k => f (a + INR (2 * k + 1) * h)) n
                          + 2 * sum_n_m (fun k => f (a + INR (2 * k) * h)) 1 n)).
  { rewrite (sum_n_ext Q (fun k => h / 3 * ((fun i => f (a + INR i * h)) (2 * k)%nat
                                            + 4 * (fun i => f (a + INR i * h)) (2 * k + 1)%nat
                                            + (fun i => f (a + INR i * h)) (2 * k + 2)%nat))).
    - rewrite (sum_triple (fun i => f (a + INR i * h)) (h / 3) n). cbv beta.
      replace (a + INR 0 * h) with a by (simpl; ring).
      replace (a + INR (2 * n + 2) * h) with b.
      + reflexivity.
      + rewrite plus_INR, mult_INR, S_INR in *. simpl. lra.
    - intro k. unfold Q. cbv beta.
      replace (a + INR (2 * k) * h) with (a + INR k * (2 * h)) by (rewrite mult_INR; simpl; ring).
      replace (a + INR (2 * k + 1) * h) with (a + INR k * (2 * h) + h)
        by (rewrite plus_INR, mult_INR; simpl; ring).
      replace (a + INR (2 * k + 2) * h) with (a + INR k * (2 * h) + 2 * h)
        by (rewrite plus_INR, mult_INR; simpl; ring).
      reflexivity. }
  rewrite <- HT.
  eapply Rle_trans; [exact Hpe |].
  right. rewrite <- Hph. field.
Qed.
