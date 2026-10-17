From VST.floyd Require Import proofauto.
From Diana.Clight Require Import newton_init_aarch64_macos.
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

Definition t_state := Tstruct _diana_newton_state noattr.

Definition cstate_repr (c : cstate) : reptype t_state :=
  (Vfloat (cx c), (Vfloat (cdx c), (Vfloat (ctol c), (Vint (citer c), Vint (cmax c))))).

Definition init_repr (old : reptype t_state) (o : option cstate) : reptype t_state :=
  match o with Some c => cstate_repr c | None => old end.

Definition init_spec :=
  DECLARE _diana_newton_init
  WITH sh : share, s : val, old : reptype t_state, x0 : float, tol : float, m : int
  PRE [ tptr t_state, tdouble, tdouble, tuint ]
    PROP (writable_share sh)
    PARAMS (s; Vfloat x0; Vfloat tol; Vint m)
    SEP (data_at sh t_state old s)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr (fst (c_init x0 tol m))))
    SEP (data_at sh t_state (init_repr old (snd (c_init x0 tol m))) s).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; init_spec]).

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

Lemma body_diana_newton_init : semax_body Vprog Gprog f_diana_newton_init init_spec.
Proof.
  start_function.
  assert_PROP (isptr s) as Hs by entailer!.
  forward_if.
  { subst s. contradiction. }
  forward_call x0.
  forward_if (temp _t'2 (Vint (if (negb (c_fin x0) || negb (c_fin tol))%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward_call tol. forward. entailer!. bool_solve. }
  destruct (negb (c_fin x0) || negb (c_fin tol))%bool eqn:Hfin.
  { forward_if.
    - init_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  forward_if (temp _t'4 (Vint (if (Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool
                               then Int.one else Int.zero))).
  { forward. entailer!. bool_solve. }
  { forward. entailer!. bool_solve. }
  destruct (Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool eqn:Hrange.
  { forward_if.
    - init_post. forward.
    - exfalso; apply Int.one_not_zero; assumption. }
  forward_if.
  { contradiction. }
  sep_apply (data_at_data_at_ sh t_state old s).
  forward. forward. forward. forward. forward.
  init_post. forward.
Qed.
