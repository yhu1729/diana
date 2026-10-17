From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core Plus_error Relative Mult_error IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Float Require Euler Trapezoidal.
Import ListNotations.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Lemma half_exact (x : R) :
  generic_format radix2 fexp x -> bpow radix2 (-1021) <= Rabs x ->
  round radix2 fexp ZnearestE (/ 2 * x) = / 2 * x.
Proof.
  intros Hx Hb. apply round_generic; [typeclasses eauto |].
  assert (Hb1 : bpow radix2 (-1) = / 2) by (rewrite <- (half_bpow (-1)); simpl; ring).
  replace (/ 2 * x) with (x * bpow radix2 (-1)) by (rewrite Hb1; ring).
  apply (mult_bpow_exact_FLT radix2 emin prec); [exact Hx |].
  assert (Hm : (-1020 <= mag radix2 x)%Z).
  { apply mag_ge_bpow. replace (-1020 - 1)%Z with (-1021)%Z by lia. exact Hb. }
  lia.
Qed.

Lemma scale_div6_error (H sh St A e1 e2 d1 d2 : R) (k : nat) :
  Rabs (sh - St) <= gamma k * A -> Rabs St <= A ->
  Rabs e1 <= u -> Rabs e2 <= u -> Rabs d1 <= eta -> Rabs d2 <= eta ->
  INR (k + 2) * u < 1 ->
  Rabs ((H * sh * (1 + e1) + d1) / 6 * (1 + e2) + d2 - H * St / 6)
    <= gamma (k + 2) * Rabs H * A / 6 + (1 + u) * eta / 6 + eta.
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
  replace (M / 6 * (1 + e2) + d2 - H * St / 6) with ((M - H * St) / 6 + e2 * (M / 6) + d2)
    by field.
  eapply Rle_trans; [apply Rabs_triang |].
  eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
  unfold Rdiv. rewrite !Rabs_mult, (Rabs_pos_eq (/ 6)) by lra.
  assert (T4 : Rabs e2 * (Rabs M * / 6)
               <= u * ((Rabs H * A + gamma (S k) * (Rabs H * A) + eta) * / 6)).
  { apply Rmult_le_compat; [apply Rabs_pos | | exact He2 |].
    - apply Rmult_le_pos; [apply Rabs_pos | lra].
    - apply Rmult_le_compat_r; lra. }
  assert (T5 : (gamma (S k) * (1 + u) + u) * (Rabs H * A) <= gamma (S (S k)) * (Rabs H * A))
    by (apply Rmult_le_compat_r; [apply Rmult_le_pos; lra | exact Hg2]).
  assert (T6 : Rabs (M - H * St) * / 6 <= (gamma (S k) * (Rabs H * A) + eta) * / 6)
    by (apply Rmult_le_compat_r; lra).
  nra.
Qed.

Definition exact_coef (s : Z) (h : R) : R := if Z.eqb s 4 then h else h / 2.

Section Model.

