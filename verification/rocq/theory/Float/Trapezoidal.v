From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core Plus_error Relative IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
Import ListNotations.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Lemma half_error (x : R) :
  generic_format radix2 fexp x ->
  Rabs (round radix2 fexp ZnearestE (/ 2 * x) - / 2 * x) <= eta.
Proof.
  intro Hx. destruct (FLT_format_generic radix2 emin prec x Hx) as [f Hf Hm He].
  destruct (Z.eq_dec (Fexp f) emin) as [Heq | Hne].
  - rewrite <- half_emin.
    assert (Hsmall : Rabs (/ 2 * x) < bpow radix2 (emin + prec)).
    { rewrite Hf. unfold F2R. rewrite Heq, Rabs_mult, Rabs_mult, Rabs_inv, Rabs_pos_eq by lra.
      rewrite (Rabs_pos_eq (bpow _ _)) by (left; apply bpow_gt_0).
      rewrite bpow_plus. rewrite <- abs_IZR.
      assert (Hlt : IZR (Z.abs (Fnum f)) < bpow radix2 prec).
      { rewrite <- IZR_Zpower by lia. apply IZR_lt. exact Hm. }
      pose proof (bpow_gt_0 radix2 emin). pose proof (IZR_le 0 _ (Z.abs_nonneg (Fnum f))). nra. }
    rewrite <- (ulp_FLT_small radix2 emin prec (/ 2 * x) Hsmall).
    apply error_le_half_ulp. typeclasses eauto.
  - rewrite round_generic; [rewrite Rminus_diag, Rabs_R0; left; apply eta_pos | typeclasses eauto |].
    apply generic_format_FLT. exists (Float radix2 (Fnum f) (Fexp f - 1)).
    + rewrite Hf. unfold F2R; simpl. replace (Fexp f) with (Fexp f - 1 + 1)%Z at 1 by ring.
      rewrite bpow_plus, bpow_1. change (IZR (radix_val radix2)) with 2. field.
    + exact Hm.
    + simpl. lia.
Qed.

Section Model.

Variable plus_nan mult_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Definition half : b64 :=
  B754_finite prec emax false 4503599627370496 (-53) ltac:(vm_compute; reflexivity).

Lemma B2R_half : B2R prec emax half = / 2.
Proof.
  unfold half, B2R, F2R; simpl.
  change (Z.pow_pos 2 53) with 9007199254740992%Z. lra.
Qed.

Local Abbreviation fadd := (Diana.Float.Sum.fadd plus_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).

Definition start (y0 yl : b64) : b64 := fmul half (fadd y0 yl).
Definition fsum (y0 yl : b64) (m : list b64) : b64 := fold_left fadd m (start y0 yl).
Definition ftrap (y0 yl : b64) (m : list b64) (h : b64) : b64 := fmul h (fsum y0 yl m).

Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

Theorem finite_result (y0 yl : b64) (m : list b64) (h : b64) :
  fin (ftrap y0 yl m h) ->
  fin h /\ fin y0 /\ fin yl /\ Forall (fun x => fin x) m /\
  forall k, fin (fold_left fadd (firstn k m) (start y0 yl)).
Proof.
  intro H. unfold ftrap in H. destruct (fmul_value _ _ H) as [Hh [Hs _]].
  unfold fsum in Hs. destruct (fold_finite_inv _ _ Hs) as [H0 Hm].
  unfold start in H0. destruct (fmul_value _ _ H0) as [_ [Hp _]].
  destruct (fadd_finite_inv _ _ Hp) as [Hy0 Hyl].
  split; [exact Hh | split; [exact Hy0 | split; [exact Hyl | split; [exact Hm |]]]].
  intro k. rewrite <- (firstn_skipn k m) in Hs. rewrite fold_left_app in Hs.
  exact (proj1 (fold_finite_inv _ _ Hs)).
Qed.

Theorem forward_error (y0 yl : b64) (m : list b64) (h : b64) :
  fin (ftrap y0 yl m h) ->
  INR (length m + 2) * u < 1 ->
  Rabs (r (ftrap y0 yl m h) - r h * ((r y0 + r yl) / 2 + rsum m))
    <= gamma (length m + 2) * Rabs (r h) * (Rabs (r y0 + r yl) / 2 + rabs_sum m)
       + (1 + gamma (length m + 1)) * Rabs (r h) * eta + eta.
