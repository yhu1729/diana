From Stdlib Require Import Reals Lra Lia Psatz.
From Coquelicot Require Import Coquelicot.
From Diana.Real Require Import Quadrature Vector OneStep.
Open Scope R_scope.

Lemma taylor_first (y dy d2y : R -> R) (t h M2 : R) :
  0 <= h ->
  (forall s, t <= s <= t + h -> is_derive y s (dy s)) ->
  (forall s, t <= s <= t + h -> is_derive dy s (d2y s)) ->
  (forall s, t <= s <= t + h -> Rabs (d2y s) <= M2) ->
  Rabs (y (t + h) - y t - h * dy t) <= M2 * h ^ 2 / 2.
Proof.
  intros Hh Hy Hdy HM.
  assert (HD : forall s, t <= s <= t + h -> Rabs (dy s - dy t) <= M2 * (s - t)).
  { intros s Hs.
    apply (bound_of_derive (fun r => dy r - dy t) d2y (fun r => M2 * (r - t)) (fun _ => M2) t s).
    - lra.
    - intros r Hr. pose proof (Hdy r ltac:(lra)) as A. auto_derive.
      + repeat split; try exact I; eexists; eassumption.
      + rewrite (Derive_of _ _ _ A). field.
    - intros r _. auto_derive; [exact I | cbv beta; field].
    - intros r Hr. cbv beta. exact (HM r ltac:(lra)).
    - cbv beta. replace (dy t - dy t) with 0 by ring. rewrite Rabs_R0. right. field. }
  pose proof (bound_of_derive (fun r => y r - y t - (r - t) * dy t) (fun r => dy r - dy t)
                (fun r => M2 * (r - t) ^ 2 / 2) (fun r => M2 * (r - t)) t (t + h)) as HG.
  cbv beta in HG. replace (t + h - t) with h in HG by ring. apply HG.
  - lra.
  - intros r Hr. pose proof (Hy r Hr) as A. auto_derive.
    + repeat split; try exact I; eexists; eassumption.
    + rewrite (Derive_of _ _ _ A). field.
  - intros r _. auto_derive; [exact I | cbv beta; field].
  - intros r Hr. exact (HD r Hr).
  - replace (y t - y t - (t - t) * dy t) with 0 by ring. rewrite Rabs_R0. right. field.
Qed.

Theorem local_error (d : nat) (F : R -> (nat -> R) -> nat -> R) (Y Y2 : R -> nat -> R)
  (t h M2 : R) :
  0 <= h -> 0 <= M2 ->
  (forall i, (i < d)%nat -> forall s, t <= s <= t + h ->
     is_derive (fun r => Y r i) s (F s (Y s) i)) ->
  (forall i, (i < d)%nat -> forall s, t <= s <= t + h ->
     is_derive (fun r => F r (Y r) i) s (Y2 s i)) ->
  (forall i, (i < d)%nat -> forall s, t <= s <= t + h -> Rabs (Y2 s i) <= M2) ->
  vnorm d (fun i => Y (t + h) i - Y t i - h * F t (Y t) i) <= M2 * h ^ 2 / 2.
Proof.
  intros Hh HM0 HY HF HM.
  apply vnorm_le; [apply Rmult_le_pos; [apply Rmult_le_pos; [lra | apply pow_le; lra] | lra] |].
  intros i Hi.
  exact (taylor_first (fun r => Y r i) (fun r => F r (Y r) i) (fun r => Y2 r i) t h M2 Hh
           (HY i Hi) (HF i Hi) (HM i Hi)).
Qed.

Definition euler (F : R -> (nat -> R) -> nat -> R) (t0 h : R) (y0 : nat -> R) (k : nat)
  : nat -> R := iterate F t0 h y0 k.

Theorem global_error (d : nat) (F : R -> (nat -> R) -> nat -> R) (Y Y2 : R -> nat -> R)
  (t0 h L M2 : R) (N : nat) :
  0 < h -> 0 < L -> 0 <= M2 ->
  (forall i, (i < d)%nat -> forall s, t0 <= s <= t0 + INR N * h ->
     is_derive (fun r => Y r i) s (F s (Y s) i)) ->
  (forall i, (i < d)%nat -> forall s, t0 <= s <= t0 + INR N * h ->
     is_derive (fun r => F r (Y r) i) s (Y2 s i)) ->
  (forall i, (i < d)%nat -> forall s, t0 <= s <= t0 + INR N * h -> Rabs (Y2 s i) <= M2) ->
  (forall s, t0 <= s <= t0 + INR N * h -> forall y z,
     vnorm d (fun i => F s y i - F s z i) <= L * vnorm d (fun i => y i - z i)) ->
  forall k, (k <= N)%nat ->
  vnorm d (fun i => euler F t0 h (Y t0) k i - Y (t0 + INR k * h) i)
    <= M2 * h / (2 * L) * (exp (L * (INR k * h)) - 1).
Proof.
  intros Hh HL HM0 HY HF HM Hlip k Hk.
  assert (Hgrid : forall j, (j < N)%nat -> forall s, t0 + INR j * h <= s <= t0 + INR j * h + h ->
            t0 <= s <= t0 + INR N * h).
  { intros j Hj s Hs.
    assert (Hj' : INR j + 1 <= INR N) by (rewrite <- S_INR; apply le_INR; lia).
    assert (0 <= INR j * h) by (apply Rmult_le_pos; [apply pos_INR | lra]).
    assert ((INR j + 1) * h <= INR N * h) by (apply Rmult_le_compat_r; lra).
    lra. }
  assert (Htr : forall j, (j < N)%nat ->
     vnorm d (fun i => Y (t0 + INR (S j) * h) i - Y (t0 + INR j * h) i
                       - h * F (t0 + INR j * h) (Y (t0 + INR j * h)) i) <= M2 * h ^ 2 / 2).
  { intros j Hj.
    replace (t0 + INR (S j) * h) with (t0 + INR j * h + h) by (rewrite S_INR; ring).
    apply (local_error d F Y Y2); [lra | exact HM0 | | | ]; intros i Hi s Hs.
    - exact (HY i Hi s (Hgrid j Hj s Hs)).
    - exact (HF i Hi s (Hgrid j Hj s Hs)).
    - exact (HM i Hi s (Hgrid j Hj s Hs)). }
  assert (Hlip' : forall j, (j < N)%nat -> forall y z,
     vnorm d (fun i => F (t0 + INR j * h) y i - F (t0 + INR j * h) z i)
       <= L * vnorm d (fun i => y i - z i)).
  { intros j Hj y z. apply Hlip. apply (Hgrid j Hj). lra. }
  assert (Htau : 0 <= M2 * h ^ 2 / 2)
    by (apply Rmult_le_pos; [apply Rmult_le_pos; [lra | apply pow_le; lra] | lra]).
  pose proof (one_step_error d F Y t0 h L (M2 * h ^ 2 / 2) N Hh HL Htau Hlip' Htr k Hk) as H.
  unfold euler.
  replace (M2 * h / (2 * L)) with (M2 * h ^ 2 / 2 / (h * L)) by (field; lra).
  exact H.
Qed.
