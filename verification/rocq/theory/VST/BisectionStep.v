From VST.floyd Require Import proofauto.
From Diana.Clight Require Import bisection_step_aarch64_macos.
From Diana.VST Require Import Bisection.
From Diana.VST Require BisectionMid.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition t_state := Tstruct _diana_bisection_state noattr.

Definition cstate_repr (c : cstate) (st : int) : reptype t_state :=
  (Vfloat (FB.sa (cfl c)), (Vfloat (FB.sb (cfl c)), (Vfloat (FB.sfa (cfl c)),
   (Vfloat (FB.sfb (cfl c)), (Vfloat (FB.sx (cfl c)), (Vfloat (FB.stol (cfl c)),
   (Vint (citer c), (Vint (cmax c), Vint st)))))))).

(* A state whose status is not DIANA_CONTINUE (1) is rejected unchanged; otherwise the step is
   c_step and the status becomes its result, except that -1 leaves it at 1. *)
Definition step_result (st : int) (c : cstate) (fx : float) : Z :=
  if Int.eq st Int.one then fst (c_step c fx) else -1.

Definition step_repr (st : int) (c : cstate) (fx : float) : reptype t_state :=
  if Int.eq st Int.one then
    cstate_repr (snd (c_step c fx))
      (if Z.eqb (fst (c_step c fx)) (-1) then st else Int.repr (fst (c_step c fx)))
  else cstate_repr c st.

Definition step_spec :=
  DECLARE _diana_bisection_step
  WITH sh : share, s : val, c : cstate, st : int, fx : float
  PRE [ tptr t_state, tdouble ]
    PROP (writable_share sh)
    PARAMS (s; Vfloat fx)
    SEP (data_at sh t_state (cstate_repr c st) s)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr (step_result st c fx)))
    SEP (data_at sh t_state (step_repr st c fx) s).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; Diana.VST.BisectionMid.mid_spec; step_spec]).

Lemma body_diana_fp_finite : semax_body Vprog Gprog f_diana_fp_finite fp_finite_spec.
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
  match goal with |- semax _ _ _ ?P => unfold P end;
  unfold abbreviate, step_result, step_repr, c_step, c_zero; rewrite Int.eq_true;
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
  cbv iota beta; cbn [fst snd negb orb Z.eqb Pos.eqb].

#[local] Opaque c_keep c_mid c_abs.

Lemma body_diana_bisection_step : semax_body Vprog Gprog f_diana_bisection_step step_spec.
Proof.
  start_function.
  destruct c as [[a b fa fb x tol] it m].
  unfold cstate_repr. cbn [cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
  assert_PROP (isptr s) as Hs by entailer!.
  forward_if (temp _t'1 (Vint (if Int.eq st Int.one then Int.zero else Int.one))).
  { subst s. contradiction. }
  { forward. forward. entailer!. change (Int.repr 1) with Int.one.
    destruct (Int.eq st Int.one); reflexivity. }
  destruct (Int.eq st Int.one) eqn:Est.
  2: { forward_if (temp _t'2 (Vint Int.one)).
       - forward. entailer!.
       - apply Int.one_not_zero in H. contradiction.
       - forward_if.
         + match goal with |- semax _ _ _ ?P => unfold P end.
           unfold abbreviate, step_result, step_repr. rewrite Est. cbv iota.
           forward.
         + apply Int.one_not_zero in H. contradiction. }
  apply Int.same_if_eq in Est. subst st.
  forward_if (temp _t'2 (Vint (if c_fin fx then Int.zero else Int.one))).
  { contradiction. }
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
  { forward. forward. forward. forward. forward. step_post. forward. }
  forward.
  forward_if (PROP () LOCAL (temp _x (Vfloat x); temp _s s; temp _fx (Vfloat fx))
    SEP (data_at sh t_state (cstate_repr
           (mkcstate (c_keep (FB.mkstate a b fa fb x tol) fx) (Int.add it Int.one) m)
           Int.one) s)).
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
  { forward. step_post. forward. }
  forward. forward. forward_call (a1, b1). forward.
  forward. forward.
  forward_if (temp _t'5 (Vint (if (Float.cmp Cle (c_mid a1 b1) a1 ||
                                  Float.cmp Cge (c_mid a1 b1) b1)%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. rewrite H2. reflexivity. }
  { forward. forward. forward. entailer!. rewrite H2. simpl.
    destruct (Float.cmp Cge _ _); reflexivity. }
  destruct (Float.cmp Cle (c_mid a1 b1) a1 || Float.cmp Cge (c_mid a1 b1) b1)%bool eqn:Hst.
  { forward_if.
    - forward. step_post. forward.
    - apply Int.one_not_zero in H2. contradiction. }
  forward_if.
  { contradiction. }
  forward. forward.
  forward_if.
  { forward. step_post. forward. }
  step_post. forward.
Qed.
