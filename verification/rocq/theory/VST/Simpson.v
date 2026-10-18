From VST.floyd Require Import proofauto.
From Diana.Clight Require Import simpson_aarch64_macos.
From Diana.Float Require Simpson.
From Diana.VST Require Bisection.
From Diana.VST Require Euler.
From Diana.VST Require Import Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition c_zero : float := Float.of_bits (Int64.repr 0).
Definition c_two : float := Float.of_bits (Int64.repr 4611686018427387904).
Definition c_three : float := Float.of_bits (Int64.repr 4613937818241073152).
Definition c_four : float := Float.of_bits (Int64.repr 4616189618054758400).

Lemma c_zero_eq : c_zero = Diana.Float.Simpson.zero.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_two_eq : c_two = Diana.Float.Simpson.two.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_three_eq : c_three = Diana.Float.Simpson.three.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_four_eq : c_four = Diana.Float.Simpson.four.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Definition pick (ys : list float) (f : Z -> Z) (k : Z) : list float :=
  map (fun j => Znth (f (Z.of_nat j)) ys) (seq 0 (Z.to_nat k)).

Lemma pick_succ (ys : list float) (f : Z -> Z) (k : Z) :
  0 <= k -> pick ys f (k + 1) = pick ys f k ++ (Znth (f k) ys :: nil).
Proof.
  intro Hk. unfold pick. rewrite Z2Nat.inj_add by lia.
  change (Z.to_nat 1) with 1%nat. rewrite Nat.add_1_r, seq_S, map_app. simpl.
  rewrite Z2Nat.id by lia. reflexivity.
Qed.

Definition c_odd (ys : list float) (k : Z) : float :=
  fold_left Float.add (pick ys (fun j => 2 * j + 1) k) c_zero.

Definition c_even (ys : list float) (k : Z) : float :=
  fold_left Float.add (pick ys (fun j => 2 * j + 2) (k - 1)) c_zero.

Lemma c_odd_step (ys : list float) (k : Z) :
  0 <= k -> c_odd ys (k + 1) = Float.add (c_odd ys k) (Znth (2 * k + 1) ys).
Proof. intro Hk. unfold c_odd. rewrite pick_succ, fold_left_app by lia. reflexivity. Qed.

Lemma c_even_step (ys : list float) (k : Z) :
  1 <= k -> c_even ys (k + 1) = Float.add (c_even ys k) (Znth (2 * k) ys).
Proof.
  intro Hk. unfold c_even. replace (k + 1 - 1) with (k - 1 + 1) by lia.
  rewrite pick_succ, fold_left_app by lia. simpl.
  replace (2 * (k - 1) + 2) with (2 * k) by lia. reflexivity.
Qed.

Definition c_s (ys : list float) : float :=
  Float.add
    (Float.add (Float.add (Znth 0 ys) (Znth (Zlength ys - 1) ys))
       (Float.mul c_four (c_odd ys (Zlength ys / 2))))
    (Float.mul c_two (c_even ys (Zlength ys / 2))).

Definition c_simpson (ys : list float) (h : float) : float :=
  Float.div (Float.mul h (c_s ys)) c_three.

Definition simpson_status (ys : list float) (h : float) : Z :=
  if Binary.is_finite 53 1024 (c_simpson ys h) then 0
  else if (Binary.is_finite 53 1024 h && forallb (Binary.is_finite 53 1024) ys)%bool
  then -5 else -1.

Lemma c_simpson_model (ys : list float) (h : float) :
  c_simpson ys h =
  Diana.Float.Simpson.fsimpson Float.binop_nan Float.binop_nan Float.binop_nan
    (Znth 0 ys) (Znth (Zlength ys - 1) ys)
    (pick ys (fun j => 2 * j + 1) (Zlength ys / 2))
    (pick ys (fun j => 2 * j + 2) (Zlength ys / 2 - 1)) h.
Proof.
  unfold c_simpson, c_s, c_odd, c_even, Diana.Float.Simpson.fsimpson,
    Diana.Float.Simpson.fsum.
  rewrite c_zero_eq, c_two_eq, c_three_eq, c_four_eq. reflexivity.