Variable plus_nan mult_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fadd := (Diana.Float.Sum.fadd plus_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fdiv := (Diana.Float.Sum.fdiv div_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

Definition two : b64 :=
  B754_finite prec emax false 4503599627370496 (-51) ltac:(vm_compute; reflexivity).

Definition six : b64 :=
  B754_finite prec emax false 6755399441055744 (-50) ltac:(vm_compute; reflexivity).

Lemma B2R_two : r two = bpow radix2 1.
Proof.
  unfold two, B2R, F2R; simpl.
  change (Z.pow_pos 2 51) with 2251799813685248%Z. lra.
Qed.

Lemma B2R_six : r six = 6.
Proof.
  unfold six, B2R, F2R; simpl.
  change (Z.pow_pos 2 50) with 1125899906842624%Z. lra.
Qed.

Definition coef (s : Z) (h : b64) : b64 :=
  if Z.eqb s 4 then h else fmul Diana.Float.Trapezoidal.half h.

Definition fstage (s : Z) (h y k : b64) : b64 :=
  Diana.Float.Euler.fstep plus_nan mult_nan (coef s h) y k.

Definition frk4_stage (s : Z) (h : b64) (ys ks : list b64) : list b64 :=
  Diana.Float.Euler.feuler plus_nan mult_nan (coef s h) ys ks.

Definition fslope (k1 k2 k3 k4 : b64) : b64 := fadd (fadd k1 k4) (fmul two (fadd k2 k3)).

Definition fstep (h y k1 k2 k3 k4 : b64) : b64 :=
  fadd y (fdiv (fmul h (fslope k1 k2 k3 k4)) six).

Fixpoint frk4_step (h : b64) (ys k1s k2s k3s k4s : list b64) : list b64 :=
  match ys, k1s, k2s, k3s, k4s with
  | y :: ys', a :: k1s', b :: k2s', c :: k3s', e :: k4s' =>
      fstep h y a b c e :: frk4_step h ys' k1s' k2s' k3s' k4s'
  | _, _, _, _, _ => nil
  end.

Theorem stage_finite (s : Z) (h y k : b64) :
  fin (fstage s h y k) ->
  fin h /\ fin y /\ fin k /\ fin (coef s h) /\ fin (fmul (coef s h) k).
Proof.
  intro H. unfold fstage in H.
  destruct (Diana.Float.Euler.finite_result _ _ _ _ _ H) as [Hc [Hy [Hk Hm]]].
  repeat split; try assumption.
  unfold coef in Hc. destruct (Z.eqb s 4); [exact Hc |].
  exact (proj1 (proj2 (fmul_value _ _ Hc))).
Qed.

Theorem coef_error (s : Z) (h : b64) :
  fin (coef s h) ->
  Rabs (r (coef s h) - exact_coef s (r h)) <= eta /\
  (bpow radix2 (-1021) <= Rabs (r h) -> r (coef s h) = exact_coef s (r h)).
Proof.
  intro H. pose proof eta_pos as Heta.
  unfold coef, exact_coef in *. destruct (Z.eqb s 4).
  - rewrite Rminus_diag, Rabs_R0. split; [lra | reflexivity].
  - destruct (fmul_value _ _ H) as [_ [_ Hv]].
    rewrite Hv, Diana.Float.Trapezoidal.B2R_half.
    replace (r h / 2) with (/ 2 * r h) by field.
    split.
    + exact (Diana.Float.Trapezoidal.half_error _ (generic_format_B2R prec emax h)).
    + intro Hb. exact (half_exact _ (generic_format_B2R prec emax h) Hb).
Qed.

Theorem stage_error (s : Z) (h y k : b64) :
  fin (fstage s h y k) ->
  let c := exact_coef s (r h) in
  Rabs (r (fstage s h y k) - (r y + c * r k))
    <= u * Rabs (r y + c * r k) + (1 + u) * (u * Rabs (c * r k) + eta)
       + (1 + u) ^ 2 * Rabs (r (coef s h) - c) * Rabs (r k).
Proof.
  intros H c. unfold fstage, Diana.Float.Euler.fstep in H |- *.
  destruct (fadd_finite_inv _ _ H) as [Hy Hm].
  destruct (fmul_value _ _ Hm) as [_ [_ Hvm]].
  rewrite (fadd_value _ _ H).
  destruct (add_error (r y) (r (fmul (coef s h) k)) (generic_format_B2R prec emax y)
              (generic_format_B2R prec emax _)) as [e2 [He2 Hr2]].
  rewrite Hr2.
  destruct (round_error (r (coef s h) * r k)) as [e1 [d1 [He1 [Hd1 Hr1]]]].
  rewrite Hvm, Hr1 in *.
  pose proof u_pos as Hu. pose proof eta_pos as Heta.
  set (ct := r (coef s h)) in *.
  set (dl := ct - c).
  set (p := c * r k).
  set (m := ct * r k * (1 + e1) + d1).
  assert (Hmp : Rabs (m - p) <= u * Rabs p + eta + (1 + u) * Rabs dl * Rabs (r k)).
  { unfold m, p.
    replace (ct * r k * (1 + e1) + d1 - c * r k)
      with (e1 * (c * r k) + d1 + (1 + e1) * (dl * r k)) by (unfold dl; ring).
    eapply Rle_trans; [apply Rabs_triang |].
    eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
    rewrite (Rabs_mult e1), (Rabs_mult (1 + e1)), (Rabs_mult dl).
    assert (T1 : Rabs e1 * Rabs (c * r k) <= u * Rabs (c * r k))
      by (apply Rmult_le_compat_r; [apply Rabs_pos | exact He1]).
    assert (H1e : Rabs (1 + e1) <= 1 + u).
    { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_R1. lra. }
    assert (T2 : Rabs (1 + e1) * (Rabs dl * Rabs (r k)) <= (1 + u) * (Rabs dl * Rabs (r k)))
      by (apply Rmult_le_compat_r; [apply Rmult_le_pos; apply Rabs_pos | exact H1e]).
    lra. }
  replace ((r y + m) * (1 + e2) - (r y + p)) with ((m - p) * (1 + e2) + e2 * (r y + p))
    by ring.
  eapply Rle_trans; [apply Rabs_triang |]. rewrite !Rabs_mult.
  assert (H1e : Rabs (1 + e2) <= 1 + u).
  { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_R1. lra. }
  assert (T1 : Rabs (m - p) * Rabs (1 + e2)
               <= (u * Rabs p + eta + (1 + u) * Rabs dl * Rabs (r k)) * (1 + u))
    by (apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | exact Hmp | exact H1e]).
  assert (T2 : Rabs e2 * Rabs (r y + p) <= u * Rabs (r y + p))
    by (apply Rmult_le_compat_r; [apply Rabs_pos | exact He2]).
  fold dl. simpl (_ ^ 2). lra.
Qed.

Theorem step_finite (h y k1 k2 k3 k4 : b64) :
  fin (fstep h y k1 k2 k3 k4) ->
  fin h /\ fin y /\ fin k1 /\ fin k2 /\ fin k3 /\ fin k4 /\
  fin (fadd k1 k4) /\ fin (fadd k2 k3) /\ fin (fmul two (fadd k2 k3)) /\
  fin (fslope k1 k2 k3 k4) /\ fin (fmul h (fslope k1 k2 k3 k4)) /\
  fin (fdiv (fmul h (fslope k1 k2 k3 k4)) six).
Proof.
  intro H. unfold fstep in H.
  destruct (fadd_finite_inv _ _ H) as [Hy Hq].
  pose proof (fdiv_finite_inv _ _ Hq) as Hm.
  destruct (fmul_value _ _ Hm) as [Hh [Hs _]].
  pose proof Hs as Hs'. unfold fslope in Hs'.
  destruct (fadd_finite_inv _ _ Hs') as [Ha Hb2].
  destruct (fmul_value _ _ Hb2) as [_ [Hb _]].
  destruct (fadd_finite_inv _ _ Ha) as [H1 H4].
  destruct (fadd_finite_inv _ _ Hb) as [H2 H3].
  repeat split; assumption.
Qed.

Theorem step_error (h y k1 k2 k3 k4 : b64) :
  fin (fstep h y k1 k2 k3 k4) ->
  let S := r k1 + 2 * r k2 + 2 * r k3 + r k4 in
  let A := Rabs (r k1 + r k4) + 2 * Rabs (r k2 + r k3) in
  Rabs (r (fstep h y k1 k2 k3 k4) - (r y + r h * S / 6))
    <= u * Rabs (r y + r h * S / 6)
       + (1 + u) * (gamma 4 * Rabs (r h) * A / 6 + (1 + u) * eta / 6 + eta).
Proof.
  intros H S A.
  pose proof u_pos as Hu. pose proof eta_pos as Heta.
  assert (Hu4 : INR 4 * u < 1).
  { unfold u. simpl. replace (bpow radix2 (-53)) with (/ 9007199254740992) by
      (simpl; reflexivity). lra. }
  assert (Hu1 : 2 * u < 1) by (simpl in Hu4; lra).
  pose proof (u_le_gamma_1 Hu1) as Hug.
  destruct (step_finite _ _ _ _ _ _ H)
    as [Hh [Hy [H1 [H2 [H3 [H4 [Ha [Hb [Hb2 [Hs [Hm Hq]]]]]]]]]]].
  unfold fstep in H |- *.
  set (a := fadd k1 k4) in *. set (b := fadd k2 k3) in *.
  set (s := fslope k1 k2 k3 k4) in *.
  assert (Hvs : r s = round radix2 fexp ZnearestE (r a + r (fmul two b)))
    by exact (fadd_value _ _ Hs).
  pose proof (fmul_exact two b 1 ltac:(lia) B2R_two Hb2) as Hv2.
  change (bpow radix2 1) with 2 in Hv2.
  (* |a - (k1 + k4)| <= u |k1 + k4| and |2b - 2 (k2 + k3)| <= u * 2 |k2 + k3| *)
  assert (Ea : Rabs (r a - (r k1 + r k4)) <= gamma 1 * Rabs (r k1 + r k4)).
  { unfold a. rewrite (fadd_value _ _ Ha).
    destruct (add_error (r k1) (r k4) (generic_format_B2R prec emax k1)
                (generic_format_B2R prec emax k4)) as [d [Hd Hrd]].
    rewrite Hrd.
    replace ((r k1 + r k4) * (1 + d) - (r k1 + r k4)) with (d * (r k1 + r k4)) by ring.
    rewrite Rabs_mult. apply Rmult_le_compat_r; [apply Rabs_pos | lra]. }
  assert (Eb : Rabs (r (fmul two b) - 2 * (r k2 + r k3)) <= gamma 1 * (2 * Rabs (r k2 + r k3))).
  { rewrite Hv2. unfold b. rewrite (fadd_value _ _ Hb).
    destruct (add_error (r k2) (r k3) (generic_format_B2R prec emax k2)
                (generic_format_B2R prec emax k3)) as [d [Hd Hrd]].
    rewrite Hrd.
    replace (2 * ((r k2 + r k3) * (1 + d)) - 2 * (r k2 + r k3)) with (d * (2 * (r k2 + r k3)))
      by ring.
    rewrite Rabs_mult, (Rabs_mult 2), (Rabs_pos_eq 2) by lra.
    apply Rmult_le_compat_r; [apply Rmult_le_pos; [lra | apply Rabs_pos] | lra]. }
  assert (Es : Rabs (r s - S) <= gamma 2 * A).
  { rewrite Hvs.
    replace S with ((r k1 + r k4) + 2 * (r k2 + r k3)) by (unfold S; ring).
    unfold A.
    apply (add_step (r a) (r (fmul two b)) (r k1 + r k4) (2 * (r k2 + r k3))
             (Rabs (r k1 + r k4)) (2 * Rabs (r k2 + r k3)) 1);
      try apply generic_format_B2R.
    - exact Ea.
    - exact Eb.
    - lra.
    - rewrite Rabs_mult, (Rabs_pos_eq 2) by lra. lra.
    - eapply Rle_lt_trans; [| exact Hu4]. apply Rmult_le_compat_r; [lra |]. simpl; lra. }
  assert (HSA : Rabs S <= A).
  { unfold S, A. replace (r k1 + 2 * r k2 + 2 * r k3 + r k4)
      with ((r k1 + r k4) + 2 * (r k2 + r k3)) by ring.
    eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult, (Rabs_pos_eq 2) by lra. lra. }
  assert (H6 : r six <> 0) by (rewrite B2R_six; lra).
  pose proof (fdiv_value _ _ Hq H6) as Hvq.
  destruct (fmul_value _ _ Hm) as [_ [_ Hvm]].
  rewrite B2R_six in Hvq.
  destruct (round_error (r h * r s)) as [e1 [d1 [He1 [Hd1 Hr1]]]].
  destruct (round_error (r (fmul h s) / 6)) as [e2 [d2 [He2 [Hd2 Hr2]]]].
  set (q := fdiv (fmul h s) six) in *.
  assert (Eq : Rabs (r q - r h * S / 6) <= gamma 4 * Rabs (r h) * A / 6 + (1 + u) * eta / 6 + eta).
  { rewrite Hvq, Hr2, Hvm, Hr1.
    exact (scale_div6_error (r h) (r s) S A e1 e2 d1 d2 2 Es HSA He1 He2 Hd1 Hd2
             ltac:(simpl in Hu4 |- *; lra)). }
  rewrite (fadd_value _ _ H).
  destruct (add_error (r y) (r q) (generic_format_B2R prec emax y)
              (generic_format_B2R prec emax q)) as [e3 [He3 Hr3]].
  rewrite Hr3.
  set (T := r y + r h * S / 6).
  replace ((r y + r q) * (1 + e3) - T) with ((r q - r h * S / 6) * (1 + e3) + e3 * T)
    by (unfold T; ring).
  eapply Rle_trans; [apply Rabs_triang |]. rewrite !Rabs_mult.
  assert (H1e : Rabs (1 + e3) <= 1 + u).
  { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_R1. lra. }
  assert (T1 : Rabs (r q - r h * S / 6) * Rabs (1 + e3)
               <= (gamma 4 * Rabs (r h) * A / 6 + (1 + u) * eta / 6 + eta) * (1 + u))
    by (apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | exact Eq | exact H1e]).
  assert (T2 : Rabs e3 * Rabs T <= u * Rabs T)
    by (apply Rmult_le_compat_r; [apply Rabs_pos | exact He3]).
  lra.
Qed.

End Model.
