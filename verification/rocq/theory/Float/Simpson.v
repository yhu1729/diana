From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
Import ListNotations.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Lemma scale_div_error (H sh St A e1 e2 d1 d2 : R) (k : nat) :
  Rabs (sh - St) <= gamma k * A -> Rabs St <= A ->
  Rabs e1 <= u -> Rabs e2 <= u -> Rabs d1 <= eta -> Rabs d2 <= eta ->
  INR (k + 2) * u < 1 ->
  Rabs ((H * sh * (1 + e1) + d1) / 3 * (1 + e2) + d2 - H * St / 3)
    <= gamma (k + 2) * Rabs H * A / 3 + (1 + u) * eta / 3 + eta.
Proof.
  intros Hs HS He1 He2 Hd1 Hd2 Hk.
  pose proof u_pos as Hu. pose proof eta_pos as Heta.
  replace (k + 2)%nat with (S (S k)) in * by lia.
  assert (Hk1 : INR (S k) * u < 1).
  { eapply Rle_lt_trans; [| exact Hk]. apply Rmult_le_compat_r; [lra | apply le_INR; lia]. }
  assert (Hk0 : INR k * u < 1).
  { eapply Rle_lt_trans; [| exact Hk1]. apply Rmult_le_compat_r; [lra | apply le_INR; lia]. }
  pose proof (gamma_step k Hk1) as Hg1. pose proof (gamma_step (S k) Hk) as Hg2.
  pose proof (gamma_nonneg k Hk0) as Hg0p. pose proof (gamma_nonneg (S k) Hk1) as Hg1p.
  assert (HA : 0 <= A) by (eapply Rle_trans; [apply Rabs_pos | exact HS]).
  pose proof (Rabs_pos H) as HH.
  set (M := H * sh * (1 + e1) + d1).
  assert (Hsh : Rabs sh <= A + gamma k * A).
  { replace sh with (St + (sh - St)) by ring. eapply Rle_trans; [apply Rabs_triang | lra]. }
  assert (Hstep : Rabs (M - H * St) <= gamma (S k) * (Rabs H * A) + eta).
  { unfold M.
    replace (H * sh * (1 + e1) + d1 - H * St) with (H * (sh - St) + e1 * (H * sh) + d1) by ring.
    eapply Rle_trans; [apply Rabs_triang |].
    eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
    rewrite !Rabs_mult.
    assert (T1 : Rabs H * Rabs (sh - St) <= Rabs H * (gamma k * A))
      by (apply Rmult_le_compat_l; lra).
    assert (T2 : Rabs e1 * (Rabs H * Rabs sh) <= u * (Rabs H * (A + gamma k * A))).
    { apply Rmult_le_compat; [apply Rabs_pos | apply Rmult_le_pos; apply Rabs_pos | exact He1 |].
      apply Rmult_le_compat_l; lra. }
    assert (T3 : (gamma k * (1 + u) + u) * (Rabs H * A) <= gamma (S k) * (Rabs H * A))
      by (apply Rmult_le_compat_r; [apply Rmult_le_pos; lra | exact Hg1]).
    nra. }
  assert (HM : Rabs M <= Rabs H * A + gamma (S k) * (Rabs H * A) + eta).
  { replace M with (H * St + (M - H * St)) by ring. eapply Rle_trans; [apply Rabs_triang |].
    rewrite Rabs_mult.
    assert (Rabs H * Rabs St <= Rabs H * A) by (apply Rmult_le_compat_l; lra). lra. }
  replace (M / 3 * (1 + e2) + d2 - H * St / 3) with ((M - H * St) / 3 + e2 * (M / 3) + d2)
    by field.
  eapply Rle_trans; [apply Rabs_triang |].
  eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
  unfold Rdiv. rewrite !Rabs_mult, (Rabs_pos_eq (/ 3)) by lra.
  assert (T4 : Rabs e2 * (Rabs M * / 3)
               <= u * ((Rabs H * A + gamma (S k) * (Rabs H * A) + eta) * / 3)).
  { apply Rmult_le_compat; [apply Rabs_pos | | exact He2 |].
    - apply Rmult_le_pos; [apply Rabs_pos | lra].
    - apply Rmult_le_compat_r; lra. }
  assert (T5 : (gamma (S k) * (1 + u) + u) * (Rabs H * A) <= gamma (S (S k)) * (Rabs H * A))
    by (apply Rmult_le_compat_r; [apply Rmult_le_pos; lra | exact Hg2]).
  assert (T6 : Rabs (M - H * St) * / 3 <= (gamma (S k) * (Rabs H * A) + eta) * / 3)
    by (apply Rmult_le_compat_r; lra).
  nra.
