From VST.floyd Require Import proofauto.
From Diana.Clight Require Import lu_aarch64_macos.
From Diana.Real Require LU.
From Diana.Float Require LU.
From Diana.VST Require Bisection.
From Diana.VST Require Import Matrix Tactic.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

(* The binary64 model with CompCert's operations: Float.sub, Float.mul, Float.div, and the
   C's magnitude v < 0.0 ? -v : v with Float.neg, by conversion. *)
Definition cops : Diana.Real.LU.ops float :=
  Diana.Float.LU.fops Float.binop_nan Float.binop_nan Float.binop_nan Float.neg_nan.

(* A i j = a[i + j*n], column-major. *)
Definition c_a (al : list float) (n : Z) (i j : nat) : float :=
  Znth (Z.of_nat i + Z.of_nat j * n) al.

(* The working matrix after k steps, the pivot row and the magnitude tested at step k. *)
Definition c_state (al : list float) (n : Z) (k : nat) : nat -> nat -> float :=
  Diana.Real.LU.state cops (Z.to_nat n) (c_a al n) k.

Definition c_piv (al : list float) (n : Z) (k : nat) : nat :=
  Diana.Real.LU.pivot cops (Z.to_nat n) k (c_state al n k).

Definition c_top (al : list float) (n : Z) (k : nat) : float :=
  Diana.Real.LU.top cops (Z.to_nat n) k (c_state al n k).

(* An n x n matrix as the column-major list of its entries. *)
Definition mlist (n : Z) (M : nat -> nat -> float) : list float :=
  map (fun p => M (Z.to_nat (p mod n)) (Z.to_nat (p / n))) (upto (Z.to_nat (n * n))).

(* The pivot rows as the C stores them in piv. *)
Definition c_piv_list (al : list float) (n : Z) : list val :=
  map (fun k => Vlong (Int64.repr (Z.of_nat (c_piv al n (Z.to_nat k))))) (upto (Z.to_nat n)).

(* The C's exits: every entry of a finite; step k passes its pivot test and its updates are
   finite (Diana.Float.LU.step_ok); a zero pivot; an overflowing update. *)
Definition all_finite (al : list float) (n : Z) : Prop :=
  forall p, 0 <= p < n * n -> Binary.is_finite 53 1024 (Znth p al) = true.

Definition c_step_ok (al : list float) (n : Z) (k : nat) : Prop :=
  Diana.Float.LU.step_ok Float.binop_nan Float.binop_nan Float.binop_nan Float.neg_nan
    (c_a al n) (Z.to_nat n) k.

Definition c_ok (al : list float) (n : Z) : Prop :=
  Diana.Float.LU.fok Float.binop_nan Float.binop_nan Float.binop_nan Float.neg_nan
    (c_a al n) (Z.to_nat n).

Definition c_zero_pivot (al : list float) (n : Z) (k : nat) : Prop :=
  Float.cmp Ceq (c_top al n k) Float.zero = true.

Definition c_overflow (al : list float) (n : Z) (k : nat) : Prop :=
  Float.cmp Ceq (c_top al n k) Float.zero = false /\
  exists i j, (k < i)%nat /\ (i < Z.to_nat n)%nat /\ (k < j)%nat /\ (j < Z.to_nat n)%nat /\
    Binary.is_finite 53 1024 (c_state al n (S k) i j) = false.

(* Partial states of step k on B, the working matrix before it. *)

(* Rows k and p interchanged in the columns before j. *)
Definition pswap (k p j : nat) (B : nat -> nat -> float) (i' j' : nat) : float :=
  if (j' <? j)%nat then Diana.Real.LU.swap k p B i' j' else B i' j'.

(* The multipliers of the rows k + 1, ..., i - 1 stored. *)
Definition pmult (k i : nat) (B : nat -> nat -> float) (i' j' : nat) : float :=
  if andb (andb (j' =? k)%nat (k <? i')%nat) (i' <? i)%nat then Diana.Real.LU.elim cops k B i' j'
  else B i' j'.

(* The columns before j and the rows before i of column j eliminated. *)
Definition pcell (k j i : nat) (B : nat -> nat -> float) (i' j' : nat) : float :=
  if orb (j' <? j)%nat (andb (j' =? j)%nat (i' <? i)%nat) then Diana.Real.LU.elim cops k B i' j'
  else B i' j'.

(* The finished part of the updates is finite. *)
Definition pfin (n : Z) (k j i : nat) (B : nat -> nat -> float) : Prop :=
  forall i' j', (k < i')%nat -> (i' < Z.to_nat n)%nat -> (k < j')%nat ->
    ((j' < j)%nat \/ (j' = j /\ i' < i)%nat) ->
    Binary.is_finite 53 1024 (Diana.Real.LU.elim cops k B i' j') = true.

Definition vpre (L ol : list val) (N p : Z) : list val := sublist 0 p L ++ sublist p N ol.

Lemma zero_bits : Float.of_bits (Int64.repr 0) = Float.zero.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma Zlength_mlist (n : Z) (M : nat -> nat -> float) :
  0 <= n -> Zlength (mlist n M) = n * n.
Proof.
  intro Hn. unfold mlist. rewrite Zlength_map, Zlength_upto, Z2Nat.id by nia. reflexivity.
Qed.

Lemma Znth_mlist (n : Z) (M : nat -> nat -> float) (i j : Z) :
  0 <= i < n -> 0 <= j < n -> Znth (i + j * n) (mlist n M) = M (Z.to_nat i) (Z.to_nat j).
Proof.
  intros Hi Hj. unfold mlist.
  rewrite Znth_map by (rewrite Zlength_upto, Z2Nat.id by nia; nia).
  rewrite Znth_upto by (rewrite Z2Nat.id by nia; nia).
  rewrite Z.mod_add, Z.mod_small by lia. rewrite Z.div_add, Z.div_small by lia.
  reflexivity.
Qed.

Lemma mlist_ext (n : Z) (M M' : nat -> nat -> float) :
  0 <= n ->
  (forall i j, (i < Z.to_nat n)%nat -> (j < Z.to_nat n)%nat -> M i j = M' i j) ->
  mlist n M = mlist n M'.
Proof.
  intros Hn H. unfold mlist. apply map_ext_in. intros q Hq.
  apply In_upto in Hq. rewrite Z2Nat.id in Hq by nia.
  assert (Hn0 : 0 < n) by nia.
  apply H.
  - pose proof (Z.mod_pos_bound q n ltac:(lia)). lia.
  - assert (0 <= q / n < n) by (split; [apply Z.div_pos; lia | apply Z.div_lt_upper_bound; nia]).
    lia.
Qed.

(* Storing v at (i, j). *)
Definition fupd (M : nat -> nat -> float) (i j : nat) (v : float) (i' j' : nat) : float :=
  if andb (i' =? i)%nat (j' =? j)%nat then v else M i' j'.

Lemma upd_mlist (n : Z) (M : nat -> nat -> float) (i j : Z) (v : float) :
  0 <= i < n -> 0 <= j < n ->
  upd_Znth (i + j * n) (map Vfloat (mlist n M)) (Vfloat v) =
  map Vfloat (mlist n (fupd M (Z.to_nat i) (Z.to_nat j) v)).
Proof.
  intros Hi Hj. assert (Hl : Zlength (mlist n M) = n * n) by (apply Zlength_mlist; lia).
  apply Znth_eq_ext.
  - rewrite Zlength_upd_Znth, !Zlength_map, Hl, Zlength_mlist by lia. reflexivity.
  - intros q Hq. rewrite Zlength_upd_Znth, Zlength_map, Hl in Hq.
    assert (Hn0 : 0 < n) by lia.
    set (i' := q mod n). set (j' := q / n).
    assert (Hq' : q = i' + j' * n) by (unfold i', j'; pose proof (Z.div_mod q n ltac:(lia)); lia).
    assert (Hi' : 0 <= i' < n) by (apply Z.mod_pos_bound; lia).
    assert (Hj' : 0 <= j' < n) by (split; [apply Z.div_pos; lia | apply Z.div_lt_upper_bound; nia]).
    rewrite Znth_map by (rewrite Zlength_mlist; lia).
    rewrite Hq', Znth_mlist by lia. unfold fupd.
    destruct (Z.eq_dec (i' + j' * n) (i + j * n)) as [E | E].
    + rewrite E, upd_Znth_same by (rewrite Zlength_map, Hl; nia).
      assert (Ei : i' = i /\ j' = j).
      { assert (Ejj : j' = j) by (apply (f_equal (fun x => x / n)) in E;
                                  rewrite !Z.div_add, !Z.div_small in E by lia; lia).
        split; [lia | exact Ejj]. }
      destruct Ei as [-> ->]. rewrite !Nat.eqb_refl. reflexivity.
    + rewrite upd_Znth_diff by (rewrite ?Zlength_map, ?Hl; nia).
      rewrite Znth_map by (rewrite Hl; nia). rewrite Znth_mlist by lia.
      replace (andb (Z.to_nat i' =? Z.to_nat i)%nat (Z.to_nat j' =? Z.to_nat j)%nat)
        with false; [reflexivity |].
      symmetry. apply andb_false_iff.
      destruct (Z.eq_dec i' i) as [-> | Hii].
      * right. apply Nat.eqb_neq. intro Ej. apply E. apply Z2Nat.inj in Ej; lia.
      * left. apply Nat.eqb_neq. intro Ei. apply Hii. apply Z2Nat.inj in Ei; lia.
Qed.

Lemma mlist_c_a (al : list float) (n : Z) :
  0 <= n -> Zlength al = n * n -> mlist n (c_a al n) = al.
Proof.
  intros Hn Hl. apply Znth_eq_ext; [rewrite Zlength_mlist; lia |].
  intros q Hq. rewrite Zlength_mlist in Hq by lia.
  assert (Hn0 : 0 < n) by nia.
  pose proof (Z.div_mod q n ltac:(lia)) as Hdm.
  assert (Hi' : 0 <= q mod n < n) by (apply Z.mod_pos_bound; lia).
  assert (Hj' : 0 <= q / n < n) by (split; [apply Z.div_pos; lia | apply Z.div_lt_upper_bound; nia]).
  rewrite Hdm at 1. rewrite Z.add_comm, Z.mul_comm, Znth_mlist by lia.
  unfold c_a. rewrite !Z2Nat.id by lia. f_equal. lia.
Qed.

Lemma Zlength_vpre (L ol : list val) (N p : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= p <= N -> Zlength (vpre L ol N p) = N.
Proof. intros. unfold vpre. list_solve. Qed.

Lemma vpre_step (L ol : list val) (N p : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= p < N ->
  upd_Znth p (vpre L ol N p) (Znth p L) = vpre L ol N (p + 1).
Proof. intros. unfold vpre. list_solve. Qed.

Lemma vpre_zero (L ol : list val) (N : Z) : Zlength ol = N -> vpre L ol N 0 = ol.
Proof. intros. unfold vpre. list_solve. Qed.

Lemma vpre_full (L ol : list val) (N : Z) :
  Zlength L = N -> Zlength ol = N -> vpre L ol N N = L.
Proof. intros. unfold vpre. list_solve. Qed.

Lemma Zlength_c_piv_list (al : list float) (n : Z) : 0 <= n -> Zlength (c_piv_list al n) = n.
Proof. intro. unfold c_piv_list. rewrite Zlength_map, Zlength_upto, Z2Nat.id by lia. reflexivity. Qed.

Lemma Znth_c_piv_list (al : list float) (n k : Z) :
  0 <= k < n ->
  Znth k (c_piv_list al n) = Vlong (Int64.repr (Z.of_nat (c_piv al n (Z.to_nat k)))).
Proof.
  intro Hk. unfold c_piv_list.
  rewrite Znth_map by (rewrite Zlength_upto, Z2Nat.id by lia; lia).
  rewrite Znth_upto by (rewrite Z2Nat.id by lia; lia). reflexivity.
Qed.

Lemma all_finite_c_a (al : list float) (n : Z) :
  0 <= n -> all_finite al n ->
  forall i j, (i < Z.to_nat n)%nat -> (j < Z.to_nat n)%nat ->
    Binary.is_finite 53 1024 (c_a al n i j) = true.
Proof. intros Hn H i j Hi Hj. unfold c_a. apply H. nia. Qed.

Lemma c_state_succ (al : list float) (n : Z) (k : nat) :
  c_state al n (S k) =
  Diana.Real.LU.elim cops k (Diana.Real.LU.swap k (c_piv al n k) (c_state al n k)).
Proof. reflexivity. Qed.

Lemma search_succ (B : nat -> nat -> float) (k t : nat) :
  Diana.Real.LU.search cops B k (S t) =
  if Float.cmp Cgt (if Float.cmp Clt (B (k + t)%nat k) Float.zero then Float.neg (B (k + t)%nat k)
                    else B (k + t)%nat k)
       (snd (Diana.Real.LU.search cops B k t))
  then ((k + t)%nat, if Float.cmp Clt (B (k + t)%nat k) Float.zero then Float.neg (B (k + t)%nat k)
                     else B (k + t)%nat k)
  else Diana.Real.LU.search cops B k t.
Proof. reflexivity. Qed.

Ltac nat_cases :=
  repeat match goal with
  | |- context [(?x =? ?y)%nat] => destruct (Nat.eqb_spec x y)
  | |- context [(?x <? ?y)%nat] => destruct (Nat.ltb_spec x y)
  end; cbn [andb orb negb]; try lia; try reflexivity; try (subst; reflexivity).

Lemma pswap_zero (k p : nat) (B : nat -> nat -> float) (i j : nat) : pswap k p 0 B i j = B i j.
Proof. reflexivity. Qed.

Lemma pswap_step (k p j : nat) (B : nat -> nat -> float) (i' j' : nat) :
  fupd (fupd (pswap k p j B) k j (B p j)) p j (B k j) i' j' = pswap k p (S j) B i' j'.
Proof. unfold fupd, pswap, Diana.Real.LU.swap. nat_cases. Qed.

Lemma pswap_full (k p N : nat) (B : nat -> nat -> float) (i j : nat) :
  (j < N)%nat -> pswap k p N B i j = Diana.Real.LU.swap k p B i j.
Proof. intro H. unfold pswap. nat_cases. Qed.

Lemma pswap_get (k p j : nat) (B : nat -> nat -> float) (i : nat) : pswap k p j B i j = B i j.
Proof. unfold pswap. nat_cases. Qed.

Lemma pmult_start (k : nat) (B : nat -> nat -> float) (i j : nat) : pmult k (S k) B i j = B i j.
Proof. unfold pmult. nat_cases. Qed.

Lemma pmult_step (k i : nat) (B : nat -> nat -> float) (i' j' : nat) :
  (k < i)%nat ->
  fupd (pmult k i B) i k (Diana.Real.LU.elim cops k B i k) i' j' = pmult k (S i) B i' j'.
Proof. intro H. unfold fupd, pmult. nat_cases. Qed.

Lemma pmult_get (k i : nat) (B : nat -> nat -> float) : pmult k i B i k = B i k.
Proof. unfold pmult. nat_cases. Qed.

Lemma pmult_pcell (k N : nat) (B : nat -> nat -> float) (i j : nat) :
  (i < N)%nat -> pmult k N B i j = pcell k (S k) 0 B i j.
Proof. intro H. unfold pmult, pcell, Diana.Real.LU.elim. nat_cases. Qed.

Lemma pcell_start (k j : nat) (B : nat -> nat -> float) (i' j' : nat) :
  (k < j)%nat -> pcell k j 0 B i' j' = pcell k j (S k) B i' j'.
Proof. intro H. unfold pcell, Diana.Real.LU.elim. nat_cases. Qed.

Lemma pcell_step (k j i : nat) (B : nat -> nat -> float) (i' j' : nat) :
  fupd (pcell k j i B) i j (Diana.Real.LU.elim cops k B i j) i' j' = pcell k j (S i) B i' j'.
Proof. unfold fupd, pcell. nat_cases. Qed.

Lemma pcell_next (k j N : nat) (B : nat -> nat -> float) (i' j' : nat) :
  (i' < N)%nat -> pcell k j N B i' j' = pcell k (S j) 0 B i' j'.
Proof. intro H. unfold pcell. nat_cases. Qed.

Lemma pcell_full (k N : nat) (B : nat -> nat -> float) (i j : nat) :
  (j < N)%nat -> pcell k N 0 B i j = Diana.Real.LU.elim cops k B i j.
Proof. intro H. unfold pcell. nat_cases. Qed.

Lemma pcell_get (k j i : nat) (B : nat -> nat -> float) : pcell k j i B i j = B i j.
Proof. unfold pcell. nat_cases. Qed.

Lemma pcell_mult (k j i' i : nat) (B : nat -> nat -> float) :
  (k < j)%nat -> pcell k j i' B i k = Diana.Real.LU.elim cops k B i k.
Proof. intro H. unfold pcell. nat_cases. Qed.

Lemma pcell_row (k j : nat) (B : nat -> nat -> float) : pcell k j 0 B k j = B k j.
Proof. unfold pcell. nat_cases. Qed.

Lemma elim_update (k i j : nat) (B : nat -> nat -> float) :
  (k < i)%nat -> (k < j)%nat ->
  Diana.Real.LU.elim cops k B i j =
  Float.sub (B i j) (Float.mul (Diana.Real.LU.elim cops k B i k) (B k j)).
Proof.
  intros Hi Hj. unfold Diana.Real.LU.elim.
  replace (k <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Hi).
  rewrite Nat.eqb_refl.
  replace (j =? k)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
  replace (k <? j)%nat with true by (symmetry; apply Nat.ltb_lt; exact Hj).
  reflexivity.
Qed.

Lemma elim_mult (k i : nat) (B : nat -> nat -> float) :
  (k < i)%nat -> Diana.Real.LU.elim cops k B i k = Float.div (B i k) (B k k).
Proof.
  intro Hi. unfold Diana.Real.LU.elim.
  replace (k <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Hi).
  rewrite Nat.eqb_refl. reflexivity.
Qed.

Lemma swap_diag (k p : nat) (B : nat -> nat -> float) : Diana.Real.LU.swap k p B k k = B p k.
Proof. unfold Diana.Real.LU.swap. rewrite Nat.eqb_refl. reflexivity. Qed.

Lemma mul_repr_nn (n : Z) :
  0 <= n <= Int64.max_unsigned -> Int64.mul (Int64.repr n) (Int64.repr n) = Int64.repr (n * n).
Proof. intro H. unfold Int64.mul. rewrite Int64.unsigned_repr by lia. reflexivity. Qed.

Definition c_mag (x : float) : float := if Float.cmp Clt x Float.zero then Float.neg x else x.

Lemma search_zero (B : nat -> nat -> float) (k : nat) :
  Diana.Real.LU.search cops B k 0 = (k, Float.zero).
Proof. reflexivity. Qed.

Lemma search_step_z (B : nat -> nat -> float) (k i : Z) :
  0 <= k <= i ->
  Diana.Real.LU.search cops B (Z.to_nat k) (Z.to_nat (i - k + 1)) =
  if Float.cmp Cgt (c_mag (B (Z.to_nat i) (Z.to_nat k)))
       (snd (Diana.Real.LU.search cops B (Z.to_nat k) (Z.to_nat (i - k))))
  then (Z.to_nat i, c_mag (B (Z.to_nat i) (Z.to_nat k)))
  else Diana.Real.LU.search cops B (Z.to_nat k) (Z.to_nat (i - k)).
Proof.
  intro H. replace (Z.to_nat (i - k + 1)) with (S (Z.to_nat (i - k))) by lia.
  rewrite search_succ. replace (Z.to_nat k + Z.to_nat (i - k))%nat with (Z.to_nat i) by lia.
  reflexivity.
Qed.

Lemma search_end (al : list float) (n k : Z) :
  0 <= k <= n ->
  Diana.Real.LU.search cops (c_state al n (Z.to_nat k)) (Z.to_nat k) (Z.to_nat (n - k)) =
  (c_piv al n (Z.to_nat k), c_top al n (Z.to_nat k)).
Proof.
  intro H. unfold c_piv, c_top, Diana.Real.LU.pivot, Diana.Real.LU.top.
  replace (Z.to_nat (n - k)) with (Z.to_nat n - Z.to_nat k)%nat by lia.
  destruct (Diana.Real.LU.search _ _ _ _). reflexivity.
Qed.

Lemma c_piv_range (al : list float) (n k : Z) :
  0 <= k < n -> (Z.to_nat k <= c_piv al n (Z.to_nat k) < Z.to_nat n)%nat.
Proof. intro H. apply Diana.Real.LU.pivot_range. lia. Qed.

Definition fp_finite_spec :=
  DECLARE _diana_fp_finite
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tint ]
    PROP () RETURN (Vint (if Binary.is_finite 53 1024 x then Int.one else Int.zero)) SEP ().

Definition lu_spec :=
  DECLARE _diana_lu
  WITH sha : share, shl : share, shp : share, a : val, lu : val, piv : val,
       al : list float, n : Z, ol : list val, opl : list val
  PRE [ tptr tdouble, tulong, tptr tdouble, tptr tulong ]
    PROP (readable_share sha; writable_share shl; writable_share shp; 1 <= n;
          (n * n)%Z <= Int64.max_unsigned; Zlength al = (n * n)%Z; Zlength ol = (n * n)%Z;
          Zlength opl = n)
    PARAMS (a; Vlong (Int64.repr n); lu; piv)
    SEP (data_at sha (tarray tdouble ((n * n)%Z)) (map Vfloat al) a;
         data_at shl (tarray tdouble ((n * n)%Z)) ol lu;
         data_at shp (tarray tulong n) opl piv)
  POST [ tint ]
    EX st : Z, EX ls : list val, EX ps : list val,
    PROP ((st = 0 /\ c_ok al n /\ ls = map Vfloat (mlist n (c_state al n (Z.to_nat n))) /\
           ps = c_piv_list al n) \/
          (st = -1 /\ ~ all_finite al n /\ ls = ol /\ ps = opl) \/
          (st = -1 /\ all_finite al n /\
           (exists k, (k < Z.to_nat n)%nat /\ (forall k', (k' < k)%nat -> c_step_ok al n k') /\
              c_overflow al n k) /\
           Zlength ls = (n * n)%Z /\ Zlength ps = n) \/
          (st = -4 /\ all_finite al n /\
           (exists k, (k < Z.to_nat n)%nat /\ (forall k', (k' < k)%nat -> c_step_ok al n k') /\
              c_zero_pivot al n k) /\
           Zlength ls = (n * n)%Z /\ Zlength ps = n))
    RETURN (Vint (Int.repr st))
    SEP (data_at sha (tarray tdouble ((n * n)%Z)) (map Vfloat al) a;
         data_at shl (tarray tdouble ((n * n)%Z)) ls lu;
         data_at shp (tarray tulong n) ps piv).

Definition Gprog : funspecs := ltac:(with_library prog [fp_finite_spec; lu_spec]).

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

Lemma body_diana_lu : semax_body Vprog Gprog f_diana_lu lu_spec.
Proof.
  start_function.
  assert (Hn0 : n <= Int64.max_unsigned) by nia.
  assert_PROP (isptr a /\ isptr lu /\ isptr piv) as Hptr by entailer!.
  destruct Hptr as [Ha [Hl Hp]].
  join_zero _t'1.
  { subst a. contradiction. }
  { forward. entailer!. destruct lu; try contradiction. reflexivity. }
  join_zero _t'2.
  { contradiction. }
  { forward. entailer!. destruct piv; try contradiction. reflexivity. }
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
  assert (Hnn : 0 <= n * n) by nia.
  (* every entry of a is finite *)
  forward_for
    (fun q : Z => PROP (0 <= q <= n * n;
        forall p, 0 <= p < q -> Binary.is_finite 53 1024 (Znth p al) = true)
       LOCAL (temp _q (Vlong (Int64.repr q)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) ol lu;
            data_at shp (tarray tulong n) opl piv))
    continue:
    (fun q : Z => PROP (0 <= q < n * n;
        forall p, 0 <= p < q + 1 -> Binary.is_finite 53 1024 (Znth p al) = true)
       LOCAL (temp _q (Vlong (Int64.repr q)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) ol lu;
            data_at shp (tarray tulong n) opl piv))
    break:
    (PROP (all_finite al n)
       LOCAL (temp _a a; temp _n (Vlong (Int64.repr n)); temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) ol lu;
            data_at shp (tarray tulong n) opl piv)).
  { forward. Exists 0. entailer!; intros; lia. }
  { entailer!. }
  { rename a0 into q. rewrite mul_repr_nn in * by lia. lt_of_ltu.
    forward.
    rewrite Znth_map by lia.
    forward_call (Znth q al).
    destruct (Binary.is_finite 53 1024 (Znth q al)) eqn:Hfin.
    - forward_if; [discriminate |].
      forward. Exists q. entailer!. intros p' Hp'.
      destruct (zeq p' q) as [-> | Hne]; [exact Hfin |].
      match goal with H : forall p, 0 <= p < q -> _ |- _ => apply H; lia end.
    - forward_if.
      + forward. Exists (-1) ol opl. entailer!.
        right. left. split; [reflexivity |]. split; [| split; reflexivity].
        intro Haf. rewrite (Haf q) in Hfin by lia. discriminate.
      + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
  { rename a0 into q. forward. Exists (q + 1). entailer!. }
  { rename a0 into q. rewrite mul_repr_nn in * by lia. lt_of_ltu.
    entailer!. intros p' Hp'.
    match goal with H : forall p, 0 <= p < q -> _ |- _ => apply H; lia end. }
  match goal with H : all_finite _ _ |- _ => rename H into Haf end.
  (* lu = a *)
  forward_for
    (fun q : Z => PROP (0 <= q <= n * n)
       LOCAL (temp _q (Vlong (Int64.repr q)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) (lpre al ol (n * n) q) lu;
            data_at shp (tarray tulong n) opl piv))
    continue:
    (fun q : Z => PROP (0 <= q < n * n)
       LOCAL (temp _q (Vlong (Int64.repr q)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) (lpre al ol (n * n) (q + 1)) lu;
            data_at shp (tarray tulong n) opl piv))
    break:
    (PROP ()
       LOCAL (temp _a a; temp _n (Vlong (Int64.repr n)); temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n)) (lpre al ol (n * n) (n * n)) lu;
            data_at shp (tarray tulong n) opl piv)).
  { forward. Exists 0. rewrite lpre_zero by lia. entailer!. }
  { entailer!. }
  { rename a0 into q. rewrite mul_repr_nn in * by lia. lt_of_ltu.
    forward.
    rewrite Znth_map by lia.
    forward. Exists q. entailer!. rewrite lpre_step by lia. cancel. }
  { rename a0 into q. forward. Exists (q + 1). entailer!. }
  { rename a0 into q. rewrite mul_repr_nn in * by lia. lt_of_ltu.
    replace q with (n * n) by lia. entailer!. }
  rewrite lpre_full by lia.
  assert (HP : Zlength (c_piv_list al n) = n) by (apply Zlength_c_piv_list; lia).
  (* the steps k = 0, ..., n - 1 *)
  forward_for
    (fun k : Z => PROP (0 <= k <= n;
        forall k', (k' < Z.to_nat k)%nat -> c_step_ok al n k')
       LOCAL (temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n))
              (map Vfloat (mlist n (c_state al n (Z.to_nat k)))) lu;
            data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n k) piv))
    continue:
    (fun k : Z => PROP (0 <= k < n;
        forall k', (k' < Z.to_nat (k + 1))%nat -> c_step_ok al n k')
       LOCAL (temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
              temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n))
              (map Vfloat (mlist n (c_state al n (Z.to_nat (k + 1))))) lu;
            data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
    break:
    (PROP (forall k', (k' < Z.to_nat n)%nat -> c_step_ok al n k')
       LOCAL (temp _a a; temp _n (Vlong (Int64.repr n)); temp _lu lu; temp _piv piv)
       SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
            data_at shl (tarray tdouble (n * n))
              (map Vfloat (mlist n (c_state al n (Z.to_nat n)))) lu;
            data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n n) piv)).
  { forward. Exists 0. rewrite vpre_zero by lia.
    change (c_state al n (Z.to_nat 0)) with (c_a al n). rewrite mlist_c_a by lia.
    entailer!. }
  { entailer!. }
  { rename a0 into k. lt_of_ltu.
    match goal with H : forall k', (k' < Z.to_nat k)%nat -> _ |- _ => rename H into Hok end.
    set (kn := Z.to_nat k).
    set (B := c_state al n kn).
    assert (Hkk : 0 <= k + k * n < n * n) by nia.
    forward. forward.
    (* the pivot search *)
    forward_for
      (fun i : Z => PROP (k <= i <= n)
         LOCAL (temp _i (Vlong (Int64.repr i));
                temp _p (Vlong (Int64.repr (Z.of_nat
                  (fst (Diana.Real.LU.search cops B kn (Z.to_nat (i - k)))))));
                temp _m (Vfloat (snd (Diana.Real.LU.search cops B kn (Z.to_nat (i - k)))));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (map Vfloat (mlist n B)) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n k) piv))
      continue:
      (fun i : Z => PROP (k <= i < n)
         LOCAL (temp _i (Vlong (Int64.repr i));
                temp _p (Vlong (Int64.repr (Z.of_nat
                  (fst (Diana.Real.LU.search cops B kn (Z.to_nat (i - k + 1)))))));
                temp _m (Vfloat (snd (Diana.Real.LU.search cops B kn (Z.to_nat (i - k + 1)))));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (map Vfloat (mlist n B)) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n k) piv))
      break:
      (PROP ()
         LOCAL (temp _p (Vlong (Int64.repr (Z.of_nat (c_piv al n kn))));
                temp _m (Vfloat (c_top al n kn));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (map Vfloat (mlist n B)) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n k) piv)).
    { forward. Exists k. rewrite Z.sub_diag, search_zero. cbn [fst snd]. rewrite zero_bits.
      unfold kn. rewrite Z2Nat.id by lia. entailer!. }
    { entailer!. }
    { rename a0 into i. lt_of_ltu.
      assert (Hik : 0 <= i + k * n < n * n) by nia.
      forward.
      rewrite Znth_map by (rewrite Zlength_mlist; lia). rewrite Znth_mlist by lia.
      set (x := B (Z.to_nat i) (Z.to_nat k)).
      set (pm := Diana.Real.LU.search cops B kn (Z.to_nat (i - k))).
      forward_if
        (PROP ()
         LOCAL (temp _v (Vfloat (c_mag x)); temp _i (Vlong (Int64.repr i));
                temp _p (Vlong (Int64.repr (Z.of_nat (fst pm)))); temp _m (Vfloat (snd pm));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (map Vfloat (mlist n B)) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n k) piv)).
      { forward. entailer!. unfold c_mag. rewrite zero_bits in *.
        match goal with H : Float.cmp Clt x Float.zero = true |- _ => rewrite H end.
        reflexivity. }
      { forward. entailer!. unfold c_mag. rewrite zero_bits in *.
        match goal with H : Float.cmp Clt x Float.zero = false |- _ => rewrite H end.
        reflexivity. }
      assert (Hst : Diana.Real.LU.search cops B kn (Z.to_nat (i - k + 1)) =
                    if Float.cmp Cgt (c_mag x) (snd pm) then (Z.to_nat i, c_mag x) else pm)
        by (unfold kn, x, pm; apply search_step_z; lia).
      forward_if
        (PROP ()
         LOCAL (temp _i (Vlong (Int64.repr i));
                temp _p (Vlong (Int64.repr (Z.of_nat
                  (fst (Diana.Real.LU.search cops B kn (Z.to_nat (i - k + 1)))))));
                temp _m (Vfloat (snd (Diana.Real.LU.search cops B kn (Z.to_nat (i - k + 1)))));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n)) (map Vfloat (mlist n B)) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n k) piv)).
      { forward. forward. entailer!. rewrite Hst.
        match goal with H : Float.cmp Cgt (c_mag x) (snd pm) = true |- _ => rewrite H end.
        cbn [fst snd]. rewrite Z2Nat.id by lia. split; reflexivity. }
      { forward. entailer!. rewrite Hst.
        match goal with H : Float.cmp Cgt (c_mag x) (snd pm) = false |- _ => rewrite H end.
        split; reflexivity. }
      Exists i. entailer!. }
    { rename a0 into i. forward. Exists (i + 1).
      replace (i + 1 - k) with (i - k + 1) by lia. entailer!. }
    { rename a0 into i. lt_of_ltu. replace i with n by lia.
      change (Diana.Real.LU.search cops B kn (Z.to_nat (n - k)))
        with (Diana.Real.LU.search cops (c_state al n (Z.to_nat k)) (Z.to_nat k)
                (Z.to_nat (n - k))).
      rewrite search_end by lia. entailer!. }
    (* a zero pivot *)
    forward_if.
    { assert (Hz : exists k0, (k0 < Z.to_nat n)%nat /\
                     (forall k', (k' < k0)%nat -> c_step_ok al n k') /\ c_zero_pivot al n k0).
      { exists kn. split; [unfold kn; lia |]. split; [exact Hok |].
        unfold c_zero_pivot. rewrite zero_bits in *. assumption. }
      assert (Hl1 : Zlength (map Vfloat (mlist n B)) = n * n)
        by (rewrite Zlength_map, Zlength_mlist; lia).
      assert (Hl2 : Zlength (vpre (c_piv_list al n) opl n k) = n) by (apply Zlength_vpre; lia).
      set (ls0 := map Vfloat (mlist n B)) in *.
      set (ps0 := vpre (c_piv_list al n) opl n k) in *.
      forward. Exists (-4) ls0 ps0.
      entailer!. right. right. right. rewrite ?ZtoNat_Zlength in *.
      repeat match goal with |- _ /\ _ => split end; (reflexivity || assumption). }
    match goal with H : Float.cmp Ceq _ _ = false |- _ => rename H into Htop end.
    rewrite zero_bits in Htop.
    pose proof (c_piv_range al n k ltac:(lia)) as Hpr. fold kn in Hpr.
    set (p := c_piv al n kn) in *.
    set (pz := Z.of_nat p).
    assert (Hpz : Z.to_nat pz = p) by (unfold pz; apply Nat2Z.id).
    (* piv[k] = p *)
    forward.
    assert (Hv : upd_Znth k (vpre (c_piv_list al n) opl n k) (Vlong (Int64.repr pz)) =
                 vpre (c_piv_list al n) opl n (k + 1)).
    { rewrite <- vpre_step by lia. rewrite Znth_c_piv_list by lia. reflexivity. }
    rewrite Hv.
    (* the interchange of rows k and p *)
    forward_for
      (fun j : Z => PROP (0 <= j <= n)
         LOCAL (temp _j (Vlong (Int64.repr j)); temp _p (Vlong (Int64.repr pz));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (pswap kn p (Z.to_nat j) B))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
      continue:
      (fun j : Z => PROP (0 <= j < n)
         LOCAL (temp _j (Vlong (Int64.repr j)); temp _p (Vlong (Int64.repr pz));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (pswap kn p (Z.to_nat (j + 1)) B))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
      break:
      (PROP ()
         LOCAL (temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (Diana.Real.LU.swap kn p B))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv)).
    { forward. Exists 0. entailer!. }
    { entailer!. }
    { rename a0 into j. lt_of_ltu.
      assert (Hkj : 0 <= k + j * n < n * n) by nia.
      assert (Hpj : 0 <= pz + j * n < n * n) by nia.
      forward.
      rewrite Znth_map by (rewrite Zlength_mlist; lia). rewrite Znth_mlist by lia.
      forward.
      rewrite Znth_map by (rewrite Zlength_mlist; lia). rewrite Znth_mlist by lia.
      rewrite Hpz, !pswap_get.
      forward.
      rewrite upd_mlist by lia.
      forward.
      rewrite upd_mlist by lia. rewrite ?Hpz.
      erewrite (mlist_ext n _ (pswap kn p (Z.to_nat (j + 1)) B)).
      2: lia.
      2: { intros i' j' _ _. replace (Z.to_nat (j + 1)) with (S (Z.to_nat j)) by lia.
           apply pswap_step. }
      Exists j. entailer!. }
    { rename a0 into j. forward. Exists (j + 1). entailer!. }
    { rename a0 into j. lt_of_ltu.
      rewrite (mlist_ext n (pswap kn p (Z.to_nat j) B) (Diana.Real.LU.swap kn p B)).
      2: lia.
      2: { intros i' j' _ Hj'. apply pswap_full. lia. }
      entailer!. }
    set (B1 := Diana.Real.LU.swap kn p B).
    (* d = lu[k + k*n] *)
    forward.
    rewrite Znth_map by (rewrite Zlength_mlist; lia). rewrite Znth_mlist by lia.
    fold kn.
    (* the multipliers *)
    forward_for
      (fun i : Z => PROP (k + 1 <= i <= n)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _d (Vfloat (B1 kn kn));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (pmult kn (Z.to_nat i) B1))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
      continue:
      (fun i : Z => PROP (k + 1 <= i < n)
         LOCAL (temp _i (Vlong (Int64.repr i)); temp _d (Vfloat (B1 kn kn));
                temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (pmult kn (Z.to_nat (i + 1)) B1))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
      break:
      (PROP ()
         LOCAL (temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (pcell kn (S kn) 0 B1))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv)).
    { forward.
      rewrite (mlist_ext n B1 (pmult kn (Z.to_nat (k + 1)) B1)).
      2: lia.
      2: { intros i' j' _ _. replace (Z.to_nat (k + 1)) with (S kn) by lia.
           symmetry. apply pmult_start. }
      Exists (k + 1). entailer!. }
    { entailer!. }
    { rename a0 into i. lt_of_ltu.
      assert (Hik : 0 <= i + k * n < n * n) by nia.
      forward.
      rewrite Znth_map by (rewrite Zlength_mlist; lia). rewrite Znth_mlist by lia.
      fold kn. rewrite pmult_get.
      forward.
      rewrite upd_mlist by lia. fold kn.
      rewrite <- (elim_mult kn (Z.to_nat i) B1) by lia.
      erewrite (mlist_ext n _ (pmult kn (Z.to_nat (i + 1)) B1)).
      2: lia.
      2: { intros i' j' _ _. replace (Z.to_nat (i + 1)) with (S (Z.to_nat i)) by lia.
           apply pmult_step. lia. }
      Exists i. entailer!. }
    { rename a0 into i. forward. Exists (i + 1). entailer!. }
    { rename a0 into i. lt_of_ltu.
      rewrite (mlist_ext n (pmult kn (Z.to_nat i) B1) (pcell kn (S kn) 0 B1)).
      2: lia.
      2: { intros i' j' Hi' _. apply pmult_pcell. lia. }
      entailer!. }
    (* the updates of the rows and columns after k *)
    apply <- semax_seq_skip.
    forward_for
      (fun j : Z => PROP (k + 1 <= j <= n; pfin n kn (Z.to_nat j) 0 B1)
         LOCAL (temp _j (Vlong (Int64.repr j)); temp _k (Vlong (Int64.repr k)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (pcell kn (Z.to_nat j) 0 B1))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
      continue:
      (fun j : Z => PROP (k + 1 <= j < n; pfin n kn (Z.to_nat (j + 1)) 0 B1)
         LOCAL (temp _j (Vlong (Int64.repr j)); temp _k (Vlong (Int64.repr k)); temp _a a;
                temp _n (Vlong (Int64.repr n)); temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (pcell kn (Z.to_nat (j + 1)) 0 B1))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
      break:
      (PROP (pfin n kn (Z.to_nat n) 0 B1)
         LOCAL (temp _k (Vlong (Int64.repr k)); temp _a a; temp _n (Vlong (Int64.repr n));
                temp _lu lu; temp _piv piv)
         SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
              data_at shl (tarray tdouble (n * n))
                (map Vfloat (mlist n (pcell kn (Z.to_nat n) 0 B1))) lu;
              data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv)).
    { forward. Exists (k + 1).
      replace (Z.to_nat (k + 1)) with (S kn) by lia.
      assert (Hf0 : pfin n kn (S kn) 0 B1) by (intros i' j' G1 G2 G3 G4; exfalso; lia).
      entailer!. }
    { entailer!. }
    { rename a0 into j. lt_of_ltu.
      match goal with H : pfin _ _ _ _ _ |- _ => rename H into Hpf end.
      assert (Hkj : 0 <= k + j * n < n * n) by nia.
      forward.
      rewrite Znth_map by (rewrite Zlength_mlist; lia). rewrite Znth_mlist by lia.
      fold kn. rewrite pcell_row.
      apply <- semax_seq_skip.
      forward_for
        (fun i : Z => PROP (k + 1 <= i <= n; pfin n kn (Z.to_nat j) (Z.to_nat i) B1)
           LOCAL (temp _i (Vlong (Int64.repr i)); temp _u (Vfloat (B1 kn (Z.to_nat j)));
                  temp _j (Vlong (Int64.repr j)); temp _k (Vlong (Int64.repr k)); temp _a a;
                  temp _n (Vlong (Int64.repr n)); temp _lu lu; temp _piv piv)
           SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
                data_at shl (tarray tdouble (n * n))
                  (map Vfloat (mlist n (pcell kn (Z.to_nat j) (Z.to_nat i) B1))) lu;
                data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
        continue:
        (fun i : Z => PROP (k + 1 <= i < n; pfin n kn (Z.to_nat j) (Z.to_nat (i + 1)) B1)
           LOCAL (temp _i (Vlong (Int64.repr i)); temp _u (Vfloat (B1 kn (Z.to_nat j)));
                  temp _j (Vlong (Int64.repr j)); temp _k (Vlong (Int64.repr k)); temp _a a;
                  temp _n (Vlong (Int64.repr n)); temp _lu lu; temp _piv piv)
           SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
                data_at shl (tarray tdouble (n * n))
                  (map Vfloat (mlist n (pcell kn (Z.to_nat j) (Z.to_nat (i + 1)) B1))) lu;
                data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv))
        break:
        (PROP (pfin n kn (Z.to_nat j) (Z.to_nat n) B1)
           LOCAL (temp _j (Vlong (Int64.repr j)); temp _k (Vlong (Int64.repr k)); temp _a a;
                  temp _n (Vlong (Int64.repr n)); temp _lu lu; temp _piv piv)
           SEP (data_at sha (tarray tdouble (n * n)) (map Vfloat al) a;
                data_at shl (tarray tdouble (n * n))
                  (map Vfloat (mlist n (pcell kn (Z.to_nat j) (Z.to_nat n) B1))) lu;
                data_at shp (tarray tulong n) (vpre (c_piv_list al n) opl n (k + 1)) piv)).
      { forward.
        rewrite (mlist_ext n (pcell kn (Z.to_nat j) 0 B1)
                   (pcell kn (Z.to_nat j) (Z.to_nat (k + 1)) B1)).
        2: lia.
        2: { intros i' j' _ _. replace (Z.to_nat (k + 1)) with (S kn) by lia.
             apply pcell_start. lia. }
        assert (Hf : pfin n kn (Z.to_nat j) (Z.to_nat (k + 1)) B1)
          by (intros i' j' G1 G2 G3 G4; apply Hpf; lia).
        Exists (k + 1). entailer!. }
      { entailer!. }
      { rename a0 into i. lt_of_ltu.
        match goal with H : pfin _ _ _ (Z.to_nat i) _ |- _ => rename H into Hpi end.
        assert (Hij : 0 <= i + j * n < n * n) by nia.
        assert (Hik : 0 <= i + k * n < n * n) by nia.
        forward.
        rewrite Znth_map by (rewrite Zlength_mlist; lia). rewrite Znth_mlist by lia.
        rewrite pcell_get.
        forward.
        rewrite Znth_map by (rewrite Zlength_mlist; lia). rewrite Znth_mlist by lia.
        fold kn. rewrite pcell_mult by lia.
        forward.
        rewrite <- elim_update by lia.
        forward_call (Diana.Real.LU.elim cops kn B1 (Z.to_nat i) (Z.to_nat j)).
        destruct (Binary.is_finite 53 1024 (Diana.Real.LU.elim cops kn B1 (Z.to_nat i) (Z.to_nat j)))
          eqn:Hfin.
        - forward_if; [discriminate |].
          forward.
          rewrite upd_mlist by lia.
          erewrite (mlist_ext n _ (pcell kn (Z.to_nat j) (Z.to_nat (i + 1)) B1)).
          2: lia.
          2: { intros i' j' _ _. replace (Z.to_nat (i + 1)) with (S (Z.to_nat i)) by lia.
               apply pcell_step. }
          assert (Hf : pfin n kn (Z.to_nat j) (Z.to_nat (i + 1)) B1).
          { intros i' j' G1 G2 G3 G4.
            destruct (Nat.eq_dec j' (Z.to_nat j)) as [Ej | Ej];
              [destruct (Nat.eq_dec i' (Z.to_nat i)) as [Ei | Ei] |].
            - subst i' j'. exact Hfin.
            - apply Hpi; lia.
            - apply Hpi; lia. }
          Exists i. entailer!.
        - forward_if (PROP (False) LOCAL () SEP ()).
          + assert (Hov : exists k0, (k0 < Z.to_nat n)%nat /\
                      (forall k', (k' < k0)%nat -> c_step_ok al n k') /\ c_overflow al n k0).
            { exists kn. split; [unfold kn; lia |]. split; [exact Hok |].
              split; [exact Htop |].
              exists (Z.to_nat i), (Z.to_nat j).
              split; [lia |]. split; [lia |]. split; [lia |]. split; [lia |].
              rewrite c_state_succ. exact Hfin. }
            set (ls0 := map Vfloat (mlist n (pcell kn (Z.to_nat j) (Z.to_nat i) B1))) in *.
            set (ps0 := vpre (c_piv_list al n) opl n (k + 1)) in *.
            assert (Hl1 : Zlength ls0 = n * n) by (unfold ls0; rewrite Zlength_map, Zlength_mlist; lia).
            assert (Hl2 : Zlength ps0 = n) by (apply Zlength_vpre; lia).
            forward.
            match goal with |- context [data_at shp _ ?ps piv] => Exists (-1) ls0 ps end.
            entailer!. right. right. left. rewrite ?ZtoNat_Zlength in *.
            repeat match goal with |- _ /\ _ => split end; (reflexivity || assumption).
          + exfalso. match goal with H : _ <> _ |- _ => apply H; reflexivity end. }
      { rename a0 into i. forward. Exists (i + 1). entailer!. }
      { rename a0 into i. lt_of_ltu. assert (Ei : i = n) by lia. subst i. entailer!.
        all: rewrite ?ZtoNat_Zlength in *; assumption. }
      match goal with H : pfin _ _ _ (Z.to_nat n) _ |- _ => rename H into Hpn end.
      rewrite (mlist_ext n (pcell kn (Z.to_nat j) (Z.to_nat n) B1)
                 (pcell kn (Z.to_nat (j + 1)) 0 B1)).
      2: lia.
      2: { intros i' j' Hi' _. replace (Z.to_nat (j + 1)) with (S (Z.to_nat j)) by lia.
           apply pcell_next. exact Hi'. }
      assert (Hf : pfin n kn (Z.to_nat (j + 1)) 0 B1).
      { intros i' j' G1 G2 G3 G4.
        destruct (Nat.eq_dec j' (Z.to_nat j)) as [Ej | Ej]; [apply Hpn; lia | apply Hpf; lia]. }
      forward. Exists j. entailer!. }
    { rename a0 into j. forward. Exists (j + 1). entailer!. }
    { rename a0 into j. lt_of_ltu. assert (Ej : j = n) by lia. subst j. entailer!.
      all: rewrite ?ZtoNat_Zlength in *; assumption. }
    match goal with H : pfin _ _ (Z.to_nat n) 0 _ |- _ => rename H into Hpn end.
    rewrite (mlist_ext n (pcell kn (Z.to_nat n) 0 B1) (c_state al n (Z.to_nat (k + 1)))).
    2: lia.
    2: { intros i' j' _ Hj'. replace (Z.to_nat (k + 1)) with (S kn) by lia.
         rewrite c_state_succ. apply pcell_full. exact Hj'. }
    assert (Hst : c_step_ok al n kn).
    { split; [exact Htop |]. intros i' j' G1 G2 G3 G4.
      change (Binary.is_finite 53 1024 (Diana.Real.LU.elim cops kn B1 i' j') = true).
      apply Hpn; lia. }
    assert (Hok1 : forall k', (k' < Z.to_nat (k + 1))%nat -> c_step_ok al n k').
    { intros k' Hk'. destruct (Nat.eq_dec k' kn) as [-> | Hne]; [exact Hst | apply Hok; lia]. }
    forward. Exists k. entailer!. }
  { rename a0 into k. forward. Exists (k + 1). entailer!. }
  { rename a0 into k. lt_of_ltu. assert (Ek : k = n) by lia. subst k. entailer!.
    all: rewrite ?ZtoNat_Zlength in *; assumption. }
  match goal with H : forall k', (k' < Z.to_nat n)%nat -> c_step_ok al n k' |- _ =>
    rename H into Hall end.
  rewrite vpre_full by lia.
  assert (Hok : c_ok al n).
  { split; [| exact Hall]. intros i j Hi Hj. apply all_finite_c_a; assumption || lia. }
  forward.
  match goal with |- context [data_at shl _ ?ls lu] =>
    match goal with |- context [data_at shp _ ?ps piv] => Exists 0 ls ps end end.
  entailer!.
Qed.
