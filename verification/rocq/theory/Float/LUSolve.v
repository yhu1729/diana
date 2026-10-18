From Stdlib Require Import Reals ZArith Lia Lra Psatz.
From Flocq Require Import Core Relative IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Float Require Cholesky Substitution LU.
From Diana.Real Require Import Cholesky Substitution LU LUSolve.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Section Model.

Variable sub_nan mult_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.
Variable opp_nan : b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fdotv := (Diana.Float.Substitution.fdotv sub_nan mult_nan).
Local Abbreviation fbwd := (Diana.Float.Substitution.fbwd sub_nan mult_nan div_nan).
Local Abbreviation flu := (Diana.Float.LU.flu sub_nan mult_nan div_nan opp_nan).
Local Abbreviation fprow := (Diana.Float.LU.fprow sub_nan mult_nan div_nan opp_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).
Local Abbreviation rmat := Diana.Float.Substitution.rmat.

(* The unit lower-triangular solve after rows 0, ..., m - 1; later entries are zero. *)
Fixpoint fusolve (F : nat -> nat -> b64) (c : nat -> b64) (m : nat) : nat -> b64 :=
  match m with
  | O => fun _ => Diana.Float.Cholesky.fzero
  | S m' => fun i =>
      if (i =? m')%nat then fdotv (F m') (fusolve F c m') (c m') m' else fusolve F c m' i
  end.

(* Entry i of the unit lower-triangular solve: c i - F i 0 * y 0 - ... - F i (i-1) * y (i-1),
   each product rounded and subtracted in order, with no division by the unit diagonal. *)
Definition funit (F : nat -> nat -> b64) (c : nat -> b64) (i : nat) : b64 := fusolve F c (S i) i.

(* The forward solve of diana_lu_solve: funit on c = P b, F i k = lu[i + k*n], p k = piv[k] and
   b i = b[i]. *)
Definition fforward (F : nat -> nat -> b64) (p : nat -> nat) (b : nat -> b64) (n : nat) :
  nat -> b64 :=
  funit F (fun i => b (pperm p n i)).

(* The binary64 model of diana_lu_solve: back substitution on y with U, the transpose of the
   lower-triangular fun k i => F i k, in the C's order, the products subtracted from
   k = n - 1 down to i + 1 and the difference divided by F i i (Substitution.fbwd_eq). *)
Definition fsolution (F : nat -> nat -> b64) (p : nat -> nat) (b : nat -> b64) (n : nat) :
  nat -> b64 :=
  fbwd (fun k i => F i k) (fforward F p b n) n.

(* The pivot rows diana_lu writes. *)
Definition fpivots (A : nat -> nat -> b64) (n k : nat) : nat :=
  pivot (Diana.Float.LU.fops sub_nan mult_nan div_nan opp_nan) n k
    (Diana.Float.LU.fstate sub_nan mult_nan div_nan opp_nan n A k).

(* The backward-error bounds of row i of the forward solve (forward_backward_error) and of the
   back solve (back_backward_error). *)
Definition forward_bound (F : nat -> nat -> b64) (p : nat -> nat) (b : nat -> b64) (n i : nat) :
  R :=
  gamma i * (sum i (fun k => Rabs (r (F i k) * r (fforward F p b n k)))
             + Rabs (r (fforward F p b n i)))
  + (1 + gamma i) * INR i * eta.

Definition back_bound (F : nat -> nat -> b64) (p : nat -> nat) (b : nat -> b64) (n i : nat) : R :=
  gamma (n - i) * sum (n - i) (fun t => Rabs (r (F i (i + t)%nat) * r (fsolution F p b n (i + t))))
  + (1 + gamma (n - i)) * (INR (n - 1 - i) + Rabs (r (F i i))) * eta.

(* The bound of entry (i, j) of P A - L U, LU-B3 on and above the diagonal, LU-B4 below. *)
Definition factor_bound (A : nat -> nat -> b64) (n i j : nat) : R :=
  if (i <=? j)%nat then
    gamma i * (sum i (fun t => Rabs (r (flu A n i t) * r (flu A n t j))) + Rabs (r (flu A n i j)))
    + (1 + gamma i) * INR i * eta
  else
    gamma (S j) * (sum j (fun t => Rabs (r (flu A n i t) * r (flu A n t j)))
                   + Rabs (r (flu A n j j) * r (flu A n i j)))
    + (1 + gamma (S j)) * (INR j + Rabs (r (flu A n j j))) * eta.

