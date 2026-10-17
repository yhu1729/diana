From VST.floyd Require Import proofauto.
From Diana.Clight Require Import rk4_aarch64_macos.
From Diana.Float Require Euler RK4 Trapezoidal.
From Diana.VST Require Bisection Euler.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition c_half : float := Float.of_bits (Int64.repr 4602678819172646912).
Definition c_two : float := Float.of_bits (Int64.repr 4611686018427387904).
Definition c_six : float := Float.of_bits (Int64.repr 4618441417868443648).

Lemma c_half_eq : c_half = Diana.Float.Trapezoidal.half.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_two_eq : c_two = Diana.Float.RK4.two.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_six_eq : c_six = Diana.Float.RK4.six.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Definition c_coef (s : Z) (h : float) : float := if Z.eqb s 4 then h else Float.mul c_half h.

Definition c_stage (s : Z) (h : float) (ys ks : list float) : list float :=
  Diana.VST.Euler.c_euler (c_coef s h) ys ks.

Lemma c_stage_model (s : Z) (h : float) (ys ks : list float) :
  c_stage s h ys ks = Diana.Float.RK4.frk4_stage Float.binop_nan Float.binop_nan s h ys ks.
Proof.
  unfold c_stage, Diana.Float.RK4.frk4_stage. rewrite Diana.VST.Euler.c_euler_model.
  f_equal. unfold c_coef, Diana.Float.RK4.coef. rewrite c_half_eq. reflexivity.
Qed.

Definition c_step (h y a b c e : float) : float :=
  Float.add y (Float.div (Float.mul h (Float.add (Float.add a e) (Float.mul c_two (Float.add b c))))
                 c_six).

Fixpoint c_rk4 (h : float) (ys k1s k2s k3s k4s : list float) : list float :=
  match ys, k1s, k2s, k3s, k4s with
  | y :: ys', a :: k1s', b :: k2s', c :: k3s', e :: k4s' =>
      c_step h y a b c e :: c_rk4 h ys' k1s' k2s' k3s' k4s'
  | _, _, _, _, _ => nil
  end.

Lemma c_rk4_model (h : float) (ys k1s k2s k3s k4s : list float) :
  c_rk4 h ys k1s k2s k3s k4s =
  Diana.Float.RK4.frk4_step Float.binop_nan Float.binop_nan Float.binop_nan h ys k1s k2s k3s k4s.
Proof.
  revert k1s k2s k3s k4s.
  induction ys as [| y ys IH]; intros [| a k1s] [| b k2s] [| c k3s] [| e k4s]; try reflexivity.
  cbn [c_rk4 Diana.Float.RK4.frk4_step]. f_equal; [| apply IH].
  unfold c_step, Diana.Float.RK4.fstep, Diana.Float.RK4.fslope.
  rewrite c_two_eq, c_six_eq. reflexivity.
Qed.

Lemma Zlength_c_rk4 (h : float) (ys k1s k2s k3s k4s : list float) :
  Zlength k1s = Zlength ys -> Zlength k2s = Zlength ys -> Zlength k3s = Zlength ys ->
  Zlength k4s = Zlength ys -> Zlength (c_rk4 h ys k1s k2s k3s k4s) = Zlength ys.
Proof.
  revert k1s k2s k3s k4s.
  induction ys as [| y ys IH]; intros k1s k2s k3s k4s H1 H2 H3 H4; [reflexivity |].
  pose proof (Zlength_nonneg ys).
  destruct k1s as [| a k1s]; [rewrite Zlength_nil, Zlength_cons in H1; lia |].
  destruct k2s as [| b k2s]; [rewrite Zlength_nil, Zlength_cons in H2; lia |].
  destruct k3s as [| c k3s]; [rewrite Zlength_nil, Zlength_cons in H3; lia |].
  destruct k4s as [| e k4s]; [rewrite Zlength_nil, Zlength_cons in H4; lia |].
  rewrite !Zlength_cons in *. cbn [c_rk4]. rewrite Zlength_cons, IH by lia. reflexivity.
