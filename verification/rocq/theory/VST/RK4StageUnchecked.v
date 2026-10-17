From VST.floyd Require Import proofauto.
From Diana.Clight Require Import rk4_stage_unchecked_aarch64_macos.
From Diana.VST Require Euler RK4.
From Diana.VST Require Import Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition stage_spec :=
  DECLARE _diana_rk4_stage_unchecked
  WITH shy : share, shk : share, sho : share, y : val, k : val, out : val,
       ys : list float, ks : list float, h : float, s : Z, os : list val
  PRE [ tptr tdouble, tptr tdouble, tulong, tdouble, tint, tptr tdouble ]
    PROP (readable_share shy; readable_share shk; writable_share sho;
          1 <= Zlength ys <= Int64.max_unsigned; Zlength ks = Zlength ys;
          Zlength os = Zlength ys; 2 <= s <= 4)
    PARAMS (y; k; Vlong (Int64.repr (Zlength ys)); Vfloat h; Vint (Int.repr s); out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) os out)
  POST [ tint ]
    PROP ()
    RETURN (Vint (Int.repr 0))
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) (map Vfloat (Diana.VST.RK4.c_stage s h ys ks)) out).

Definition Gprog : funspecs :=
  ltac:(with_library prog [stage_spec]).

Lemma body_diana_rk4_stage_unchecked :
  semax_body Vprog Gprog f_diana_rk4_stage_unchecked stage_spec.
Proof.
  start_function.
  assert_PROP (isptr y /\ isptr k /\ isptr out) as Hptr by entailer!.
  destruct Hptr as [Hy [Hk Hout]].
  join_zero _t'1.
  { subst y. contradiction. }
  { forward. entailer!. destruct k; try contradiction. reflexivity. }
  join_zero _t'2.
  { contradiction. }
  { forward. entailer!. destruct out; try contradiction. reflexivity. }
  join_zero _t'3.
  { contradiction. }
  { forward. entailer!. destruct (zeq (Zlength ys) 0); [lia | reflexivity]. }
  join_zero _t'4.
  { contradiction. }
  { forward. entailer!. destruct (zlt s 2); [lia | reflexivity]. }
  join_zero _t'5.
  { contradiction. }
  { forward. entailer!. destruct (zlt 4 s); [lia | reflexivity]. }
  forward_if; try contradiction.
  set (c := Diana.VST.RK4.c_coef s h).
  forward_if (PROP () LOCAL (temp _c (Vfloat c); temp _y y; temp _k k;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { forward. entailer!. }
  { forward. entailer!. subst c. unfold Diana.VST.RK4.c_coef.
    destruct (Z.eqb_spec s 4) as [-> | _]; [contradiction | reflexivity]. }
  set (L := Diana.VST.RK4.c_stage s h ys ks).
  assert (HL : Zlength L = Zlength ys)
    by (apply Diana.VST.Euler.Zlength_c_euler; lia).
  assert (HZ : forall i, 0 <= i < Zlength ys ->
            Znth i L = Diana.VST.Euler.c_step c (Znth i ys) (Znth i ks))
    by (intros; apply Diana.VST.Euler.Znth_c_euler; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength ys)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _c (Vfloat c); temp _y y; temp _k k;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
            data_at sho (tarray tdouble (Zlength ys))
              (map Vfloat (sublist 0 i L) ++ sublist i (Zlength ys) os) out))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength ys)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _c (Vfloat c); temp _y y; temp _k k;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
            data_at sho (tarray tdouble (Zlength ys))
              (map Vfloat (sublist 0 (i + 1) L) ++ sublist (i + 1) (Zlength ys) os) out))
    break:
    (PROP ()
       LOCAL ()
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
            data_at sho (tarray tdouble (Zlength ys)) (map Vfloat L) out)).
  { forward. Exists 0. entailer!. rewrite app_nil_l, sublist_same by lia. cancel. }
  { entailer!. }
  { forward. forward. forward. Exists a. entailer!.
    match goal with |- context [upd_Znth a _ ?v] =>
      replace v with (Vfloat (Diana.VST.Euler.c_step c (Znth a ys) (Znth a ks)))
        by reflexivity end.
    apply derives_refl'. f_equal.
    rewrite (sublist_split 0 a (a + 1) L) by lia. rewrite (sublist_len_1 a L) by lia.
    rewrite HZ by lia. list_solve. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. entailer!.
    rewrite sublist_same, sublist_nil, app_nil_r by lia. cancel. }
  forward.
Qed.
