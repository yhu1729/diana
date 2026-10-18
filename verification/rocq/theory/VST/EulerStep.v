From VST.floyd Require Import proofauto.
From Diana.Clight Require Import euler_step_aarch64_macos.
From Diana.VST Require Import Euler.
From Diana.VST Require Bisection.
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

Definition euler_spec :=
  DECLARE _diana_euler_step
  WITH shy : share, shf : share, sho : share, y : val, f : val, out : val,
       ys : list float, fs : list float, h : float, os : list val
  PRE [ tptr tdouble, tptr tdouble, tulong, tdouble, tptr tdouble ]
    PROP (readable_share shy; readable_share shf; writable_share sho;
          1 <= Zlength ys <= Int64.max_unsigned; Zlength fs = Zlength ys;
          Zlength os = Zlength ys)
    PARAMS (y; f; Vlong (Int64.repr (Zlength ys)); Vfloat h; out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys)) os out)
  POST [ tint ]
    PROP ()
    RETURN (Vint (Int.repr (euler_status h ys fs)))
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys))
           (if forallb (Binary.is_finite 53 1024) (c_euler h ys fs)
            then map Vfloat (c_euler h ys fs) else os) out).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; euler_spec]).

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

Lemma body_diana_euler_step : semax_body Vprog Gprog f_diana_euler_step euler_spec.
Proof.
  start_function.
  assert_PROP (isptr y /\ isptr f /\ isptr out) as Hptr by entailer!.
  destruct Hptr as [Hy [Hf Hout]].
  join_zero _t'1.
  { subst y. contradiction. }
  { forward. entailer!. destruct f; try contradiction. reflexivity. }
  join_zero _t'2.
  { contradiction. }
  { forward. entailer!. destruct out; try contradiction. reflexivity. }
  join_zero _t'3.
  { contradiction. }
  { forward. entailer!. destruct (zeq (Zlength ys) 0); [lia | reflexivity]. }
  forward_if.
  { contradiction. }
  set (L := c_euler h ys fs).
  assert (HL : Zlength L = Zlength ys) by (apply Zlength_c_euler; lia).
  assert (HZ : forall i, 0 <= i < Zlength ys -> Znth i L = c_step h (Znth i ys) (Znth i fs))
    by (intros; apply Znth_c_euler; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength ys;
                        forallb (Binary.is_finite 53 1024) (sublist 0 i L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _y y; temp _f f;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
            data_at sho (tarray tdouble (Zlength ys)) os out))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength ys;
                        forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _y y; temp _f f;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
            data_at sho (tarray tdouble (Zlength ys)) os out))
    break:
    (PROP (forallb (Binary.is_finite 53 1024) L = true)
       LOCAL (temp _y y; temp _f f; temp _d (Vlong (Int64.repr (Zlength ys)));
              temp _h (Vfloat h); temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
            data_at sho (tarray tdouble (Zlength ys)) os out)).
  { forward. Exists 0. entailer!. }
  { entailer!. }
  { forward. forward. forward.
    forward_call (c_step h (Znth a ys) (Znth a fs)).
    destruct (Binary.is_finite 53 1024 (c_step h (Znth a ys) (Znth a fs))) eqn:Hfin.
    - forward_if.
      + discriminate.
      + forward. Exists a. entailer!. rewrite forallb_sublist_succ by lia.
        rewrite HZ by lia. rewrite Hfin, andb_true_r. assumption.
    - forward_if.
      + assert (Hb : forallb (Binary.is_finite 53 1024) L = false).
        { apply (forallb_false L a); [lia |]. rewrite HZ by lia. exact Hfin. }
        forward_call h.
        destruct (Binary.is_finite 53 1024 h) eqn:Hh.
        2: { forward_if; [| contradiction]. forward.
             unfold euler_status. fold L. rewrite Hb, Hh. entailer!. }
        forward_if; [discriminate |].
        forward_for
          (fun j : Z => PROP (0 <= j <= Zlength ys;
                              forallb (Binary.is_finite 53 1024) (sublist 0 j ys) = true;
                              forallb (Binary.is_finite 53 1024) (sublist 0 j fs) = true)
             LOCAL (temp _j (Vlong (Int64.repr j)); temp _y y; temp _f f;
                    temp _d (Vlong (Int64.repr (Zlength ys))))
             SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                  data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
                  data_at sho (tarray tdouble (Zlength ys)) os out))
          continue:
          (fun j : Z => PROP (0 <= j < Zlength ys;
                              forallb (Binary.is_finite 53 1024) (sublist 0 (j + 1) ys) = true;
                              forallb (Binary.is_finite 53 1024) (sublist 0 (j + 1) fs) = true)
             LOCAL (temp _j (Vlong (Int64.repr j)); temp _y y; temp _f f;
                    temp _d (Vlong (Int64.repr (Zlength ys))))
             SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                  data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
                  data_at sho (tarray tdouble (Zlength ys)) os out))
          break:
          (PROP (forallb (Binary.is_finite 53 1024) ys = true;
                 forallb (Binary.is_finite 53 1024) fs = true)
             LOCAL ()
             SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                  data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
                  data_at sho (tarray tdouble (Zlength ys)) os out)).
        { forward. Exists 0. entailer!. }
        { entailer!. }
        { rename a0 into j.
          forward. forward_call (Znth j ys).
          destruct (Binary.is_finite 53 1024 (Znth j ys)) eqn:Hyj.
          2: { forward_if; [| contradiction]. forward.
               assert (Hys : forallb (Binary.is_finite 53 1024) ys = false)
                 by (apply (forallb_false ys j); [lia | exact Hyj]).
               unfold euler_status. fold L. rewrite Hb, Hh, Hys. entailer!. }
          forward_if; [discriminate |].
          forward. forward_call (Znth j fs).
          destruct (Binary.is_finite 53 1024 (Znth j fs)) eqn:Hfj.
          2: { forward_if; [| contradiction]. forward.
               assert (Hfs : forallb (Binary.is_finite 53 1024) fs = false)
                 by (apply (forallb_false fs j); [lia | exact Hfj]).
               unfold euler_status. fold L. rewrite Hb, Hh, Hfs, andb_false_r. entailer!. }
          forward_if; [discriminate |].
          forward. Exists j. entailer!.
          rewrite !forallb_sublist_succ by lia. rewrite Hyj, Hfj, !andb_true_r. auto. }
        { forward. Exists (a0 + 1). entailer!. }
        { assert (a0 = Zlength ys) by lia. subst a0.
          rewrite !sublist_same in * by lia. entailer!. }
        forward.
        match goal with
        | Hy : forallb _ ys = true, Hf : forallb _ fs = true |- _ =>
            unfold euler_status; fold L; rewrite Hb, Hh, Hy, Hf
        end.
        entailer!.
      + contradiction. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. rewrite sublist_same in * by lia. entailer!. }
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength ys)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _y y; temp _f f;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
            data_at sho (tarray tdouble (Zlength ys))
              (map Vfloat (sublist 0 i L) ++ sublist i (Zlength ys) os) out))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength ys)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _y y; temp _f f;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
            data_at sho (tarray tdouble (Zlength ys))
              (map Vfloat (sublist 0 (i + 1) L) ++ sublist (i + 1) (Zlength ys) os) out))
    break:
    (PROP ()
       LOCAL ()
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
            data_at sho (tarray tdouble (Zlength ys)) (map Vfloat L) out)).
  { forward. Exists 0. entailer!. rewrite app_nil_l, sublist_same by lia. cancel. }
  { entailer!. }
  { forward. forward. forward. forward. Exists a. entailer!.
    match goal with |- context [upd_Znth a _ ?v] =>
      replace v with (Vfloat (c_step h (Znth a ys) (Znth a fs))) by reflexivity end.
    apply derives_refl'. f_equal.
    rewrite (sublist_split 0 a (a + 1) L) by lia. rewrite (sublist_len_1 a L) by lia.
    rewrite HZ by lia. list_solve. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. entailer!.
    rewrite sublist_same, sublist_nil, app_nil_r by lia. cancel. }
  forward. fold L. unfold euler_status. fold L.
  match goal with H : forallb _ L = true |- _ => rewrite H end.
  entailer!.
Qed.
