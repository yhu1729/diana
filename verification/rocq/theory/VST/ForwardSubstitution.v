From VST.floyd Require Import proofauto.
From Diana.Clight Require Import forward_substitution_aarch64_macos.
From Diana.VST Require Bisection.
From Diana.VST Require Import Matrix Substitution Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition forward_substitution_spec :=
  DECLARE _diana_forward_substitution
  WITH shl : share, shb : share, shx : share, l : val, b : val, x : val,
       ll : list float, bl : list float, n : Z, ox : list val
  PRE [ tptr tdouble, tulong, tptr tdouble, tptr tdouble ]
    PROP (readable_share shl; readable_share shb; writable_share shx; 1 <= n;
          (n * n)%Z <= Int64.max_unsigned; Zlength ll = (n * n)%Z; Zlength bl = n;
          Zlength ox = n)
    PARAMS (l; Vlong (Int64.repr n); b; x)
    SEP (data_at shl (tarray tdouble ((n * n)%Z)) (map Vfloat ll) l;
         data_at shb (tarray tdouble n) (map Vfloat bl) b;
         data_at shx (tarray tdouble n) ox x)
  POST [ tint ]
    EX st : Z, EX xs : list val,
    PROP ((st = 0 /\ lower_finite ll n /\ vec_finite bl n /\ diag_nonzero ll n /\
           fwd_finite ll bl n /\ xs = map Vfloat (c_fwd_list ll bl n)) \/
          (st = -1 /\ ~ (lower_finite ll n /\ vec_finite bl n) /\ xs = ox) \/
          (st = -4 /\ lower_finite ll n /\ vec_finite bl n /\ ~ diag_nonzero ll n /\ xs = ox) \/
          (st = -1 /\ lower_finite ll n /\ vec_finite bl n /\ diag_nonzero ll n /\
           exists i, 0 <= i < n /\
             (forall i', 0 <= i' < i -> Binary.is_finite 53 1024 (c_fwd ll bl n i') = true) /\
             Binary.is_finite 53 1024 (c_fwd ll bl n i) = false /\
             xs = lpre (c_fwd_list ll bl n) ox n i))
    RETURN (Vint (Int.repr st))
    SEP (data_at shl (tarray tdouble ((n * n)%Z)) (map Vfloat ll) l;
         data_at shb (tarray tdouble n) (map Vfloat bl) b;
         data_at shx (tarray tdouble n) xs x).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; forward_substitution_spec]).

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

Lemma body_diana_forward_substitution :
  semax_body Vprog Gprog f_diana_forward_substitution forward_substitution_spec.
Proof.
  start_function.
  assert (Hn0 : n <= Int64.max_unsigned) by nia.
  assert_PROP (isptr l /\ isptr b /\ isptr x) as Hptr by entailer!.
  destruct Hptr as [Hl [Hb Hx]].
  join_zero _t'1.
  { subst l. contradiction. }
  { forward. entailer!. destruct b; try contradiction. reflexivity. }
  join_zero _t'2.
  { contradiction. }
  { forward. entailer!. destruct x; try contradiction. reflexivity. }
  join_zero _t'3.
  { contradiction. }
  { forward. entailer!.
    match goal with |- context [zeq ?m 0] => destruct (zeq m 0); [lia | reflexivity] end. }
  join_zero _t'4.
  { contradiction. }
  { forward.
    - entailer!.
      match goal with H : Int64.repr _ = _ |- _ =>
        apply (f_equal Int64.unsigned) in H; rewrite Int64.unsigned_repr in H by nia;
        discriminate H || (simpl in H; lia) end.
    - entailer!. rewrite no_overflow by assumption. reflexivity. }
  forward_if.
  { contradiction. }
  (* every entry on or below the diagonal of l is finite *)
  forward_for
    (fun j : Z => PROP (0 <= j <= n;
        forall i' j', 0 <= j' < j -> j' <= i' < n ->
          Binary.is_finite 53 1024 (Znth (i' + j' * n) ll) = true)
       LOCAL (temp _j (Vlong (Int64.repr j)); temp _l l; temp _n (Vlong (Int64.repr n));
              temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    continue:
    (fun j : Z => PROP (0 <= j < n;
        forall i' j', 0 <= j' < j + 1 -> j' <= i' < n ->
          Binary.is_finite 53 1024 (Znth (i' + j' * n) ll) = true)
       LOCAL (temp _j (Vlong (Int64.repr j)); temp _l l; temp _n (Vlong (Int64.repr n));
              temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    break:
    (PROP (lower_finite ll n)
       LOCAL (temp _l l; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x)).
  { forward. Exists 0. entailer!; try (intros; lia). }
  { entailer!. }
  { rename a into j. lt_of_ltu.
    apply <- semax_seq_skip.
    forward_for
      (fun i : Z => PROP (j <= i <= n; 0 <= j < n;
          forall i' j', 0 <= j' < j -> j' <= i' < n ->
            Binary.is_finite 53 1024 (Znth (i' + j' * n) ll) = true;
          forall i', j <= i' < i -> Binary.is_finite 53 1024 (Znth (i' + j * n) ll) = true)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _j (Vlong (Int64.repr j)); temp _l l;
                temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) ox x))
      continue:
      (fun i : Z => PROP (j <= i < n; 0 <= j < n;
          forall i' j', 0 <= j' < j -> j' <= i' < n ->
            Binary.is_finite 53 1024 (Znth (i' + j' * n) ll) = true;
          forall i', j <= i' < i + 1 -> Binary.is_finite 53 1024 (Znth (i' + j * n) ll) = true)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _j (Vlong (Int64.repr j)); temp _l l;
                temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) ox x))
      break:
      (PROP (0 <= j < n;
          forall i' j', 0 <= j' < j + 1 -> j' <= i' < n ->
            Binary.is_finite 53 1024 (Znth (i' + j' * n) ll) = true)
         LOCAL (temp _j (Vlong (Int64.repr j)); temp _l l; temp _n (Vlong (Int64.repr n));
                temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) ox x)).
    { forward. Exists j. entailer!; try (intros; lia). }
    { entailer!. }
    { rename a into i. lt_of_ltu.
      assert (Hidx : 0 <= i + j * n < n * n) by nia.
      forward.
      rewrite Znth_map by lia.
      forward_call (Znth (i + j * n) ll).
      destruct (Binary.is_finite 53 1024 (Znth (i + j * n) ll)) eqn:Hfin.
      - forward_if; [discriminate |].
        forward. Exists i. entailer!. intros i' Hi'.
        destruct (zeq i' i) as [-> | Hne]; [exact Hfin |].
        match goal with H : forall i', j <= i' < i -> _ |- _ => apply H; lia end.
      - forward_if.
        + forward. Exists (-1) ox. entailer!.
          right. left. split; [reflexivity |]. split; [| reflexivity].
          intros [Hlf _]. rewrite (Hlf i j) in Hfin by lia. discriminate.
        + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
    { rename a into i. forward. Exists (i + 1). entailer!. }
    { rename a into i. lt_of_ltu.
      entailer!. intros i' j' Hj' Hi'.
      destruct (zlt j' j).
      - match goal with H : forall i' j', 0 <= j' < j -> _ |- _ => apply H; lia end.
      - replace j' with j by lia.
        match goal with H : forall i', j <= i' < i -> _ |- _ => apply H; lia end. }
    forward. Exists j. entailer!. }
  { rename a into j. forward. Exists (j + 1). entailer!. }
  { rename a into j. lt_of_ltu.
    entailer!. intros i' j' Hj' Hi'.
    match goal with H : forall i' j', 0 <= j' < j -> _ |- _ => apply H; lia end. }
  match goal with H : lower_finite _ _ |- _ => rename H into Hlf end.
  (* every entry of b is finite *)
  forward_for
    (fun i : Z => PROP (0 <= i <= n;
        forall i', 0 <= i' < i -> Binary.is_finite 53 1024 (Znth i' bl) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
              temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    continue:
    (fun i : Z => PROP (0 <= i < n;
        forall i', 0 <= i' < i + 1 -> Binary.is_finite 53 1024 (Znth i' bl) = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
              temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    break:
    (PROP (vec_finite bl n)
       LOCAL (temp _l l; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x)).
  { forward. Exists 0. entailer!; try (intros; lia). }
  { entailer!. }
  { rename a into i. lt_of_ltu.
    forward.
    rewrite Znth_map by lia.
    forward_call (Znth i bl).
    destruct (Binary.is_finite 53 1024 (Znth i bl)) eqn:Hfin.
    - forward_if; [discriminate |].
      forward. Exists i. entailer!. intros i' Hi'.
      destruct (zeq i' i) as [-> | Hne]; [exact Hfin |].
      match goal with H : forall i', 0 <= i' < i -> _ |- _ => apply H; lia end.
    - forward_if.
      + forward. Exists (-1) ox. entailer!.
        right. left. split; [reflexivity |]. split; [| reflexivity].
        intros [_ Hvf]. rewrite (Hvf i) in Hfin by lia. discriminate.
      + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
  { rename a into i. forward. Exists (i + 1). entailer!. }
  { rename a into i. lt_of_ltu.
    entailer!. intros i' Hi'.
    match goal with H : forall i', 0 <= i' < i -> _ |- _ => apply H; lia end. }
  match goal with H : vec_finite _ _ |- _ => rename H into Hvf end.
  (* no diagonal entry is zero *)
  forward_for
    (fun i : Z => PROP (0 <= i <= n;
        forall i', 0 <= i' < i -> Float.cmp Ceq (Znth (i' + i' * n) ll) Float.zero = false)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
              temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    continue:
    (fun i : Z => PROP (0 <= i < n;
        forall i', 0 <= i' < i + 1 -> Float.cmp Ceq (Znth (i' + i' * n) ll) Float.zero = false)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
              temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    break:
    (PROP (diag_nonzero ll n)
       LOCAL (temp _l l; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x)).
  { forward. Exists 0. entailer!; try (intros; lia). }
  { entailer!. }
  { rename a into i. lt_of_ltu.
    assert (Hii : 0 <= i + i * n < n * n) by nia.
    forward.
    rewrite Znth_map by lia.
    forward_if.
    - forward. Exists (-4) ox. entailer!.
      right. right. left. split; [reflexivity |]. split; [exact Hlf |]. split; [exact Hvf |].
      split; [| reflexivity].
      intro Hdz. specialize (Hdz i ltac:(lia)).
      match goal with H : Float.cmp Ceq _ (Float.of_bits (Int64.repr 0)) = true |- _ =>
        rewrite zero_float, Hdz in H; discriminate H end.
    - forward. Exists i. entailer!. intros i' Hi'.
      destruct (zeq i' i) as [-> | Hne].
      + match goal with H : Float.cmp Ceq _ (Float.of_bits (Int64.repr 0)) = false |- _ =>
          rewrite zero_float in H; exact H end.
      + match goal with H : forall i', 0 <= i' < i -> _ |- _ => apply H; lia end. }
  { rename a into i. forward. Exists (i + 1). entailer!. }
  { rename a into i. lt_of_ltu.
    entailer!. intros i' Hi'.
    match goal with H : forall i', 0 <= i' < i -> _ |- _ => apply H; lia end. }
  match goal with H : diag_nonzero _ _ |- _ => rename H into Hdz end.
  (* the solve: x[i] = (b[i] - l[i] * x[0] - ... - l[i + (i-1)*n] * x[i-1]) / l[i + i*n] *)
  assert (HX : Zlength (c_fwd_list ll bl n) = n) by (apply Zlength_c_fwd_list; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= n;
        forall i', 0 <= i' < i -> Binary.is_finite 53 1024 (c_fwd ll bl n i') = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
              temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (lpre (c_fwd_list ll bl n) ox n i) x))
    continue:
    (fun i : Z => PROP (0 <= i < n;
        forall i', 0 <= i' < i + 1 -> Binary.is_finite 53 1024 (c_fwd ll bl n i') = true)
       LOCAL (temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
              temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (lpre (c_fwd_list ll bl n) ox n (i + 1)) x))
    break:
    (PROP (fwd_finite ll bl n)
       LOCAL (temp _l l; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (lpre (c_fwd_list ll bl n) ox n n) x)).
  { forward. Exists 0. rewrite lpre_zero by lia. entailer!; intros; lia. }
  { entailer!. }
  { rename a into i. lt_of_ltu.
    assert (Hii : 0 <= i + i * n < n * n) by nia.
    forward.
    rewrite Znth_map by lia.
    forward_for
      (fun k : Z => PROP (0 <= k <= i)
         LOCAL (temp _k (Vlong (Int64.repr k)); temp _s (Vfloat (c_fdot ll bl n i k));
                temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
                temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) (lpre (c_fwd_list ll bl n) ox n i) x))
      continue:
      (fun k : Z => PROP (0 <= k < i)
         LOCAL (temp _k (Vlong (Int64.repr k)); temp _s (Vfloat (c_fdot ll bl n i (k + 1)));
                temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
                temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) (lpre (c_fwd_list ll bl n) ox n i) x))
      break:
      (PROP ()
         LOCAL (temp _s (Vfloat (c_fdot ll bl n i i));
                temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
                temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) (lpre (c_fwd_list ll bl n) ox n i) x)).
    { forward. Exists 0. entailer!. }
    { entailer!. }
    { rename a into k. lt_of_ltu.
      assert (Hik : 0 <= i + k * n < n * n) by nia.
      forward.
      rewrite Znth_map by lia.
      forward.
      { entailer!. rewrite lpre_get by lia. exact I. }
      rewrite lpre_get by lia. rewrite Znth_c_fwd_list by lia.
      forward. Exists k. entailer!. rewrite c_fdot_succ by lia. reflexivity. }
    { rename a into k. forward. Exists (k + 1). entailer!. }
    { rename a into k. lt_of_ltu. replace k with i by lia. entailer!. }
    forward.
    rewrite Znth_map by lia.
    forward.
    rewrite <- c_fwd_eq by lia.
    forward_call (c_fwd ll bl n i).
    destruct (Binary.is_finite 53 1024 (c_fwd ll bl n i)) eqn:Hfin.
    - forward_if; [discriminate |].
      replace (Vfloat (c_fwd ll bl n i)) with (Vfloat (Znth i (c_fwd_list ll bl n)))
        by (rewrite Znth_c_fwd_list by lia; reflexivity).
      forward. Exists i. entailer!.
      + intros i' Hi'. destruct (zeq i' i) as [-> | Hne]; [exact Hfin |].
        match goal with H : forall i', 0 <= i' < i -> _ |- _ => apply H; lia end.
      + rewrite lpre_step by lia. cancel.
    - forward_if.
      + set (xs := lpre (c_fwd_list ll bl n) ox n i).
        forward. Exists (-1) xs. entailer!.
        right. right. right. split; [reflexivity |]. split; [exact Hlf |].
        split; [exact Hvf |]. split; [exact Hdz |].
        exists i. split; [lia |]. split; [| split; [exact Hfin | reflexivity]].
        match goal with H : forall i', 0 <= i' < i -> _ |- _ => exact H end.
      + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
  { rename a into i. forward. Exists (i + 1). entailer!. }
  { rename a into i. lt_of_ltu. replace i with n by lia.
    entailer!. intros i' Hi'.
    match goal with H : forall i', 0 <= i' < _ -> _ |- _ => apply H; lia end. }
  rewrite lpre_full by lia.
  set (xs := map Vfloat (c_fwd_list ll bl n)).
  forward. Exists 0 xs. entailer!.
  left. repeat split; assumption.
Qed.