Lemma fusolve_eq (F : nat -> nat -> b64) (c : nat -> b64) (m i : nat) :
  (i < m)%nat -> fusolve F c m i = funit F c i.
Proof.
  revert i. induction m as [| m IH]; intros i Hi; [lia |].
  destruct (Nat.eq_dec i m) as [-> | Hne]; [reflexivity |].
  simpl. replace (i =? m)%nat with false by (symmetry; apply Nat.eqb_neq; exact Hne).
  apply IH. lia.
Qed.

Lemma funit_eq (F : nat -> nat -> b64) (c : nat -> b64) (i : nat) :
  funit F c i = fdotv (F i) (funit F c) (c i) i.
Proof.
  unfold funit at 1. simpl. rewrite Nat.eqb_refl.
  apply Diana.Float.Substitution.fdotv_congr; [reflexivity |].
  intros k Hk. apply fusolve_eq. exact Hk.
Qed.

Lemma lt_u (m n : nat) : (m <= n)%nat -> INR n * u < 1 -> INR m * u < 1.
Proof.
  intros Hmn Hn. eapply Rle_lt_trans; [| exact Hn].
  apply Rmult_le_compat_r; [left; apply u_pos | apply le_INR; exact Hmn].
Qed.

(* Layer B, backward error of the forward solve, row i: when the computed y i is finite,
   |(P b) i - sum_{k<i} L i k * y k - y i|
     <= gamma i * (sum_{k<i} |L i k * y k| + |y i|) + (1 + gamma i) * i * eta,
   so y solves (L + dL) y = P b with |dL| <= gamma i * |L| in row i, up to underflow. *)
Theorem forward_backward_error (F : nat -> nat -> b64) (p : nat -> nat) (b : nat -> b64)
    (n i : nat) :
  fin (fforward F p b n i) -> INR i * u < 1 ->
  Rabs (r (b (pperm p n i)) - sum i (fun k => r (F i k) * r (fforward F p b n k))
        - r (fforward F p b n i))
    <= forward_bound F p b n i.
Proof.
  intros Hf Hk. unfold forward_bound.
  assert (Hy : fforward F p b n i = fdotv (F i) (fforward F p b n) (b (pperm p n i)) i)
    by exact (funit_eq F (fun i' => b (pperm p n i')) i).
  rewrite Hy in Hf.
  destruct (Diana.Float.LU.dotv_error sub_nan mult_nan (F i) (fforward F p b n)
              (b (pperm p n i)) i Hf Hk) as [G [HG Hb]].
  rewrite <- Hy in Hb.
  set (S0 := sum i (fun k => r (F i k) * r (fforward F p b n k))) in *.
  set (A0 := sum i (fun k => Rabs (r (F i k) * r (fforward F p b n k)))) in *.
  set (c := r (b (pperm p n i))) in *.
  set (y := r (fforward F p b n i)) in *.
  replace (c - S0 - y) with ((c - S0 - y * G) + y * (G - 1)) by ring.
  eapply Rle_trans; [apply Rabs_triang |]. rewrite (Rabs_mult y).
  assert (H2 : Rabs y * Rabs (G - 1) <= gamma i * Rabs y).
  { rewrite Rmult_comm. apply Rmult_le_compat_r; [apply Rabs_pos | exact HG]. }
  lra.
Qed.

(* Layer B, backward error of the back solve, row i: when the computed x i is finite and U i i
   is not zero,
   |y i - sum_{i <= k < n} U i k * x k|
     <= gamma (n - i) * sum_{i <= k < n} |U i k * x k|
        + (1 + gamma (n - i)) * (n - 1 - i + |U i i|) * eta,
   SUBSTITUTION-B3 with U as the transpose of a lower-triangular matrix. *)
Theorem back_backward_error (F : nat -> nat -> b64) (p : nat -> nat) (b : nat -> b64)
    (n i : nat) :
  (i < n)%nat -> fin (fsolution F p b n i) -> r (F i i) <> 0 -> INR (n - i) * u < 1 ->
  Rabs (r (fforward F p b n i)
        - sum (n - i) (fun t => r (F i (i + t)%nat) * r (fsolution F p b n (i + t))))
    <= back_bound F p b n i.