Qed.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition simpson_spec :=
  DECLARE _diana_simpson
  WITH sh : share, shr : share, y : val, res : val, ys : list float, h : float, r0 : val
  PRE [ tptr tdouble, tulong, tdouble, tptr tdouble ]
    PROP (readable_share sh; writable_share shr; 3 <= Zlength ys <= Int64.max_unsigned;
          Z.odd (Zlength ys) = true)
    PARAMS (y; Vlong (Int64.repr (Zlength ys)); Vfloat h; res)
    SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shr tdouble r0 res)
  POST [ tint ]
    PROP ()
    RETURN (Vint (Int.repr (simpson_status ys h)))
    SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
         data_at shr tdouble
           (if Binary.is_finite 53 1024 (c_simpson ys h) then Vfloat (c_simpson ys h) else r0)
           res).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; simpson_spec]).

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

Lemma body_diana_simpson : semax_body Vprog Gprog f_diana_simpson simpson_spec.
Proof.
  start_function.
  assert_PROP (isptr y /\ isptr res) as Hptr by entailer!.
  destruct Hptr as [Hy Hres].
  assert (Hn2 : Zlength ys = 2 * (Zlength ys / 2) + 1).
  { pose proof (Z.div_mod (Zlength ys) 2 ltac:(lia)) as Hdm.
    assert (Hodd : Z.odd (Zlength ys) = true) by assumption.
    rewrite Zmod_odd, Hodd in Hdm. lia. }
  join_zero _t'1.
  { subst y. contradiction. }
  { forward. entailer!. destruct res; try contradiction. reflexivity. }
  join_zero _t'2.
  { contradiction. }
  { forward. entailer!. destruct (zlt (Zlength ys) 3); [lia | reflexivity]. }
  join_zero _t'3.
  { contradiction. }
  { forward. entailer!. unfold Int64.modu.
    rewrite !Int64.unsigned_repr by rep_lia. rewrite Zmod_odd, H0. reflexivity. }
  forward_if.
  { contradiction. }
  forward.
  assert (Hp : Int64.divu (Int64.repr (Zlength ys)) (Int64.repr (Int.unsigned (Int.repr 2)))
               = Int64.repr (Zlength ys / 2)).
  { unfold Int64.divu. rewrite Int.unsigned_repr, !Int64.unsigned_repr by rep_lia.
    reflexivity. }
  rewrite Hp. clear Hp.
  forward.
  forward_for
    (fun k : Z => PROP (0 <= k <= Zlength ys / 2)
       LOCAL (temp _k (Vlong (Int64.repr k)); temp _so (Vfloat (c_odd ys k));
              temp _p (Vlong (Int64.repr (Zlength ys / 2))); temp _y y;
              temp _n (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res))
    continue:
    (fun k : Z => PROP (0 <= k < Zlength ys / 2)
       LOCAL (temp _k (Vlong (Int64.repr k)); temp _so (Vfloat (c_odd ys (k + 1)));
              temp _p (Vlong (Int64.repr (Zlength ys / 2))); temp _y y;
              temp _n (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res))
    break:
    (PROP ()
       LOCAL (temp _so (Vfloat (c_odd ys (Zlength ys / 2)));
              temp _p (Vlong (Int64.repr (Zlength ys / 2))); temp _y y;
              temp _n (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res)).
  { forward. Exists 0. entailer!. }
  { entailer!. }
  { forward. forward. Exists a. entailer!. rewrite c_odd_step by lia. reflexivity. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys / 2) by lia. subst a. entailer!. }
  forward.
  forward_for
    (fun k : Z => PROP (1 <= k <= Zlength ys / 2)
       LOCAL (temp _k (Vlong (Int64.repr k)); temp _se (Vfloat (c_even ys k));
              temp _so (Vfloat (c_odd ys (Zlength ys / 2)));
              temp _p (Vlong (Int64.repr (Zlength ys / 2))); temp _y y;
              temp _n (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res))
    continue:
    (fun k : Z => PROP (1 <= k < Zlength ys / 2)
       LOCAL (temp _k (Vlong (Int64.repr k)); temp _se (Vfloat (c_even ys (k + 1)));
              temp _so (Vfloat (c_odd ys (Zlength ys / 2)));
              temp _p (Vlong (Int64.repr (Zlength ys / 2))); temp _y y;
              temp _n (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res))
    break:
    (PROP ()
       LOCAL (temp _se (Vfloat (c_even ys (Zlength ys / 2)));
              temp _so (Vfloat (c_odd ys (Zlength ys / 2))); temp _y y;
              temp _n (Vlong (Int64.repr (Zlength ys))); temp _h (Vfloat h);
              temp _result res)
       SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
            data_at shr tdouble r0 res)).
  { forward. Exists 1. entailer!. }
  { entailer!. }
  { forward. forward. Exists a. entailer!. rewrite c_even_step by lia. reflexivity. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys / 2) by lia. subst a. entailer!. }
  forward. forward.
  rewrite !Znth_map by lia.
  forward. forward.
  forward_call (c_simpson ys h).
  destruct (Binary.is_finite 53 1024 (c_simpson ys h)) eqn:Hfin.
  - forward_if.
    + discriminate.
    + forward. forward. unfold simpson_status. rewrite Hfin. entailer!.
  - forward_if.
    + assert (Hc : Binary.is_finite 53 1024 (c_simpson ys h) = false) by exact Hfin.
      forward_call h.
      destruct (Binary.is_finite 53 1024 h) eqn:Hh.
      2: { forward_if; [| contradiction]. forward.
           unfold simpson_status. rewrite Hc, Hh. entailer!. }
      forward_if; [discriminate |].
      forward_for
        (fun j : Z => PROP (0 <= j <= Zlength ys;
                            forallb (Binary.is_finite 53 1024) (sublist 0 j ys) = true)
           LOCAL (temp _k (Vlong (Int64.repr j)); temp _y y;
                  temp _n (Vlong (Int64.repr (Zlength ys))))
           SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                data_at shr tdouble r0 res))
        continue:
        (fun j : Z => PROP (0 <= j < Zlength ys;
                            forallb (Binary.is_finite 53 1024) (sublist 0 (j + 1) ys) = true)
           LOCAL (temp _k (Vlong (Int64.repr j)); temp _y y;
                  temp _n (Vlong (Int64.repr (Zlength ys))))
           SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                data_at shr tdouble r0 res))
        break:
        (PROP (forallb (Binary.is_finite 53 1024) ys = true)
           LOCAL ()
           SEP (data_at sh (tarray tdouble (Zlength ys)) (map Vfloat ys) y;
                data_at shr tdouble r0 res)).
      { forward. Exists 0. entailer!. }
      { entailer!. }
      { match goal with |- context [temp _k (Vlong (Int64.repr ?x))] => rename x into j end.
        forward. forward_call (Znth j ys).
        destruct (Binary.is_finite 53 1024 (Znth j ys)) eqn:Hyj.
        2: { forward_if; [| contradiction]. forward.
             assert (Hys : forallb (Binary.is_finite 53 1024) ys = false)
               by (apply (Diana.VST.Euler.forallb_false ys j); [lia | exact Hyj]).
             unfold simpson_status. rewrite Hc, Hh, Hys. entailer!. }
        forward_if; [discriminate |].
        forward. Exists j. entailer!.
        rewrite Diana.VST.Euler.forallb_sublist_succ by lia. rewrite Hyj, andb_true_r. auto. }
      { match goal with |- context [temp _k (Vlong (Int64.repr ?x))] => rename x into j end.
        forward. Exists (j + 1). entailer!. }
      { match goal with H : forallb _ (sublist 0 ?x ys) = true |- _ =>
          assert (x = Zlength ys) by lia; subst x end.
        rewrite sublist_same in * by lia. entailer!. }
      forward.
      match goal with H : forallb _ ys = true |- _ => unfold simpson_status; rewrite Hc, Hh, H end.
      entailer!.
    + contradiction.
Qed.
