From VST.floyd Require Import proofauto.
From Diana.Clight Require Import euler_aarch64_macos.
From Diana.Float Require Euler.
From Diana.VST Require Bisection.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition c_step (h y f : float) : float := Float.add y (Float.mul h f).

Fixpoint c_euler (h : float) (ys fs : list float) : list float :=
  match ys, fs with
  | y :: ys', f :: fs' => c_step h y f :: c_euler h ys' fs'
  | _, _ => nil
  end.

Lemma c_euler_model (h : float) (ys fs : list float) :
  c_euler h ys fs = Diana.Float.Euler.feuler Float.binop_nan Float.binop_nan h ys fs.
Proof.
  revert fs. induction ys as [| y ys IH]; intros [| f fs]; try reflexivity.
  cbn [c_euler]. unfold Diana.Float.Euler.feuler. cbn [combine map fst snd].
  f_equal. apply IH.
Qed.

Lemma Zlength_c_euler (h : float) (ys fs : list float) :
  Zlength fs = Zlength ys -> Zlength (c_euler h ys fs) = Zlength ys.
Proof.
  revert fs. induction ys as [| y ys IH]; intros [| f fs] Hl; cbn [c_euler]; try reflexivity.
  - rewrite Zlength_nil, Zlength_cons in Hl. pose proof (Zlength_nonneg ys). lia.
  - rewrite !Zlength_cons in *. rewrite IH by lia. reflexivity.
Qed.

Lemma Znth_c_euler (h : float) (ys fs : list float) (i : Z) :
  Zlength fs = Zlength ys -> 0 <= i < Zlength ys ->
  Znth i (c_euler h ys fs) = c_step h (Znth i ys) (Znth i fs).
Proof.
  revert fs i. induction ys as [| y ys IH]; intros [| f fs] i Hl Hi.
  - rewrite Zlength_nil in Hi. lia.
  - rewrite Zlength_nil in Hi. lia.
  - rewrite Zlength_nil, Zlength_cons in Hl. pose proof (Zlength_nonneg ys). lia.
  - cbn [c_euler]. pose proof (Zlength_cons y ys). pose proof (Zlength_cons f fs).
    destruct (Z.eq_dec i 0) as [-> | Hne].
    + rewrite !Znth_0_cons. reflexivity.
    + rewrite !Znth_pos_cons by lia. apply IH; lia.
Qed.

Lemma forallb_sublist_succ (L : list float) (i : Z) :
  0 <= i < Zlength L ->
  forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) L)
  = andb (forallb (Binary.is_finite 53 1024) (sublist 0 i L))
         (Binary.is_finite 53 1024 (Znth i L)).
Proof.
  intro Hi. rewrite (sublist_split 0 i (i + 1)) by lia.
  rewrite forallb_app, sublist_len_1 by lia. simpl. rewrite andb_true_r. reflexivity.
Qed.

Lemma forallb_false (L : list float) (i : Z) :
  0 <= i < Zlength L -> Binary.is_finite 53 1024 (Znth i L) = false ->
  forallb (Binary.is_finite 53 1024) L = false.
Proof.
  intros Hi Hf. destruct (forallb (Binary.is_finite 53 1024) L) eqn:Hb; [| reflexivity].
  rewrite forallb_forall in Hb. rewrite Hb in Hf; [discriminate |]. apply Znth_In. exact Hi.
Qed.

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
    RETURN (Vint (Int.repr
      (if forallb (Binary.is_finite 53 1024) (c_euler h ys fs) then 0 else -1)))
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys))
           (if forallb (Binary.is_finite 53 1024) (c_euler h ys fs)
            then map Vfloat (c_euler h ys fs) else os) out).

Definition euler_unchecked_spec :=
  DECLARE _diana_euler_step_unchecked
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
    RETURN (Vint (Int.repr 0))
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys)) (map Vfloat (c_euler h ys fs)) out).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; euler_spec; euler_unchecked_spec]).

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
  forward_if (PROP () LOCAL (temp _t'1 (Vint Int.zero); temp _y y; temp _f f;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { subst y. contradiction. }
  { forward. entailer!. destruct f; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'2 (Vint Int.zero); temp _y y; temp _f f;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct out; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'3 (Vint Int.zero); temp _y y; temp _f f;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
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
        forward. fold L. rewrite Hb. entailer!.
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
  forward. fold L.
  match goal with H : forallb _ L = true |- _ => rewrite H end.
  entailer!.
Qed.

Lemma body_diana_euler_step_unchecked :
  semax_body Vprog Gprog f_diana_euler_step_unchecked euler_unchecked_spec.
Proof.
  start_function.
  assert_PROP (isptr y /\ isptr f /\ isptr out) as Hptr by entailer!.
  destruct Hptr as [Hy [Hf Hout]].
  forward_if (PROP () LOCAL (temp _t'1 (Vint Int.zero); temp _y y; temp _f f;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { subst y. contradiction. }
  { forward. entailer!. destruct f; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'2 (Vint Int.zero); temp _y y; temp _f f;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct out; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'3 (Vint Int.zero); temp _y y; temp _f f;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shf (tarray tdouble (Zlength ys)) (map Vfloat fs) f;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct (zeq (Zlength ys) 0); [lia | reflexivity]. }
  forward_if.
  { contradiction. }
  set (L := c_euler h ys fs).
  assert (HL : Zlength L = Zlength ys) by (apply Zlength_c_euler; lia).
  assert (HZ : forall i, 0 <= i < Zlength ys -> Znth i L = c_step h (Znth i ys) (Znth i fs))
    by (intros; apply Znth_c_euler; lia).
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
  { forward. forward. forward. Exists a. entailer!.
    match goal with |- context [upd_Znth a _ ?v] =>
      replace v with (Vfloat (c_step h (Znth a ys) (Znth a fs))) by reflexivity end.
    apply derives_refl'. f_equal.
    rewrite (sublist_split 0 a (a + 1) L) by lia. rewrite (sublist_len_1 a L) by lia.
    rewrite HZ by lia. list_solve. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. entailer!.
    rewrite sublist_same, sublist_nil, app_nil_r by lia. cancel. }
  forward.
Qed.