Qed.

Section Model.

Variable plus_nan mult_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fadd := (Diana.Float.Sum.fadd plus_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fdiv := (Diana.Float.Sum.fdiv div_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

Definition zero : b64 := B754_zero prec emax false.

Definition two : b64 :=
  B754_finite prec emax false 4503599627370496 (-51) ltac:(vm_compute; reflexivity).

Definition three : b64 :=
  B754_finite prec emax false 6755399441055744 (-51) ltac:(vm_compute; reflexivity).

Definition four : b64 :=
  B754_finite prec emax false 4503599627370496 (-50) ltac:(vm_compute; reflexivity).

Lemma B2R_zero : r zero = 0.
Proof. reflexivity. Qed.

Lemma B2R_two : r two = bpow radix2 1.
Proof.
  unfold two, B2R, F2R; simpl.
  change (Z.pow_pos 2 51) with 2251799813685248%Z. lra.
Qed.

Lemma B2R_four : r four = bpow radix2 2.
Proof.
  unfold four, B2R, F2R; simpl.
  change (Z.pow_pos 2 50) with 1125899906842624%Z. lra.
Qed.

Lemma B2R_three : r three = 3.
Proof.
  unfold three, B2R, F2R; simpl.
  change (Z.pow_pos 2 51) with 2251799813685248%Z. lra.
Qed.

Definition fsum (y0 yl : b64) (odd even : list b64) : b64 :=
  fadd (fadd (fadd y0 yl) (fmul four (fold_left fadd odd zero)))
    (fmul two (fold_left fadd even zero)).

Definition fsimpson (y0 yl : b64) (odd even : list b64) (h : b64) : b64 :=
  fdiv (fmul h (fsum y0 yl odd even)) three.

Theorem finite_result (y0 yl : b64) (odd even : list b64) (h : b64) :
  fin (fsimpson y0 yl odd even h) ->
  fin h /\ fin y0 /\ fin yl /\ Forall (fun x => fin x) odd /\ Forall (fun x => fin x) even /\
  (forall k, fin (fold_left fadd (firstn k odd) zero)) /\
  (forall k, fin (fold_left fadd (firstn k even) zero)).
Proof.
  intro H. unfold fsimpson in H.
  pose proof (fdiv_finite_inv _ _ H) as Hm.
  destruct (fmul_value _ _ Hm) as [Hh [Hs _]].
  unfold fsum in Hs.
  destruct (fadd_finite_inv _ _ Hs) as [Ht2 H2se].
  destruct (fadd_finite_inv _ _ Ht2) as [Ht1 H4so].
  destruct (fadd_finite_inv _ _ Ht1) as [Hy0 Hyl].
  destruct (fmul_value _ _ H4so) as [_ [Hso _]].
  destruct (fmul_value _ _ H2se) as [_ [Hse _]].
  destruct (fold_finite_inv _ _ Hso) as [_ Hodd].
  destruct (fold_finite_inv _ _ Hse) as [_ Heven].
  repeat split; try assumption.
  - intro k. rewrite <- (firstn_skipn k odd) in Hso. rewrite fold_left_app in Hso.
    exact (proj1 (fold_finite_inv _ _ Hso)).
  - intro k. rewrite <- (firstn_skipn k even) in Hse. rewrite fold_left_app in Hse.
    exact (proj1 (fold_finite_inv _ _ Hse)).
Qed.

Lemma sum_error (m : list b64) :
  fin (fold_left fadd m zero) ->
  INR (S (length m)) * u < 1 ->
  Rabs (r (fold_left fadd m zero) - rsum m) <= gamma (S (length m)) * rabs_sum m.
Proof.
  intros Hf Hn.
  assert (Hb : Rabs (r zero - 0) <= gamma 1 * 0 + (1 + gamma 0) * 0).
  { rewrite B2R_zero, Rminus_0_r, Rabs_R0. right. ring. }
  assert (HX : Rabs 0 <= 0) by (rewrite Rabs_R0; lra).
  pose proof (fold_error m zero 0 0 0 0 Hf (Rle_refl 0) Hb HX Hn) as He.
  rewrite Rplus_0_l, Rplus_0_l, Rmult_0_r, Rplus_0_r in He. exact He.
Qed.

Theorem forward_error (y0 yl : b64) (odd even : list b64) (h : b64) :
  fin (fsimpson y0 yl odd even h) ->
  (length even <= length odd)%nat ->
  INR (length odd + 5) * u < 1 ->
  Rabs (r (fsimpson y0 yl odd even h)
        - r h * ((r y0 + r yl) + 4 * rsum odd + 2 * rsum even) / 3)
    <= gamma (length odd + 5) * Rabs (r h)
         * (Rabs (r y0 + r yl) + 4 * rabs_sum odd + 2 * rabs_sum even) / 3
       + (1 + u) * eta / 3 + eta.
Proof.
  intros H Hlen Hn.
  set (p := length odd) in *. set (q := length even) in *.
  pose proof u_pos as Hu.
  assert (HnL : forall k, (k <= p + 5)%nat -> INR k * u < 1).
  { intros k Hk. eapply Rle_lt_trans; [| exact Hn].
    apply Rmult_le_compat_r; [lra | apply le_INR; exact Hk]. }
  unfold fsimpson in H |- *.
  pose proof (fdiv_finite_inv _ _ H) as Hm.
  assert (H3 : r three <> 0) by (rewrite B2R_three; lra).
  pose proof (fdiv_value _ _ H H3) as Hvr.
  destruct (fmul_value _ _ Hm) as [Hh [Hs Hvm]].
  unfold fsum in Hs, Hvm, Hvr |- *.
  destruct (fadd_finite_inv _ _ Hs) as [Ht2 H2se].
  destruct (fadd_finite_inv _ _ Ht2) as [Ht1 H4so].
  destruct (fmul_value _ _ H4so) as [_ [Hso _]].
  destruct (fmul_value _ _ H2se) as [_ [Hse _]].
  pose proof (fadd_value _ _ Hs) as Hvs.
  pose proof (fadd_value _ _ Ht2) as Hvt2.
  pose proof (fadd_value _ _ Ht1) as Hvt1.
  pose proof (fmul_exact four _ 2 ltac:(lia) B2R_four H4so) as Hv4.
  pose proof (fmul_exact two _ 1 ltac:(lia) B2R_two H2se) as Hv2.
  change (bpow radix2 2) with 4 in Hv4. change (bpow radix2 1) with 2 in Hv2.
  set (so := fold_left fadd odd zero) in *.
  set (se := fold_left fadd even zero) in *.
  set (t1 := fadd y0 yl) in *.
  set (t2 := fadd t1 (fmul four so)) in *.
  set (s := fadd t2 (fmul two se)) in *.
  assert (Hgp : INR (S p) * u < 1) by (apply HnL; lia).
  assert (Hgq : INR (S q) * u < 1) by (apply HnL; lia).
  pose proof (sum_error odd Hso Hgp) as Eo. fold p so in Eo.
  pose proof (sum_error even Hse Hgq) as Ee. fold q se in Ee.
  pose proof (gamma_nonneg _ Hgp) as Hgpp.
  (* t1 = fl(y0 + yl) *)
  assert (E1 : Rabs (r t1 - (r y0 + r yl)) <= gamma (S p) * Rabs (r y0 + r yl)).
  { rewrite Hvt1.
    destruct (add_error (r y0) (r yl) (generic_format_B2R prec emax y0)
                (generic_format_B2R prec emax yl)) as [d [Hd Hrd]].
    rewrite Hrd.
    replace ((r y0 + r yl) * (1 + d) - (r y0 + r yl)) with (d * (r y0 + r yl)) by ring.
    rewrite Rabs_mult. apply Rmult_le_compat_r; [apply Rabs_pos |].
    eapply Rle_trans; [exact Hd |].
    eapply Rle_trans; [apply u_le_gamma_1; apply (HnL 2%nat); lia |].
    apply gamma_mono; [lia | exact Hgp]. }
  (* t2 = fl(t1 + 4 so) *)
  assert (E2 : Rabs (r t2 - ((r y0 + r yl) + 4 * rsum odd))
               <= gamma (S (S p)) * (Rabs (r y0 + r yl) + 4 * rabs_sum odd)).
  { rewrite Hvt2.
    apply add_step.
    - apply generic_format_B2R.
    - apply generic_format_B2R.
    - exact E1.
    - rewrite Hv4. replace (4 * r so - 4 * rsum odd) with (4 * (r so - rsum odd)) by ring.
      rewrite Rabs_mult, (Rabs_pos_eq 4) by lra. nra.
    - lra.
    - rewrite Rabs_mult, (Rabs_pos_eq 4) by lra. pose proof (rsum_abs odd). lra.
    - apply HnL. lia. }
  (* s = fl(t2 + 2 se) *)
  assert (E3 : Rabs (r s - ((r y0 + r yl) + 4 * rsum odd + 2 * rsum even))
               <= gamma (S (S (S p)))
                  * (Rabs (r y0 + r yl) + 4 * rabs_sum odd + 2 * rabs_sum even)).
  { rewrite Hvs.
    assert (Hgq2 : gamma (S q) <= gamma (S (S p))) by (apply gamma_mono; [lia | apply HnL; lia]).
    pose proof (gamma_nonneg (S q) Hgq) as Hgqp.
    pose proof (rabs_sum_nonneg even) as Hae.
    apply add_step.
    - apply generic_format_B2R.
    - apply generic_format_B2R.
    - exact E2.
    - rewrite Hv2. replace (2 * r se - 2 * rsum even) with (2 * (r se - rsum even)) by ring.
      rewrite Rabs_mult, (Rabs_pos_eq 2) by lra.
      assert (gamma (S q) * rabs_sum even <= gamma (S (S p)) * rabs_sum even)
        by (apply Rmult_le_compat_r; assumption).
      nra.
    - eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult, (Rabs_pos_eq 4) by lra.
      pose proof (rsum_abs odd). lra.
    - rewrite Rabs_mult, (Rabs_pos_eq 2) by lra. pose proof (rsum_abs even). lra.
    - apply HnL. lia. }
  set (S0 := (r y0 + r yl) + 4 * rsum odd + 2 * rsum even) in *.
  set (A := Rabs (r y0 + r yl) + 4 * rabs_sum odd + 2 * rabs_sum even) in *.
  assert (HS : Rabs S0 <= A).
  { unfold S0, A. eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult, (Rabs_pos_eq 2) by lra.
    eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
    rewrite Rabs_mult, (Rabs_pos_eq 4) by lra.
    pose proof (rsum_abs odd). pose proof (rsum_abs even). lra. }
  rewrite Hvr, B2R_three, Hvm.
  destruct (round_error (r h * r s)) as [e1 [d1 [He1 [Hd1 Hr1]]]].
  rewrite Hr1.
  destruct (round_error ((r h * r s * (1 + e1) + d1) / 3)) as [e2 [d2 [He2 [Hd2 Hr2]]]].
  rewrite Hr2.
  replace (p + 5)%nat with (S (S (S p)) + 2)%nat by lia.
  apply scale_div_error; try assumption.
  replace (S (S (S p)) + 2)%nat with (p + 5)%nat by lia. exact Hn.
Qed.

End Model.
