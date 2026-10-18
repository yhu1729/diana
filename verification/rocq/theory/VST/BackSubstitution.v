From VST.floyd Require Import proofauto.
From Diana.Clight Require Import back_substitution_aarch64_macos.
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

Definition back_substitution_spec :=
  DECLARE _diana_back_substitution
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
           bwd_finite ll bl n /\ xs = map Vfloat (c_bwd_list ll bl n)) \/
          (st = -1 /\ ~ (lower_finite ll n /\ vec_finite bl n) /\ xs = ox) \/
          (st = -4 /\ lower_finite ll n /\ vec_finite bl n /\ ~ diag_nonzero ll n /\ xs = ox) \/
          (st = -5 /\ lower_finite ll n /\ vec_finite bl n /\ diag_nonzero ll n /\
           exists i, 0 <= i < n /\
             (forall i', i < i' < n -> Binary.is_finite 53 1024 (c_bwd ll bl n i') = true) /\
             Binary.is_finite 53 1024 (c_bwd ll bl n i) = false /\
             xs = lsuf (c_bwd_list ll bl n) ox n (i + 1)))
    RETURN (Vint (Int.repr st))
    SEP (data_at shl (tarray tdouble ((n * n)%Z)) (map Vfloat ll) l;
         data_at shb (tarray tdouble n) (map Vfloat bl) b;
         data_at shx (tarray tdouble n) xs x).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; back_substitution_spec]).

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

Lemma body_diana_back_substitution :
  semax_body Vprog Gprog f_diana_back_substitution back_substitution_spec.
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
  (* the solve, i = n - 1 down to 0:
     x[i] = (b[i] - l[n-1 + i*n] * x[n-1] - ... - l[i+1 + i*n] * x[i+1]) / l[i + i*n] *)
  assert (HY : Zlength (c_bwd_list ll bl n) = n) by (apply Zlength_c_bwd_list; lia).
  forward.
  forward_while
    (EX i : Z,
     PROP (0 <= i <= n;
           forall i', i <= i' < n -> Binary.is_finite 53 1024 (c_bwd ll bl n i') = true)
     LOCAL (temp _i (Vlong (Int64.repr i)); temp _l l; temp _n (Vlong (Int64.repr n));
            temp _b b; temp _x x)
     SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
          data_at shb (tarray tdouble n) (map Vfloat bl) b;
          data_at shx (tarray tdouble n) (lsuf (c_bwd_list ll bl n) ox n i) x)).
  { Exists n. rewrite lsuf_zero by lia. entailer!; intros; lia. }
  { entailer!. }
  { rename HRE into Hi0.
    forward.
    assert (Hii : 0 <= i - 1 + (i - 1) * n < n * n) by nia.
    forward.
    rewrite Znth_map by lia.
    forward_for
      (fun k : Z => PROP (i - 1 <= k <= n - 1)
         LOCAL (temp _k (Vlong (Int64.repr k));
                temp _s (Vfloat (c_bdot ll bl n (i - 1) (n - 1 - k)));
                temp _i (Vlong (Int64.repr (i - 1))); temp _l l; temp _n (Vlong (Int64.repr n));
                temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) (lsuf (c_bwd_list ll bl n) ox n i) x))
      continue:
      (fun k : Z => PROP (i - 1 < k <= n - 1)
         LOCAL (temp _k (Vlong (Int64.repr k));
                temp _s (Vfloat (c_bdot ll bl n (i - 1) (n - k)));
                temp _i (Vlong (Int64.repr (i - 1))); temp _l l; temp _n (Vlong (Int64.repr n));
                temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) (lsuf (c_bwd_list ll bl n) ox n i) x))
      break:
      (PROP ()
         LOCAL (temp _s (Vfloat (c_bdot ll bl n (i - 1) (n - 1 - (i - 1))));
                temp _i (Vlong (Int64.repr (i - 1))); temp _l l; temp _n (Vlong (Int64.repr n));
                temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) l;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n) (lsuf (c_bwd_list ll bl n) ox n i) x)).
    { forward. Exists (n - 1). replace (n - 1 - (n - 1)) with 0 by lia. entailer!. }
    { entailer!. }
    { rename a into k.
      assert (Hk : i - 1 < k) by (lt_of_ltu; lia).
      assert (Hki : 0 <= k + (i - 1) * n < n * n) by nia.
      forward.
      rewrite Znth_map by lia.
      forward.
      { entailer!. rewrite lsuf_get by lia. exact I. }
      rewrite lsuf_get by lia. rewrite Znth_c_bwd_list by lia.
      forward. Exists k.
      replace (n - k) with (n - 1 - k + 1) by lia.
      rewrite c_bdot_succ by lia. replace (n - 1 - (n - 1 - k)) with k by lia.
      entailer!. }
    { rename a into k. forward. Exists (k - 1). replace (n - 1 - (k - 1)) with (n - k) by lia.
      entailer!. }
    { rename a into k.
      assert (Hk : k <= i - 1) by (lt_of_ltu; lia).
      replace k with (i - 1) by lia. entailer!. }
    forward.
    rewrite Znth_map by lia.
    forward.
    rewrite <- c_bwd_eq by lia.
    forward_call (c_bwd ll bl n (i - 1)).
    destruct (Binary.is_finite 53 1024 (c_bwd ll bl n (i - 1))) eqn:Hfin.
    - forward_if; [discriminate |].
      replace (Vfloat (c_bwd ll bl n (i - 1))) with (Vfloat (Znth (i - 1) (c_bwd_list ll bl n)))
        by (rewrite Znth_c_bwd_list by lia; reflexivity).
      forward. Exists (i - 1). entailer!.
      + intros i' Hi'. destruct (zeq i' (i - 1)) as [-> | Hne]; [exact Hfin |].
        match goal with H : forall i', i <= i' < _ -> _ |- _ => apply H; lia end.
      + rewrite lsuf_step by lia. cancel.
    - forward_if.
      + set (xs := lsuf (c_bwd_list ll bl n) ox n i).
        forward. Exists (-5) xs. entailer!.
        right. right. right. split; [reflexivity |]. split; [exact Hlf |].
        split; [exact Hvf |]. split; [exact Hdz |].
        exists (i - 1). split; [lia |].
        split; [| split; [exact Hfin | unfold xs; f_equal; lia]].
        intros i' Hi'.
        match goal with H : forall i', i <= i' < _ -> _ |- _ => apply H; lia end.
      + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
  assert (Hi0 : i = 0) by lia.
  subst i.
  rewrite lsuf_full by lia.
  set (xs := map Vfloat (c_bwd_list ll bl n)).
  forward. Exists 0 xs. entailer!.
  left. repeat split; assumption.
Qed.
