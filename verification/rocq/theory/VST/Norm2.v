From VST.floyd Require Import proofauto.
From Diana.Clight Require Import norm_2_aarch64_macos.
From Diana.VST Require Bisection.
From Diana.VST Require Euler.
From Diana.VST Require FpSqrt.
From Diana.VST Require Import Norm Tactic.

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

Definition norm2_spec :=
  DECLARE _diana_norm_2
  WITH sh : share, shr : share, x : val, res : val, xs : list float, r0 : val
  PRE [ tptr tdouble, tulong, tptr tdouble ]
    PROP (readable_share sh; writable_share shr; 1 <= Zlength xs <= Int64.max_unsigned)
    PARAMS (x; Vlong (Int64.repr (Zlength xs)); res)
    SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
         data_at shr tdouble r0 res)
  POST [ tint ]
    PROP ()
    RETURN (Vint (Int.repr (norm2_status xs)))
    SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
         data_at shr tdouble
           (if Z.eqb (norm2_status xs) 0 then Vfloat (c_norm2 xs) else r0) res).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; fp_abs_spec; Diana.VST.FpSqrt.sqrt_spec; norm2_spec]).

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

Lemma body_diana_norm_2 : semax_body Vprog Gprog f_diana_norm_2 norm2_spec.
Proof.
  start_function.
  assert_PROP (isptr x /\ isptr res) as Hptr by entailer!.
  destruct Hptr as [Hx Hres].
  join_zero _t'1.
  { subst x. contradiction. }
  { forward. entailer!. destruct res; try contradiction. reflexivity. }
  forward_if.
  { contradiction. }
  forward. forward.
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength xs;
                        forallb (Binary.is_finite 53 1024) (sublist 0 i xs) = true)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _m (Vfloat (snd (c_scale (sublist 0 i xs))));
              temp _k (Vlong (Int64.repr (Z.of_nat (snd (fst (c_scale (sublist 0 i xs)))))));
              temp _x x; temp _n (Vlong (Int64.repr (Zlength xs))); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shr tdouble r0 res))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength xs;
                        forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) xs) = true)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _m (Vfloat (snd (c_scale (sublist 0 (i + 1) xs))));
              temp _k (Vlong (Int64.repr
                                (Z.of_nat (snd (fst (c_scale (sublist 0 (i + 1) xs)))))));
              temp _x x; temp _n (Vlong (Int64.repr (Zlength xs))); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shr tdouble r0 res))
    break:
    (PROP (forallb (Binary.is_finite 53 1024) xs = true)
       LOCAL (temp _m (Vfloat (snd (c_scale xs)));
              temp _k (Vlong (Int64.repr (Z.of_nat (snd (fst (c_scale xs))))));
              temp _x x; temp _n (Vlong (Int64.repr (Zlength xs))); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shr tdouble r0 res)).
  { forward. Exists 0. entailer!. }
  { entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?a))] => rename a into i end.
    repeat rewrite Int64.unsigned_repr in H1 by rep_lia.
    forward. forward_call (Znth i xs).
    destruct (Binary.is_finite 53 1024 (Znth i xs)) eqn:Hxi.
    2: { forward_if; [| contradiction]. forward.
         assert (Hall : forallb (Binary.is_finite 53 1024) xs = false)
           by (apply (Diana.VST.Euler.forallb_false xs i); [lia | exact Hxi]).
         unfold norm2_status. rewrite Hall. entailer!. }
    forward_if; [discriminate |].
    forward. forward_call (Znth i xs). forward.
    assert (Hf : forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) xs) = true).
    { rewrite Diana.VST.Euler.forallb_sublist_succ by lia.
      match goal with H : forallb _ (sublist 0 i xs) = true |- _ => rewrite H end.
      rewrite Hxi. reflexivity. }
    forward_if.
    - forward. forward. Exists i.
      match goal with H : Float.cmp Cgt _ _ = true |- _ =>
        destruct (c_scale_take xs i ltac:(lia) H) as [Em Ek] end.
      rewrite Em, Ek, Z2Nat.id by lia. entailer!.
    - forward. Exists i.
      match goal with H : Float.cmp Cgt _ _ = false |- _ =>
        destruct (c_scale_keep xs i ltac:(lia) H) as [Em Ek] end.
      rewrite Em, Ek. entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?a))] => rename a into i end.
    forward. Exists (i + 1). entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?a))] => rename a into i end.
    repeat rewrite Int64.unsigned_repr in H1 by rep_lia.
    assert (i = Zlength xs) by lia. subst i.
    rewrite sublist_same in * by lia. entailer!. }
  match goal with H : forallb _ xs = true |- _ => rename H into Hall end.
  pose proof (c_scale_index_lt xs) as Hkr.
  set (kk := snd (fst (c_scale xs))) in *.
  set (m := snd (c_scale xs)) in *.
  assert (Hmodel : c_norm2 xs =
    if Float.cmp Ceq m c_zero then c_zero
    else Float.mul m (Float.sqrt (c_sumsq m (Diana.Real.Norm.remove kk xs)))).
  { unfold c_norm2, m, kk. destruct (c_scale xs) as [[cnt k] mm]. reflexivity. }
  forward_if.
  { forward. forward.
    unfold norm2_status. rewrite Hall, Hmodel.
    match goal with H : Float.cmp Ceq _ _ = true |- _ => unfold c_zero; rewrite H end.
    entailer!. }
  forward.
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength xs)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _s (Vfloat (c_sumsq m (Diana.Real.Norm.remove kk (sublist 0 i xs))));
              temp _m (Vfloat m); temp _k (Vlong (Int64.repr (Z.of_nat kk)));
              temp _x x; temp _n (Vlong (Int64.repr (Zlength xs))); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shr tdouble r0 res))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength xs)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _s (Vfloat (c_sumsq m (Diana.Real.Norm.remove kk (sublist 0 (i + 1) xs))));
              temp _m (Vfloat m); temp _k (Vlong (Int64.repr (Z.of_nat kk)));
              temp _x x; temp _n (Vlong (Int64.repr (Zlength xs))); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shr tdouble r0 res))
    break:
    (PROP ()
       LOCAL (temp _s (Vfloat (c_sumsq m (Diana.Real.Norm.remove kk xs)));
              temp _m (Vfloat m); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shr tdouble r0 res)).
  { forward. Exists 0. entailer!.
    rewrite sublist_nil. unfold Diana.Real.Norm.remove. rewrite List.firstn_nil. reflexivity. }
  { entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?a))] => rename a into i end.
    repeat rewrite Int64.unsigned_repr in H1 by rep_lia.
    forward_if.
    - forward. forward. forward. Exists i. entailer!.
      rewrite c_sumsq_succ by lia.
      destruct (Nat.eqb_spec kk (Z.to_nat i)) as [E | E]; [| reflexivity].
      exfalso. subst kk. rewrite E, Z2Nat.id in * by lia. contradiction.
    - forward. Exists i. entailer!.
      rewrite c_sumsq_succ by lia.
      destruct (Nat.eqb_spec kk (Z.to_nat i)) as [E | E]; [reflexivity |].
      exfalso. apply E.
      match goal with Hq : Int64.eq _ _ = true |- _ => apply Int64.same_if_eq in Hq;
        apply repr_inj_unsigned64 in Hq; [| rep_lia | rep_lia] end.
      lia. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?a))] => rename a into i end.
    forward. Exists (i + 1). entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?a))] => rename a into i end.
    repeat rewrite Int64.unsigned_repr in H1 by rep_lia.
    assert (i = Zlength xs) by lia. subst i.
    rewrite sublist_same in * by lia. entailer!. }
  forward_call (c_sumsq m (Diana.Real.Norm.remove kk xs)).
  forward.
  forward_call (Float.mul m (Float.sqrt (c_sumsq m (Diana.Real.Norm.remove kk xs)))).
  match goal with H : Float.cmp Ceq _ _ = false |- _ => rename H into Hm end.
  assert (Hc : c_norm2 xs = Float.mul m (Float.sqrt (c_sumsq m (Diana.Real.Norm.remove kk xs))))
    by (rewrite Hmodel; unfold c_zero; rewrite Hm; reflexivity).
  destruct (Binary.is_finite 53 1024
              (Float.mul m (Float.sqrt (c_sumsq m (Diana.Real.Norm.remove kk xs))))) eqn:Hr.
  2: { forward_if; [| contradiction]. forward.
       unfold norm2_status. rewrite Hall, Hc, Hr. entailer!. }
  forward_if; [discriminate |].
  forward. forward.
  unfold norm2_status. rewrite Hall, Hc, Hr. entailer!.
Qed.
