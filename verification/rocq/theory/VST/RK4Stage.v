From VST.floyd Require Import proofauto.
From Diana.Clight Require Import rk4_stage_aarch64_macos.
From Diana.VST Require Bisection Euler.
From Diana.VST Require Import RK4.
From Diana.VST Require Import Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition stage_spec :=
  DECLARE _diana_rk4_stage
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
    RETURN (Vint (Int.repr (stage_status s h ys ks)))
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys))
           (if forallb (Binary.is_finite 53 1024) (c_stage s h ys ks)
            then map Vfloat (c_stage s h ys ks) else os) out).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; stage_spec]).

Lemma body_diana_fp_finite : semax_body Vprog Gprog f_diana_fp_finite fp_finite_spec.
Proof.
  start_function.
  forward_if (PROP () LOCAL (temp _t'1
      (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero))) SEP ()).
  - forward. entailer!.
    rewrite Diana.VST.Bisection.cmp_sub_self_zero by
      (destruct (Binary.is_nan 53 1024 x) eqn:Hn; [| reflexivity];
       rewrite Diana.VST.Bisection.cmp_eq_self, Hn in H; discriminate H).
    destruct (Binary.is_finite 53 1024 x); reflexivity.
  - forward. entailer!.
    rewrite Diana.VST.Bisection.cmp_eq_self in H.
    destruct (Binary.is_nan 53 1024 x) eqn:Hn; [| discriminate H].
    destruct x; try discriminate Hn. reflexivity.
  - forward.
Qed.

