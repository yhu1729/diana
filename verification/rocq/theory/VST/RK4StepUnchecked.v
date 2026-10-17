From VST.floyd Require Import proofauto.
From Diana.Clight Require Import rk4_step_unchecked_aarch64_macos.
From Diana.VST Require RK4.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition step_spec :=
  DECLARE _diana_rk4_step_unchecked
  WITH shy : share, sh1 : share, sh2 : share, sh3 : share, sh4 : share, sho : share,
       y : val, k1 : val, k2 : val, k3 : val, k4 : val, out : val,
       ys : list float, k1s : list float, k2s : list float, k3s : list float,
       k4s : list float, h : float, os : list val
  PRE [ tptr tdouble, tptr tdouble, tptr tdouble, tptr tdouble, tptr tdouble, tulong, tdouble,
        tptr tdouble ]
    PROP (readable_share shy; readable_share sh1; readable_share sh2; readable_share sh3;
          readable_share sh4; writable_share sho;
          1 <= Zlength ys <= Int64.max_unsigned; Zlength k1s = Zlength ys;
          Zlength k2s = Zlength ys; Zlength k3s = Zlength ys; Zlength k4s = Zlength ys;
          Zlength os = Zlength ys)
    PARAMS (y; k1; k2; k3; k4; Vlong (Int64.repr (Zlength ys)); Vfloat h; out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys)) os out)
  POST [ tint ]
    PROP ()
    RETURN (Vint (Int.repr 0))
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys))
           (map Vfloat (Diana.VST.RK4.c_rk4 h ys k1s k2s k3s k4s)) out).

Definition Gprog : funspecs :=
  ltac:(with_library prog [step_spec]).

Lemma body_diana_rk4_step_unchecked :
  semax_body Vprog Gprog f_diana_rk4_step_unchecked step_spec.
Proof.
  start_function.
  assert_PROP (isptr y /\ isptr k1 /\ isptr k2 /\ isptr k3 /\ isptr k4 /\ isptr out)
    as Hptr by entailer!.
  destruct Hptr as [Hy [Hk1 [Hk2 [Hk3 [Hk4 Hout]]]]].
  forward_if (PROP () LOCAL (temp _t'1 (Vint Int.zero); temp _y y; temp _k1 k1; temp _k2 k2;
      temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { subst y. contradiction. }
  { forward. entailer!. destruct k1; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'2 (Vint Int.zero); temp _y y; temp _k1 k1; temp _k2 k2;
      temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct k2; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'3 (Vint Int.zero); temp _y y; temp _k1 k1; temp _k2 k2;
      temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct k3; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'4 (Vint Int.zero); temp _y y; temp _k1 k1; temp _k2 k2;
      temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct k4; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'5 (Vint Int.zero); temp _y y; temp _k1 k1; temp _k2 k2;
      temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct out; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'6 (Vint Int.zero); temp _y y; temp _k1 k1; temp _k2 k2;
      temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct (zeq (Zlength ys) 0); [lia | reflexivity]. }
  forward_if; try contradiction.
  set (L := Diana.VST.RK4.c_rk4 h ys k1s k2s k3s k4s).
  assert (HL : Zlength L = Zlength ys) by (apply Diana.VST.RK4.Zlength_c_rk4; lia).
  assert (HZ : forall i, 0 <= i < Zlength ys ->
            Znth i L = Diana.VST.RK4.c_step h (Znth i ys) (Znth i k1s) (Znth i k2s) (Znth i k3s) (Znth i k4s))
    by (intros; apply Diana.VST.RK4.Znth_c_rk4; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength ys)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _h (Vfloat h); temp _y y; temp _k1 k1; temp _k2 k2;
              temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys)));
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
            data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
            data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
            data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
            data_at sho (tarray tdouble (Zlength ys))
              (map Vfloat (sublist 0 i L) ++ sublist i (Zlength ys) os) out))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength ys)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _h (Vfloat h); temp _y y; temp _k1 k1; temp _k2 k2;
              temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys)));
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
            data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
            data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
            data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
            data_at sho (tarray tdouble (Zlength ys))
              (map Vfloat (sublist 0 (i + 1) L) ++ sublist (i + 1) (Zlength ys) os) out))
    break:
    (PROP ()
       LOCAL ()
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
            data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
            data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
            data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
            data_at sho (tarray tdouble (Zlength ys))
              (map Vfloat L) out)).
  { forward. Exists 0. entailer!. rewrite app_nil_l, sublist_same by lia. cancel. }
  { entailer!. }
  { do 7 forward. Exists a. entailer!.
    match goal with |- context [upd_Znth a _ ?v] =>
      replace v with
        (Vfloat (Diana.VST.RK4.c_step h (Znth a ys) (Znth a k1s) (Znth a k2s) (Znth a k3s) (Znth a k4s)))
        by reflexivity end.
    apply derives_refl'. f_equal.
    rewrite (sublist_split 0 a (a + 1) L) by lia. rewrite (sublist_len_1 a L) by lia.
    rewrite HZ by lia. list_solve. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. entailer!.
    rewrite sublist_same, sublist_nil, app_nil_r by lia. cancel. }
  forward.
Qed.
