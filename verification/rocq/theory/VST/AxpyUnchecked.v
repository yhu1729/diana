From VST.floyd Require Import proofauto.
From Diana.Clight Require Import axpy_unchecked_aarch64_macos.
From Diana.VST Require Euler.
From Diana.VST Require Import Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

(* The written values are c_euler a ys xs of VST/Euler.v, which is the checked kernel's model
   c_axpy a xs ys (c_axpy_euler in VST/Axpy.v). *)
Definition axpy_unchecked_spec :=
  DECLARE _diana_axpy_unchecked
  WITH shx : share, shy : share, x : val, y : val, a : float,
       xs : list float, ys : list float
  PRE [ tdouble, tptr tdouble, tulong, tptr tdouble ]
    PROP (readable_share shx; writable_share shy;
          1 <= Zlength xs <= Int64.max_unsigned; Zlength ys = Zlength xs)
    PARAMS (Vfloat a; x; Vlong (Int64.repr (Zlength xs)); y)
    SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
         data_at shy (tarray tdouble (Zlength xs)) (map Vfloat ys) y)
  POST [ tint ]
    PROP ()
    RETURN (Vint (Int.repr 0))
    SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
         data_at shy (tarray tdouble (Zlength xs))
           (map Vfloat (Diana.VST.Euler.c_euler a ys xs)) y).

Definition Gprog : funspecs :=
  ltac:(with_library prog [axpy_unchecked_spec]).

Lemma body_diana_axpy_unchecked :
  semax_body Vprog Gprog f_diana_axpy_unchecked axpy_unchecked_spec.
Proof.
  start_function.
  assert_PROP (isptr x /\ isptr y) as Hptr by entailer!.
  destruct Hptr as [Hx Hy].
  join_zero _t'1.
  { subst x. contradiction. }
  { forward. entailer!. destruct y; try contradiction. reflexivity. }
  forward_if.
  { contradiction. }
  set (L := Diana.VST.Euler.c_euler a ys xs).
  assert (HL : Zlength L = Zlength xs)
    by (unfold L; rewrite Diana.VST.Euler.Zlength_c_euler by lia; lia).
  assert (HZ : forall i, 0 <= i < Zlength xs ->
                 Znth i L = Diana.VST.Euler.c_step a (Znth i ys) (Znth i xs))
    by (intros; apply Diana.VST.Euler.Znth_c_euler; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength xs)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _a (Vfloat a); temp _x x;
              temp _n (Vlong (Int64.repr (Zlength xs))); temp _y y)
       SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shy (tarray tdouble (Zlength xs))
              (map Vfloat (sublist 0 i L ++ sublist i (Zlength xs) ys)) y))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength xs)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _a (Vfloat a); temp _x x;
              temp _n (Vlong (Int64.repr (Zlength xs))); temp _y y)
       SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shy (tarray tdouble (Zlength xs))
              (map Vfloat (sublist 0 (i + 1) L ++ sublist (i + 1) (Zlength xs) ys)) y))
    break:
    (PROP ()
       LOCAL ()
       SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shy (tarray tdouble (Zlength xs)) (map Vfloat L) y)).
  { forward. Exists 0. entailer!. rewrite sublist_nil, app_nil_l, sublist_same by lia. cancel. }
  { entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?v))] => rename v into i end.
    assert (Hyi : Znth i (sublist 0 i L ++ sublist i (Zlength xs) ys) = Znth i ys).
    { rewrite app_Znth2 by (rewrite Zlength_sublist; lia).
      rewrite Zlength_sublist by lia. rewrite Znth_sublist by lia. f_equal. lia. }
    forward. forward. forward. Exists i. entailer!.
    rewrite !Znth_map by (try (rewrite Zlength_app, !Zlength_sublist); lia).
    rewrite Hyi.
    match goal with |- context [upd_Znth i _ ?v] =>
      replace v with (Vfloat (Diana.VST.Euler.c_step a (Znth i ys) (Znth i xs)))
        by reflexivity end.
    rewrite upd_Znth_map.
    apply derives_refl'. do 2 f_equal.
    rewrite (sublist_split 0 i (i + 1) L) by lia. rewrite (sublist_len_1 i L) by lia.
    rewrite HZ by lia.
    rewrite upd_Znth_app2 by (rewrite !Zlength_sublist; lia).
    rewrite Zlength_sublist by lia. replace (i - (i - 0)) with 0 by lia.
    rewrite (sublist_split i (i + 1) (Zlength xs) ys) by lia.
    rewrite (sublist_len_1 i ys) by lia.
    rewrite <- app_assoc. cbn [app]. rewrite upd_Znth0. reflexivity. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?v))] => rename v into i end.
    forward. Exists (i + 1). entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?v))] => rename v into i end.
    assert (i = Zlength xs) by lia. subst i. entailer!.
    rewrite sublist_same, sublist_nil, app_nil_r by lia. cancel. }
  forward.
Qed.