Proof.
  intros H Hn.
  unfold ftrap in H |- *. destruct (fmul_value _ _ H) as [Hh [Hs Hr]].
  unfold fsum in Hs, Hr |- *. destruct (fold_finite_inv _ _ Hs) as [H0 _].
  unfold start in H0. destruct (fmul_value _ _ H0) as [_ [Hp Hv0]].
  pose proof (fadd_value _ _ Hp) as Hvp.
  pose proof u_pos as Hu. pose proof eta_pos as Heta.
  set (L := length m) in *.
  assert (HnL : forall k, (k <= L + 2)%nat -> INR k * u < 1).
  { intros k Hk. eapply Rle_lt_trans; [| exact Hn].
    apply Rmult_le_compat_r; [lra | apply le_INR; exact Hk]. }
  set (X0 := (r y0 + r yl) / 2).
  set (R0 := Rabs (r y0 + r yl) / 2).
  assert (HX0 : Rabs X0 <= R0).
  { unfold X0, R0, Rdiv. rewrite Rabs_mult, Rabs_inv, (Rabs_pos_eq 2) by lra. lra. }
  assert (Hbase : Rabs (r (start y0 yl) - X0) <= gamma 1 * R0 + (1 + gamma 0) * eta).
  { unfold start. rewrite Hv0, B2R_half. rewrite gamma_0, Rplus_0_r, Rmult_1_l.
    pose proof (half_error (r (fadd y0 yl)) (generic_format_B2R prec emax _)) as Hhalf.
    destruct (add_error (r y0) (r yl) (generic_format_B2R prec emax y0)
                (generic_format_B2R prec emax yl)) as [d [Hd Hrd]].
    rewrite Hvp, Hrd in Hhalf. rewrite Hvp, Hrd.
    pose proof (u_le_gamma_1 ltac:(apply (HnL 2%nat); lia || (simpl; lia))) as Hug.
    replace (round radix2 fexp ZnearestE (/ 2 * ((r y0 + r yl) * (1 + d))) - X0)
      with ((round radix2 fexp ZnearestE (/ 2 * ((r y0 + r yl) * (1 + d)))
             - / 2 * ((r y0 + r yl) * (1 + d))) + d * X0) by (unfold X0; field).
    eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult.
    assert (Hd0 : Rabs d * Rabs X0 <= gamma 1 * R0).
    { apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | lra | exact HX0]. }
    lra. }
  assert (HnS : INR (S 0 + L) * u < 1) by (apply HnL; lia).
  pose proof (fold_error m (start y0 yl) X0 R0 0 Hs Hbase HX0 HnS) as Hsum.
  fold L in Hsum. simpl (S 0 + L)%nat in Hsum. simpl (0 + L)%nat in Hsum.
  set (sh := fold_left fadd m (start y0 yl)) in *.
  set (St := X0 + rsum m) in *.
  set (A := R0 + rabs_sum m) in *.
  set (E := gamma (S L) * A + (1 + gamma L) * eta) in *.
  assert (HS : Rabs St <= A).
  { unfold St, A. eapply Rle_trans; [apply Rabs_triang |].
    pose proof (rsum_abs m). lra. }
  rewrite Hr.
  destruct (round_error (r h * r sh)) as [e [dd [He [Hdd Hround]]]].
  rewrite Hround.
  replace (r h * r sh * (1 + e) + dd - r h * St)
    with (r h * (r sh - St) + e * (r h * r sh) + dd) by ring.
  assert (Hg1 : gamma (S L) * (1 + u) + u <= gamma (L + 2)).
  { replace (L + 2)%nat with (S (S L)) by lia. apply gamma_step. apply HnL; lia. }
  assert (Hg0 : gamma L * (1 + u) + u <= gamma (L + 1)).
  { replace (L + 1)%nat with (S L) by lia. apply gamma_step. apply HnL; lia. }
  assert (Hg1p : 0 <= gamma (S L)) by (apply gamma_nonneg; apply HnL; lia).
  assert (HAp : 0 <= A).
  { unfold A, R0. pose proof (rabs_sum_nonneg m). pose proof (Rabs_pos (r y0 + r yl)). lra. }
  pose proof (Rabs_pos (r h)) as Hhp.
  set (Hm := Rabs (r h)) in *.
  assert (Hsh : Rabs (r sh) <= A + E).
  { replace (r sh) with (St + (r sh - St)) by ring.
    eapply Rle_trans; [apply Rabs_triang | lra]. }
  assert (T1 : Rabs (r h * (r sh - St)) <= Hm * E).
  { rewrite Rabs_mult. apply Rmult_le_compat_l; [exact Hhp | exact Hsum]. }
  assert (T2 : Rabs (e * (r h * r sh)) <= u * (Hm * (A + E))).
  { rewrite !Rabs_mult. apply Rmult_le_compat; [apply Rabs_pos | | exact He |].
    - apply Rmult_le_pos; [exact Hhp | apply Rabs_pos].
    - apply Rmult_le_compat_l; [exact Hhp | exact Hsh]. }
  eapply Rle_trans; [apply Rabs_triang |].
  eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
  assert (H1 : (gamma (S L) * (1 + u) + u) * (Hm * A) <= gamma (L + 2) * (Hm * A))
    by (apply Rmult_le_compat_r; [apply Rmult_le_pos; lra | exact Hg1]).
  assert (H2 : (gamma L * (1 + u) + u) * (Hm * eta) <= gamma (L + 1) * (Hm * eta))
    by (apply Rmult_le_compat_r; [apply Rmult_le_pos; lra | exact Hg0]).
  unfold E in *. nra.
Qed.

End Model.
