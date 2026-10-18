From VST.floyd Require Import proofauto.
From Stdlib Require Import RIneq.
From Diana.Float Require Substitution.
From Diana.VST Require Import Matrix.

(* The binary64 models with CompCert's operations: L i k = l[i + k*n] column-major, b i = b[i].
   No Clight AST. *)

Definition c_L (ll : list float) (n : Z) (i k : nat) : float :=
  Znth (Z.of_nat i + Z.of_nat k * n) ll.

Definition c_b (bl : list float) (i : nat) : float := Znth (Z.of_nat i) bl.

Definition c_fwd (ll bl : list float) (n i : Z) : float :=
  Diana.Float.Substitution.ffwd Float.binop_nan Float.binop_nan Float.binop_nan
    (c_L ll n) (c_b bl) (Z.to_nat i).

Definition c_bwd (ll bl : list float) (n i : Z) : float :=
  Diana.Float.Substitution.fbwd Float.binop_nan Float.binop_nan Float.binop_nan
    (c_L ll n) (c_b bl) (Z.to_nat n) (Z.to_nat i).

(* s after the first k subtractions of row i: b[i] - l[i]*x[0] - ... - l[i + (k-1)*n]*x[k-1]. *)
Definition c_fdot (ll bl : list float) (n i k : Z) : float :=
  Diana.Float.Substitution.fdotv Float.binop_nan Float.binop_nan
    (c_L ll n (Z.to_nat i))
    (Diana.Float.Substitution.ffwd Float.binop_nan Float.binop_nan Float.binop_nan
       (c_L ll n) (c_b bl))
    (Znth i bl) (Z.to_nat k).

(* s after the first t subtractions of back-substitution row i, k = n - 1 down to n - t. *)
Definition c_bdot (ll bl : list float) (n i t : Z) : float :=
  Diana.Float.Substitution.fdotv Float.binop_nan Float.binop_nan
    (fun q => c_L ll n (Z.to_nat n - 1 - q)%nat (Z.to_nat i))
    (fun q => Diana.Float.Substitution.fbwd Float.binop_nan Float.binop_nan Float.binop_nan
                (c_L ll n) (c_b bl) (Z.to_nat n) (Z.to_nat n - 1 - q)%nat)
    (Znth i bl) (Z.to_nat t).

Definition c_fwd_list (ll bl : list float) (n : Z) : list float :=
  map (c_fwd ll bl n) (upto (Z.to_nat n)).

Definition c_bwd_list (ll bl : list float) (n : Z) : list float :=
  map (c_bwd ll bl n) (upto (Z.to_nat n)).

