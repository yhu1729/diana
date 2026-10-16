From VST.floyd Require Import proofauto.
From Diana.Clight Require Import bisection_aarch64_macos.
From Diana.Float Require Bisection.
From Stdlib Require Import RIneq Lra.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition c_half : float := Float.of_bits (Int64.repr 4602678819172646912).

Lemma c_half_eq : c_half = Diana.Float.Bisection.half.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Definition c_mid (a b : float) : float := Float.mul c_half (Float.add a b).

Lemma c_mid_model (a b : float) :
  c_mid a b = Diana.Float.Bisection.mid Float.binop_nan Float.binop_nan a b.
Proof. unfold c_mid, Diana.Float.Bisection.mid. rewrite c_half_eq. reflexivity. Qed.

Definition mid_spec :=
  DECLARE _bisection_mid
  WITH a : float, b : float
  PRE [ tdouble, tdouble ]
    PROP () PARAMS (Vfloat a; Vfloat b) SEP ()
  POST [ tdouble ]
    PROP () RETURN (Vfloat (c_mid a b)) SEP ().

Definition Gprog : funspecs := [mid_spec].

Lemma body_bisection_mid : semax_body Vprog Gprog f_bisection_mid mid_spec.
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

Definition t_state := Tstruct _diana_bisection_state noattr.

Definition state_repr (a b fa fb x tol : float) (iter max_iter : Z) : reptype t_state :=
  (Vfloat a, (Vfloat b, (Vfloat fa, (Vfloat fb,
   (Vfloat x, (Vfloat tol, (Vint (Int.repr iter), Vint (Int.repr max_iter)))))))).


Definition result_spec :=
  DECLARE _diana_bisection_result
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

Lemma body_diana_bisection_result :
  semax_body Vprog Gprog3 f_diana_bisection_result result_spec.
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

Module FB := Diana.Float.Bisection.

Definition c_max : float :=
  Float.div (Float.of_bits (Int64.repr 9218868437227405311))
            (Float.of_bits (Int64.repr 4611686018427387904)).

Lemma c_max_B2R :
  Binary.B2R 53 1024 c_max = FB.dbl_max_half /\ Binary.is_finite 53 1024 c_max = true.
Proof.
  assert (H : c_max = Binary.B754_finite 53 1024 false 9007199254740991 970 eq_refl)
    by (apply Binary.B2FF_inj; vm_compute; reflexivity).
  rewrite H. split; [| reflexivity].
  unfold FB.dbl_max_half, Binary.B2R, Defs.F2R; simpl Defs.Fnum; simpl Defs.Fexp.
  change 1023%Z with (53 + 970)%Z. rewrite Raux.bpow_plus.
  change (Raux.bpow Zaux.radix2 53) with (IZR 9007199254740992).
  change 9007199254740991%Z with (9007199254740992 - 1)%Z.
  rewrite minus_IZR. simpl. ring.
Qed.

Record cstate : Type := mkcstate { cfl : FB.state; citer : int; cmax : int }.

Definition cstate_repr (c : cstate) : reptype t_state :=
  (Vfloat (FB.sa (cfl c)), (Vfloat (FB.sb (cfl c)), (Vfloat (FB.sfa (cfl c)),
   (Vfloat (FB.sfb (cfl c)), (Vfloat (FB.sx (cfl c)), (Vfloat (FB.stol (cfl c)),
   (Vint (citer c), Vint (cmax c)))))))).

Lemma cstate_repr_state_repr (c : cstate) :
  cstate_repr c = state_repr (FB.sa (cfl c)) (FB.sb (cfl c)) (FB.sfa (cfl c)) (FB.sfb (cfl c))
                    (FB.sx (cfl c)) (FB.stol (cfl c))
                    (Int.unsigned (citer c)) (Int.unsigned (cmax c)).
Proof. unfold cstate_repr, state_repr. rewrite !Int.repr_unsigned. reflexivity. Qed.

Definition c_fin (x : float) : bool := Binary.is_finite 53 1024 x.