Proof.
  intros Hi Hf Hd Hk.
  exact (Diana.Float.Substitution.back_backward_error sub_nan mult_nan div_nan
           (fun k i' => F i' k) (fforward F p b n) n i Hi Hf Hd Hk).
Qed.

(* (U x) t: the sum over the row of U from the diagonal. *)
Lemma up_row (F : nat -> nat -> b64) (x : nat -> R) (n t : nat) :
  (t <= n)%nat ->
  sum n (fun j => up (rmat F) t j * x j) =
  sum (n - t) (fun s => r (F t (t + s)%nat) * x (t + s)%nat).
Proof.
  intro Ht. rewrite (sum_split t n) by exact Ht.
  rewrite (sum_zero t) by (intros j Hj; unfold up;
                           replace (t <=? j)%nat with false by (symmetry; apply Nat.leb_gt; lia);
                           ring).
  rewrite Rplus_0_l. apply sum_ext. intros s Hs. unfold up, rmat.
  replace (t <=? t + s)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity.
Qed.

(* Layer B, residual of the factored system: when every computed y i and x i is finite and U
   has no zero on the diagonal (the C's DIANA_OK),
   |(P b) i - (L U x) i| <= forward_bound i + sum_{t <= i} |L i t| * back_bound t,
   L and U the unit lower and upper triangles of the binary64 factor read as reals. *)
Theorem factor_residual (F : nat -> nat -> b64) (p : nat -> nat) (b : nat -> b64) (n : nat) :
  (forall i, (i < n)%nat -> r (F i i) <> 0) ->
  (forall i, (i < n)%nat -> fin (fforward F p b n i)) ->
  (forall i, (i < n)%nat -> fin (fsolution F p b n i)) ->
  INR n * u < 1 ->
  forall i, (i < n)%nat ->
  Rabs (r (b (pperm p n i))
        - sum n (fun t => lo (rmat F) i t
                          * sum n (fun j => up (rmat F) t j * r (fsolution F p b n j))))
    <= forward_bound F p b n i + sum (S i) (fun t => Rabs (lo (rmat F) i t) * back_bound F p b n t).
Proof.
  intros Hd Hy Hx Hn i Hi.
  set (w := fun t => sum n (fun j => up (rmat F) t j * r (fsolution F p b n j))).
  change (sum n (fun t => lo (rmat F) i t
                          * sum n (fun j => up (rmat F) t j * r (fsolution F p b n j))))
    with (sum n (fun t => lo (rmat F) i t * w t)).
  assert (He : forall t, (t < n)%nat ->
            Rabs (r (fforward F p b n t) - w t) <= back_bound F p b n t).
  { intros t Ht. unfold w. rewrite up_row by lia.
    apply back_backward_error; [exact Ht | apply Hx; exact Ht | apply Hd; exact Ht |].
    apply (lt_u (n - t) n); [lia | exact Hn]. }
  pose proof (forward_backward_error F p b n i (Hy i Hi) (lt_u i n ltac:(lia) Hn)) as Hf.
  assert (Hlo : forall t, (t < i)%nat -> lo (rmat F) i t = r (F i t)).
  { intros t Ht. unfold lo, rmat.
    replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Ht). reflexivity. }
  assert (Hlo1 : lo (rmat F) i i = 1)
    by (unfold lo; rewrite Nat.ltb_irrefl, Nat.eqb_refl; reflexivity).
  rewrite (sum_trunc (fun t => lo (rmat F) i t * w t) (S i) n).
  2: lia.
  2: { intros t H1 H2. unfold lo.
       replace (t <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
       replace (t =? i)%nat with false by (symmetry; apply Nat.eqb_neq; lia). ring. }
  cbn [sum]. rewrite Hlo1, Rabs_R1.
  rewrite (sum_ext i (fun t => lo (rmat F) i t * w t) (fun t => r (F i t) * w t))
    by (intros t Ht; rewrite Hlo by exact Ht; reflexivity).
  rewrite (sum_ext i (fun t => Rabs (lo (rmat F) i t) * back_bound F p b n t)
             (fun t => Rabs (r (F i t)) * back_bound F p b n t))
    by (intros t Ht; rewrite Hlo by exact Ht; reflexivity).
  set (c := r (b (pperm p n i))) in *.
  set (S0 := sum i (fun k => r (F i k) * r (fforward F p b n k))) in *.
  set (y := r (fforward F p b n i)) in *.
  assert (Hsplit : c - (sum i (fun t => r (F i t) * w t) + 1 * w i)
                   = (c - S0 - y) + sum i (fun t => r (F i t) * (r (fforward F p b n t) - w t))
                     + (y - w i)).
  { unfold S0. rewrite (sum_ext i (fun t => r (F i t) * (r (fforward F p b n t) - w t))
                          (fun t => r (F i t) * r (fforward F p b n t) - r (F i t) * w t))
      by (intros; ring).
    rewrite sum_minus. ring. }
  rewrite Hsplit.
  assert (Hs : Rabs (sum i (fun t => r (F i t) * (r (fforward F p b n t) - w t)))
               <= sum i (fun t => Rabs (r (F i t)) * back_bound F p b n t)).
  { eapply Rle_trans; [apply sum_Rabs |]. apply sum_le. intros t Ht. rewrite Rabs_mult.
    apply Rmult_le_compat_l; [apply Rabs_pos | apply He; lia]. }
  pose proof (He i Hi) as Hei. fold y in Hei.
  eapply Rle_trans; [apply Rabs_triang |].
  eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
  lra.
Qed.

(* Entry (i, j) of L U for a packed factor: the products of row i of L and column j of U. *)
Lemma factor_product (F : nat -> nat -> b64) (n i j : nat) :
  (i < n)%nat -> (j < n)%nat ->
  sum n (fun t => lo (rmat F) i t * up (rmat F) t j) =
  if (i <=? j)%nat then sum i (fun t => r (F i t) * r (F t j)) + r (F i j)
  else sum j (fun t => r (F i t) * r (F t j)) + r (F j j) * r (F i j).
Proof.
  intros Hi Hj. destruct (Nat.leb_spec i j) as [Hij | Hji].
  - rewrite (sum_trunc _ (S i) n).
    2: lia.
    2: { intros t H1 H2. unfold lo.
         replace (t <? i)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
         replace (t =? i)%nat with false by (symmetry; apply Nat.eqb_neq; lia). ring. }
    cbn [sum]. unfold lo at 2, up at 2, rmat at 2 3.
    rewrite Nat.ltb_irrefl, Nat.eqb_refl.
    replace (i <=? j)%nat with true by (symmetry; apply Nat.leb_le; exact Hij).
    rewrite Rmult_1_l. f_equal. apply sum_ext. intros t Ht. unfold lo, up, rmat.
    replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Ht).
    replace (t <=? j)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity.
  - rewrite (sum_trunc _ (S j) n).
    2: lia.
    2: { intros t H1 H2. unfold up.
         replace (t <=? j)%nat with false by (symmetry; apply Nat.leb_gt; lia). ring. }
    cbn [sum]. unfold lo at 2, up at 2, rmat at 2 3.
    replace (j <? i)%nat with true by (symmetry; apply Nat.ltb_lt; exact Hji).
    rewrite Nat.leb_refl. rewrite (Rmult_comm (r (F i j))). f_equal. apply sum_ext.
    intros t Ht. unfold lo, up, rmat.
    replace (t <? i)%nat with true by (symmetry; apply Nat.ltb_lt; lia).
    replace (t <=? j)%nat with true by (symmetry; apply Nat.leb_le; lia). reflexivity.
