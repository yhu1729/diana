From VST.floyd Require Import proofauto.
From Diana.Clight Require Import trapezoidal_aarch64_macos.
From Diana.Float Require Trapezoidal.
From Diana.VST Require Bisection.
From Diana.VST Require Import Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition c_half : float := Float.of_bits (Int64.repr 4602678819172646912).

Lemma c_half_eq : c_half = Diana.Float.Trapezoidal.half.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Definition c_start (ys : list float) : float :=
  Float.mul c_half (Float.add (Znth 0 ys) (Znth (Zlength ys - 1) ys)).

Definition c_sum (ys : list float) (i : Z) : float :=
  fold_left Float.add (sublist 1 i ys) (c_start ys).

Definition c_trap (ys : list float) (h : float) : float :=
  Float.mul h (c_sum ys (Zlength ys - 1)).

Lemma c_trap_model (ys : list float) (h : float) :
  c_trap ys h =
  Diana.Float.Trapezoidal.ftrap Float.binop_nan Float.binop_nan
    (Znth 0 ys) (Znth (Zlength ys - 1) ys) (sublist 1 (Zlength ys - 1) ys) h.
Proof.
  unfold c_trap, c_sum, c_start, Diana.Float.Trapezoidal.ftrap,
    Diana.Float.Trapezoidal.fsum, Diana.Float.Trapezoidal.start.
  rewrite c_half_eq. reflexivity.
Qed.

Lemma c_sum_step (ys : list float) (i : Z) :
  1 <= i < Zlength ys ->
  c_sum ys (i + 1) = Float.add (c_sum ys i) (Znth i ys).
Proof.
  intro Hi. unfold c_sum.
  rewrite (sublist_split 1 i (i + 1)) by lia.
  rewrite fold_left_app, sublist_len_1 by lia. reflexivity.
Qed.

Lemma unsigned_sub_one (n : Z) :
  1 <= n <= Int64.max_unsigned ->
  Int64.unsigned (Int64.sub (Int64.repr n) (Int64.repr 1)) = n - 1.
Proof.
  intro Hn. unfold Int64.sub.
  rewrite (Int64.unsigned_repr n) by rep_lia.
  rewrite (Int64.unsigned_repr 1) by rep_lia.
  apply Int64.unsigned_repr. rep_lia.
Qed.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition trapezoidal_spec :=
  DECLARE _diana_trapezoidal
  WITH sh : share, shr : share, y : val, res : val, ys : list float, h : float, r0 : val
  PRE [ tptr tdouble, tulong, tdouble, tptr tdouble ]
    PROP (readable_share sh; writable_share shr; 2 <= Zlength ys <= Int64.max_unsigned)
    PARAMS (y; Vlong (Int64.repr (Zlength ys)); Vfloat h; res)
    SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shr tdouble r0 res)
  POST [ tint ]
    PROP ()
    RETURN (Vint (Int.repr (if Binary.is_finite 53 1024 (c_trap ys h) then 0 else -1)))
    SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shr tdouble
           (if Binary.is_finite 53 1024 (c_trap ys h) then Vfloat (c_trap ys h) else r0) res).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; trapezoidal_spec]).

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

Lemma body_diana_trapezoidal :
  semax_body Vprog Gprog f_diana_trapezoidal trapezoidal_spec.
Proof.
  start_function.
  assert_PROP (isptr y /\ isptr res) as Hptr by entailer!.
  destruct Hptr as [Hy Hres].
  join_zero _t'1.
  { subst y. contradiction. }
  { forward. entailer!. destruct res; try contradiction. reflexivity. }
  join_zero _t'2.
  { contradiction. }
  { forward. entailer!. destruct (zlt (Zlength ys) 2); [lia | reflexivity]. }
  forward_if.
  { contradiction. }
  forward. forward. forward.
  forward_for
    (fun i : Z => PROP (1 <= i <= Zlength ys - 1)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _s (Vfloat (c_sum ys i)); temp _y y;
              temp _n (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res))
    continue:
    (fun i : Z => PROP (1 <= i < Zlength ys - 1)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _s (Vfloat (c_sum ys (i + 1))); temp _y y;
              temp _n (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res))
    break:
    (PROP ()
       LOCAL (temp _s (Vfloat (c_sum ys (Zlength ys - 1))); temp _y y;
              temp _h (Vfloat h); temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res)).
  { forward. Exists 1. entailer!.
    unfold c_sum, c_start. rewrite sublist_nil. reflexivity. }
  { entailer!. }
  { rewrite Int64.unsigned_repr in H1 by rep_lia.
    rewrite unsigned_sub_one in H1 by rep_lia.
    forward. forward. Exists a. entailer!.
    rewrite c_sum_step by lia. reflexivity. }
  { forward. Exists (a + 1). entailer!. }
  { rewrite Int64.unsigned_repr in H1 by rep_lia.
    rewrite unsigned_sub_one in H1 by rep_lia.
    assert (a = Zlength ys - 1) by lia. subst a. entailer!. }
  forward.
  forward_call (Float.mul h (c_sum ys (Zlength ys - 1))).
  destruct (Binary.is_finite 53 1024 (Float.mul h (c_sum ys (Zlength ys - 1)))) eqn:Hfin.
  - forward_if.
    + discriminate.
    + forward. forward. unfold c_trap. rewrite Hfin. entailer!.
  - forward_if.
    + forward. unfold c_trap. rewrite Hfin. entailer!.
    + contradiction.
Qed.
