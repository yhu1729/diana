From VST.floyd Require Import proofauto.
From Diana.Float Require Newton.
From Diana.VST Require Bisection.
From Stdlib Require Import RIneq Lra.

Module FN := Diana.Float.Newton.
Module VB := Diana.VST.Bisection.

Definition c_zero : float := Float.of_bits (Int64.repr 0).

Record cstate : Type := mkcstate { cx : float; cdx : float; ctol : float; citer : int; cmax : int }.

Definition c_fin (x : float) : bool := Binary.is_finite 53 1024 x.

Definition c_init (x0 tol : float) (m : int) : Z * option cstate :=
  if (negb (c_fin x0) || negb (c_fin tol))%bool then (-1, None)
  else if (Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool then (-1, None)
  else (1, Some (mkcstate x0 c_zero tol Int.zero m)).

Definition c_step (c : cstate) (fx dfx : float) : Z * cstate :=
  if (negb (c_fin fx) || negb (c_fin dfx))%bool then (-1, c) else
  let it := Int.add (citer c) Int.one in
  if Float.cmp Ceq fx c_zero then (0, mkcstate (cx c) c_zero (ctol c) it (cmax c)) else
  if Float.cmp Ceq dfx c_zero then (-4, c) else
  let dx := Float.div fx dfx in
  if negb (c_fin dx) then (-5, c) else
  let x := Float.sub (cx c) dx in
  if negb (c_fin x) then (-5, c) else
  let c' := mkcstate x dx (ctol c) it (cmax c) in
  if (Float.cmp Ceq x (cx c) || Float.cmp Cle (VB.c_abs dx) (ctol c))%bool then (0, c')
  else if negb (Int.ltu it (cmax c)) then (-3, c')
  else (1, c').

Theorem c_step_fstep (c : cstate) (fx dfx : float) :
  c_fin fx = true -> c_fin dfx = true -> Float.cmp Ceq fx c_zero = false ->
  Float.cmp Ceq dfx c_zero = false ->
  c_fin (Float.div fx dfx) = true -> c_fin (Float.sub (cx c) (Float.div fx dfx)) = true ->
  fst (c_step c fx dfx) <> (-1)%Z /\ fst (c_step c fx dfx) <> (-5)%Z /\
  cx (snd (c_step c fx dfx)) = FN.fstep Float.binop_nan Float.binop_nan (cx c) fx dfx /\
  cdx (snd (c_step c fx dfx)) = Diana.Float.Sum.fdiv Float.binop_nan fx dfx /\
  citer (snd (c_step c fx dfx)) = Int.add (citer c) Int.one /\
  cmax (snd (c_step c fx dfx)) = cmax c.
Proof.
  intros Hfx Hdfx Hz Hdz Hdx Hx. unfold c_step. rewrite Hfx, Hdfx, Hz, Hdz. cbn [negb orb].
  cbv zeta.
  rewrite Hdx, Hx. cbn [negb].
  destruct (Float.cmp Ceq _ _ || Float.cmp Cle _ _)%bool; [| destruct (negb (Int.ltu _ _))];
    cbn [fst snd cx cdx ctol citer cmax]; repeat split; try discriminate; reflexivity.
Qed.
