From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Float Require Euler EulerUnchecked RK4 Trapezoidal.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.

Section Model.

Variable plus_nan mult_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fadd := (Diana.Float.Sum.fadd plus_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fdiv := (Diana.Float.Sum.fdiv div_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).
Local Abbreviation rnd x := (round radix2 fexp ZnearestE x).
Local Abbreviation coef := (Diana.Float.RK4.coef mult_nan).
Local Abbreviation fstage := (Diana.Float.RK4.fstage plus_nan mult_nan).
Local Abbreviation fstep := (Diana.Float.RK4.fstep plus_nan mult_nan div_nan).

Lemma coef_finite (s : Z) (h : b64) : fin (coef s h) <-> fin h.
Proof.
  unfold Diana.Float.RK4.coef. destruct (Z.eqb s 4); [tauto |]. split.
  - intro H. exact (proj1 (proj2 (fmul_value _ _ H))).
  - intro Hh. apply (proj2 (fmul_finite_iff Diana.Float.Trapezoidal.half h eq_refl Hh)).
    rewrite Diana.Float.Trapezoidal.B2R_half.
    apply Rle_lt_trans with (Rabs (r h)); [| apply abs_B2R_lt_emax].
    apply abs_round_le_generic; try typeclasses eauto.
    + apply generic_format_abs. apply generic_format_B2R.
    + rewrite Rabs_mult, (Rabs_pos_eq (/ 2)) by lra. pose proof (Rabs_pos (r h)). lra.
Qed.

Theorem stage_finite_iff (s : Z) (h y k : b64) :
  fin (fstage s h y k) <->
  fin h /\ fin y /\ fin k /\ Rabs (rnd (r (coef s h) * r k)) < bpow radix2 emax /\
  Rabs (rnd (r y + rnd (r (coef s h) * r k))) < bpow radix2 emax.
Proof.
  unfold Diana.Float.RK4.fstage.
  rewrite Diana.Float.EulerUnchecked.finite_iff, coef_finite. tauto.
Qed.

Theorem step_finite_iff (h y k1 k2 k3 k4 : b64) :
  fin (fstep h y k1 k2 k3 k4) <->
  fin h /\ fin y /\ fin k1 /\ fin k2 /\ fin k3 /\ fin k4 /\
  let a := rnd (r k1 + r k4) in
  let b := rnd (r k2 + r k3) in
  let t := rnd (2 * b) in
  let s := rnd (a + t) in
  let p := rnd (r h * s) in
  let q := rnd (p / 6) in
  Rabs a < bpow radix2 emax /\ Rabs b < bpow radix2 emax /\ Rabs t < bpow radix2 emax /\
  Rabs s < bpow radix2 emax /\ Rabs p < bpow radix2 emax /\ Rabs q < bpow radix2 emax /\
  Rabs (rnd (r y + q)) < bpow radix2 emax.
Proof.
  pose proof Diana.Float.RK4.B2R_two as H2.
  pose proof Diana.Float.RK4.B2R_six as H6.
  change (bpow radix2 1) with 2 in H2.
  assert (F2 : fin (Diana.Float.RK4.two)) by reflexivity.
  assert (N6 : r (Diana.Float.RK4.six) <> 0) by (rewrite H6; lra).
  cbv zeta. unfold Diana.Float.RK4.fstep, Diana.Float.RK4.fslope. split.
  - intro H.
    destruct (Diana.Float.RK4.step_finite plus_nan mult_nan div_nan h y k1 k2 k3 k4 H)
      as [Hh [Hy [H1 [Hk2 [H3 [H4 [Ha [Hb [Ht [Hs [Hp Hq]]]]]]]]]]].
    unfold Diana.Float.RK4.fslope in Hs, Hp, Hq.
    destruct (fmul_value _ _ Ht) as [_ [_ Hvt]].
    destruct (fmul_value _ _ Hp) as [_ [_ Hvp]].
    pose proof (fadd_value _ _ Ha) as Hva. pose proof (fadd_value _ _ Hb) as Hvb.
    pose proof (fadd_value _ _ Hs) as Hvs.
    pose proof (fdiv_value _ _ Hq N6) as Hvq.
    pose proof (proj1 (fadd_finite_iff _ _ H1 H4) Ha) as Ra.
    pose proof (proj1 (fadd_finite_iff _ _ Hk2 H3) Hb) as Rb.
    pose proof (proj1 (fmul_finite_iff _ _ F2 Hb) Ht) as Rt.
    pose proof (proj1 (fadd_finite_iff _ _ Ha Ht) Hs) as Rs.
    pose proof (proj1 (fmul_finite_iff _ _ Hh Hs) Hp) as Rp.
    pose proof (proj1 (fdiv_finite_iff _ _ Hp N6) Hq) as Rq.
    pose proof (proj1 (fadd_finite_iff _ _ Hy Hq) H) as Ro.
    rewrite H2, Hvb in Rt, Hvt. rewrite Hva, Hvt in Rs. rewrite Hvs, Hva, Hvt in Rp, Hvp.
    rewrite Hvp, H6 in Rq, Hvq. rewrite Hvq in Ro.
    repeat split; assumption.
  - intros [Hh [Hy [H1 [Hk2 [H3 [H4 [Ra [Rb [Rt [Rs [Rp [Rq Ro]]]]]]]]]]]].
    assert (Ha : fin (fadd k1 k4)) by exact (proj2 (fadd_finite_iff _ _ H1 H4) Ra).
    assert (Hb : fin (fadd k2 k3)) by exact (proj2 (fadd_finite_iff _ _ Hk2 H3) Rb).
    pose proof (fadd_value _ _ Ha) as Hva. pose proof (fadd_value _ _ Hb) as Hvb.
    assert (Ht : fin (fmul (Diana.Float.RK4.two) (fadd k2 k3))).
    { apply (proj2 (fmul_finite_iff _ _ F2 Hb)). rewrite H2, Hvb. exact Rt. }
    destruct (fmul_value _ _ Ht) as [_ [_ Hvt]]. rewrite H2, Hvb in Hvt.
    assert (Hs : fin (fadd (fadd k1 k4) (fmul (Diana.Float.RK4.two) (fadd k2 k3)))).
    { apply (proj2 (fadd_finite_iff _ _ Ha Ht)). rewrite Hva, Hvt. exact Rs. }
    pose proof (fadd_value _ _ Hs) as Hvs. rewrite Hva, Hvt in Hvs.
    assert (Hp : fin (fmul h (fadd (fadd k1 k4) (fmul (Diana.Float.RK4.two)
                                                    (fadd k2 k3))))).
    { apply (proj2 (fmul_finite_iff _ _ Hh Hs)). rewrite Hvs. exact Rp. }
    destruct (fmul_value _ _ Hp) as [_ [_ Hvp]]. rewrite Hvs in Hvp.
    assert (Hq : fin (fdiv (fmul h (fadd (fadd k1 k4) (fmul (Diana.Float.RK4.two)
                                                              (fadd k2 k3))))
                           (Diana.Float.RK4.six))).
    { apply (proj2 (fdiv_finite_iff _ _ Hp N6)). rewrite Hvp, H6. exact Rq. }
    pose proof (fdiv_value _ _ Hq N6) as Hvq. rewrite Hvp, H6 in Hvq.
    apply (proj2 (fadd_finite_iff _ _ Hy Hq)). rewrite Hvq. exact Ro.
Qed.

End Model.