Lemma body_diana_rk4_stage : semax_body Vprog Gprog f_diana_rk4_stage stage_spec.
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
  set (c := c_coef s h).
  forward_if (PROP () LOCAL (temp _c (Vfloat c); temp _h (Vfloat h); temp _y y; temp _k k;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { forward. entailer!. }
  { forward. entailer!. subst c. unfold c_coef.
    destruct (Z.eqb_spec s 4) as [-> | _]; [contradiction | reflexivity]. }
  set (L := c_stage s h ys ks).
  assert (HL : Zlength L = Zlength ys)
    by (apply Diana.VST.Euler.Zlength_c_euler; lia).
  assert (HZ : forall i, 0 <= i < Zlength ys ->
            Znth i L = Diana.VST.Euler.c_step c (Znth i ys) (Znth i ks))
    by (intros; apply Diana.VST.Euler.Znth_c_euler; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength ys;
                        forallb (Binary.is_finite 53 1024) (sublist 0 i L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _c (Vfloat c); temp _h (Vfloat h); temp _y y; temp _k k;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
            data_at sho (tarray tdouble (Zlength ys)) os out))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength ys;
                        forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _c (Vfloat c); temp _h (Vfloat h); temp _y y; temp _k k;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
            data_at sho (tarray tdouble (Zlength ys)) os out))
    break:
    (PROP (forallb (Binary.is_finite 53 1024) L = true)
       LOCAL (temp _c (Vfloat c); temp _h (Vfloat h); temp _y y; temp _k k;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
            data_at sho (tarray tdouble (Zlength ys)) os out)).
  { forward. Exists 0. entailer!. }
  { entailer!. }
  { forward. forward. forward.
    forward_call (Diana.VST.Euler.c_step c (Znth a ys) (Znth a ks)).
    destruct (Binary.is_finite 53 1024 (Diana.VST.Euler.c_step c (Znth a ys) (Znth a ks)))
      eqn:Hfin.
    - forward_if.
      + discriminate.
      + forward. Exists a. entailer!.
        rewrite Diana.VST.Euler.forallb_sublist_succ by lia.
        rewrite HZ by lia. rewrite Hfin, andb_true_r. assumption.
    - forward_if.
      + assert (Hb : forallb (Binary.is_finite 53 1024) L = false).
        { apply (Diana.VST.Euler.forallb_false L a); [lia |]. rewrite HZ by lia. exact Hfin. }
        forward_call h.
        destruct (Binary.is_finite 53 1024 h) eqn:Hh.
        2: { forward_if; [| contradiction]. forward.
             unfold stage_status. fold L. rewrite Hb, Hh. entailer!. }
        forward_if; [discriminate |].
        forward_for
          (fun j : Z => PROP (0 <= j <= Zlength ys;
                              forallb (Binary.is_finite 53 1024) (sublist 0 j ys) = true;
                              forallb (Binary.is_finite 53 1024) (sublist 0 j ks) = true)
             LOCAL (temp _j (Vlong (Int64.repr j)); temp _y y; temp _k k;
                    temp _d (Vlong (Int64.repr (Zlength ys))))
             SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                  data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
                  data_at sho (tarray tdouble (Zlength ys)) os out))
          continue:
          (fun j : Z => PROP (0 <= j < Zlength ys;
                              forallb (Binary.is_finite 53 1024) (sublist 0 (j + 1) ys) = true;
                              forallb (Binary.is_finite 53 1024) (sublist 0 (j + 1) ks) = true)
             LOCAL (temp _j (Vlong (Int64.repr j)); temp _y y; temp _k k;
                    temp _d (Vlong (Int64.repr (Zlength ys))))
             SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                  data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
                  data_at sho (tarray tdouble (Zlength ys)) os out))
          break:
          (PROP (forallb (Binary.is_finite 53 1024) ys = true;
                 forallb (Binary.is_finite 53 1024) ks = true)
             LOCAL ()
             SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                  data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
                  data_at sho (tarray tdouble (Zlength ys)) os out)).
        { forward. Exists 0. entailer!. }
        { entailer!. }
        { rename a0 into j.
          forward. forward_call (Znth j ys).
          destruct (Binary.is_finite 53 1024 (Znth j ys)) eqn:Hyj.
          2: { forward_if; [| contradiction]. forward.
               assert (Hys : forallb (Binary.is_finite 53 1024) ys = false)
                 by (apply (Diana.VST.Euler.forallb_false ys j); [lia | exact Hyj]).
               unfold stage_status. fold L. rewrite Hb, Hh, Hys. entailer!. }
          forward_if; [discriminate |].
          forward. forward_call (Znth j ks).
          destruct (Binary.is_finite 53 1024 (Znth j ks)) eqn:Hkj.
          2: { forward_if; [| contradiction]. forward.
               assert (Hks : forallb (Binary.is_finite 53 1024) ks = false)
                 by (apply (Diana.VST.Euler.forallb_false ks j); [lia | exact Hkj]).
               unfold stage_status. fold L. rewrite Hb, Hh, Hks, andb_false_r. entailer!. }
          forward_if; [discriminate |].
          forward. Exists j. entailer!.
          rewrite !Diana.VST.Euler.forallb_sublist_succ by lia.
          rewrite Hyj, Hkj, !andb_true_r. auto. }
        { forward. Exists (a0 + 1). entailer!. }
        { assert (a0 = Zlength ys) by lia. subst a0.
          rewrite !sublist_same in * by lia. entailer!. }
        forward.
        match goal with
        | Hy : forallb _ ys = true, Hk : forallb _ ks = true |- _ =>
            unfold stage_status; fold L; rewrite Hb, Hh, Hy, Hk
        end.
        entailer!.
      + contradiction. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. rewrite sublist_same in * by lia. entailer!. }
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
  { forward. forward. forward. forward. Exists a. entailer!.
    match goal with |- context [upd_Znth a _ ?v] =>
      replace v with (Vfloat (Diana.VST.Euler.c_step c (Znth a ys) (Znth a ks)))
        by reflexivity end.
    apply derives_refl'. f_equal.
    rewrite (sublist_split 0 a (a + 1) L) by lia. rewrite (sublist_len_1 a L) by lia.
    rewrite HZ by lia. list_solve. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. entailer!.
    rewrite sublist_same, sublist_nil, app_nil_r by lia. cancel. }
  forward. fold L. unfold stage_status. fold L.
  match goal with H : forallb _ L = true |- _ => rewrite H end.
  entailer!.
Qed.
