From Stdlib Require Import Reals Lra Lia Psatz.
From Diana.Real Require Import Vector.
Open Scope R_scope.

Lemma gronwall_pow (a : nat -> R) (c tau : R) (N : nat) :
  0 < c -> 0 <= tau -> a O <= 0 ->
  (forall k, (k < N)%nat -> a (S k) <= (1 + c) * a k + tau) ->
  forall k, (k <= N)%nat -> a k <= tau * ((1 + c) ^ k - 1) / c.
Proof.
  intros Hc Ht H0 Hs k. induction k as [| k IH]; intro Hk.
  - simpl. replace (tau * (1 - 1) / c) with 0 by (field; lra). exact H0.
  - eapply Rle_trans; [apply Hs; lia |].
    specialize (IH ltac:(lia)).
    assert (Hp : (1 + c) * a k <= (1 + c) * (tau * ((1 + c) ^ k - 1) / c))
      by (apply Rmult_le_compat_l; lra).
    simpl (_ ^ S k).
    replace (tau * ((1 + c) * (1 + c) ^ k - 1) / c)
      with ((1 + c) * (tau * ((1 + c) ^ k - 1) / c) + tau) by (field; lra).
    lra.
Qed.

Lemma pow_le_exp (c : R) (k : nat) : 0 <= c -> (1 + c) ^ k <= exp (INR k * c).
Proof.
  intro Hc. induction k as [| k IH].
  - simpl. rewrite Rmult_0_l, exp_0. lra.
  - rewrite S_INR. replace ((INR k + 1) * c) with (c + INR k * c) by ring.
    rewrite exp_plus. simpl.
    apply Rmult_le_compat; [lra | apply pow_le; lra | apply exp_ineq1_le | exact IH].
Qed.

Fixpoint iterate (Phi : R -> (nat -> R) -> nat -> R) (t0 h : R) (y0 : nat -> R) (k : nat)
  : nat -> R :=
  match k with
  | O => y0
  | S k' => fun i => iterate Phi t0 h y0 k' i
                     + h * Phi (t0 + INR k' * h) (iterate Phi t0 h y0 k') i
  end.

Theorem one_step_pow (d : nat) (Phi : R -> (nat -> R) -> nat -> R) (Y : R -> nat -> R)
  (t0 h L tau : R) (N : nat) :
  0 < h -> 0 < L -> 0 <= tau ->
  (forall k, (k < N)%nat -> forall y z,
     vnorm d (fun i => Phi (t0 + INR k * h) y i - Phi (t0 + INR k * h) z i)
       <= L * vnorm d (fun i => y i - z i)) ->
  (forall k, (k < N)%nat ->
     vnorm d (fun i => Y (t0 + INR (S k) * h) i - Y (t0 + INR k * h) i
                       - h * Phi (t0 + INR k * h) (Y (t0 + INR k * h)) i) <= tau) ->
  forall k, (k <= N)%nat ->
  vnorm d (fun i => iterate Phi t0 h (Y t0) k i - Y (t0 + INR k * h) i)
    <= tau * ((1 + h * L) ^ k - 1) / (h * L).