(* The C's DIANA_OK conditions besides lower_finite. *)
Definition vec_finite (bl : list float) (n : Z) : Prop :=
  forall i, 0 <= i < n -> Binary.is_finite 53 1024 (Znth i bl) = true.

Definition diag_nonzero (ll : list float) (n : Z) : Prop :=
  forall i, 0 <= i < n -> Float.cmp Ceq (Znth (i + i * n) ll) Float.zero = false.

Definition fwd_finite (ll bl : list float) (n : Z) : Prop :=
  forall i, 0 <= i < n -> Binary.is_finite 53 1024 (c_fwd ll bl n i) = true.

Definition bwd_finite (ll bl : list float) (n : Z) : Prop :=
  forall i, 0 <= i < n -> Binary.is_finite 53 1024 (c_bwd ll bl n i) = true.

Lemma zero_float : Float.of_bits (Int64.repr 0) = Float.zero.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

(* A finite entry that passes the C test l[i + i*n] == 0.0 as false is a nonzero real, the
   hypothesis of the layer-B theorems. *)
Lemma diag_real (v : float) :
  Binary.is_finite 53 1024 v = true -> Float.cmp Ceq v Float.zero = false ->
  Binary.B2R 53 1024 v <> 0%R.
Proof.
  intros Hf Hc E.
  Transparent Float.cmp. unfold Float.cmp, Float.compare in Hc. Opaque Float.cmp.
  change Float.zero with (Binary.B754_zero 53 1024 false) in Hc.
  rewrite (Binary.Bcompare_correct 53 1024 v (Binary.B754_zero 53 1024 false) Hf
             (eq_refl : Binary.is_finite 53 1024 (Binary.B754_zero 53 1024 false) = true)) in Hc.
  rewrite E in Hc. simpl Binary.B2R in Hc.
  rewrite Flocq.Core.Raux.Rcompare_Eq in Hc by reflexivity. discriminate Hc.
Qed.

Lemma c_fdot_0 (ll bl : list float) (n i : Z) : c_fdot ll bl n i 0 = Znth i bl.
Proof. reflexivity. Qed.

Lemma c_fdot_succ (ll bl : list float) (n i k : Z) :
  0 <= i -> 0 <= k ->
  c_fdot ll bl n i (k + 1) =
  Float.sub (c_fdot ll bl n i k) (Float.mul (Znth (i + k * n) ll) (c_fwd ll bl n k)).
Proof.
  intros Hi Hk. unfold c_fdot. rewrite Z2Nat.inj_add by lia.
  change (Z.to_nat 1) with 1%nat. rewrite Nat.add_1_r. simpl.
  replace (c_L ll n (Z.to_nat i) (Z.to_nat k)) with (Znth (i + k * n) ll)
    by (unfold c_L; rewrite !Z2Nat.id by lia; reflexivity).
  reflexivity.
Qed.

Lemma c_fwd_eq (ll bl : list float) (n i : Z) :
  0 <= i -> c_fwd ll bl n i = Float.div (c_fdot ll bl n i i) (Znth (i + i * n) ll).
Proof.
  intro Hi. unfold c_fwd at 1. rewrite Diana.Float.Substitution.ffwd_eq. unfold c_fdot.
  replace (c_b bl (Z.to_nat i)) with (Znth i bl)
    by (unfold c_b; rewrite Z2Nat.id by lia; reflexivity).
  replace (c_L ll n (Z.to_nat i) (Z.to_nat i)) with (Znth (i + i * n) ll)
    by (unfold c_L; rewrite Z2Nat.id by lia; reflexivity).
  reflexivity.
Qed.

Lemma c_bdot_0 (ll bl : list float) (n i : Z) : c_bdot ll bl n i 0 = Znth i bl.
Proof. reflexivity. Qed.

Lemma c_bdot_succ (ll bl : list float) (n i t : Z) :
  0 <= i -> 0 <= t < n ->
  c_bdot ll bl n i (t + 1) =
  Float.sub (c_bdot ll bl n i t)
    (Float.mul (Znth (n - 1 - t + i * n) ll) (c_bwd ll bl n (n - 1 - t))).
Proof.
  intros Hi Ht. unfold c_bdot. rewrite Z2Nat.inj_add by lia.
  change (Z.to_nat 1) with 1%nat. rewrite Nat.add_1_r. simpl.
  replace (c_L ll n (Z.to_nat n - 1 - Z.to_nat t)%nat (Z.to_nat i))
    with (Znth (n - 1 - t + i * n) ll)
    by (unfold c_L; f_equal; rewrite !Nat2Z.inj_sub by lia; rewrite !Z2Nat.id by lia; lia).
  replace (Diana.Float.Substitution.fbwd Float.binop_nan Float.binop_nan Float.binop_nan
             (c_L ll n) (c_b bl) (Z.to_nat n) (Z.to_nat n - 1 - Z.to_nat t)%nat)
    with (c_bwd ll bl n (n - 1 - t)) by (unfold c_bwd; f_equal; lia).
  reflexivity.
Qed.

Lemma c_bwd_eq (ll bl : list float) (n i : Z) :
  0 <= i < n ->
  c_bwd ll bl n i = Float.div (c_bdot ll bl n i (n - 1 - i)) (Znth (i + i * n) ll).
Proof.
  intro Hi. unfold c_bwd at 1. rewrite Diana.Float.Substitution.fbwd_eq by lia.
  unfold c_bdot.
  replace (c_b bl (Z.to_nat i)) with (Znth i bl)
    by (unfold c_b; rewrite Z2Nat.id by lia; reflexivity).
  replace (c_L ll n (Z.to_nat i) (Z.to_nat i)) with (Znth (i + i * n) ll)
    by (unfold c_L; rewrite Z2Nat.id by lia; reflexivity).
  replace (Z.to_nat (n - 1 - i)) with (Z.to_nat n - 1 - Z.to_nat i)%nat by lia.
  reflexivity.
Qed.

Lemma Zlength_c_fwd_list (ll bl : list float) (n : Z) :
  0 <= n -> Zlength (c_fwd_list ll bl n) = n.
Proof.
  intro Hn. unfold c_fwd_list. rewrite Zlength_map, Zlength_upto, Z2Nat.id by lia.
  reflexivity.
Qed.

Lemma Znth_c_fwd_list (ll bl : list float) (n i : Z) :
  0 <= i < n -> Znth i (c_fwd_list ll bl n) = c_fwd ll bl n i.
Proof.
  intro Hi. unfold c_fwd_list.
  rewrite Znth_map by (rewrite Zlength_upto, Z2Nat.id by lia; lia).
  rewrite Znth_upto by (rewrite Z2Nat.id by lia; lia). reflexivity.
Qed.

Lemma Zlength_c_bwd_list (ll bl : list float) (n : Z) :
  0 <= n -> Zlength (c_bwd_list ll bl n) = n.
Proof.
  intro Hn. unfold c_bwd_list. rewrite Zlength_map, Zlength_upto, Z2Nat.id by lia.
  reflexivity.
Qed.

Lemma Znth_c_bwd_list (ll bl : list float) (n i : Z) :
  0 <= i < n -> Znth i (c_bwd_list ll bl n) = c_bwd ll bl n i.
Proof.
  intro Hi. unfold c_bwd_list.
  rewrite Znth_map by (rewrite Zlength_upto, Z2Nat.id by lia; lia).
  rewrite Znth_upto by (rewrite Z2Nat.id by lia; lia). reflexivity.
Qed.