Definition c_init (a b fa fb tol : float) (m : int) : Z * option cstate :=
  if (negb (c_fin a) || negb (c_fin b) || negb (c_fin fa) || negb (c_fin fb) ||
      negb (c_fin tol))%bool then (-1, None)
  else if (Float.cmp Cgt a b || Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool
  then (-1, None)
  else if (Float.cmp Cgt (c_abs a) c_max || Float.cmp Cgt (c_abs b) c_max)%bool
  then (-1, None)
  else if (Float.cmp Cgt fa c_zero && Float.cmp Cgt fb c_zero ||
           Float.cmp Clt fa c_zero && Float.cmp Clt fb c_zero)%bool then (-2, None)
  else if Float.cmp Ceq fa c_zero then
    (0, Some (mkcstate (FB.mkstate a a fa fa a tol) Int.zero m))
  else if Float.cmp Ceq fb c_zero then
    (0, Some (mkcstate (FB.mkstate b b fb fb b tol) Int.zero m))
  else
    let c := mkcstate (FB.mkstate a b fa fb (c_mid a b) tol) Int.zero m in
    if (Float.cmp Cle (Float.sub b a) tol || Float.cmp Cle (c_mid a b) a ||
        Float.cmp Cge (c_mid a b) b)%bool then (0, Some c) else (1, Some c).

Definition c_keep (s : FB.state) (fx : float) : FB.state :=
  if Bool.eqb (Float.cmp Cgt fx c_zero) (Float.cmp Cgt (FB.sfa s) c_zero)
  then FB.mkstate (FB.sx s) (FB.sb s) fx (FB.sfb s) (FB.sx s) (FB.stol s)
  else FB.mkstate (FB.sa s) (FB.sx s) (FB.sfa s) fx (FB.sx s) (FB.stol s).

Definition c_step (c : cstate) (fx : float) : Z * cstate :=
  if negb (c_fin fx) then (-1, c) else
  let s := cfl c in
  let it := Int.add (citer c) Int.one in
  if Float.cmp Ceq fx c_zero then
    (0, mkcstate (FB.mkstate (FB.sx s) (FB.sx s) fx fx (FB.sx s) (FB.stol s)) it (cmax c))
  else
    let s1 := c_keep s fx in
    if Float.cmp Cle (Float.sub (FB.sb s1) (FB.sa s1)) (FB.stol s1) then
      (0, mkcstate s1 it (cmax c))
    else
      let x := c_mid (FB.sa s1) (FB.sb s1) in
      let s2 := FB.mkstate (FB.sa s1) (FB.sb s1) (FB.sfa s1) (FB.sfb s1) x (FB.stol s1) in
      if (Float.cmp Cle x (FB.sa s1) || Float.cmp Cge x (FB.sb s1))%bool then
        (0, mkcstate s2 it (cmax c))
      else if negb (Int.ltu it (cmax c)) then (-3, mkcstate s2 it (cmax c))
      else (1, mkcstate s2 it (cmax c)).

Lemma cmp_zero_correct (c : comparison) (x : float) :
  Binary.is_finite 53 1024 x = true ->
  Float.cmp c x c_zero =
  cmp_of_comparison c (Some (Raux.Rcompare (Binary.B2R 53 1024 x) 0%R)).
Proof.
  intro Hf. unfold c_zero. rewrite of_bits_zero.
  Transparent Float.cmp. unfold Float.cmp, Float.compare. Opaque Float.cmp.
  rewrite (Binary.Bcompare_correct 53 1024 x (Binary.B754_zero 53 1024 false) Hf
             (eq_refl : Binary.is_finite 53 1024 (Binary.B754_zero 53 1024 false) = true)).
  reflexivity.
Qed.

Lemma cmp_gt_zero_fpos (x : float) :
  Binary.is_finite 53 1024 x = true -> Float.cmp Cgt x c_zero = FB.fpos x.
Proof.
  intro Hf. rewrite cmp_zero_correct by exact Hf. unfold FB.fpos.
  destruct (Raux.Rcompare_spec (Binary.B2R 53 1024 x) 0%R) as [H | H | H];
    destruct (Rlt_dec 0 (Binary.B2R 53 1024 x)); simpl; try reflexivity; lra.
Qed.

Lemma cmp_eq_zero_true (x : float) :
  Binary.is_finite 53 1024 x = true ->
  (Float.cmp Ceq x c_zero = true <-> Binary.B2R 53 1024 x = 0%R).
Proof.
  intro Hf. rewrite cmp_zero_correct by exact Hf.
  destruct (Raux.Rcompare_spec (Binary.B2R 53 1024 x) 0%R) as [H | H | H]; simpl;
    split; intro; try reflexivity; try discriminate; lra.
Qed.

Lemma cmp_le_fle (x y : float) : Float.cmp Cle x y = FB.fle x y.
Proof.
  Transparent Float.cmp. unfold Float.cmp, Float.compare, FB.fle. Opaque Float.cmp.
  destruct (Binary.Bcompare 53 1024 x y) as [[] |]; reflexivity.
Qed.

Lemma sub_fwidth (s : FB.state) :
  Float.sub (FB.sb s) (FB.sa s) = FB.fwidth Float.binop_nan s.
Proof. reflexivity. Qed.

Theorem c_step_fstep (c : cstate) (fx : float) :
  Binary.is_finite 53 1024 fx = true -> Binary.is_finite 53 1024 (FB.sfa (cfl c)) = true ->
  snd (c_step c fx) =
  mkcstate (FB.fstep Float.binop_nan Float.binop_nan Float.binop_nan (cfl c) fx)
           (Int.add (citer c) Int.one) (cmax c).
Proof.
  intros Hfx Hfa. unfold c_step, c_fin. rewrite Hfx. cbv zeta. simpl negb. cbv iota.
  unfold FB.fstep.
  destruct (Req_dec_T (Binary.B2R 53 1024 fx) 0) as [E | E].
  - apply cmp_eq_zero_true in E; [| exact Hfx]. rewrite E. reflexivity.
  - assert (E' : Float.cmp Ceq fx c_zero = false).
    { destruct (Float.cmp Ceq fx c_zero) eqn:Hc; [| reflexivity].
      apply cmp_eq_zero_true in Hc; [contradiction | exact Hfx]. }
    rewrite E'.
    assert (Hk : c_keep (cfl c) fx = FB.fkeep (cfl c) fx).
    { unfold c_keep, FB.fkeep. rewrite !cmp_gt_zero_fpos by assumption. reflexivity. }
    rewrite Hk, sub_fwidth, cmp_le_fle.
    destruct (FB.fle _ _); [reflexivity |].
    rewrite c_mid_model.
    destruct (Float.cmp Cle _ _ || Float.cmp Cge _ _)%bool; [reflexivity |].
    destruct (negb (Int.ltu _ _)); reflexivity.
Qed.

Section Chain.
Local Open Scope R_scope.

Lemma cmp_correct (c : comparison) (x y : float) :
  Binary.is_finite 53 1024 x = true -> Binary.is_finite 53 1024 y = true ->
  Float.cmp c x y =
  cmp_of_comparison c (Some (Raux.Rcompare (Binary.B2R 53 1024 x) (Binary.B2R 53 1024 y))).
Proof.
  intros Hx Hy.
  Transparent Float.cmp. unfold Float.cmp, Float.compare. Opaque Float.cmp.
  rewrite (Binary.Bcompare_correct 53 1024 x y Hx Hy). reflexivity.
Qed.

Lemma cmp_real (c : comparison) (x y : float) :
  Binary.is_finite 53 1024 x = true -> Binary.is_finite 53 1024 y = true ->
  let u := Binary.B2R 53 1024 x in let v := Binary.B2R 53 1024 y in
  (Float.cmp c x y = true -> match c with
                             | Ceq => u = v | Cne => u <> v | Clt => u < v
                             | Cle => u <= v | Cgt => v < u | Cge => v <= u end) /\
  (Float.cmp c x y = false -> match c with
                              | Ceq => u <> v | Cne => u = v | Clt => v <= u
                              | Cle => v < u | Cgt => u <= v | Cge => u < v end).
Proof.
  intros Hx Hy u v. rewrite cmp_correct by assumption. fold u v.
  destruct (Raux.Rcompare_spec u v); destruct c; simpl;
    split; intro E; try discriminate E; lra.
Qed.

Ltac real_of H :=
  match type of H with
  | Float.cmp ?c ?x ?y = true =>
      apply (proj1 (cmp_real c x y ltac:(assumption) ltac:(assumption))) in H; cbv zeta in H
  | Float.cmp ?c ?x ?y = false =>
      apply (proj2 (cmp_real c x y ltac:(assumption) ltac:(assumption))) in H; cbv zeta in H
  end.

Lemma c_zero_B2R : Binary.B2R 53 1024 c_zero = 0 /\ Binary.is_finite 53 1024 c_zero = true.
Proof. unfold c_zero. rewrite of_bits_zero. split; reflexivity. Qed.

Theorem c_init_bracket (a b fa fb tol : float) (m : int) (r : Z) (c : cstate) :
  c_init a b fa fb tol m = (r, Some c) ->
  FB.Bracket (cfl c) /\ (r = 1%Z -> FB.Next (cfl c)) /\ (r = 0%Z \/ r = 1%Z) /\
  citer c = Int.zero /\ cmax c = m /\ Int.eq m Int.zero = false.
Proof.
  destruct c_zero_B2R as [Hz Hzf].
  destruct c_max_B2R as [Hmx Hmxf].
  unfold c_init.
  destruct (negb (c_fin a) || negb (c_fin b) || negb (c_fin fa) || negb (c_fin fb) ||
            negb (c_fin tol))%bool eqn:Hfin; [discriminate |].
  unfold c_fin in Hfin. rewrite !Bool.orb_false_iff, !Bool.negb_false_iff in Hfin.
  destruct Hfin as [[[[Ha Hb] Hfa] Hfb] Htol].
  destruct (Float.cmp Cgt a b || Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool
    eqn:Hrange; [discriminate |].
  rewrite !Bool.orb_false_iff in Hrange. destruct Hrange as [[Hab Htol0] Hm].
  real_of Hab. real_of Htol0. rewrite Hz in Htol0.
  destruct (Float.cmp Cgt (c_abs a) c_max || Float.cmp Cgt (c_abs b) c_max)%bool
    eqn:Habs; [discriminate |].
  rewrite !Bool.orb_false_iff in Habs. destruct Habs as [Haa Hbb].
  pose proof (c_abs_finite a Ha). pose proof (c_abs_finite b Hb).
  real_of Haa. real_of Hbb. rewrite c_abs_B2R, Hmx in Haa, Hbb by assumption.
  destruct (Float.cmp Cgt fa c_zero && Float.cmp Cgt fb c_zero ||
            Float.cmp Clt fa c_zero && Float.cmp Clt fb c_zero)%bool
    eqn:Hsign; [discriminate |].
  assert (Hsg : (Binary.B2R 53 1024 fa <= 0 \/ Binary.B2R 53 1024 fb <= 0) /\
                (0 <= Binary.B2R 53 1024 fa \/ 0 <= Binary.B2R 53 1024 fb)).
  { rewrite Bool.orb_false_iff, !Bool.andb_false_iff in Hsign.
    destruct Hsign as [[H1 | H1] [H2 | H2]]; real_of H1; real_of H2; rewrite Hz in *;
      split; (left; lra) || (right; lra). }
  destruct (Float.cmp Ceq fa c_zero) eqn:Hfa0.
  { intro E. injection E as <- <-. real_of Hfa0. rewrite Hz in Hfa0.
    unfold FB.Bracket, FB.Next; cbn [cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
    split; [repeat split; try assumption; try lra; right; right; repeat split; assumption |].
    split; [intro; discriminate |]. repeat split; auto. }
  destruct (Float.cmp Ceq fb c_zero) eqn:Hfb0.
  { intro E. injection E as <- <-. real_of Hfb0. rewrite Hz in Hfb0.
    unfold FB.Bracket, FB.Next; cbn [cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
    split; [repeat split; try assumption; try lra; right; right; repeat split; assumption |].
    split; [intro; discriminate |]. repeat split; auto. }
  real_of Hfa0. real_of Hfb0. rewrite Hz in Hfa0, Hfb0.
  assert (Hbr : FB.Bracket (FB.mkstate a b fa fb (c_mid a b) tol)).
  { unfold FB.Bracket; cbn [FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
    repeat split; try assumption; lra. }
  destruct (Float.cmp Cle (Float.sub b a) tol || Float.cmp Cle (c_mid a b) a ||
            Float.cmp Cge (c_mid a b) b)%bool eqn:Hstop.
  - intro E. injection E as <- <-. cbn [cfl citer cmax].
    split; [exact Hbr |]. split; [intro; discriminate |]. repeat split; auto.
  - intro E. injection E as <- <-. cbn [cfl citer cmax].
    split; [exact Hbr |]. split; [| repeat split; auto].
    intros _. rewrite !Bool.orb_false_iff in Hstop. destruct Hstop as [[_ Hxa] Hxb].
    destruct (FB.mid_in_bracket Float.binop_nan Float.binop_nan a b Ha Hb Hab Haa Hbb)
      as [Hxf _].
    rewrite <- c_mid_model in Hxf.
    real_of Hxa. real_of Hxb.
    unfold FB.Next; cbn [FB.sa FB.sb FB.sx]. split; [exact Hxf | split; assumption].
Qed.

Theorem c_step_next (c c' : cstate) (fx : float) :
  FB.Bracket (cfl c) -> FB.Next (cfl c) -> c_step c fx = (1%Z, c') ->
  FB.Bracket (cfl c') /\ FB.Next (cfl c') /\ Int.ltu (citer c') (cmax c') = true.
Proof.
  intros HB HN Hc.
  destruct (c_fin fx) eqn:Hf.
  2: { unfold c_step in Hc. rewrite Hf in Hc. discriminate. }
  assert (Hfa : Binary.is_finite 53 1024 (FB.sfa (cfl c)) = true)
    by (destruct HB as [_ [_ [Hfa _]]]; exact Hfa).
  pose proof (c_step_fstep c fx Hf Hfa) as E. rewrite Hc in E. cbn [snd] in E.
  assert (HB' : FB.Bracket (cfl c')).
  { rewrite E. cbn [cfl].
    exact (proj1 (FB.step_in_bracket Float.binop_nan Float.binop_nan Float.binop_nan
                    (cfl c) fx HB HN Hf)). }
  split; [exact HB' |].
  unfold c_step in Hc. rewrite Hf in Hc. cbv zeta in Hc. cbn [negb] in Hc.
  destruct (Float.cmp Ceq fx c_zero); [discriminate |].
  destruct (Float.cmp Cle _ _); [discriminate |].
  destruct (Float.cmp Cle _ _ || Float.cmp Cge _ _)%bool eqn:Hst; [discriminate |].
  destruct (negb (Int.ltu _ _)) eqn:Hlt; [discriminate |].
  injection Hc as <-. cbn [cfl citer cmax] in *.
  split; [| rewrite Bool.negb_false_iff in Hlt; exact Hlt].
  destruct HB' as [Ha [Hb [_ [_ [_ [Hab [Hba [Hbb _]]]]]]]].
  cbn [FB.sa FB.sb] in Ha, Hb, Hab, Hba, Hbb.
  destruct (FB.mid_in_bracket Float.binop_nan Float.binop_nan _ _ Ha Hb Hab Hba Hbb)
    as [Hxf _].
  rewrite <- c_mid_model in Hxf.
  rewrite !Bool.orb_false_iff in Hst. destruct Hst as [Hxa Hxb].
  real_of Hxa. real_of Hxb.
  unfold FB.Next; cbn [FB.sa FB.sb FB.sx]. split; [exact Hxf | split; assumption].
Qed.

End Chain.

Definition init_repr (old : reptype t_state) (o : option cstate) : reptype t_state :=
  match o with Some c => cstate_repr c | None => old end.

Definition init_spec :=
  DECLARE _diana_bisection_init
  WITH sh : share, s : val, old : reptype t_state,
       a : float, b : float, fa : float, fb : float, tol : float, m : int
  PRE [ tptr t_state, tdouble, tdouble, tdouble, tdouble, tdouble, tuint ]
    PROP (writable_share sh)
    PARAMS (s; Vfloat a; Vfloat b; Vfloat fa; Vfloat fb; Vfloat tol; Vint m)
    SEP (data_at sh t_state old s)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr (fst (c_init a b fa fb tol m))))
    SEP (data_at sh t_state (init_repr old (snd (c_init a b fa fb tol m))) s).

Definition step_spec :=
  DECLARE _diana_bisection_step
  WITH sh : share, s : val, c : cstate, fx : float
  PRE [ tptr t_state, tdouble ]
    PROP (writable_share sh)
    PARAMS (s; Vfloat fx)
    SEP (data_at sh t_state (cstate_repr c) s)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr (fst (c_step c fx))))
    SEP (data_at sh t_state (cstate_repr (snd (c_step c fx))) s).

Definition Gprog4 : funspecs :=
  ltac:(with_library prog [fp_finite_spec; fp_abs_spec; mid_spec; init_spec; step_spec]).

Ltac bool_solve :=
  unfold c_fin, c_zero, c_max in *;
  change (Int.repr 0) with Int.zero in *;
  repeat match goal with
    | H : context [Binary.is_finite 53 1024 _] |- _ =>
        lazymatch type of H with
        | orb _ _ = _ => fail | Binary.is_finite _ _ _ = _ => fail | _ => revert H end
    | H : context [Float.cmp _ _ _] |- _ =>
        lazymatch type of H with orb _ _ = _ => fail | _ => revert H end
    | H : context [Int.eq _ _] |- _ =>
        lazymatch type of H with orb _ _ = _ => fail | _ => revert H end
    end;
  repeat match goal with
    | |- context [Binary.is_finite 53 1024 ?x] => destruct (Binary.is_finite 53 1024 x)
    | |- context [Float.cmp ?c ?x ?y] => destruct (Float.cmp c x y)
    end;
  cbn [negb orb andb];
  rewrite ?Int.eq_true, ?(Int.eq_false _ _ Int.one_not_zero);
  repeat match goal with
    | |- context [Int.eq ?x ?y] => destruct (Int.eq x y)
    end;
  cbn [negb orb andb];
  intros;
  first [ reflexivity
        | discriminate
        | exfalso; apply Int.one_not_zero; assumption
        | exfalso; apply Int.one_not_zero; symmetry; assumption
        | match goal with H : _ <> _ |- _ => solve [contradiction H; reflexivity] end ].

Ltac init_post :=
  match goal with |- semax _ _ _ ?P => unfold P end; unfold abbreviate, c_init;
  repeat match goal with H : Float.cmp _ _ (Float.of_bits (Int64.repr 0)) = _ |- _ =>
    change (Float.of_bits (Int64.repr 0)) with c_zero in H end;
  cbv zeta;
  repeat match goal with
    | H : orb _ _ = _ |- _ => rewrite H
    end;
  repeat match goal with
    | H : Float.cmp _ _ _ = _ |- _ => rewrite H
    end;
  cbv iota beta;
  cbn [fst snd negb orb andb init_repr].

Lemma b2z_repr_eq (p q : bool) : Int.repr (Z.b2z p) = Int.repr (Z.b2z q) -> p = q.
Proof.
  destruct p, q; simpl; intro H; try reflexivity; exfalso;
    [exact (Int.one_not_zero H) | exact (Int.one_not_zero (eq_sym H))].
Qed.

Lemma c_keep_same (a b fa fb x tol fx : float) :
  Float.cmp Cgt fx c_zero = Float.cmp Cgt fa c_zero ->
  c_keep (FB.mkstate a b fa fb x tol) fx = FB.mkstate x b fx fb x tol.
Proof.
  intro H. unfold c_keep. cbn [FB.sfa FB.sx FB.sb FB.sfb FB.stol].
  rewrite H, Bool.eqb_reflx. reflexivity.
Qed.

Lemma c_keep_diff (a b fa fb x tol fx : float) :
  Float.cmp Cgt fx c_zero <> Float.cmp Cgt fa c_zero ->
  c_keep (FB.mkstate a b fa fb x tol) fx = FB.mkstate a x fa fx x tol.
Proof.
  intro H. unfold c_keep. cbn [FB.sfa FB.sx FB.sa FB.sfb FB.stol].
  destruct (Bool.eqb _ _) eqn:E; [| reflexivity].
  apply Bool.eqb_prop in E. contradiction.
Qed.

Ltac step_post :=
  match goal with |- semax _ _ _ ?P => unfold P end; unfold abbreviate, c_step, c_zero;
  cbv zeta beta;
  cbn [fst snd cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol];
  repeat match goal with H : FB.mkstate _ _ _ _ _ _ = c_keep _ _ |- _ => rewrite <- H end;
  cbn [fst snd cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol];
  repeat match goal with
    | H : Float.cmp _ _ _ = _ |- _ => rewrite H
    | H : c_fin _ = _ |- _ => rewrite H
    | H : orb _ _ = _ |- _ => rewrite H
    | H : Int.ltu _ _ = _ |- _ => rewrite H
    end;
  cbv iota beta; cbn [fst snd negb orb].

#[local] Opaque c_keep c_mid c_abs.

Lemma body_diana_bisection_init : semax_body Vprog Gprog4 f_diana_bisection_init init_spec.
Proof.
  start_function.
  assert_PROP (isptr s) as Hs by entailer!.
  forward_if.
  { subst s. contradiction. }
  forward_call a.
  forward_if (temp _t'2 (Vint (if (negb (c_fin a) || negb (c_fin b))%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_call b. forward. entailer!. bool_solve. }
  forward_if (temp _t'4 (Vint (if (negb (c_fin a) || negb (c_fin b) || negb (c_fin fa))%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_call fa. forward. entailer!. bool_solve. }
  forward_if (temp _t'6 (Vint (if (negb (c_fin a) || negb (c_fin b) || negb (c_fin fa) ||
                                   negb (c_fin fb))%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_call fb. forward. entailer!. bool_solve. }
  forward_if (temp _t'8 (Vint (if (negb (c_fin a) || negb (c_fin b) || negb (c_fin fa) ||
                                   negb (c_fin fb) || negb (c_fin tol))%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_call tol. forward. entailer!. bool_solve. }
  destruct (negb (c_fin a) || negb (c_fin b) || negb (c_fin fa) || negb (c_fin fb) ||
            negb (c_fin tol))%bool eqn:Hfin.
  { forward_if.
    - init_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  assert (Hf : Binary.is_finite 53 1024 a = true /\ Binary.is_finite 53 1024 b = true /\
               Binary.is_finite 53 1024 fa = true /\ Binary.is_finite 53 1024 fb = true /\
               Binary.is_finite 53 1024 tol = true).
  { unfold c_fin in Hfin. rewrite !Bool.orb_false_iff, !Bool.negb_false_iff in Hfin. tauto. }
  destruct Hf as [Ha [Hb [Hfa [Hfb Htol]]]].
  forward_if (temp _t'10 (Vint (if (Float.cmp Cgt a b || Float.cmp Clt tol c_zero)%bool
                                then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward. entailer!. bool_solve. }
  forward_if (temp _t'11 (Vint (if (Float.cmp Cgt a b || Float.cmp Clt tol c_zero ||
                                    Int.eq m Int.zero)%bool
                                then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward. entailer!. bool_solve. }
  destruct (Float.cmp Cgt a b || Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool
    eqn:Hrange.
  { forward_if.
    - init_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  forward_call a.
  forward_if (temp _t'13 (Vint (if (Float.cmp Cgt (c_abs a) c_max ||
                                    Float.cmp Cgt (c_abs b) c_max)%bool
                                then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_call b. forward. entailer!. bool_solve. }
  destruct (Float.cmp Cgt (c_abs a) c_max || Float.cmp Cgt (c_abs b) c_max)%bool eqn:Habs.
  { forward_if.
    - init_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  forward_if (temp _t'15 (Vint (if (Float.cmp Cgt fa c_zero && Float.cmp Cgt fb c_zero)%bool
                                then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward. entailer!. bool_solve. }
  forward_if (temp _t'16 (Vint (if (Float.cmp Cgt fa c_zero && Float.cmp Cgt fb c_zero ||
                                    Float.cmp Clt fa c_zero && Float.cmp Clt fb c_zero)%bool
                                then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_if.
    - forward. forward. entailer!. bool_solve.
    - forward. entailer!. bool_solve. }
  destruct (Float.cmp Cgt fa c_zero && Float.cmp Cgt fb c_zero ||
            Float.cmp Clt fa c_zero && Float.cmp Clt fb c_zero)%bool eqn:Hsign.
  { forward_if.
    - init_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  sep_apply (data_at_data_at_ sh t_state old s).
  forward. forward. forward. forward. forward. forward. forward.
  forward_call (a, b).
  forward.
  forward_if.
  { forward. forward. forward. init_post. forward. }
  forward_if.
  { forward. forward. forward. init_post. forward. }
  forward_if (temp _t'18 (Vint (if (Float.cmp Cle (Float.sub b a) tol ||
                                    Float.cmp Cle (c_mid a b) a)%bool
                                then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward. forward. entailer!. bool_solve. }
  forward_if (temp _t'19 (Vint (if (Float.cmp Cle (Float.sub b a) tol ||
                                    Float.cmp Cle (c_mid a b) a ||
                                    Float.cmp Cge (c_mid a b) b)%bool
                                then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward. forward. entailer!. bool_solve. }
  destruct (Float.cmp Cle (Float.sub b a) tol || Float.cmp Cle (c_mid a b) a ||
            Float.cmp Cge (c_mid a b) b)%bool eqn:Hstop.
  { forward_if.
    - init_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  init_post. forward.
Qed.

Lemma body_diana_bisection_step : semax_body Vprog Gprog4 f_diana_bisection_step step_spec.
Proof.
  start_function.
  destruct c as [[a b fa fb x tol] it m].
  unfold cstate_repr. cbn [cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
  assert_PROP (isptr s) as Hs by entailer!.
  forward_if (temp _t'1 (Vint (if c_fin fx then Int.zero else Int.one))).
  { subst s. contradiction. }
  { forward_call fx. forward. entailer!. unfold c_fin.
    destruct (Binary.is_finite 53 1024 fx); reflexivity. }
  destruct (c_fin fx) eqn:Hfin.
  2: { forward_if.
       - step_post. forward.
       - apply Int.one_not_zero in H. contradiction. }
  forward_if.
  { contradiction. }
  forward. forward. forward.
  forward_if.
  { forward. forward. forward. forward. step_post. forward. }
  forward.
  forward_if (PROP () LOCAL (temp _x (Vfloat x); temp _s s; temp _fx (Vfloat fx))
    SEP (data_at sh t_state (cstate_repr
           (mkcstate (c_keep (FB.mkstate a b fa fb x tol) fx) (Int.add it Int.one) m)) s)).
  { forward. forward. rewrite c_keep_same by (apply b2z_repr_eq; assumption).
    entailer!. }
  { forward. forward.
    rewrite c_keep_diff by (intro E; apply H1; unfold c_zero in E; rewrite E; reflexivity).
    entailer!. }
  remember (c_keep (FB.mkstate a b fa fb x tol) fx) as s1 eqn:Hs1.
  destruct s1 as [a1 b1 fa1 fb1 x1 tol1].
  unfold cstate_repr. cbn [cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
  forward. forward. forward.
  forward_if.
  { step_post. forward. }
  forward. forward. forward_call (a1, b1). forward.
  forward. forward.
  forward_if (temp _t'4 (Vint (if (Float.cmp Cle (c_mid a1 b1) a1 ||
                                  Float.cmp Cge (c_mid a1 b1) b1)%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. rewrite H2. reflexivity. }
  { forward. forward. forward. entailer!. rewrite H2. simpl.
    destruct (Float.cmp Cge _ _); reflexivity. }
  destruct (Float.cmp Cle (c_mid a1 b1) a1 || Float.cmp Cge (c_mid a1 b1) b1)%bool eqn:Hst.
  { forward_if.
    - step_post. forward.
    - apply Int.one_not_zero in H2. contradiction. }
  forward_if.
  { contradiction. }
  forward. forward.
  forward_if.
  { step_post. forward. }
  step_post. forward.
Qed.