Proof.
  intros Hh HL Ht Hlip Htr.
  set (a := fun k => vnorm d (fun i => iterate Phi t0 h (Y t0) k i - Y (t0 + INR k * h) i)).
  assert (H0 : a O <= 0).
  { unfold a. apply vnorm_le; [lra |]. intros i _. simpl.
    replace (t0 + 0 * h) with t0 by ring. replace (Y t0 i - Y t0 i) with 0 by ring.
    rewrite Rabs_R0. lra. }
  assert (Hs : forall k, (k < N)%nat -> a (S k) <= (1 + h * L) * a k + tau).
  { intros k Hk. unfold a.
    set (yk := iterate Phi t0 h (Y t0) k).
    set (tk := t0 + INR k * h).
    set (ek := vnorm d (fun i => yk i - Y tk i)).
    pose proof (Hlip k Hk yk (Y tk)) as Hl. fold tk in Hl.
    pose proof (Htr k Hk) as Hr. fold tk in Hr.
    pose proof (vnorm_nonneg d (fun i => yk i - Y tk i)) as He.
    fold ek in He. fold ek in Hl.
    assert (HhLe : 0 <= h * (L * ek)) by (apply Rmult_le_pos; [lra | apply Rmult_le_pos; lra]).
    assert (Hbound : vnorm d (fun i => iterate Phi t0 h (Y t0) (S k) i - Y (t0 + INR (S k) * h) i)
                     <= ek + h * (L * ek) + tau).
    { apply vnorm_le; [lra |]. intros i Hi. cbn [iterate]. fold yk tk.
      replace (yk i + h * Phi tk yk i - Y (t0 + INR (S k) * h) i)
        with ((yk i - Y tk i) + h * (Phi tk yk i - Phi tk (Y tk) i)
              - (Y (t0 + INR (S k) * h) i - Y tk i - h * Phi tk (Y tk) i)) by ring.
      eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_Ropp.
      eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
      rewrite Rabs_mult, (Rabs_pos_eq h) by lra.
      pose proof (vnorm_ge d (fun i => yk i - Y tk i) i Hi) as A1.
      pose proof (vnorm_ge d (fun i => Phi tk yk i - Phi tk (Y tk) i) i Hi) as A2.
      pose proof (vnorm_ge d (fun i => Y (t0 + INR (S k) * h) i - Y tk i
                                       - h * Phi tk (Y tk) i) i Hi) as A3.
      cbv beta in A1, A2, A3. fold ek in A1.
      assert (h * Rabs (Phi tk yk i - Phi tk (Y tk) i) <= h * (L * ek))
        by (apply Rmult_le_compat_l; lra).
      lra. }
    fold ek. eapply Rle_trans; [exact Hbound | right; ring]. }
  intros k Hk.
  assert (Hc : 0 < h * L) by nra.
  exact (gronwall_pow a (h * L) tau N Hc Ht H0 Hs k Hk).
Qed.

Theorem one_step_error (d : nat) (Phi : R -> (nat -> R) -> nat -> R) (Y : R -> nat -> R)
  (t0 h L tau : R) (N : nat) :
  0 < h -> 0 < L -> 0 <= tau ->
  (forall k, (k < N)%nat -> forall y z,
     vnorm d (fun i => Phi (t0 + INR k * h) y i - Phi (t0 + INR k * h) z i)
       <= L * vnorm d (fun i => y i - z i)) ->
  (forall k, (k < N)%nat ->
     vnorm d (fun i => Y (t0 + INR (S k) * h) i - Y (t0 + INR k * h) i
                       - h * Phi (t0 + INR k * h) (Y (t0 + INR k * h)) i) <= tau) ->
  forall k, (k <= N)%nat ->
  vnorm d (fun i => iterate Phi t0 h (Y t0) k i - Y (t0 + INR k * h) i)
    <= tau / (h * L) * (exp (L * (INR k * h)) - 1).
Proof.
  intros Hh HL Ht Hlip Htr k Hk.
  assert (Hc : 0 < h * L) by nra.
  pose proof (one_step_pow d Phi Y t0 h L tau N Hh HL Ht Hlip Htr k Hk) as Hg.
  pose proof (pow_le_exp (h * L) k ltac:(lra)) as Hp.
  replace (INR k * (h * L)) with (L * (INR k * h)) in Hp by ring.
  eapply Rle_trans; [exact Hg |].
  replace (tau * ((1 + h * L) ^ k - 1) / (h * L))
    with (tau / (h * L) * ((1 + h * L) ^ k - 1)) by (field; lra).
  apply Rmult_le_compat_l; [apply Rmult_le_pos; [lra | left; apply Rinv_0_lt_compat; lra] | lra].
Qed.
