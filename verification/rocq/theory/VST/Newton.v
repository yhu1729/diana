From VST.floyd Require Import proofauto.
From Diana.Clight Require Import newton_aarch64_macos.
From Diana.Float Require Newton.
From Diana.VST Require Bisection.
From Stdlib Require Import RIneq Lra.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Module FN := Diana.Float.Newton.
Module VB := Diana.VST.Bisection.

Definition c_zero : float := Float.of_bits (Int64.repr 0).

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

Record cstate : Type := mkcstate { cx : float; cdx : float; ctol : float; citer : int; cmax : int }.

Definition cstate_repr (c : cstate) : reptype t_state :=
  (Vfloat (cx c), (Vfloat (cdx c), (Vfloat (ctol c), (Vint (citer c), Vint (cmax c))))).

Definition result_spec :=
  DECLARE _diana_newton_result
  WITH sh : share, s : val, root : val, dx : val, c : cstate, shr : share, shw : share
  PRE [ tptr t_state, tptr tdouble, tptr tdouble ]
    PROP (readable_share sh; writable_share shr; writable_share shw;
          s <> nullval; root <> nullval; dx <> nullval)
    PARAMS (s; root; dx)
    SEP (data_at sh t_state (cstate_repr c) s;
         data_at_ shr tdouble root; data_at_ shw tdouble dx)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr 0))
    SEP (data_at sh t_state (cstate_repr c) s;
         data_at shr tdouble (Vfloat (cx c)) root;
         data_at shw tdouble (Vfloat (cdx c)) dx).

Definition c_fin (x : float) : bool := Binary.is_finite 53 1024 x.

Definition c_init (x0 tol : float) (m : int) : Z * option cstate :=
  if (negb (c_fin x0) || negb (c_fin tol))%bool then (-1, None)
  else if (Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool then (-1, None)
  else (1, Some (mkcstate x0 c_zero tol Int.zero m)).

Definition c_step (c : cstate) (fx dfx : float) : Z * cstate :=
  if (negb (c_fin fx) || negb (c_fin dfx))%bool then (-1, c) else
  let it := Int.add (citer c) Int.one in
  if Float.cmp Ceq fx c_zero then (0, mkcstate (cx c) c_zero (ctol c) it (cmax c)) else
  let dx := Float.div fx dfx in
  if negb (c_fin dx) then (-1, c) else
  let x := Float.sub (cx c) dx in
  if negb (c_fin x) then (-1, c) else
  let c' := mkcstate x dx (ctol c) it (cmax c) in
  if (Float.cmp Ceq x (cx c) || Float.cmp Cle (VB.c_abs dx) (ctol c))%bool then (0, c')
  else if negb (Int.ltu it (cmax c)) then (-3, c')
  else (1, c').

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
  ltac:(with_library prog [fp_finite_spec; fp_abs_spec; result_spec; init_spec; step_spec]).

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

Lemma body_diana_newton_result :
  semax_body Vprog Gprog f_diana_newton_result result_spec.
Proof.
  start_function.
  forward_if.
  - subst s. contradiction.
  - forward_if (PROP ()
      LOCAL (temp _s s; temp _root root; temp _dx dx)
      SEP (data_at sh t_state (cstate_repr c) s;
           data_at shr tdouble (Vfloat (cx c)) root;
           data_at_ shw tdouble dx)).
    + forward. forward. entailer!.
    + contradiction.
    + forward_if (PROP ()
        LOCAL (temp _s s; temp _root root; temp _dx dx)
        SEP (data_at sh t_state (cstate_repr c) s;
             data_at shr tdouble (Vfloat (cx c)) root;
             data_at shw tdouble (Vfloat (cdx c)) dx)).
      * forward. forward. entailer!.
      * contradiction.
      * forward.
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

Theorem c_step_fstep (c : cstate) (fx dfx : float) :
  c_fin fx = true -> c_fin dfx = true -> Float.cmp Ceq fx c_zero = false ->
  c_fin (Float.div fx dfx) = true -> c_fin (Float.sub (cx c) (Float.div fx dfx)) = true ->
  fst (c_step c fx dfx) <> (-1)%Z /\
  cx (snd (c_step c fx dfx)) = FN.fstep Float.binop_nan Float.binop_nan (cx c) fx dfx /\
  cdx (snd (c_step c fx dfx)) = Diana.Float.Sum.fdiv Float.binop_nan fx dfx /\
  citer (snd (c_step c fx dfx)) = Int.add (citer c) Int.one /\
  cmax (snd (c_step c fx dfx)) = cmax c.
Proof.
  intros Hfx Hdfx Hz Hdx Hx. unfold c_step. rewrite Hfx, Hdfx, Hz. cbn [negb orb]. cbv zeta.
  rewrite Hdx, Hx. cbn [negb].
  destruct (Float.cmp Ceq _ _ || Float.cmp Cle _ _)%bool; [| destruct (negb (Int.ltu _ _))];
    cbn [fst snd cx cdx ctol citer cmax]; repeat split; try discriminate; reflexivity.
Qed.