Qed.

Lemma Znth_c_rk4 (h : float) (ys k1s k2s k3s k4s : list float) (i : Z) :
  Zlength k1s = Zlength ys -> Zlength k2s = Zlength ys -> Zlength k3s = Zlength ys ->
  Zlength k4s = Zlength ys -> 0 <= i < Zlength ys ->
  Znth i (c_rk4 h ys k1s k2s k3s k4s) =
  c_step h (Znth i ys) (Znth i k1s) (Znth i k2s) (Znth i k3s) (Znth i k4s).
Proof.
  revert k1s k2s k3s k4s i.
  induction ys as [| y ys IH]; intros k1s k2s k3s k4s i H1 H2 H3 H4 Hi.
  { rewrite Zlength_nil in Hi. lia. }
  pose proof (Zlength_nonneg ys).
  destruct k1s as [| a k1s]; [rewrite Zlength_nil, Zlength_cons in H1; lia |].
  destruct k2s as [| b k2s]; [rewrite Zlength_nil, Zlength_cons in H2; lia |].
  destruct k3s as [| c k3s]; [rewrite Zlength_nil, Zlength_cons in H3; lia |].
  destruct k4s as [| e k4s]; [rewrite Zlength_nil, Zlength_cons in H4; lia |].
  rewrite !Zlength_cons in *. cbn [c_rk4].
  destruct (Z.eq_dec i 0) as [-> | Hne].
  - rewrite !Znth_0_cons. reflexivity.
  - rewrite !Znth_pos_cons by lia. apply IH; lia.
Qed.

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
    RETURN (Vint (Int.repr
      (if forallb (Binary.is_finite 53 1024) (c_stage s h ys ks) then 0 else -1)))
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys))
           (if forallb (Binary.is_finite 53 1024) (c_stage s h ys ks)
            then map Vfloat (c_stage s h ys ks) else os) out).

