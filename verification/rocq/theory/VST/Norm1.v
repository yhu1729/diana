From VST.floyd Require Import proofauto.
From Diana.Clight Require Import norm_1_aarch64_macos.
From Diana.VST Require Bisection.
From Diana.VST Require Euler.
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

Definition norm1_spec :=
  DECLARE _diana_norm_1
  WITH sh : share, shr : share, x : val, res : val, xs : list float, r0 : val
  PRE [ tptr tdouble, tulong, tptr tdouble ]
    PROP (readable_share sh; writable_share shr; 1 <= Zlength xs <= Int64.max_unsigned)
    PARAMS (x; Vlong (Int64.repr (Zlength xs)); res)
    SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
         data_at shr tdouble r0 res)
  POST [ tint ]
    PROP ()
    RETURN (Vint (Int.repr (norm1_status xs)))
    SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
         data_at shr tdouble
           (if Z.eqb (norm1_status xs) 0 then Vfloat (c_norm1 xs) else r0) res).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; fp_abs_spec; norm1_spec]).

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

Lemma body_diana_norm_1 : semax_body Vprog Gprog f_diana_norm_1 norm1_spec.
Proof.
  start_function.
  assert_PROP (isptr x /\ isptr res) as Hptr by entailer!.
  destruct Hptr as [Hx Hres].
  join_zero _t'1.
  { subst x. contradiction. }
  { forward. entailer!. destruct res; try contradiction. reflexivity. }
  forward_if.
  { contradiction. }
  forward.
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength xs;
                        forallb (Binary.is_finite 53 1024) (sublist 0 i xs) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _s (Vfloat (c_norm1 (sublist 0 i xs)));
              temp _x x; temp _n (Vlong (Int64.repr (Zlength xs))); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shr tdouble r0 res))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength xs;
                        forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) xs) = true)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _s (Vfloat (c_norm1 (sublist 0 (i + 1) xs)));
              temp _x x; temp _n (Vlong (Int64.repr (Zlength xs))); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shr tdouble r0 res))
    break:
    (PROP (forallb (Binary.is_finite 53 1024) xs = true)
       LOCAL (temp _s (Vfloat (c_norm1 xs)); temp _result res)
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
         unfold norm1_status. rewrite Hall. entailer!. }
    forward_if; [discriminate |].
    forward. forward_call (Znth i xs). forward.
    Exists i. entailer!. split.
    - rewrite Diana.VST.Euler.forallb_sublist_succ by lia.
      match goal with H : forallb _ (sublist 0 i xs) = true |- _ => rewrite H end.
      rewrite Hxi. reflexivity.
    - rewrite c_norm1_succ by lia. reflexivity. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?a))] => rename a into i end.
    forward. Exists (i + 1). entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?a))] => rename a into i end.
    repeat rewrite Int64.unsigned_repr in H1 by rep_lia.
    assert (i = Zlength xs) by lia. subst i.
    rewrite sublist_same in * by lia. entailer!. }
  forward_call (c_norm1 xs).
  match goal with H : forallb _ xs = true |- _ => rename H into Hall end.
  destruct (Binary.is_finite 53 1024 (c_norm1 xs)) eqn:Hs.
  2: { forward_if; [| contradiction]. forward.
       unfold norm1_status. rewrite Hall, Hs. entailer!. }
  forward_if; [discriminate |].
  forward. forward.
  unfold norm1_status. rewrite Hall, Hs. entailer!.
Qed.
