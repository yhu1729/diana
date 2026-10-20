From VST.floyd Require Import proofauto.
From Diana.Clight Require Import axpy_aarch64_macos.
From Diana.Float Require Axpy.
From Diana.VST Require Bisection.
From Diana.VST Require Import Euler Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

(* The binary64 model of the kernel with CompCert's operations: each component is the Euler
   step c_step with a as the step size, y as the state and x as the slope. *)
Definition c_update (a x y : float) : float := c_step a y x.

Fixpoint c_axpy (a : float) (xs ys : list float) : list float :=
  match xs, ys with
  | x :: xs', y :: ys' => c_update a x y :: c_axpy a xs' ys'
  | _, _ => nil
  end.

Definition axpy_status (a : float) (xs ys : list float) : Z :=
  if negb (Binary.is_finite 53 1024 a) then -1
  else if forallb (Binary.is_finite 53 1024) (c_axpy a xs ys) then 0
  else if (forallb (Binary.is_finite 53 1024) xs &&
           forallb (Binary.is_finite 53 1024) ys)%bool
  then -5 else -1.

Lemma c_axpy_euler (a : float) (xs ys : list float) : c_axpy a xs ys = c_euler a ys xs.
Proof.
  revert ys. induction xs as [| x xs IH]; intros [| y ys]; try reflexivity.
  cbn [c_axpy c_euler]. f_equal. apply IH.
Qed.

Lemma c_axpy_model (a : float) (xs ys : list float) :
  c_axpy a xs ys = Diana.Float.Axpy.faxpy Float.binop_nan Float.binop_nan a xs ys.
Proof.
  revert ys. induction xs as [| x xs IH]; intros [| y ys]; try reflexivity.
  cbn [c_axpy]. unfold Diana.Float.Axpy.faxpy. cbn [combine map fst snd].
  f_equal. apply IH.
Qed.

Lemma Zlength_c_axpy (a : float) (xs ys : list float) :
  Zlength ys = Zlength xs -> Zlength (c_axpy a xs ys) = Zlength xs.
Proof. intro H. rewrite c_axpy_euler. rewrite Zlength_c_euler by lia. lia. Qed.

Lemma Znth_c_axpy (a : float) (xs ys : list float) (i : Z) :
  Zlength ys = Zlength xs -> 0 <= i < Zlength xs ->
  Znth i (c_axpy a xs ys) = c_update a (Znth i xs) (Znth i ys).
Proof.
  intros Hl Hi. rewrite c_axpy_euler. unfold c_update. apply Znth_c_euler; lia.
Qed.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition axpy_spec :=
  DECLARE _diana_axpy
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
    RETURN (Vint (Int.repr (axpy_status a xs ys)))
    SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
         data_at shy (tarray tdouble (Zlength xs))
           (map Vfloat (if Z.eqb (axpy_status a xs ys) 0 then c_axpy a xs ys else ys)) y).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; axpy_spec]).

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

