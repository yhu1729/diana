From VST.floyd Require Import proofauto.
From Diana.Clight Require Import cholesky_aarch64_macos.
From Diana.Float Require Cholesky.
From Diana.VST Require Bisection.
From Diana.VST Require FpSqrt.
From Diana.VST Require Import Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

(* The binary64 model with CompCert's operations: A i j = a[i + j*n], column-major. *)

Definition c_a (al : list float) (n : Z) (i j : nat) : float :=
  Znth (Z.of_nat i + Z.of_nat j * n) al.

Definition c_l (al : list float) (n i j : Z) : float :=
  Diana.Float.Cholesky.fchol Float.binop_nan Float.binop_nan Float.binop_nan Float.unop_nan
    (c_a al n) (Z.to_nat i) (Z.to_nat j).

Definition c_dot (al : list float) (n : Z) (c : float) (i j k : Z) : float :=
  Diana.Float.Cholesky.fdot Float.binop_nan Float.binop_nan
    (Diana.Float.Cholesky.fchol Float.binop_nan Float.binop_nan Float.binop_nan Float.unop_nan
       (c_a al n))
    c (Z.to_nat i) (Z.to_nat j) (Z.to_nat k).

Definition c_piv (al : list float) (n j : Z) : float := c_dot al n (Znth (j + j * n) al) j j j.

Definition c_list (al : list float) (n : Z) : list float :=
  map (fun p => c_l al n (p mod n) (p / n)) (upto (Z.to_nat (n * n))).

(* The C's DIANA_OK conditions. *)
Definition lower_finite (al : list float) (n : Z) : Prop :=
  forall i j, 0 <= j <= i -> i < n -> Binary.is_finite 53 1024 (Znth (i + j * n) al) = true.

Definition pivots_ok (al : list float) (n : Z) : Prop :=
  forall j, 0 <= j < n -> Float.cmp Cgt (c_piv al n j) Float.zero = true.

Definition c_zero : float := Float.of_bits (Int64.repr 0).

Lemma c_zero_eq : c_zero = Diana.Float.Cholesky.fzero.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_zero_float : Float.of_bits (Int64.repr 0) = Float.zero.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_a_Z (al : list float) (n i j : Z) :
  0 <= i -> 0 <= j -> c_a al n (Z.to_nat i) (Z.to_nat j) = Znth (i + j * n) al.
Proof. intros Hi Hj. unfold c_a. rewrite !Z2Nat.id by lia. reflexivity. Qed.

Lemma c_dot_0 (al : list float) (n : Z) (c : float) (i j : Z) : c_dot al n c i j 0 = c.
Proof. reflexivity. Qed.

Lemma c_dot_succ (al : list float) (n : Z) (c : float) (i j k : Z) :
  0 <= k ->
  c_dot al n c i j (k + 1) =
  Float.sub (c_dot al n c i j k) (Float.mul (c_l al n i k) (c_l al n j k)).
Proof.
  intro Hk. unfold c_dot, c_l. rewrite Z2Nat.inj_add by lia.
  change (Z.to_nat 1) with 1%nat. rewrite Nat.add_1_r. reflexivity.
Qed.

Lemma c_l_upper (al : list float) (n i j : Z) : 0 <= i < j -> c_l al n i j = c_zero.
Proof.
  intro H. rewrite c_zero_eq. unfold c_l.
  apply Diana.Float.Cholesky.fchol_upper. lia.
Qed.

Lemma c_l_diag (al : list float) (n j : Z) :
  0 <= j -> c_l al n j j = Float.sqrt (c_piv al n j).
Proof.
  intro Hj. unfold c_l, c_piv, c_dot. rewrite Diana.Float.Cholesky.fchol_diag.
  unfold Diana.Float.Cholesky.fpiv, Diana.Float.Cholesky.fpivot.
  rewrite c_a_Z by lia. reflexivity.
Qed.

Lemma c_l_lower (al : list float) (n i j : Z) :
  0 <= j < i ->
  c_l al n i j = Float.div (c_dot al n (Znth (i + j * n) al) i j j) (c_l al n j j).
Proof.
  intro H. unfold c_l at 1. rewrite Diana.Float.Cholesky.fchol_lower by lia.
  unfold c_dot, c_l. rewrite c_a_Z by lia. reflexivity.
Qed.

Lemma Zlength_c_list (al : list float) (n : Z) : 0 <= n -> Zlength (c_list al n) = n * n.
Proof.
  intro Hn. unfold c_list. rewrite Zlength_map, Zlength_upto, Z2Nat.id by nia. reflexivity.
Qed.

Lemma Znth_c_list (al : list float) (n i j : Z) :
  0 <= i < n -> 0 <= j < n -> Znth (i + j * n) (c_list al n) = c_l al n i j.
Proof.
  intros Hi Hj. unfold c_list.
  rewrite Znth_map by (rewrite Zlength_upto, Z2Nat.id by nia; nia).
  rewrite Znth_upto by (rewrite Z2Nat.id by nia; nia).
  rewrite Z.mod_add, Z.mod_small by lia. rewrite Z.div_add, Z.div_small by lia.
  reflexivity.
Qed.

(* The output buffer while the kernel writes it in increasing linear index: the model up to p,
   the caller's contents after it. *)
Definition lpre (L : list float) (ol : list val) (N p : Z) : list val :=
  map Vfloat (sublist 0 p L) ++ sublist p N ol.

Lemma Zlength_lpre (L : list float) (ol : list val) (N p : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= p <= N -> Zlength (lpre L ol N p) = N.
Proof. intros. unfold lpre. list_solve. Qed.

Lemma lpre_step (L : list float) (ol : list val) (N p : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= p < N ->
  upd_Znth p (lpre L ol N p) (Vfloat (Znth p L)) = lpre L ol N (p + 1).
Proof. intros. unfold lpre. list_solve. Qed.

Lemma Znth_inhabitant {A : Type} (d1 d2 : Inhabitant A) (q : Z) (xs : list A) :
  0 <= q < Zlength xs -> @Znth A d1 q xs = @Znth A d2 q xs.
Proof.
  intro H. unfold Znth. destruct (Z_lt_dec q 0); [lia |]. apply nth_indep.
  rewrite <- ZtoNat_Zlength. lia.
Qed.

Lemma lpre_get {d : Inhabitant val} (L : list float) (ol : list val) (N p q : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= q < p -> p <= N ->
  @Znth val d q (lpre L ol N p) = Vfloat (Znth q L).
Proof.
  intros. rewrite (Znth_inhabitant d Inhabitant_val) by (rewrite Zlength_lpre; lia).
  unfold lpre. list_solve.
Qed.

Lemma lpre_full (L : list float) (ol : list val) (N : Z) :
  Zlength L = N -> Zlength ol = N -> lpre L ol N N = map Vfloat L.
Proof. intros. unfold lpre. list_solve. Qed.

Lemma lpre_zero (L : list float) (ol : list val) (N : Z) :
  Zlength ol = N -> lpre L ol N 0 = ol.
Proof. intros. unfold lpre. list_solve. Qed.

Lemma ltu_lt (x y : Z) :
  0 <= x <= Int64.max_unsigned -> 0 <= y <= Int64.max_unsigned ->
  Int64.ltu (Int64.repr x) (Int64.repr y) = true -> x < y.
Proof.
  intros Hx Hy H. unfold Int64.ltu in H. rewrite !Int64.unsigned_repr in H by lia.
  destruct (zlt x y); [lia | discriminate].
Qed.

Lemma ltu_ge (x y : Z) :
  0 <= x <= Int64.max_unsigned -> 0 <= y <= Int64.max_unsigned ->
  Int64.ltu (Int64.repr x) (Int64.repr y) = false -> y <= x.
Proof.
  intros Hx Hy H. unfold Int64.ltu in H. rewrite !Int64.unsigned_repr in H by lia.
  destruct (zlt x y); [discriminate | lia].
Qed.

Ltac lt_of_ltu :=
  repeat match goal with
  | H : Int64.ltu (Int64.repr _) (Int64.repr _) = true |- _ =>
      apply ltu_lt in H; [| lia | lia]
  | H : Int64.ltu (Int64.repr _) (Int64.repr _) = false |- _ =>
      apply ltu_ge in H; [| lia | lia]
  end.

Lemma no_overflow (n : Z) :
  1 <= n -> n * n <= Int64.max_unsigned ->
  Int64.cmpu Cgt (Int64.repr n)
    (Int64.divu (Int64.repr (Int.signed (Int.neg (Int.repr 1)))) (Int64.repr n)) = false.
Proof.
  intros H1 H2. change (Int.signed (Int.neg (Int.repr 1))) with (-1).
  unfold Int64.cmpu, Int64.ltu, Int64.divu.
  change (Int64.unsigned (Int64.repr (-1))) with Int64.max_unsigned.
  assert (Hn : Int64.unsigned (Int64.repr n) = n) by (apply Int64.unsigned_repr; nia).
  rewrite Hn.
  assert (Hq : n <= Int64.max_unsigned / n) by (apply Z.div_le_lower_bound; lia).
  rewrite Int64.unsigned_repr.
  - destruct (zlt (Int64.max_unsigned / n) n); [lia | reflexivity].
  - split; [apply Z.div_pos; rep_lia |].
    apply Z.div_le_upper_bound; [lia |]. rep_lia.
Qed.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition cholesky_spec :=
  DECLARE _diana_cholesky
  WITH sha : share, shl : share, a : val, l : val, al : list float, n : Z, ol : list val
  PRE [ tptr tdouble, tulong, tptr tdouble ]
    PROP (readable_share sha; writable_share shl; 1 <= n; (n * n)%Z <= Int64.max_unsigned;
          Zlength al = (n * n)%Z; Zlength ol = (n * n)%Z)
    PARAMS (a; Vlong (Int64.repr n); l)
    SEP (data_at sha (tarray tdouble ((n * n)%Z)) (map Vfloat al) a;
         data_at shl (tarray tdouble ((n * n)%Z)) ol l)
  POST [ tint ]
    EX st : Z, EX ls : list val,
    PROP ((st = 0 /\ lower_finite al n /\ pivots_ok al n /\ ls = map Vfloat (c_list al n)) \/
          (st = -1 /\ ~ lower_finite al n /\ ls = ol) \/
          (st = -4 /\ lower_finite al n /\ ~ pivots_ok al n /\ Zlength ls = (n * n)%Z))
    RETURN (Vint (Int.repr st))
    SEP (data_at sha (tarray tdouble ((n * n)%Z)) (map Vfloat al) a;
         data_at shl (tarray tdouble ((n * n)%Z)) ls l).

Definition Gprog : funspecs :=
  ltac:(with_library prog [fp_finite_spec; Diana.VST.FpSqrt.sqrt_spec; cholesky_spec]).

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

Lemma body_diana_cholesky : semax_body Vprog Gprog f_diana_cholesky cholesky_spec.
Proof.
  start_function.
  assert_PROP (isptr a /\ isptr l) as Hptr by entailer!.
  destruct Hptr as [Ha Hl].
  join_zero _t'1.
  { subst a. contradiction. }
  { forward. entailer!. destruct l; try contradiction. reflexivity. }
  join_zero _t'2.
  { contradiction. }
  { forward. entailer!. destruct (zeq n 0); [lia | reflexivity]. }
  join_zero _t'3.
  { contradiction. }
  { forward.
    - entailer!. apply (f_equal Int64.unsigned) in H10.
      rewrite Int64.unsigned_repr in H10 by nia. discriminate H10 || (simpl in H10; lia).
    - entailer!. rewrite no_overflow by assumption. reflexivity. }
  forward_if.
  { contradiction. }
  forward_for
    (fun j : Z => PROP (0 <= j <= n;
        forall i' j', 0 <= j' < j -> j' <= i' < n ->
          Binary.is_finite 53 1024 (Znth (i' + j' * n) al) = true)
       LOCAL (temp _j (Vlong (Int64.repr j)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _l l)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) ol l))
    continue:
    (fun j : Z => PROP (0 <= j < n;
        forall i' j', 0 <= j' < j + 1 -> j' <= i' < n ->
          Binary.is_finite 53 1024 (Znth (i' + j' * n) al) = true)
       LOCAL (temp _j (Vlong (Int64.repr j)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _l l)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) ol l))
    break:
    (PROP (lower_finite al n)
       LOCAL (temp _a a; temp _n (Vlong (Int64.repr n)); temp _l l)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) ol l)).
  { forward. Exists 0. entailer!; try (intros; lia). }
  { entailer!. }
  { rename a0 into j.
    assert (Hjn : j < n).
    { unfold Int64.ltu in *. rewrite !Int64.unsigned_repr in * by nia.
      destruct (zlt j n); [lia | discriminate]. }
    apply <- semax_seq_skip.
    forward_for
      (fun i : Z => PROP (j <= i <= n; 0 <= j < n;
          forall i' j', 0 <= j' < j -> j' <= i' < n ->
            Binary.is_finite 53 1024 (Znth (i' + j' * n) al) = true;
          forall i', j <= i' < i -> Binary.is_finite 53 1024 (Znth (i' + j * n) al) = true)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) ol l))
      continue:
      (fun i : Z => PROP (j <= i < n; 0 <= j < n;
          forall i' j', 0 <= j' < j -> j' <= i' < n ->
            Binary.is_finite 53 1024 (Znth (i' + j' * n) al) = true;
          forall i', j <= i' < i + 1 -> Binary.is_finite 53 1024 (Znth (i' + j * n) al) = true)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) ol l))
      break:
      (PROP (0 <= j < n;
          forall i' j', 0 <= j' < j + 1 -> j' <= i' < n ->
            Binary.is_finite 53 1024 (Znth (i' + j' * n) al) = true)
         LOCAL (temp _j (Vlong (Int64.repr j)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) ol l)).
    { forward. Exists j. entailer!; try (intros; lia). }
    { entailer!. }
    { rename a0 into i.
      assert (Hin : i < n).
      { unfold Int64.ltu in *. rewrite !Int64.unsigned_repr in * by nia.
        destruct (zlt i n); [lia | discriminate]. }
      assert (Hidx : 0 <= i + j * n < n * n) by nia.
      forward.
      rewrite Znth_map by lia.
      forward_call (Znth (i + j * n) al).
      destruct (Binary.is_finite 53 1024 (Znth (i + j * n) al)) eqn:Hfin.
      - forward_if; [discriminate |].
        forward. Exists i. entailer!. intros i' Hi'.
        destruct (zeq i' i) as [-> | Hne]; [exact Hfin | apply H10; lia].
      - forward_if.
        + forward. Exists (-1) ol. entailer!.
          right. left. split; [reflexivity |]. split; [| reflexivity].
          intro Hlf. rewrite (Hlf i j) in Hfin by lia. discriminate.
        + exfalso. apply H11. reflexivity. }
    { rename a0 into i. forward. Exists (i + 1). entailer!. }
    { rename a0 into i.
      assert (Hni : n <= i).
      { unfold Int64.ltu in *. rewrite !Int64.unsigned_repr in * by nia.
        destruct (zlt i n); [discriminate | lia]. }
      entailer!. intros i' j' Hj' Hi'.
      destruct (zlt j' j); [apply H6; lia |].
      replace j' with j by lia. apply H10. lia. }
    forward. Exists j. entailer!. }
  { rename a0 into j. forward. Exists (j + 1). entailer!. }
  { rename a0 into j.
    assert (Hnj : n <= j).
    { unfold Int64.ltu in *. rewrite !Int64.unsigned_repr in * by nia.
      destruct (zlt j n); [discriminate | lia]. }
    entailer!. intros i' j' Hj' Hi'. apply H6; lia. }
  rename H4 into Hlf.
  assert (HL : Zlength (c_list al n) = n * n) by (apply Zlength_c_list; lia).
  assert (Hn0 : n <= Int64.max_unsigned) by nia.
  forward_for
    (fun j : Z => PROP (0 <= j <= n;
        forall j', 0 <= j' < j -> Float.cmp Cgt (c_piv al n j') Float.zero = true)
       LOCAL (temp _j (Vlong (Int64.repr j)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _l l)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n)) l))
    continue:
    (fun j : Z => PROP (0 <= j < n;
        forall j', 0 <= j' < j + 1 -> Float.cmp Cgt (c_piv al n j') Float.zero = true)
       LOCAL (temp _j (Vlong (Int64.repr j)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _l l)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) ((j + 1) * n)) l))
    break:
    (PROP (pivots_ok al n)
       LOCAL (temp _a a; temp _n (Vlong (Int64.repr n)); temp _l l)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (n * n)) l)).
  { forward. Exists 0. entailer!. rewrite Z.mul_0_l, lpre_zero by lia. cancel. }
  { entailer!. }
  { rename a0 into j.
    lt_of_ltu.
    (* zero the strict upper part of column j *)
    forward_for
      (fun i : Z => PROP (0 <= i <= j; 0 <= j < n;
          forall j', 0 <= j' < j -> Float.cmp Cgt (c_piv al n j') Float.zero = true)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n + i)) l))
      continue:
      (fun i : Z => PROP (0 <= i < j; 0 <= j < n;
          forall j', 0 <= j' < j -> Float.cmp Cgt (c_piv al n j') Float.zero = true)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n + i + 1)) l))
      break:
      (PROP (0 <= j < n;
          forall j', 0 <= j' < j -> Float.cmp Cgt (c_piv al n j') Float.zero = true)
         LOCAL (temp _j (Vlong (Int64.repr j)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n + j)) l)).
    { forward. Exists 0. rewrite Z.add_0_r. entailer!. }
    { entailer!. }
    { rename a0 into i.
      lt_of_ltu.
      assert (Hidx : 0 <= i + j * n < n * n) by nia.
      forward. Exists i. entailer!.
      replace (Vfloat (Float.of_bits (Int64.repr 0))) with (Vfloat (Znth (j * n + i) (c_list al n))).
      2: { rewrite Z.add_comm, Znth_c_list, c_l_upper by lia. reflexivity. }
      replace (i + j * n) with (j * n + i) by ring. rewrite lpre_step by nia. cancel. }
    { rename a0 into i. forward. Exists (i + 1).
      replace (j * n + (i + 1)) with (j * n + i + 1) by ring. entailer!. }
    { rename a0 into i. replace i with j by lia. entailer!. }
    assert (Hjj : 0 <= j + j * n < n * n) by nia.
    forward.
    rewrite Znth_map by lia.
    (* the pivot: s = a[j + j*n] - l[j]^2 - ... *)
    forward_for
      (fun k : Z => PROP (0 <= k <= j)
         LOCAL (temp _k (Vlong (Int64.repr k));
                temp _s (Vfloat (c_dot al n (Znth (j + j * n) al) j j k));
                temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n + j)) l))
      continue:
      (fun k : Z => PROP (0 <= k < j)
         LOCAL (temp _k (Vlong (Int64.repr k));
                temp _s (Vfloat (c_dot al n (Znth (j + j * n) al) j j (k + 1)));
                temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n + j)) l))
      break:
      (PROP ()
         LOCAL (temp _s (Vfloat (c_piv al n j));
                temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n + j)) l)).
    { forward. Exists 0. entailer!. }
    { entailer!. }
    { rename a0 into k.
      assert (Hjk : 0 <= j + k * n < j * n + j) by nia.
      forward.
      { entailer!. rewrite lpre_get by nia. exact I. }
      forward.
      rewrite lpre_get by nia. rewrite Znth_c_list by lia.
      forward. Exists k. entailer!. rewrite c_dot_succ by lia. reflexivity. }
    { rename a0 into k. forward. Exists (k + 1). entailer!. }
    { rename a0 into k. replace k with j by lia. entailer!. }
    forward_if.
    { forward. Exists (-4) (lpre (c_list al n) ol (n * n) (j * n + j)). entailer!.
      right. right. split; [reflexivity |]. split; [exact Hlf |].
      split; [| apply Zlength_lpre; nia].
      intro Hp. specialize (Hp j ltac:(lia)). rewrite c_zero_float, Hp in H8.
      exact (Int.one_not_zero H8). }
    assert (Hpj : Float.cmp Cgt (c_piv al n j) Float.zero = true).
    { rewrite c_zero_float in H8.
      destruct (Float.cmp Cgt (c_piv al n j) Float.zero); [reflexivity |].
      contradiction H8; reflexivity. }
    forward_call (c_piv al n j).
    forward.
    replace (Vfloat (Float.sqrt (c_piv al n j))) with (Vfloat (Znth (j * n + j) (c_list al n))).
    2: { rewrite Z.add_comm, Znth_c_list, c_l_diag by lia. reflexivity. }
    replace (j + j * n) with (j * n + j) by ring.
    rewrite lpre_step by nia.
    replace (Znth (j * n + j) (c_list al n)) with (c_l al n j j)
      by (rewrite Z.add_comm, Znth_c_list by lia; reflexivity).
    (* the column below the diagonal *)
    apply <- semax_seq_skip.
    forward_for
      (fun i : Z => PROP (j + 1 <= i <= n)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _d (Vfloat (c_l al n j j));
                temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n + i)) l))
      continue:
      (fun i : Z => PROP (j + 1 <= i < n)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _d (Vfloat (c_l al n j j));
                temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (lpre (c_list al n) ol (n * n) (j * n + i + 1)) l))
      break:
      (PROP ()
         LOCAL (temp _j (Vlong (Int64.repr j)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _l l)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (lpre (c_list al n) ol (n * n) (j * n + n)) l)).
    { forward. Exists (j + 1). entailer!. replace (j * n + (j + 1)) with (j * n + j + 1) by ring.
      cancel. }
    { entailer!. }
    { rename a0 into i.
      assert (Hij : 0 <= i + j * n < n * n) by nia.
      forward.
      rewrite Znth_map by lia.
      forward_for
        (fun k : Z => PROP (0 <= k <= j)
           LOCAL (temp _k (Vlong (Int64.repr k));
                  temp _s (Vfloat (c_dot al n (Znth (i + j * n) al) i j k));
                  temp _i (Vlong (Int64.repr i)); temp _d (Vfloat (c_l al n j j));
                  temp _j (Vlong (Int64.repr j)); temp _a a;
                  temp _n (Vlong (Int64.repr n)); temp _l l)
           SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
                data_at shl (tarray tdouble (n * n))
                  (lpre (c_list al n) ol (n * n) (j * n + i)) l))
        continue:
        (fun k : Z => PROP (0 <= k < j)
           LOCAL (temp _k (Vlong (Int64.repr k));
                  temp _s (Vfloat (c_dot al n (Znth (i + j * n) al) i j (k + 1)));
                  temp _i (Vlong (Int64.repr i)); temp _d (Vfloat (c_l al n j j));
                  temp _j (Vlong (Int64.repr j)); temp _a a;
                  temp _n (Vlong (Int64.repr n)); temp _l l)
           SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
                data_at shl (tarray tdouble (n * n))
                  (lpre (c_list al n) ol (n * n) (j * n + i)) l))
        break:
        (PROP ()
           LOCAL (temp _s (Vfloat (c_dot al n (Znth (i + j * n) al) i j j));
                  temp _i (Vlong (Int64.repr i)); temp _d (Vfloat (c_l al n j j));
                  temp _j (Vlong (Int64.repr j)); temp _a a;
                  temp _n (Vlong (Int64.repr n)); temp _l l)
           SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
                data_at shl (tarray tdouble (n * n))
                  (lpre (c_list al n) ol (n * n) (j * n + i)) l)).
      { forward. Exists 0. entailer!. }
      { entailer!. }
      { rename a0 into k.
        assert (Hik : 0 <= i + k * n < j * n + i) by nia.
        assert (Hjk : 0 <= j + k * n < j * n + i) by nia.
        forward.
        { entailer!. rewrite lpre_get by nia. exact I. }
        forward.
        { entailer!. rewrite lpre_get by nia. exact I. }
        rewrite !lpre_get by nia. rewrite !Znth_c_list by lia.
        forward. Exists k. entailer!. rewrite c_dot_succ by lia. reflexivity. }
      { rename a0 into k. forward. Exists (k + 1). entailer!. }
      { rename a0 into k. replace k with j by lia. entailer!. }
      forward.
      replace (Vfloat (Float.div (c_dot al n (Znth (i + j * n) al) i j j) (c_l al n j j)))
        with (Vfloat (Znth (j * n + i) (c_list al n))).
      2: { rewrite Z.add_comm, Znth_c_list, c_l_lower by lia. reflexivity. }
      replace (i + j * n) with (j * n + i) by ring.
      rewrite lpre_step by nia.
      Exists i. entailer!. }
    { rename a0 into i. forward. Exists (i + 1).
      replace (j * n + (i + 1)) with (j * n + i + 1) by ring. entailer!. }
    { rename a0 into i. replace i with n by lia. entailer!. }
    forward. Exists j. entailer!.
    - intros j' Hj'. destruct (zeq j' j) as [-> | Hne]; [exact Hpj | apply H6; lia].
    - replace ((j + 1) * n) with (j * n + n) by ring. cancel. }
  { rename a0 into j. forward. Exists (j + 1). entailer!. }
  { rename a0 into j. replace j with n by lia. entailer!. unfold pivots_ok. intros. apply H6. lia. }
  forward. Exists 0 (map Vfloat (c_list al n)). entailer!. rewrite lpre_full by lia. cancel.
Qed.