Qed.

(* Layer B, residual of the solve with the factors of diana_lu: when the factorization returns
   DIANA_OK, every computed y i and x i is finite and n * u < 1, then for B = P A,
   |(P b) i - (B x) i|
     <= forward_bound i + sum_{t <= i} |L i t| * back_bound t + sum_j factor_bound i j * |x j|:
   the residual of the factored system plus the backward error of the factorization applied
   to x. *)
Theorem lu_residual (A : nat -> nat -> b64) (b : nat -> b64) (n : nat) :
  Diana.Float.LU.fok sub_nan mult_nan div_nan opp_nan A n ->
  (forall i, (i < n)%nat -> fin (fforward (flu A n) (fpivots A n) b n i)) ->
  (forall i, (i < n)%nat -> fin (fsolution (flu A n) (fpivots A n) b n i)) ->
  INR n * u < 1 ->
  forall i, (i < n)%nat ->
  Rabs (r (b (fprow A n i))
        - sum n (fun j => r (A (fprow A n i) j) * r (fsolution (flu A n) (fpivots A n) b n j)))
    <= forward_bound (flu A n) (fpivots A n) b n i
       + sum (S i) (fun t => Rabs (lo (rmat (flu A n)) i t)
                             * back_bound (flu A n) (fpivots A n) b n t)
       + sum n (fun j => factor_bound A n i j
                         * Rabs (r (fsolution (flu A n) (fpivots A n) b n j))).