Lemma body_diana_axpy : semax_body Vprog Gprog f_diana_axpy axpy_spec.
Proof.
  start_function.
  assert_PROP (isptr x /\ isptr y) as Hptr by entailer!.
  destruct Hptr as [Hx Hy].
  join_zero _t'1.
  { subst x. contradiction. }
  { forward. entailer!. destruct y; try contradiction. reflexivity. }
  forward_if.
  { contradiction. }
  forward_call a.
  destruct (Binary.is_finite 53 1024 a) eqn:Ha.
  2: { forward_if; [| contradiction]. forward.
       unfold axpy_status. rewrite Ha. entailer!. }
  forward_if; [discriminate |].
  set (L := c_axpy a xs ys).
  assert (HL : Zlength L = Zlength xs) by (apply Zlength_c_axpy; lia).
  assert (HZ : forall i, 0 <= i < Zlength xs -> Znth i L = c_update a (Znth i xs) (Znth i ys))
    by (intros; apply Znth_c_axpy; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= Zlength xs;
                        forallb (Binary.is_finite 53 1024) (sublist 0 i L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _a (Vfloat a); temp _x x;
              temp _n (Vlong (Int64.repr (Zlength xs))); temp _y y)
       SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shy (tarray tdouble (Zlength xs)) (map Vfloat ys) y))
    continue:
    (fun i : Z => PROP (0 <= i < Zlength xs;
                        forallb (Binary.is_finite 53 1024) (sublist 0 (i + 1) L) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _a (Vfloat a); temp _x x;
              temp _n (Vlong (Int64.repr (Zlength xs))); temp _y y)
       SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shy (tarray tdouble (Zlength xs)) (map Vfloat ys) y))
    break:
    (PROP (forallb (Binary.is_finite 53 1024) L = true)
       LOCAL (temp _a (Vfloat a); temp _x x; temp _n (Vlong (Int64.repr (Zlength xs)));
              temp _y y)
       SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
            data_at shy (tarray tdouble (Zlength xs)) (map Vfloat ys) y)).
  { forward. Exists 0. entailer!. }
  { entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?v))] => rename v into i end.
    forward. forward. forward.
    forward_call (c_update a (Znth i xs) (Znth i ys)).
    destruct (Binary.is_finite 53 1024 (c_update a (Znth i xs) (Znth i ys))) eqn:Hfin.
    - forward_if.
      + discriminate.
      + forward. Exists i. entailer!. rewrite forallb_sublist_succ by lia.
        rewrite HZ by lia. rewrite Hfin, andb_true_r. assumption.
    - forward_if.
      + assert (Hb : forallb (Binary.is_finite 53 1024) L = false).
        { apply (forallb_false L i); [lia |]. rewrite HZ by lia. exact Hfin. }
        forward_for
          (fun j : Z => PROP (0 <= j <= Zlength xs;
                              forallb (Binary.is_finite 53 1024) (sublist 0 j xs) = true;
                              forallb (Binary.is_finite 53 1024) (sublist 0 j ys) = true)
             LOCAL (temp _j (Vlong (Int64.repr j)); temp _x x;
                    temp _n (Vlong (Int64.repr (Zlength xs))); temp _y y)
             SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
                  data_at shy (tarray tdouble (Zlength xs)) (map Vfloat ys) y))
          continue:
          (fun j : Z => PROP (0 <= j < Zlength xs;
                              forallb (Binary.is_finite 53 1024) (sublist 0 (j + 1) xs) = true;
                              forallb (Binary.is_finite 53 1024) (sublist 0 (j + 1) ys) = true)
             LOCAL (temp _j (Vlong (Int64.repr j)); temp _x x;
                    temp _n (Vlong (Int64.repr (Zlength xs))); temp _y y)
             SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
                  data_at shy (tarray tdouble (Zlength xs)) (map Vfloat ys) y))
          break:
          (PROP (forallb (Binary.is_finite 53 1024) xs = true;
                 forallb (Binary.is_finite 53 1024) ys = true)
             LOCAL ()
             SEP (data_at shx (tarray tdouble (Zlength xs)) (map Vfloat xs) x;
                  data_at shy (tarray tdouble (Zlength xs)) (map Vfloat ys) y)).
        { forward. Exists 0. entailer!. }
        { entailer!. }
        { match goal with |- context [temp _j (Vlong (Int64.repr ?v))] => rename v into j end.
          forward. forward_call (Znth j xs).
          destruct (Binary.is_finite 53 1024 (Znth j xs)) eqn:Hxj.
          2: { forward_if; [| contradiction]. forward.
               assert (Hxs : forallb (Binary.is_finite 53 1024) xs = false)
                 by (apply (forallb_false xs j); [lia | exact Hxj]).
               unfold axpy_status. fold L. rewrite Ha, Hb, Hxs. entailer!. }
          forward_if; [discriminate |].
          forward. forward_call (Znth j ys).
          destruct (Binary.is_finite 53 1024 (Znth j ys)) eqn:Hyj.
          2: { forward_if; [| contradiction]. forward.
               assert (Hys : forallb (Binary.is_finite 53 1024) ys = false)
                 by (apply (forallb_false ys j); [lia | exact Hyj]).
               unfold axpy_status. fold L. rewrite Ha, Hb, Hys, andb_false_r. entailer!. }
          forward_if; [discriminate |].
          forward. Exists j. entailer!.
          rewrite !forallb_sublist_succ by lia. rewrite Hxj, Hyj, !andb_true_r. auto. }
        { match goal with |- context [temp _j (Vlong (Int64.repr ?v))] => rename v into j end.
          forward. Exists (j + 1). entailer!. }
        { match goal with |- context [temp _j (Vlong (Int64.repr ?v))] => rename v into j end.
          assert (j = Zlength xs) by lia. subst j.
          rewrite !sublist_same in * by lia. entailer!. }
        forward.
        match goal with
        | Hxs : forallb _ xs = true, Hys : forallb _ ys = true |- _ =>
            unfold axpy_status; fold L; rewrite Ha, Hb, Hxs, Hys
        end.
        entailer!.
      + contradiction. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?v))] => rename v into i end.
    forward. Exists (i + 1). entailer!. }
  { match goal with |- context [temp _i (Vlong (Int64.repr ?v))] => rename v into i end.
    assert (i = Zlength xs) by lia. subst i. rewrite sublist_same in * by lia. entailer!. }
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
    forward. forward. forward. forward. Exists i. entailer!.
    rewrite !Znth_map by (try (rewrite Zlength_app, !Zlength_sublist); lia).
    rewrite Hyi.
    match goal with |- context [upd_Znth i _ ?v] =>
      replace v with (Vfloat (c_update a (Znth i xs) (Znth i ys))) by reflexivity end.
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
  forward. unfold axpy_status. fold L. rewrite Ha.
  match goal with H : forallb _ L = true |- _ => rewrite H end.
  entailer!.
Qed.