Definition step_spec :=
  DECLARE _diana_rk4_step
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
    RETURN (Vint (Int.repr
      (if forallb (Binary.is_finite 53 1024) (c_rk4 h ys k1s k2s k3s k4s) then 0 else -1)))
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
         data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
         data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
         data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
         data_at sho (tarray tdouble (Zlength ys))
           (if forallb (Binary.is_finite 53 1024) (c_rk4 h ys k1s k2s k3s k4s)
            then map Vfloat (c_rk4 h ys k1s k2s k3s k4s) else os) out).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; stage_spec; step_spec]).

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
  forward_if (PROP () LOCAL (temp _t'1 (Vint Int.zero); temp _y y; temp _k k;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _stage (Vint (Int.repr s)); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { subst y. contradiction. }
  { forward. entailer!. destruct k; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'2 (Vint Int.zero); temp _y y; temp _k k;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _stage (Vint (Int.repr s)); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct out; try contradiction. reflexivity. }
  forward_if (PROP () LOCAL (temp _t'3 (Vint Int.zero); temp _y y; temp _k k;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _stage (Vint (Int.repr s)); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct (zeq (Zlength ys) 0); [lia | reflexivity]. }
  forward_if (PROP () LOCAL (temp _t'4 (Vint Int.zero); temp _y y; temp _k k;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _stage (Vint (Int.repr s)); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct (zlt s 2); [lia | reflexivity]. }
  forward_if (PROP () LOCAL (temp _t'5 (Vint Int.zero); temp _y y; temp _k k;
      temp _d (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
      temp _stage (Vint (Int.repr s)); temp _y_out out)
    SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
         data_at sho (tarray tdouble (Zlength ys)) os out)).
  { contradiction. }
  { forward. entailer!. destruct (zlt 4 s); [lia | reflexivity]. }
  forward_if; try contradiction.
  set (c := c_coef s h).
  forward_if (PROP () LOCAL (temp _c (Vfloat c); temp _y y; temp _k k;
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
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _c (Vfloat c); temp _y y; temp _k k;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
            data_at sho (tarray tdouble (Zlength ys)) os out))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength ys;
                        forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _c (Vfloat c); temp _y y; temp _k k;
              temp _d (Vlong (Int64.repr (Zlength ys))); temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shk (tarray tdouble (Zlength ys)) (map Vfloat ks) k;
            data_at sho (tarray tdouble (Zlength ys)) os out))
    break:
    (PROP (forallb (Binary.is_finite 53 1024) L = true)
       LOCAL (temp _c (Vfloat c); temp _y y; temp _k k;
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
        forward. fold L. rewrite Hb. entailer!.
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
  forward. fold L.
  match goal with H : forallb _ L = true |- _ => rewrite H end.
  entailer!.
Qed.

Lemma body_diana_rk4_step : semax_body Vprog Gprog f_diana_rk4_step step_spec.
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
  set (L := c_rk4 h ys k1s k2s k3s k4s).
  assert (HL : Zlength L = Zlength ys) by (apply Zlength_c_rk4; lia).
  assert (HZ : forall i, 0 <= i < Zlength ys ->
            Znth i L = c_step h (Znth i ys) (Znth i k1s) (Znth i k2s) (Znth i k3s) (Znth i k4s))
    by (intros; apply Znth_c_rk4; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength ys;
                        forallb (Binary.is_finite 53 1024) (sublist 0 i L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _h (Vfloat h); temp _y y; temp _k1 k1; temp _k2 k2;
              temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys)));
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
            data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
            data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
            data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
            data_at sho (tarray tdouble (Zlength ys))
              os out))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength ys;
                        forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _h (Vfloat h); temp _y y; temp _k1 k1; temp _k2 k2;
              temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys)));
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
            data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
            data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
            data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
            data_at sho (tarray tdouble (Zlength ys))
              os out))
    break:
    (PROP (forallb (Binary.is_finite 53 1024) L = true)
       LOCAL (temp _h (Vfloat h); temp _y y; temp _k1 k1; temp _k2 k2;
              temp _k3 k3; temp _k4 k4; temp _d (Vlong (Int64.repr (Zlength ys)));
              temp _y_out out)
       SEP (data_at shy (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at sh1 (tarray tdouble (Zlength ys)) (map Vfloat k1s) k1;
            data_at sh2 (tarray tdouble (Zlength ys)) (map Vfloat k2s) k2;
            data_at sh3 (tarray tdouble (Zlength ys)) (map Vfloat k3s) k3;
            data_at sh4 (tarray tdouble (Zlength ys)) (map Vfloat k4s) k4;
            data_at sho (tarray tdouble (Zlength ys))
              os out)).
  { forward. Exists 0. entailer!. }
  { entailer!. }
  { do 7 forward.
    forward_call (c_step h (Znth a ys) (Znth a k1s) (Znth a k2s) (Znth a k3s) (Znth a k4s)).
    destruct (Binary.is_finite 53 1024
                (c_step h (Znth a ys) (Znth a k1s) (Znth a k2s) (Znth a k3s) (Znth a k4s)))
      eqn:Hfin.
    - forward_if.
      + discriminate.
      + forward. Exists a. entailer!.
        rewrite Diana.VST.Euler.forallb_sublist_succ by lia.
        rewrite HZ by lia. rewrite Hfin, andb_true_r. assumption.
    - forward_if.
      + assert (Hb : forallb (Binary.is_finite 53 1024) L = false).
        { apply (Diana.VST.Euler.forallb_false L a); [lia |]. rewrite HZ by lia. exact Hfin. }
        forward. fold L. rewrite Hb. entailer!.
      + contradiction. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. rewrite sublist_same in * by lia. entailer!. }
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
  { do 8 forward. Exists a. entailer!.
    match goal with |- context [upd_Znth a _ ?v] =>
      replace v with
        (Vfloat (c_step h (Znth a ys) (Znth a k1s) (Znth a k2s) (Znth a k3s) (Znth a k4s)))
        by reflexivity end.
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
