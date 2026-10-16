From Stdlib Require Import Reals ZArith Lia Lra Psatz.
From Flocq Require Import Core IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Section Model.

Variable minus_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fdiv := (Diana.Float.Sum.fdiv div_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

Definition fsub (x y : b64) : b64 := Bminus prec emax _ _ minus_nan mode_NE x y.

Definition fstep (x fx dfx : b64) : b64 := fsub x (fdiv fx dfx).

Lemma fsub_finite_inv (x y : b64) : fin (fsub x y) -> fin x /\ fin y.
Proof.
  unfold fsub, Bminus. rewrite is_finite_BSN2B.
  destruct x as [sx|sx|sx plx Hx|sx mx ex Hx]; destruct y as [sy|sy|sy ply Hy|sy my ey Hy];
    intro H; try (split; reflexivity); simpl in H; try discriminate.
  destruct (Bool.eqb sx (negb sy)); discriminate.
Qed.

Lemma fsub_value (x y : b64) :
  fin (fsub x y) -> r (fsub x y) = round radix2 fexp ZnearestE (r x - r y).
Proof.
  intro H. destruct (fsub_finite_inv x y H) as [Hx Hy].
  pose proof (Bminus_correct prec emax _ _ minus_nan mode_NE x y Hx Hy) as Hc.
  change (SpecFloat.fexp 53 1024) with fexp in Hc.
  change (round_mode mode_NE) with ZnearestE in Hc.
  revert Hc. case Rlt_bool; intro Hc.
  - exact (proj1 Hc).
  - exfalso. destruct Hc as [Hovf _]. unfold fsub in H.
    rewrite <- is_finite_B2FF, Hovf in H. discriminate.
Qed.

Lemma sub_error (x y : R) :
  generic_format radix2 fexp x -> generic_format radix2 fexp y ->
  exists d, Rabs d <= u /\ round radix2 fexp ZnearestE (x - y) = (x - y) * (1 + d).
Proof.
  intros Hx Hy.
  destruct (add_error x (- y) Hx (generic_format_opp radix2 fexp y Hy)) as [d [Hd Hr]].
  exists d. split; [exact Hd |]. unfold Rminus. exact Hr.
Qed.

Theorem finite_result (x fx dfx : b64) :
  fin (fstep x fx dfx) -> fin x /\ fin fx /\ fin (fdiv fx dfx).
Proof.
  intro H. unfold fstep in H.
  destruct (fsub_finite_inv _ _ H) as [Hx Hq].
  pose proof (fdiv_finite_inv _ _ Hq) as Hfx.
  repeat split; assumption.
Qed.

Theorem forward_error (x fx dfx : b64) :
  fin (fstep x fx dfx) -> r dfx <> 0 ->
  Rabs (r (fstep x fx dfx) - (r x - r fx / r dfx))
    <= u * Rabs (r x - r fx / r dfx) + (1 + u) * (u * Rabs (r fx / r dfx) + eta).
Proof.
  intros H Hdfx. unfold fstep in H |- *.
  destruct (fsub_finite_inv _ _ H) as [Hx Hq].
  pose proof (fdiv_value _ _ Hq Hdfx) as Hvq.
  rewrite (fsub_value _ _ H).
  destruct (sub_error (r x) (r (fdiv fx dfx)) (generic_format_B2R prec emax x)
              (generic_format_B2R prec emax _)) as [e2 [He2 Hr2]].
  rewrite Hr2.
  destruct (round_error (r fx / r dfx)) as [e1 [d1 [He1 [Hd1 Hr1]]]].
  rewrite Hvq, Hr1 in *.
  pose proof u_pos as Hu. pose proof eta_pos as Heta.
  set (p := r fx / r dfx) in *.
  set (m := p * (1 + e1) + d1) in *.
  assert (Hmp : Rabs (m - p) <= u * Rabs p + eta).
  { unfold m. replace (p * (1 + e1) + d1 - p) with (e1 * p + d1) by ring.
    eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult.
    assert (Rabs e1 * Rabs p <= u * Rabs p)
      by (apply Rmult_le_compat_r; [apply Rabs_pos | exact He1]).
    lra. }
  replace ((r x - m) * (1 + e2) - (r x - p)) with (- (m - p) * (1 + e2) + e2 * (r x - p))
    by ring.
  eapply Rle_trans; [apply Rabs_triang |]. rewrite !Rabs_mult, Rabs_Ropp.
  assert (H1e : Rabs (1 + e2) <= 1 + u).
  { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_R1. lra. }
  assert (T1 : Rabs (m - p) * Rabs (1 + e2) <= (u * Rabs p + eta) * (1 + u))
    by (apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | exact Hmp | exact H1e]).
  assert (T2 : Rabs e2 * Rabs (r x - p) <= u * Rabs (r x - p))
    by (apply Rmult_le_compat_r; [apply Rabs_pos | exact He2]).
  lra.
Qed.

Lemma ulp_le_ulp_round (y : R) :
  ulp radix2 fexp y <= ulp radix2 fexp (round radix2 fexp ZnearestE y).
Proof.
  destruct (ulp_round radix2 fexp ZnearestE y) as [E | E].
  - rewrite E. lra.
  - assert (Hy : y <> 0).
    { intro Hy0. rewrite Hy0, round_0, Rabs_R0 in E by typeclasses eauto.
      pose proof (bpow_gt_0 radix2 (mag radix2 0)). lra. }
    assert (Hr : round radix2 fexp ZnearestE y <> 0).
    { intro H0. rewrite H0, Rabs_R0 in E. pose proof (bpow_gt_0 radix2 (mag radix2 y)). lra. }
    rewrite !ulp_neq_0 by assumption.
    unfold cexp.
    rewrite <- (mag_abs radix2 (round radix2 fexp ZnearestE y)), E, mag_bpow.
    apply bpow_le. apply monotone_exp; [typeclasses eauto | lia].
Qed.

Theorem stagnation (x dx : b64) :
  fin x -> fin dx -> fin (fsub x dx) -> r (fsub x dx) = r x ->
  Rabs (r dx) <= / 2 * ulp radix2 fexp (r x).
Proof.
  intros Hx Hdx Hf Heq.
  rewrite (fsub_value _ _ Hf) in Heq.
  pose proof (error_le_half_ulp radix2 fexp (fun z => negb (Z.even z)) (r x - r dx)) as Hb.
  change (round radix2 fexp (Znearest (fun z => negb (Z.even z))) (r x - r dx))
    with (round radix2 fexp ZnearestE (r x - r dx)) in Hb.
  rewrite Heq in Hb.
  replace (r x - (r x - r dx)) with (r dx) in Hb by ring.
  eapply Rle_trans; [exact Hb |].
  apply Rmult_le_compat_l; [lra |].
  pose proof (ulp_le_ulp_round (r x - r dx)) as HU. rewrite Heq in HU. exact HU.
Qed.

End Model.
