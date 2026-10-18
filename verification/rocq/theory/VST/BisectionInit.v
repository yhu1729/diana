From VST.floyd Require Import proofauto.
From Diana.Clight Require Import bisection_init_aarch64_macos.
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

Definition fp_abs_spec :=
  DECLARE _diana_fp_abs
  WITH x : float
  PRE [ tdouble ]
    PROP (Binary.is_finite 53 1024 x = true) PARAMS (Vfloat x) SEP ()
  POST [ tdouble ]
    PROP () RETURN (Vfloat (c_abs x)) SEP ().

Definition t_state := Tstruct _diana_bisection_state noattr.

Definition cstate_repr (c : cstate) (st : int) : reptype t_state :=
  (Vfloat (FB.sa (cfl c)), (Vfloat (FB.sb (cfl c)), (Vfloat (FB.sfa (cfl c)),
   (Vfloat (FB.sfb (cfl c)), (Vfloat (FB.sx (cfl c)), (Vfloat (FB.stol (cfl c)),
   (Vint (citer c), (Vint (cmax c), Vint st)))))))).

(* On success the status field holds the returned status. *)
Definition init_repr (old : reptype t_state) (o : option cstate) (z : Z) : reptype t_state :=
  match o with Some c => cstate_repr c (Int.repr z) | None => old end.

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
    SEP (data_at sh t_state
           (init_repr old (snd (c_init a b fa fb tol m)) (fst (c_init a b fa fb tol m))) s).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; fp_abs_spec; Diana.VST.BisectionMid.mid_spec;
                           init_spec]).

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

Lemma body_diana_fp_abs : semax_body Vprog Gprog f_diana_fp_abs fp_abs_spec.
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

#[local] Opaque c_keep c_mid c_abs.

Lemma body_diana_bisection_init : semax_body Vprog Gprog f_diana_bisection_init init_spec.
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
  { forward. forward. forward. forward. init_post. forward. }
  forward_if.
  { forward. forward. forward. forward. init_post. forward. }
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
    - forward. init_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  forward. init_post. forward.
Qed.
