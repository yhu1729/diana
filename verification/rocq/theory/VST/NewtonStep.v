From VST.floyd Require Import proofauto.
From Diana.Clight Require Import newton_step_aarch64_macos.
From Diana.VST Require Import Newton.

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
    PROP () RETURN (Vfloat (VB.c_abs x)) SEP ().

Definition t_state := Tstruct _diana_newton_state noattr.

Definition cstate_repr (c : cstate) : reptype t_state :=
  (Vfloat (cx c), (Vfloat (cdx c), (Vfloat (ctol c), (Vint (citer c), Vint (cmax c))))).

Definition step_spec :=
  DECLARE _diana_newton_step
  WITH sh : share, s : val, c : cstate, fx : float, dfx : float
  PRE [ tptr t_state, tdouble, tdouble ]
    PROP (writable_share sh)
    PARAMS (s; Vfloat fx; Vfloat dfx)
    SEP (data_at sh t_state (cstate_repr c) s)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr (fst (c_step c fx dfx))))
    SEP (data_at sh t_state (cstate_repr (snd (c_step c fx dfx))) s).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; fp_abs_spec; step_spec]).

Lemma body_diana_fp_finite : semax_body Vprog Gprog f_diana_fp_finite fp_finite_spec.
Proof.
  start_function.
  forward_if (PROP () LOCAL (temp _t'1
      (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero))) SEP ()).
  - forward. entailer!.
    rewrite VB.cmp_sub_self_zero by
      (destruct (Binary.is_nan 53 1024 x) eqn:Hn; [| reflexivity];
       rewrite VB.cmp_eq_self, Hn in H; discriminate H).
    destruct (Binary.is_finite 53 1024 x); reflexivity.
  - forward. entailer!.
    rewrite VB.cmp_eq_self in H.
    destruct (Binary.is_nan 53 1024 x) eqn:Hn; [| discriminate H].
    destruct x; try discriminate Hn. reflexivity.
  - forward.
Qed.

Lemma body_diana_fp_abs : semax_body Vprog Gprog f_diana_fp_abs fp_abs_spec.
Proof.
  start_function.
  forward_if (PROP () LOCAL (temp _t'1 (Vfloat (VB.c_abs x))) SEP ()).
  - forward. entailer!. unfold VB.c_abs.
    destruct (Float.cmp Clt x (Float.of_bits (Int64.repr 0))) eqn:Hc;
      [reflexivity | congruence].
  - forward. entailer!. unfold VB.c_abs.
    destruct (Float.cmp Clt x (Float.of_bits (Int64.repr 0))) eqn:Hc;
      [congruence | reflexivity].
  - forward.
Qed.

Ltac bool_solve :=
  unfold c_fin, c_zero in *;
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

Ltac absurd_branch :=
  first [ contradiction
        | discriminate
        | exfalso; apply Int.one_not_zero; assumption
        | exfalso; apply Int.one_not_zero; symmetry; assumption
        | match goal with H : _ |- _ =>
            rewrite ?Int.eq_true, ?(Int.eq_false _ _ Int.one_not_zero) in H; discriminate H end ].

Ltac step_post :=
  match goal with |- semax _ _ _ ?P => unfold P end; unfold abbreviate, c_step, c_zero;
  cbv zeta beta;
  cbn [fst snd cx cdx ctol citer cmax];
  repeat match goal with
    | H : Float.cmp _ _ _ = _ |- _ => rewrite H
    | H : c_fin _ = _ |- _ => rewrite H
    | H : orb _ _ = _ |- _ => rewrite H
    | H : Int.ltu _ _ = _ |- _ => try change (Int.repr 1) with Int.one in H; rewrite H
    end;
  cbv iota beta; cbn [fst snd negb orb cx cdx ctol citer cmax];
  try change (Int.repr 1) with Int.one.

#[local] Opaque VB.c_abs.

Lemma body_diana_newton_step : semax_body Vprog Gprog f_diana_newton_step step_spec.
Proof.
  start_function.
  destruct c as [x0 dx0 tol it m].
  unfold cstate_repr. cbn [cx cdx ctol citer cmax].
  assert_PROP (isptr s) as Hs by entailer!.
  forward_if (temp _t'1 (Vint (if c_fin fx then Int.zero else Int.one))).
  { subst s. contradiction. }
  { forward_call fx. forward. entailer!. unfold c_fin.
    destruct (Binary.is_finite 53 1024 fx); reflexivity. }
  forward_if (temp _t'3 (Vint (if (negb (c_fin fx) || negb (c_fin dfx))%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_call dfx. forward. entailer!. bool_solve. }
  destruct (negb (c_fin fx) || negb (c_fin dfx))%bool eqn:Hfin.
  { forward_if.
    - step_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  assert (Hf : Binary.is_finite 53 1024 fx = true /\ Binary.is_finite 53 1024 dfx = true).
  { unfold c_fin in Hfin. rewrite !Bool.orb_false_iff, !Bool.negb_false_iff in Hfin. tauto. }
  destruct Hf as [Hfx Hdfx].
  forward_if.
  { forward. forward. forward. step_post. forward. }
  forward_if.
  { step_post. forward. }
  forward.
  forward_call (Float.div fx dfx).
  change (Binary.is_finite 53 1024 (Float.div fx dfx)) with (c_fin (Float.div fx dfx)).
  destruct (c_fin (Float.div fx dfx)) eqn:Hdx.
  2: { forward_if.
       - step_post. forward.
       - absurd_branch. }
  forward_if.
  { absurd_branch. }
  forward. forward.
  assert (Hdx' : Binary.is_finite 53 1024 (Float.div fx dfx) = true) by exact Hdx.
  forward_call (Float.sub x0 (Float.div fx dfx)).
  change (Binary.is_finite 53 1024 (Float.sub x0 (Float.div fx dfx)))
    with (c_fin (Float.sub x0 (Float.div fx dfx))).
  destruct (c_fin (Float.sub x0 (Float.div fx dfx))) eqn:Hx.
  2: { forward_if.
       - step_post. forward.
       - absurd_branch. }
  forward_if.
  { absurd_branch. }
  forward.
  forward_if (temp _t'7 (Vint (if (Float.cmp Ceq (Float.sub x0 (Float.div fx dfx)) x0 ||
                                   Float.cmp Cle (VB.c_abs (Float.div fx dfx)) tol)%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_call (Float.div fx dfx).
    forward. forward. entailer!. bool_solve. }
  forward. forward. forward. forward. forward.
  destruct (Float.cmp Ceq (Float.sub x0 (Float.div fx dfx)) x0 ||
            Float.cmp Cle (VB.c_abs (Float.div fx dfx)) tol)%bool eqn:Hconv.
  { forward_if.
    - step_post. forward.
    - absurd_branch. }
  forward_if.
  { absurd_branch. }
  forward. forward.
  forward_if.
  { step_post. forward. }
  step_post. forward.
Qed.
