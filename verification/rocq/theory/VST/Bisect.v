From VST.floyd Require Import proofauto.
From Diana.Clight Require Import bisect_aarch64_macos.
From Diana.Float Require Bisect.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition c_half : float := Float.of_bits (Int64.repr 4602678819172646912).

Lemma c_half_eq : c_half = Diana.Float.Bisect.half.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Definition c_mid (a b : float) : float := Float.mul c_half (Float.add a b).

Lemma c_mid_model (a b : float) :
  c_mid a b = Diana.Float.Bisect.mid Float.binop_nan Float.binop_nan a b.
Proof. unfold c_mid, Diana.Float.Bisect.mid. rewrite c_half_eq. reflexivity. Qed.

Definition mid_spec :=
  DECLARE _bisect_mid
  WITH a : float, b : float
  PRE [ tdouble, tdouble ]
    PROP () PARAMS (Vfloat a; Vfloat b) SEP ()
  POST [ tdouble ]
    PROP () RETURN (Vfloat (c_mid a b)) SEP ().

Definition Gprog : funspecs := [mid_spec].

Lemma body_bisect_mid : semax_body Vprog Gprog f_bisect_mid mid_spec.
Proof.
  start_function.
  forward.
Qed.

Definition c_zero : float := Float.of_bits (Int64.repr 0).

Lemma c_zero_eq : c_zero = Flocq.IEEE754.Binary.B754_zero 53 1024 false.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Lemma cmp_eq_self (x : float) :
  Float.cmp Ceq x x = negb (Binary.is_nan 53 1024 x).
Proof.
  Transparent Float.cmp.
  unfold Float.cmp, Float.compare, cmp_of_comparison.
  Opaque Float.cmp.
  destruct x as [sg | sg | sg pl H | sg m e H]; simpl.
  - reflexivity.
  - destruct sg; reflexivity.
  - reflexivity.
  - unfold Binary.Bcompare; simpl.
    rewrite Z.compare_refl, Pos.compare_cont_refl.
    destruct sg; reflexivity.
Qed.

#[local] Instance prec_gt_0_53' : FLX.Prec_gt_0 53 := eq_refl.
#[local] Instance prec_lt_emax_53' : BinarySingleNaN.Prec_lt_emax 53 1024 := eq_refl.

Lemma sub_self_finite_zero (x : float) :
  Binary.is_finite 53 1024 x = true ->
  Binary.B2R 53 1024 (Float.sub x x) = Rdefinitions.IZR 0 /\
  Binary.is_finite 53 1024 (Float.sub x x) = true.
Proof.
  intro Hf.
  Transparent Float.sub. unfold Float.sub. Opaque Float.sub.
  pose proof (Binary.Bminus_correct 53 1024 _ _ Float.binop_nan
                BinarySingleNaN.mode_NE x x Hf Hf) as H.
  replace (Rdefinitions.Rminus (Binary.B2R 53 1024 x) (Binary.B2R 53 1024 x))
    with (Rdefinitions.IZR 0) in H
    by (unfold Rdefinitions.Rminus; rewrite Raxioms.Rplus_opp_r; reflexivity).
  rewrite Generic_fmt.round_0 in H by typeclasses eauto.
  rewrite Rbasic_fun.Rabs_R0, Raux.Rlt_bool_true in H by apply Raux.bpow_gt_0.
  destruct H as [Hval [Hfin _]].
  split; [exact Hval | exact Hfin].
Qed.

Lemma of_bits_zero : Float.of_bits (Int64.repr 0) = Binary.B754_zero 53 1024 false.
Proof. apply Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma cmp_sub_self_zero (x : float) :
  Binary.is_nan 53 1024 x = false ->
  Float.cmp Ceq (Float.sub x x) (Float.of_bits (Int64.repr 0))
  = Binary.is_finite 53 1024 x.
Proof.
  intro Hnan. rewrite of_bits_zero.
  destruct (Binary.is_finite 53 1024 x) eqn:Hf.
  - destruct (sub_self_finite_zero x Hf) as [Hval Hfin].
    Transparent Float.cmp. unfold Float.cmp, Float.compare, cmp_of_comparison.
    Opaque Float.cmp.
    rewrite (Binary.Bcompare_correct 53 1024 (Float.sub x x)
               (Binary.B754_zero 53 1024 false) Hfin (eq_refl : Binary.is_finite 53 1024 (Binary.B754_zero 53 1024 false) = true)).
    rewrite Hval. simpl.
    rewrite Raux.Rcompare_Eq by reflexivity. reflexivity.
  - destruct x as [sg | sg | sg pl H | sg m e H]; try discriminate.
    Transparent Float.sub Float.cmp.
    unfold Float.sub, Float.cmp, Float.compare, cmp_of_comparison.
    Opaque Float.sub Float.cmp.
    destruct sg; reflexivity.
Qed.

Definition c_abs (x : float) : float :=
  if Float.cmp Clt x (Float.of_bits (Int64.repr 0)) then Float.neg x else x.

Definition fp_abs_spec :=
  DECLARE _diana_fp_abs
  WITH x : float
  PRE [ tdouble ]
    PROP (Binary.is_finite 53 1024 x = true) PARAMS (Vfloat x) SEP ()
  POST [ tdouble ]
    PROP () RETURN (Vfloat (c_abs x)) SEP ().

Definition Gprog2 : funspecs :=
  ltac:(with_library prog [fp_finite_spec; fp_abs_spec; mid_spec]).

