From VST.floyd Require Import proofauto.
From Diana.Clight Require Import lu_solve_aarch64_macos.
From Diana.Real Require LU LUSolve.
From Diana.Float Require Substitution LUSolve.
From Diana.VST Require Bisection.
From Diana.VST Require Import Matrix Substitution Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

(* The binary64 model with CompCert's operations, Float.sub, Float.mul and Float.div by
   conversion: F i k = lu[i + k*n] (c_L), p k = piv[k] and b i = b[i] (c_b). *)
Definition c_p (pl : list Z) (k : nat) : nat := Z.to_nat (Znth (Z.of_nat k) pl).

(* Entry i of the right side after the interchanges of rows k' and piv[k'], k' < k. *)
Definition c_c (pl : list Z) (bl : list float) (k i : nat) : float :=
  Znth (Z.of_nat (Diana.Real.LUSolve.pperm (c_p pl) k i)) bl.

(* Entry i of the forward solve (y) and of the solution (x). *)
Definition c_y (ll : list float) (pl : list Z) (bl : list float) (n i : Z) : float :=
  Diana.Float.LUSolve.fforward Float.binop_nan Float.binop_nan (c_L ll n) (c_p pl) (c_b bl)
    (Z.to_nat n) (Z.to_nat i).

Definition c_x (ll : list float) (pl : list Z) (bl : list float) (n i : Z) : float :=
  Diana.Float.LUSolve.fsolution Float.binop_nan Float.binop_nan Float.binop_nan (c_L ll n)
    (c_p pl) (c_b bl) (Z.to_nat n) (Z.to_nat i).

(* s after the first k subtractions of forward row i:
   c[i] - lu[i]*y[0] - ... - lu[i + (k-1)*n]*y[k-1]. *)
Definition c_ydot (ll : list float) (pl : list Z) (bl : list float) (n i k : Z) : float :=
  Diana.Float.Substitution.fdotv Float.binop_nan Float.binop_nan (c_L ll n (Z.to_nat i))
    (Diana.Float.LUSolve.fforward Float.binop_nan Float.binop_nan (c_L ll n) (c_p pl) (c_b bl)
       (Z.to_nat n))
    (c_c pl bl (Z.to_nat n) (Z.to_nat i)) (Z.to_nat k).

(* s after the first t subtractions of back row i, k = n - 1 down to n - t. *)
Definition c_xdot (ll : list float) (pl : list Z) (bl : list float) (n i t : Z) : float :=
  Diana.Float.Substitution.fdotv Float.binop_nan Float.binop_nan
    (fun q => c_L ll n (Z.to_nat i) (Z.to_nat n - 1 - q)%nat)
    (fun q => Diana.Float.LUSolve.fsolution Float.binop_nan Float.binop_nan Float.binop_nan
                (c_L ll n) (c_p pl) (c_b bl) (Z.to_nat n) (Z.to_nat n - 1 - q)%nat)
    (c_y ll pl bl n i) (Z.to_nat t).

(* x after k interchanges, and the two solves as lists. *)
Definition c_cl (pl : list Z) (bl : list float) (n : Z) (k : nat) : list float :=
  map (fun i => c_c pl bl k (Z.to_nat i)) (upto (Z.to_nat n)).

(* x after all n interchanges: P b. *)
Definition c_pb (pl : list Z) (bl : list float) (n : Z) : list float :=
  c_cl pl bl n (Z.to_nat n).

Definition c_yl (ll : list float) (pl : list Z) (bl : list float) (n : Z) : list float :=
  map (c_y ll pl bl n) (upto (Z.to_nat n)).

Definition c_xl (ll : list float) (pl : list Z) (bl : list float) (n : Z) : list float :=
  map (c_x ll pl bl n) (upto (Z.to_nat n)).

(* The C's exits: every entry of lu finite, every pivot row below n, every entry of b finite,
   no zero on the diagonal (diag_nonzero), every y[i], every x[i] finite. *)
Definition all_finite (ll : list float) (n : Z) : Prop :=
  forall q, 0 <= q < n * n -> Binary.is_finite 53 1024 (Znth q ll) = true.

Definition piv_ok (pl : list Z) (n : Z) : Prop := forall k, 0 <= k < n -> Znth k pl < n.

Definition y_finite (ll : list float) (pl : list Z) (bl : list float) (n : Z) : Prop :=
  forall i, 0 <= i < n -> Binary.is_finite 53 1024 (c_y ll pl bl n i) = true.

Definition x_finite (ll : list float) (pl : list Z) (bl : list float) (n : Z) : Prop :=
  forall i, 0 <= i < n -> Binary.is_finite 53 1024 (c_x ll pl bl n i) = true.

Lemma Zlength_c_cl (pl : list Z) (bl : list float) (n : Z) (k : nat) :
  0 <= n -> Zlength (c_cl pl bl n k) = n.
Proof. intro. unfold c_cl. rewrite Zlength_map, Zlength_upto, Z2Nat.id by lia. reflexivity. Qed.

