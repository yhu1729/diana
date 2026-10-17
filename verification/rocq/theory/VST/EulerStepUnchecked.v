From VST.floyd Require Import proofauto.
From Diana.Clight Require Import euler_step_unchecked_aarch64_macos.
From Diana.VST Require Euler.
From Diana.VST Require Import Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition step_spec :=
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
         data_at sho (tarray tdouble (Zlength ys)) (map Vfloat (Diana.VST.Euler.c_euler h ys fs)) out).

Definition Gprog : funspecs :=
  ltac:(with_library prog [step_spec]).

Lemma body_diana_euler_step_unchecked :
  semax_body Vprog Gprog f_diana_euler_step_unchecked step_spec.
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
  set (L := Diana.VST.Euler.c_euler h ys fs).
  assert (HL : Zlength L = Zlength ys) by (apply Diana.VST.Euler.Zlength_c_euler; lia).
  assert (HZ : forall i, 0 <= i < Zlength ys -> Znth i L = Diana.VST.Euler.c_step h (Znth i ys) (Znth i fs))
    by (intros; apply Diana.VST.Euler.Znth_c_euler; lia).
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
      replace v with (Vfloat (Diana.VST.Euler.c_step h (Znth a ys) (Znth a fs))) by reflexivity end.
    apply derives_refl'. f_equal.
    rewrite (sublist_split 0 a (a + 1) L) by lia. rewrite (sublist_len_1 a L) by lia.
    rewrite HZ by lia. list_solve. }
  { forward. Exists (a + 1). entailer!. }
  { assert (a = Zlength ys) by lia. subst a. entailer!.
    rewrite sublist_same, sublist_nil, app_nil_r by lia. cancel. }
  forward.
Qed.