Lemma body_diana_fp_finite : semax_body Vprog Gprog2 f_diana_fp_finite fp_finite_spec.
Proof.
  start_function.
  forward_if (PROP () LOCAL (temp _t'1
      (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero))) SEP ()).
  - forward. entailer!.
    rewrite cmp_sub_self_zero by
      (destruct (Binary.is_nan 53 1024 x) eqn:Hn; [| reflexivity];
       rewrite cmp_eq_self, Hn in H; discriminate H).
    destruct (Binary.is_finite 53 1024 x); reflexivity.
  - forward. entailer!.
    rewrite cmp_eq_self in H.
    destruct (Binary.is_nan 53 1024 x) eqn:Hn; [| discriminate H].
    destruct x; try discriminate Hn. reflexivity.
  - forward.
Qed.

Lemma c_abs_B2R (x : float) :
  Binary.is_finite 53 1024 x = true ->
  Binary.B2R 53 1024 (c_abs x) = Rbasic_fun.Rabs (Binary.B2R 53 1024 x).
Proof.
  intro Hf. unfold c_abs.
  rewrite of_bits_zero.
  Transparent Float.cmp. unfold Float.cmp, Float.compare, cmp_of_comparison.
  Opaque Float.cmp.
  rewrite (Binary.Bcompare_correct 53 1024 x (Binary.B754_zero 53 1024 false) Hf
             (eq_refl : Binary.is_finite 53 1024 (Binary.B754_zero 53 1024 false) = true)).
  simpl.
  destruct (Raux.Rcompare_spec (Binary.B2R 53 1024 x) (Rdefinitions.IZR 0)) as [Hlt | Heq | Hgt].
  - simpl. Transparent Float.neg. unfold Float.neg. Opaque Float.neg.
    rewrite Binary.B2R_Bopp.
    rewrite Rbasic_fun.Rabs_left by exact Hlt. reflexivity.
  - simpl. rewrite Heq, Rbasic_fun.Rabs_R0. reflexivity.
  - simpl. rewrite Rbasic_fun.Rabs_right by
      (apply RIneq.Rle_ge, RIneq.Rlt_le; exact Hgt). reflexivity.
Qed.

Lemma c_abs_finite (x : float) :
  Binary.is_finite 53 1024 x = true -> Binary.is_finite 53 1024 (c_abs x) = true.
Proof.
  intro Hf. unfold c_abs. destruct (Float.cmp Clt x (Float.of_bits (Int64.repr 0)));
    [| exact Hf].
  Transparent Float.neg. unfold Float.neg. Opaque Float.neg.
  rewrite Binary.is_finite_Bopp. exact Hf.
Qed.

Lemma body_diana_fp_abs : semax_body Vprog Gprog2 f_diana_fp_abs fp_abs_spec.
Proof.
  start_function.
  forward_if (PROP () LOCAL (temp _t'1 (Vfloat (c_abs x))) SEP ()).
  - forward. entailer!. unfold c_abs.
    destruct (Float.cmp Clt x (Float.of_bits (Int64.repr 0))) eqn:Hc;
      [reflexivity | congruence].
  - forward. entailer!. unfold c_abs.
    destruct (Float.cmp Clt x (Float.of_bits (Int64.repr 0))) eqn:Hc;
      [congruence | reflexivity].
  - forward.
Qed.

Definition t_state := Tstruct _diana_bisect_state noattr.

Definition state_repr (a b fa fb x tol : float) (iter max_iter : Z) : reptype t_state :=
  (Vfloat a, (Vfloat b, (Vfloat fa, (Vfloat fb,
   (Vfloat x, (Vfloat tol, (Vint (Int.repr iter), Vint (Int.repr max_iter)))))))).


Definition result_spec :=
  DECLARE _diana_bisect_result
  WITH sh : share, s : val, root : val, width : val,
       a : float, b : float, fa : float, fb : float, x : float, tol : float,
       iter : Z, max_iter : Z, shr : share, shw : share
  PRE [ tptr t_state, tptr tdouble, tptr tdouble ]
    PROP (readable_share sh; writable_share shr; writable_share shw;
          s <> nullval; root <> nullval; width <> nullval)
    PARAMS (s; root; width)
    SEP (data_at sh t_state (state_repr a b fa fb x tol iter max_iter) s;
         data_at_ shr tdouble root; data_at_ shw tdouble width)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr 0))
    SEP (data_at sh t_state (state_repr a b fa fb x tol iter max_iter) s;
         data_at shr tdouble (Vfloat (c_mid a b)) root;
         data_at shw tdouble (Vfloat (Float.sub b a)) width).

Definition Gprog3 : funspecs :=
  ltac:(with_library prog [fp_finite_spec; fp_abs_spec; mid_spec; result_spec]).

Lemma body_diana_bisect_result :
  semax_body Vprog Gprog3 f_diana_bisect_result result_spec.
Proof.
  start_function.
  forward_if.
  - subst s. contradiction.
  - forward_if (PROP ()
      LOCAL (temp _s s; temp _root root; temp _width width)
      SEP (data_at sh t_state (state_repr a b fa fb x tol iter max_iter) s;
           data_at shr tdouble (Vfloat (c_mid a b)) root;
           data_at_ shw tdouble width)).
    + forward. forward. forward_call (a, b). forward. entailer!.
    + contradiction.
    + forward_if (PROP ()
        LOCAL (temp _s s; temp _root root; temp _width width)
        SEP (data_at sh t_state (state_repr a b fa fb x tol iter max_iter) s;
             data_at shr tdouble (Vfloat (c_mid a b)) root;
             data_at shw tdouble (Vfloat (Float.sub b a)) width)).
      * forward. forward. forward. entailer!.
      * contradiction.
      * forward.
Qed.

(* diana_bisect_init and diana_bisect_step have no VST theorem yet: their layer-C
   guarantee is BIS-C2 (Frama-C WP) and their binary64 model is BIS-B2/B3/B4.
   spec/bisect.md records the blocker. *)