Lemma Znth_c_cl (pl : list Z) (bl : list float) (n i : Z) (k : nat) :
  0 <= i < n -> Znth i (c_cl pl bl n k) = c_c pl bl k (Z.to_nat i).
Proof.
  intro Hi. unfold c_cl.
  rewrite Znth_map by (rewrite Zlength_upto, Z2Nat.id by lia; lia).
  rewrite Znth_upto by (rewrite Z2Nat.id by lia; lia). reflexivity.
Qed.

Lemma Zlength_c_pb (pl : list Z) (bl : list float) (n : Z) :
  0 <= n -> Zlength (c_pb pl bl n) = n.
Proof. apply Zlength_c_cl. Qed.

Lemma Znth_c_pb (pl : list Z) (bl : list float) (n i : Z) :
  0 <= i < n -> Znth i (c_pb pl bl n) = c_c pl bl (Z.to_nat n) (Z.to_nat i).
Proof. apply Znth_c_cl. Qed.

Lemma c_cl_zero (pl : list Z) (bl : list float) (n : Z) :
  Zlength bl = n -> c_cl pl bl n 0 = bl.
Proof.
  intro Hb. assert (Hn : 0 <= n) by (rewrite <- Hb; apply Zlength_nonneg).
  apply Znth_eq_ext; [rewrite Zlength_c_cl; lia |].
  intros q Hq. rewrite Zlength_c_cl in Hq by lia. rewrite Znth_c_cl by lia.
  unfold c_c. cbn [Diana.Real.LUSolve.pperm]. rewrite Z2Nat.id by lia. reflexivity.
Qed.

Lemma swap_step (pl : list Z) (bl : list float) (n k p : Z) :
  0 <= k < n -> 0 <= p < n -> Znth k pl = p ->
  upd_Znth p (upd_Znth k (map Vfloat (c_cl pl bl n (Z.to_nat k)))
                (Vfloat (Znth p (c_cl pl bl n (Z.to_nat k)))))
    (Vfloat (Znth k (c_cl pl bl n (Z.to_nat k)))) =
  map Vfloat (c_cl pl bl n (Z.to_nat (k + 1))).
Proof.
  intros Hk Hp Hkp.
  assert (HL : forall m, Zlength (c_cl pl bl n m) = n) by (intro; apply Zlength_c_cl; lia).
  apply Znth_eq_ext.
  - rewrite !Zlength_upd_Znth, !Zlength_map, !HL. reflexivity.
  - intros q Hq. rewrite !Zlength_upd_Znth, Zlength_map, HL in Hq.
    assert (Hpk : c_p pl (Z.to_nat k) = Z.to_nat p)
      by (unfold c_p; rewrite Z2Nat.id, Hkp by lia; reflexivity).
    assert (Hr : Znth q (map Vfloat (c_cl pl bl n (Z.to_nat (k + 1)))) =
                 Vfloat (c_c pl bl (Z.to_nat k)
                           (Diana.Real.LU.tau (Z.to_nat k) (Z.to_nat p) (Z.to_nat q)))).
    { rewrite Znth_map by (rewrite HL; lia). rewrite Znth_c_cl by lia.
      replace (Z.to_nat (k + 1)) with (S (Z.to_nat k)) by lia.
      unfold c_c. cbn [Diana.Real.LUSolve.pperm]. rewrite Hpk. reflexivity. }
    rewrite Hr. unfold Diana.Real.LU.tau.
    destruct (Z.eq_dec q p) as [-> | Hqp].
    + rewrite upd_Znth_same by (rewrite Zlength_upd_Znth, Zlength_map, HL; lia).
      rewrite Znth_c_cl by lia.
      destruct (Nat.eqb_spec (Z.to_nat p) (Z.to_nat k)) as [E | E].
      * replace p with k by lia. reflexivity.
      * rewrite Nat.eqb_refl. reflexivity.
    + rewrite upd_Znth_diff by (rewrite ?Zlength_upd_Znth, ?Zlength_map, ?HL; lia).
      replace (Z.to_nat q =? Z.to_nat k)%nat with (Z.eqb q k)
        by (destruct (Z.eqb_spec q k), (Nat.eqb_spec (Z.to_nat q) (Z.to_nat k)); lia).
      replace (Z.to_nat q =? Z.to_nat p)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
      destruct (Z.eqb_spec q k) as [-> | Hqk].
      * rewrite upd_Znth_same by (rewrite Zlength_map, HL; lia).
        rewrite Znth_c_cl by lia. reflexivity.
      * rewrite upd_Znth_diff by (rewrite ?Zlength_map, ?HL; lia).
        rewrite Znth_map by (rewrite HL; lia). rewrite Znth_c_cl by lia. reflexivity.
Qed.

Lemma c_ydot_succ (ll : list float) (pl : list Z) (bl : list float) (n i k : Z) :
  0 <= i -> 0 <= k ->
  c_ydot ll pl bl n i (k + 1) =
  Float.sub (c_ydot ll pl bl n i k) (Float.mul (Znth (i + k * n) ll) (c_y ll pl bl n k)).