Proof.
  intros Hok Hy Hx Hn i Hi.
  set (F := flu A n) in *.
  set (x := fsolution F (fpivots A n) b n) in *.
  assert (Hrow : pperm (fpivots A n) n i = fprow A n i).
  { unfold fpivots, Diana.Float.LU.fprow. symmetry. apply pperm_perm. }
  assert (Hd : forall t, (t < n)%nat -> r (F t t) <> 0)
    by (intros t Ht; apply Diana.Float.LU.diag_nonzero; assumption).
  pose proof (factor_residual F (fpivots A n) b n Hd Hy Hx Hn i Hi) as Hres.
  rewrite Hrow in Hres. fold x in Hres.
  set (P := fun j => sum n (fun t => lo (rmat F) i t * up (rmat F) t j)).
  assert (Hlux : sum n (fun t => lo (rmat F) i t * sum n (fun j => up (rmat F) t j * r (x j)))
                 = sum n (fun j => P j * r (x j))).
  { unfold P.
    rewrite (sum_ext n _ (fun t => sum n (fun j => lo (rmat F) i t * up (rmat F) t j * r (x j))))
      by (intros t Ht; rewrite <- sum_scal_l; apply sum_ext; intros; ring).
    rewrite sum_comm. apply sum_ext. intros j Hj. rewrite <- sum_scal_r. reflexivity. }
  rewrite Hlux in Hres.
  assert (HE : forall j, (j < n)%nat ->
            Rabs (r (A (fprow A n i) j) - P j) <= factor_bound A n i j).
  { intros j Hj. unfold P. rewrite factor_product by assumption. unfold factor_bound.
    fold F. destruct (Nat.leb_spec i j) as [Hij | Hji].
    - apply (Diana.Float.LU.upper_error sub_nan mult_nan div_nan opp_nan); try assumption.
      apply (lt_u i n); [lia | exact Hn].
    - apply (Diana.Float.LU.lower_error sub_nan mult_nan div_nan opp_nan); try assumption.
      apply (lt_u (S j) n); [lia | exact Hn]. }
  set (c := r (b (fprow A n i))) in *.
  assert (Hsplit : c - sum n (fun j => r (A (fprow A n i) j) * r (x j))
                   = (c - sum n (fun j => P j * r (x j)))
                     + sum n (fun j => (P j - r (A (fprow A n i) j)) * r (x j))).
  { rewrite (sum_ext n (fun j => (P j - r (A (fprow A n i) j)) * r (x j))
               (fun j => P j * r (x j) - r (A (fprow A n i) j) * r (x j))) by (intros; ring).
    rewrite sum_minus. ring. }
  rewrite Hsplit.
  assert (Hs : Rabs (sum n (fun j => (P j - r (A (fprow A n i) j)) * r (x j)))
               <= sum n (fun j => factor_bound A n i j * Rabs (r (x j)))).
  { eapply Rle_trans; [apply sum_Rabs |]. apply sum_le. intros j Hj. rewrite Rabs_mult.
    apply Rmult_le_compat_r; [apply Rabs_pos |].
    rewrite <- Rabs_Ropp.
    replace (- (P j - r (A (fprow A n i) j))) with (r (A (fprow A n i) j) - P j) by ring.
    apply HE. exact Hj. }
  eapply Rle_trans; [apply Rabs_triang |]. lra.
Qed.

End Model.