Proof.
  intros Hi Hk. unfold c_ydot. rewrite Z2Nat.inj_add by lia.
  change (Z.to_nat 1) with 1%nat. rewrite Nat.add_1_r. simpl.
  replace (c_L ll n (Z.to_nat i) (Z.to_nat k)) with (Znth (i + k * n) ll)
    by (unfold c_L; rewrite !Z2Nat.id by lia; reflexivity).
  reflexivity.
Qed.

Lemma c_y_eq (ll : list float) (pl : list Z) (bl : list float) (n i : Z) :
  0 <= i -> c_y ll pl bl n i = c_ydot ll pl bl n i i.
Proof.
  intro Hi. unfold c_y, c_ydot, Diana.Float.LUSolve.fforward.
  rewrite Diana.Float.LUSolve.funit_eq. reflexivity.
Qed.

Lemma c_xdot_succ (ll : list float) (pl : list Z) (bl : list float) (n i t : Z) :
  0 <= i -> 0 <= t < n ->
  c_xdot ll pl bl n i (t + 1) =
  Float.sub (c_xdot ll pl bl n i t)
    (Float.mul (Znth (i + (n - 1 - t) * n) ll) (c_x ll pl bl n (n - 1 - t))).
Proof.
  intros Hi Ht. unfold c_xdot. rewrite Z2Nat.inj_add by lia.
  change (Z.to_nat 1) with 1%nat. rewrite Nat.add_1_r. simpl.
  replace (c_L ll n (Z.to_nat i) (Z.to_nat n - 1 - Z.to_nat t)%nat)
    with (Znth (i + (n - 1 - t) * n) ll)
    by (unfold c_L; f_equal; rewrite !Nat2Z.inj_sub by lia; rewrite !Z2Nat.id by lia; lia).
  replace (Diana.Float.LUSolve.fsolution Float.binop_nan Float.binop_nan Float.binop_nan
             (c_L ll n) (c_p pl) (c_b bl) (Z.to_nat n) (Z.to_nat n - 1 - Z.to_nat t)%nat)
    with (c_x ll pl bl n (n - 1 - t)) by (unfold c_x; f_equal; lia).
  reflexivity.
Qed.

Lemma c_x_eq (ll : list float) (pl : list Z) (bl : list float) (n i : Z) :
  0 <= i < n ->
  c_x ll pl bl n i = Float.div (c_xdot ll pl bl n i (n - 1 - i)) (Znth (i + i * n) ll).
Proof.
  intro Hi. unfold c_x at 1, Diana.Float.LUSolve.fsolution.
  rewrite Diana.Float.Substitution.fbwd_eq by lia. unfold c_xdot.
  replace (c_L ll n (Z.to_nat i) (Z.to_nat i)) with (Znth (i + i * n) ll)
    by (unfold c_L; rewrite Z2Nat.id by lia; reflexivity).
  replace (Z.to_nat (n - 1 - i)) with (Z.to_nat n - 1 - Z.to_nat i)%nat by lia.
  reflexivity.
Qed.

Lemma Zlength_c_yl (ll : list float) (pl : list Z) (bl : list float) (n : Z) :
  0 <= n -> Zlength (c_yl ll pl bl n) = n.
Proof. intro. unfold c_yl. rewrite Zlength_map, Zlength_upto, Z2Nat.id by lia. reflexivity. Qed.

Lemma Znth_c_yl (ll : list float) (pl : list Z) (bl : list float) (n i : Z) :
  0 <= i < n -> Znth i (c_yl ll pl bl n) = c_y ll pl bl n i.
Proof.
  intro Hi. unfold c_yl.
  rewrite Znth_map by (rewrite Zlength_upto, Z2Nat.id by lia; lia).
  rewrite Znth_upto by (rewrite Z2Nat.id by lia; lia). reflexivity.
Qed.

Lemma Zlength_c_xl (ll : list float) (pl : list Z) (bl : list float) (n : Z) :
  0 <= n -> Zlength (c_xl ll pl bl n) = n.
Proof. intro. unfold c_xl. rewrite Zlength_map, Zlength_upto, Z2Nat.id by lia. reflexivity. Qed.

Lemma Znth_c_xl (ll : list float) (pl : list Z) (bl : list float) (n i : Z) :
  0 <= i < n -> Znth i (c_xl ll pl bl n) = c_x ll pl bl n i.
Proof.
  intro Hi. unfold c_xl.
  rewrite Znth_map by (rewrite Zlength_upto, Z2Nat.id by lia; lia).
  rewrite Znth_upto by (rewrite Z2Nat.id by lia; lia). reflexivity.
Qed.

(* The caller's part of a buffer being written: after the written prefix, before the written
   suffix. *)
Lemma lpre_rest {d : Inhabitant val} (L : list float) (ol : list val) (N p q : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= p <= q -> q < N ->
  @Znth val d q (lpre L ol N p) = Znth q ol.
Proof.
  intros. rewrite !(Znth_inhabitant d Inhabitant_val) by (rewrite ?Zlength_lpre; lia).
  unfold lpre. rewrite Znth_app2 by (rewrite Zlength_map, Zlength_sublist; lia).
  rewrite Zlength_map, Zlength_sublist by lia. rewrite Znth_sublist by lia. f_equal. lia.
Qed.

Lemma lsuf_rest {d : Inhabitant val} (L : list float) (ol : list val) (N p q : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= q < p -> p <= N ->
  @Znth val d q (lsuf L ol N p) = Znth q ol.
Proof.
  intros. rewrite !(Znth_inhabitant d Inhabitant_val) by (rewrite ?Zlength_lsuf; lia).
  unfold lsuf. rewrite Znth_app1 by (rewrite Zlength_sublist; lia).
  rewrite Znth_sublist by lia. f_equal. lia.
Qed.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition lu_solve_spec :=
  DECLARE _diana_lu_solve
  WITH shl : share, shp : share, shb : share, shx : share, lu : val, piv : val, b : val,
       x : val, ll : list float, pl : list Z, bl : list float, n : Z, ox : list val
  PRE [ tptr tdouble, tptr tulong, tulong, tptr tdouble, tptr tdouble ]
    PROP (readable_share shl; readable_share shp; readable_share shb; writable_share shx;
          1 <= n; (n * n)%Z <= Int64.max_unsigned; Zlength ll = (n * n)%Z; Zlength pl = n;
          Forall (fun z => 0 <= z <= Int64.max_unsigned) pl; Zlength bl = n; Zlength ox = n)
    PARAMS (lu; piv; Vlong (Int64.repr n); b; x)
    SEP (data_at shl (tarray tdouble ((n * n)%Z)) (map Vfloat ll) lu;
         data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
         data_at shb (tarray tdouble n) (map Vfloat bl) b;
         data_at shx (tarray tdouble n) ox x)
  POST [ tint ]
    EX st : Z, EX xs : list val,
    PROP ((st = 0 /\ all_finite ll n /\ piv_ok pl n /\ vec_finite bl n /\ diag_nonzero ll n /\
           y_finite ll pl bl n /\ x_finite ll pl bl n /\ xs = map Vfloat (c_xl ll pl bl n)) \/
          (st = -1 /\ ~ (all_finite ll n /\ piv_ok pl n /\ vec_finite bl n) /\ xs = ox) \/
          (st = -4 /\ all_finite ll n /\ piv_ok pl n /\ vec_finite bl n /\
           ~ diag_nonzero ll n /\ xs = ox) \/
          (st = -5 /\ all_finite ll n /\ piv_ok pl n /\ vec_finite bl n /\ diag_nonzero ll n /\
           exists i, 0 <= i < n /\
             (forall i', 0 <= i' < i -> Binary.is_finite 53 1024 (c_y ll pl bl n i') = true) /\
             Binary.is_finite 53 1024 (c_y ll pl bl n i) = false /\
             xs = lpre (c_yl ll pl bl n) (map Vfloat (c_pb pl bl n)) n i) \/
          (st = -5 /\ all_finite ll n /\ piv_ok pl n /\ vec_finite bl n /\ diag_nonzero ll n /\
           y_finite ll pl bl n /\
           exists i, 0 <= i < n /\
             (forall i', i < i' < n -> Binary.is_finite 53 1024 (c_x ll pl bl n i') = true) /\
             Binary.is_finite 53 1024 (c_x ll pl bl n i) = false /\
             xs = lsuf (c_xl ll pl bl n) (map Vfloat (c_yl ll pl bl n)) n (i + 1)))
    RETURN (Vint (Int.repr st))
    SEP (data_at shl (tarray tdouble ((n * n)%Z)) (map Vfloat ll) lu;
         data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
         data_at shb (tarray tdouble n) (map Vfloat bl) b;
         data_at shx (tarray tdouble n) xs x).

Definition Gprog : funspecs := ltac:(with_library prog [fp_finite_spec; lu_solve_spec]).

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

Lemma mul_repr_nn (n : Z) :
  0 <= n <= Int64.max_unsigned -> Int64.mul (Int64.repr n) (Int64.repr n) = Int64.repr (n * n).
Proof. intro H. unfold Int64.mul. rewrite Int64.unsigned_repr by lia. reflexivity. Qed.

Lemma body_diana_lu_solve : semax_body Vprog Gprog f_diana_lu_solve lu_solve_spec.
Proof.
  start_function.
  assert (Hn0 : n <= Int64.max_unsigned) by nia.
  assert (Hnn : 0 <= n * n) by nia.
  match goal with HF : Forall _ pl |- _ => rename HF into Hpl end.
  assert (Hpz : forall k, 0 <= k < n -> 0 <= Znth k pl <= Int64.max_unsigned).
  { intros k Hk. rewrite Forall_forall in Hpl. apply Hpl. apply Znth_In. lia. }
  assert_PROP (isptr lu /\ isptr piv /\ isptr b /\ isptr x) as Hptr by entailer!.
  destruct Hptr as [Hl [Hp [Hb Hx]]].
  join_zero _t'1.
  { subst lu. contradiction. }
  { forward. entailer!. destruct piv; try contradiction. reflexivity. }
  join_zero _t'2.
  { contradiction. }
  { forward. entailer!. destruct b; try contradiction. reflexivity. }
  join_zero _t'3.
  { contradiction. }
  { forward. entailer!. destruct x; try contradiction. reflexivity. }
  join_zero _t'4.
  { contradiction. }
  { forward. entailer!.
    match goal with |- context [zeq ?m 0] => destruct (zeq m 0); [lia | reflexivity] end. }
  join_zero _t'5.
  { contradiction. }
  { forward.
    - entailer!.
      match goal with H : Int64.repr _ = _ |- _ =>
        apply (f_equal Int64.unsigned) in H; rewrite Int64.unsigned_repr in H by nia;
        discriminate H || (simpl in H; lia) end.
    - entailer!. rewrite no_overflow by assumption. reflexivity. }
  forward_if.
  { contradiction. }
  (* every entry of lu is finite *)
  forward_for
    (fun q : Z => PROP (0 <= q <= n * n;
        forall w, 0 <= w < q -> Binary.is_finite 53 1024 (Znth w ll) = true)
       LOCAL (temp _q (Vlong (Int64.repr q)); temp _lu lu; temp _piv piv;
              temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    continue:
    (fun q : Z => PROP (0 <= q < n * n;
        forall w, 0 <= w < q + 1 -> Binary.is_finite 53 1024 (Znth w ll) = true)
       LOCAL (temp _q (Vlong (Int64.repr q)); temp _lu lu; temp _piv piv;
              temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    break:
    (PROP (all_finite ll n)
       LOCAL (temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x)).
  { forward. Exists 0. entailer!; intros; lia. }
  { entailer!. }
  { rename a into q. rewrite mul_repr_nn in * by lia. lt_of_ltu.
    forward.
    rewrite Znth_map by lia.
    forward_call (Znth q ll).
    destruct (Binary.is_finite 53 1024 (Znth q ll)) eqn:Hfin.
    - forward_if; [discriminate |].
      forward. Exists q. entailer!. intros w Hw.
      destruct (zeq w q) as [-> | Hne]; [exact Hfin |].
      match goal with H : forall w, 0 <= w < q -> _ |- _ => apply H; lia end.
    - forward_if.
      + forward. Exists (-1) ox. entailer!.
        right. left. split; [reflexivity |]. split; [| reflexivity].
        intros [Haf _]. rewrite (Haf q) in Hfin by lia. discriminate.
      + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
  { rename a into q. forward. Exists (q + 1). entailer!. }
  { rename a into q. rewrite mul_repr_nn in * by lia. lt_of_ltu.
    entailer!. intros w Hw.
    match goal with H : forall w, 0 <= w < q -> _ |- _ => apply H; lia end. }
  match goal with H : all_finite _ _ |- _ => rename H into Haf end.
  (* every pivot row is below n *)
  forward_for
    (fun k : Z => PROP (0 <= k <= n; forall k', 0 <= k' < k -> Znth k' pl < n)
       LOCAL (temp _k (Vlong (Int64.repr k)); temp _lu lu; temp _piv piv;
              temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    continue:
    (fun k : Z => PROP (0 <= k < n; forall k', 0 <= k' < k + 1 -> Znth k' pl < n)
       LOCAL (temp _k (Vlong (Int64.repr k)); temp _lu lu; temp _piv piv;
              temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x))
    break:
    (PROP (piv_ok pl n)
       LOCAL (temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) ox x)).
  { forward. Exists 0. entailer!; intros; lia. }
  { entailer!. }
  { rename a into k. lt_of_ltu.
    pose proof (Hpz k ltac:(lia)) as Hzk.
    forward.
    forward_if.
    - forward. Exists (-1) ox. entailer!.
      right. left. split; [reflexivity |]. split; [| reflexivity].
      intros [_ [Hpo _]]. specialize (Hpo k ltac:(lia)). lia.
    - forward. Exists k. entailer!. intros k' Hk'.
      destruct (zeq k' k) as [-> | Hne]; [lia |].
      match goal with H : forall k', 0 <= k' < k -> _ |- _ => apply H; lia end. }
  { rename a into k. forward. Exists (k + 1). entailer!. }
  { rename a into k. lt_of_ltu.
    entailer!. intros k' Hk'.
    match goal with H : forall k', 0 <= k' < k -> _ |- _ => apply H; lia end. }
  match goal with H : piv_ok _ _ |- _ => rename H into Hpo end.
  (* every entry of b is finite *)
  forward_for
    (fun i : Z => PROP (0 <= i <= n;
        forall i', 0 <= i' < i -> Binary.is_finite 53 1024 (Znth i' bl) = true)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b; data_at shx (tarray tdouble n) ox x))
    continue:
    (fun i : Z => PROP (0 <= i < n;
        forall i', 0 <= i' < i + 1 -> Binary.is_finite 53 1024 (Znth i' bl) = true)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b; data_at shx (tarray tdouble n) ox x))
    break:
    (PROP (vec_finite bl n)
       LOCAL (temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b; data_at shx (tarray tdouble n) ox x)).
  { forward. Exists 0. entailer!; intros; lia. }
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
        intros [_ [_ Hvf]]. rewrite (Hvf i) in Hfin by lia. discriminate.
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
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b; data_at shx (tarray tdouble n) ox x))
    continue:
    (fun i : Z => PROP (0 <= i < n;
        forall i', 0 <= i' < i + 1 -> Float.cmp Ceq (Znth (i' + i' * n) ll) Float.zero = false)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b; data_at shx (tarray tdouble n) ox x))
    break:
    (PROP (diag_nonzero ll n)
       LOCAL (temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b; data_at shx (tarray tdouble n) ox x)).
  { forward. Exists 0. entailer!; intros; lia. }
  { entailer!. }
  { rename a into i. lt_of_ltu.
    assert (Hii : 0 <= i + i * n < n * n) by nia.
    forward.
    rewrite Znth_map by lia.
    forward_if.
    - forward. Exists (-4) ox. entailer!.
      right. right. left. split; [reflexivity |]. split; [exact Haf |]. split; [exact Hpo |].
      split; [exact Hvf |]. split; [| reflexivity].
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
  (* x = b *)
  forward_for
    (fun i : Z => PROP (0 <= i <= n)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (lpre bl ox n i) x))
    continue:
    (fun i : Z => PROP (0 <= i < n)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (lpre bl ox n (i + 1)) x))
    break:
    (PROP ()
       LOCAL (temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (lpre bl ox n n) x)).
  { forward. Exists 0. rewrite lpre_zero by lia. entailer!. }
  { entailer!. }
  { rename a into i. lt_of_ltu.
    forward.
    rewrite Znth_map by lia.
    forward. Exists i. entailer!. rewrite lpre_step by lia. cancel. }
  { rename a into i. forward. Exists (i + 1). entailer!. }
  { rename a into i. lt_of_ltu. replace i with n by lia. entailer!. }
  (* the interchanges k = 0, ..., n - 1 *)
  forward_for
    (fun k : Z => PROP (0 <= k <= n)
       LOCAL (temp _k (Vlong (Int64.repr k));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (map Vfloat (c_cl pl bl n (Z.to_nat k))) x))
    continue:
    (fun k : Z => PROP (0 <= k < n)
       LOCAL (temp _k (Vlong (Int64.repr k));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (map Vfloat (c_cl pl bl n (Z.to_nat (k + 1)))) x))
    break:
    (PROP ()
       LOCAL (temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n) (map Vfloat (c_cl pl bl n (Z.to_nat n))) x)).
  { forward. Exists 0. change (Z.to_nat 0) with O. rewrite c_cl_zero by lia.
    rewrite lpre_full by lia. entailer!. }
  { entailer!. }
  { rename a into k. lt_of_ltu.
    pose proof (Hpz k ltac:(lia)) as Hzk. pose proof (Hpo k ltac:(lia)) as Hkn.
    assert (HC : Zlength (c_cl pl bl n (Z.to_nat k)) = n) by (apply Zlength_c_cl; lia).
    forward.
    forward.
    rewrite Znth_map by lia.
    forward.
    rewrite Znth_map by lia.
    forward.
    forward.
    rewrite (swap_step pl bl n k (Znth k pl)) by (reflexivity || lia).
    Exists k. entailer!. }
  { rename a into k. forward. Exists (k + 1). entailer!. }
  { rename a into k. lt_of_ltu. replace k with n by lia. entailer!. }
  (* the forward solve, i = 0, ..., n - 1:
     y[i] = c[i] - lu[i] * y[0] - ... - lu[i + (i-1)*n] * y[i-1], no division *)
  change (c_cl pl bl n (Z.to_nat n)) with (c_pb pl bl n).
  assert (HC : Zlength (c_pb pl bl n) = n) by (apply Zlength_c_pb; lia).
  assert (HY : Zlength (c_yl ll pl bl n) = n) by (apply Zlength_c_yl; lia).
  forward_for
    (fun i : Z => PROP (0 <= i <= n;
        forall i', 0 <= i' < i -> Binary.is_finite 53 1024 (c_y ll pl bl n i') = true)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n)
              (lpre (c_yl ll pl bl n) (map Vfloat (c_pb pl bl n)) n i) x))
    continue:
    (fun i : Z => PROP (0 <= i < n;
        forall i', 0 <= i' < i + 1 -> Binary.is_finite 53 1024 (c_y ll pl bl n i') = true)
       LOCAL (temp _i (Vlong (Int64.repr i));
              temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n)
              (lpre (c_yl ll pl bl n) (map Vfloat (c_pb pl bl n)) n (i + 1)) x))
    break:
    (PROP (y_finite ll pl bl n)
       LOCAL (temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
       SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
            data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
            data_at shb (tarray tdouble n) (map Vfloat bl) b;
            data_at shx (tarray tdouble n)
              (lpre (c_yl ll pl bl n) (map Vfloat (c_pb pl bl n)) n n) x)).
  { forward. Exists 0. rewrite lpre_zero by (rewrite Zlength_map; lia). entailer!; intros; lia. }
  { entailer!. }
  { rename a into i. lt_of_ltu.
    forward.
    { entailer!. rewrite lpre_rest by (rewrite ?Zlength_map; lia). rewrite Znth_map by lia.
      exact I. }
    rewrite lpre_rest by (rewrite ?Zlength_map; lia). rewrite Znth_map by lia.
    rewrite Znth_c_pb by lia.
    replace (c_c pl bl (Z.to_nat n) (Z.to_nat i)) with (c_ydot ll pl bl n i 0) by reflexivity.
    forward_for
      (fun k : Z => PROP (0 <= k <= i)
         LOCAL (temp _k (Vlong (Int64.repr k)); temp _s (Vfloat (c_ydot ll pl bl n i k));
                temp _i (Vlong (Int64.repr i));
                temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
              data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n)
                (lpre (c_yl ll pl bl n) (map Vfloat (c_pb pl bl n)) n i) x))
      continue:
      (fun k : Z => PROP (0 <= k < i)
         LOCAL (temp _k (Vlong (Int64.repr k)); temp _s (Vfloat (c_ydot ll pl bl n i (k + 1)));
                temp _i (Vlong (Int64.repr i));
                temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
              data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n)
                (lpre (c_yl ll pl bl n) (map Vfloat (c_pb pl bl n)) n i) x))
      break:
      (PROP ()
         LOCAL (temp _s (Vfloat (c_ydot ll pl bl n i i)); temp _i (Vlong (Int64.repr i));
                temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
              data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n)
                (lpre (c_yl ll pl bl n) (map Vfloat (c_pb pl bl n)) n i) x)).
    { forward. Exists 0. entailer!. }
    { entailer!. }
    { rename a into k. lt_of_ltu.
      assert (Hik : 0 <= i + k * n < n * n) by nia.
      forward.
      rewrite Znth_map by lia.
      forward.
      { entailer!. rewrite lpre_get by (rewrite ?Zlength_map; lia). exact I. }
      rewrite lpre_get by (rewrite ?Zlength_map; lia). rewrite Znth_c_yl by lia.
      forward. Exists k. entailer!. rewrite c_ydot_succ by lia. reflexivity. }
    { rename a into k. forward. Exists (k + 1). entailer!. }
    { rename a into k. lt_of_ltu. replace k with i by lia. entailer!. }
    rewrite <- c_y_eq by lia.
    forward_call (c_y ll pl bl n i).
    destruct (Binary.is_finite 53 1024 (c_y ll pl bl n i)) eqn:Hfin.
    - forward_if; [discriminate |].
      replace (Vfloat (c_y ll pl bl n i)) with (Vfloat (Znth i (c_yl ll pl bl n)))
        by (rewrite Znth_c_yl by lia; reflexivity).
      forward. Exists i. entailer!.
      + intros i' Hi'. destruct (zeq i' i) as [-> | Hne]; [exact Hfin |].
        match goal with H : forall i', 0 <= i' < i -> _ |- _ => apply H; lia end.
      + rewrite lpre_step by (rewrite ?Zlength_map; lia). cancel.
    - forward_if.
      + set (xs := lpre (c_yl ll pl bl n) (map Vfloat (c_pb pl bl n)) n i).
        forward. Exists (-5) xs. entailer!.
        right. right. right. left. split; [reflexivity |]. split; [exact Haf |].
        split; [exact Hpo |]. split; [exact Hvf |]. split; [exact Hdz |].
        exists i. split; [lia |]. split; [| split; [exact Hfin | reflexivity]].
        match goal with H : forall i', 0 <= i' < i -> _ |- _ => exact H end.
      + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
  { rename a into i. forward. Exists (i + 1). entailer!. }
  { rename a into i. lt_of_ltu. replace i with n by lia.
    entailer!. intros i' Hi'.
    match goal with H : forall i', 0 <= i' < _ -> _ |- _ => apply H; lia end. }
  match goal with H : y_finite _ _ _ _ |- _ => rename H into Hyf end.
  rewrite lpre_full by (rewrite ?Zlength_map; lia).
  (* the back solve, i = n - 1 down to 0:
     x[i] = (y[i] - lu[i + (n-1)*n] * x[n-1] - ... - lu[i + (i+1)*n] * x[i+1]) / lu[i + i*n] *)
  assert (HX : Zlength (c_xl ll pl bl n) = n) by (apply Zlength_c_xl; lia).
  forward.
  forward_while
    (EX i : Z,
     PROP (0 <= i <= n;
           forall i', i <= i' < n -> Binary.is_finite 53 1024 (c_x ll pl bl n i') = true)
     LOCAL (temp _i (Vlong (Int64.repr i));
            temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
     SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
          data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
          data_at shb (tarray tdouble n) (map Vfloat bl) b;
          data_at shx (tarray tdouble n)
            (lsuf (c_xl ll pl bl n) (map Vfloat (c_yl ll pl bl n)) n i) x)).
  { Exists n. rewrite lsuf_zero by (rewrite ?Zlength_map; lia). entailer!; intros; lia. }
  { entailer!. }
  { rename HRE into Hi0.
    forward.
    forward.
    { entailer!. rewrite lsuf_rest by (rewrite ?Zlength_map; lia). rewrite Znth_map by lia.
      exact I. }
    rewrite lsuf_rest by (rewrite ?Zlength_map; lia). rewrite Znth_map by lia.
    rewrite Znth_c_yl by lia.
    replace (c_y ll pl bl n (i - 1)) with (c_xdot ll pl bl n (i - 1) 0) by reflexivity.
    assert (Hii : 0 <= i - 1 + (i - 1) * n < n * n) by nia.
    forward_for
      (fun k : Z => PROP (i - 1 <= k <= n - 1)
         LOCAL (temp _k (Vlong (Int64.repr k));
                temp _s (Vfloat (c_xdot ll pl bl n (i - 1) (n - 1 - k)));
                temp _i (Vlong (Int64.repr (i - 1)));
                temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
              data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n)
                (lsuf (c_xl ll pl bl n) (map Vfloat (c_yl ll pl bl n)) n i) x))
      continue:
      (fun k : Z => PROP (i - 1 < k <= n - 1)
         LOCAL (temp _k (Vlong (Int64.repr k));
                temp _s (Vfloat (c_xdot ll pl bl n (i - 1) (n - k)));
                temp _i (Vlong (Int64.repr (i - 1)));
                temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
              data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n)
                (lsuf (c_xl ll pl bl n) (map Vfloat (c_yl ll pl bl n)) n i) x))
      break:
      (PROP ()
         LOCAL (temp _s (Vfloat (c_xdot ll pl bl n (i - 1) (n - 1 - (i - 1))));
                temp _i (Vlong (Int64.repr (i - 1)));
                temp _lu lu; temp _piv piv; temp _n (Vlong (Int64.repr n)); temp _b b; temp _x x)
         SEP (data_at shl (tarray tdouble (n * n)) (map Vfloat ll) lu;
              data_at shp (tarray tulong n) (map (fun z => Vlong (Int64.repr z)) pl) piv;
              data_at shb (tarray tdouble n) (map Vfloat bl) b;
              data_at shx (tarray tdouble n)
                (lsuf (c_xl ll pl bl n) (map Vfloat (c_yl ll pl bl n)) n i) x)).
    { forward. Exists (n - 1). replace (n - 1 - (n - 1)) with 0 by lia. entailer!. }
    { entailer!. }
    { rename a into k.
      assert (Hk : i - 1 < k) by (lt_of_ltu; lia).
      assert (Hki : 0 <= i - 1 + k * n < n * n) by nia.
      forward.
      rewrite Znth_map by lia.
      forward.
      { entailer!. rewrite lsuf_get by (rewrite ?Zlength_map; lia). exact I. }
      rewrite lsuf_get by (rewrite ?Zlength_map; lia). rewrite Znth_c_xl by lia.
      forward. Exists k.
      replace (n - k) with (n - 1 - k + 1) by lia.
      rewrite c_xdot_succ by lia. replace (n - 1 - (n - 1 - k)) with k by lia.
      entailer!. }
    { rename a into k. forward. Exists (k - 1). replace (n - 1 - (k - 1)) with (n - k) by lia.
      entailer!. }
    { rename a into k.
      assert (Hk : k <= i - 1) by (lt_of_ltu; lia).
      replace k with (i - 1) by lia. entailer!. }
    forward.
    rewrite Znth_map by lia.
    forward.
    rewrite <- c_x_eq by lia.
    forward_call (c_x ll pl bl n (i - 1)).
    destruct (Binary.is_finite 53 1024 (c_x ll pl bl n (i - 1))) eqn:Hfin.
    - forward_if; [discriminate |].
      replace (Vfloat (c_x ll pl bl n (i - 1))) with (Vfloat (Znth (i - 1) (c_xl ll pl bl n)))
        by (rewrite Znth_c_xl by lia; reflexivity).
      forward. Exists (i - 1). entailer!.
      + intros i' Hi'. destruct (zeq i' (i - 1)) as [-> | Hne]; [exact Hfin |].
        match goal with H : forall i', i <= i' < _ -> _ |- _ => apply H; lia end.
      + rewrite lsuf_step by (rewrite ?Zlength_map; lia). cancel.
    - forward_if.
      + set (xs := lsuf (c_xl ll pl bl n) (map Vfloat (c_yl ll pl bl n)) n i).
        forward. Exists (-5) xs. entailer!.
        right. right. right. right. split; [reflexivity |]. split; [exact Haf |].
        split; [exact Hpo |]. split; [exact Hvf |]. split; [exact Hdz |]. split; [exact Hyf |].
        exists (i - 1). split; [lia |].
        split; [| split; [exact Hfin | unfold xs; f_equal; lia]].
        intros i' Hi'.
        match goal with H : forall i', i <= i' < _ -> _ |- _ => apply H; lia end.
      + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
  assert (Hi0 : i = 0) by lia.
  subst i.
  rewrite lsuf_full by (rewrite ?Zlength_map; lia).
  set (xs := map Vfloat (c_xl ll pl bl n)).
  forward. Exists 0 xs. entailer!.
  left. repeat split; assumption.
Qed.
