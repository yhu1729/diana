From Stdlib Require Import Reals Lra Lia Psatz.
Open Scope R_scope.

(* sum n f = f 0 + ... + f (n - 1) *)
Fixpoint sum (n : nat) (f : nat -> R) : R :=
  match n with
  | O => 0
  | S m => sum m f + f m
  end.

Lemma pow2_mult (x : R) : x ^ 2 = x * x.
Proof. ring. Qed.

Lemma sum_ext (n : nat) (f g : nat -> R) :
  (forall k, (k < n)%nat -> f k = g k) -> sum n f = sum n g.
Proof.
  induction n as [| n IH]; intro H; simpl; [reflexivity |].
  rewrite IH by (intros; apply H; lia). rewrite H by lia. reflexivity.
Qed.

Lemma sum_zero (n : nat) (f : nat -> R) :
  (forall k, (k < n)%nat -> f k = 0) -> sum n f = 0.
Proof.
  induction n as [| n IH]; intro H; simpl; [reflexivity |].
  rewrite IH by (intros; apply H; lia). rewrite H by lia. ring.
Qed.

Lemma sum_plus (n : nat) (f g : nat -> R) :
  sum n (fun k => f k + g k) = sum n f + sum n g.
Proof. induction n as [| n IH]; simpl; [ring | rewrite IH; ring]. Qed.

Lemma sum_minus (n : nat) (f g : nat -> R) :
  sum n (fun k => f k - g k) = sum n f - sum n g.
Proof. induction n as [| n IH]; simpl; [ring | rewrite IH; ring]. Qed.

Lemma sum_scal_l (n : nat) (c : R) (f : nat -> R) :
  sum n (fun k => c * f k) = c * sum n f.
Proof. induction n as [| n IH]; simpl; [ring | rewrite IH; ring]. Qed.

Lemma sum_scal_r (n : nat) (c : R) (f : nat -> R) :
  sum n (fun k => f k * c) = sum n f * c.
Proof. induction n as [| n IH]; simpl; [ring | rewrite IH; ring]. Qed.

Lemma sum_comm (n m : nat) (f : nat -> nat -> R) :
  sum n (fun i => sum m (fun k => f i k)) = sum m (fun k => sum n (fun i => f i k)).
Proof.
  induction n as [| n IH]; simpl.
  - symmetry. apply sum_zero. reflexivity.
  - rewrite IH, <- sum_plus. reflexivity.
Qed.

Lemma sum_mul_sum (n m : nat) (f g : nat -> R) :
  sum n f * sum m g = sum n (fun i => sum m (fun k => f i * g k)).
Proof.
  rewrite <- sum_scal_r. apply sum_ext. intros i _.
  rewrite <- sum_scal_l. reflexivity.
Qed.

Lemma sum_trunc (f : nat -> R) (m n : nat) :
  (m <= n)%nat -> (forall k, (m <= k)%nat -> (k < n)%nat -> f k = 0) -> sum n f = sum m f.
Proof.
  induction n as [| n IH]; intros Hmn Hf.
  - replace m with O by lia. reflexivity.
  - destruct (Nat.eq_dec m (S n)) as [-> | Hne]; [reflexivity |].
    simpl. rewrite IH by (lia || (intros; apply Hf; lia)). rewrite Hf by lia. ring.
Qed.

Lemma sum_only (f : nat -> R) (n i : nat) :
  (i < n)%nat -> (forall k, (k < n)%nat -> k <> i -> f k = 0) -> sum n f = f i.
Proof.
  induction n as [| n IH]; intros Hi Hf; [lia |]. simpl.
  destruct (Nat.eq_dec i n) as [-> | Hne].
  - rewrite sum_zero by (intros; apply Hf; lia). ring.
  - rewrite IH by (lia || (intros; apply Hf; lia)). rewrite (Hf n) by lia. ring.
Qed.

Lemma sum_nonneg (n : nat) (f : nat -> R) :
  (forall k, (k < n)%nat -> 0 <= f k) -> 0 <= sum n f.
Proof.
  induction n as [| n IH]; intro H; simpl; [lra |].
  pose proof (IH (fun k Hk => H k ltac:(lia))). pose proof (H n ltac:(lia)). lra.
Qed.

Lemma sum_ge (n : nat) (f : nat -> R) (i : nat) :
  (i < n)%nat -> (forall k, (k < n)%nat -> 0 <= f k) -> f i <= sum n f.
Proof.
  induction n as [| n IH]; intros Hi H; [lia |]. simpl.
  destruct (Nat.eq_dec i n) as [-> | Hne].
  - pose proof (sum_nonneg n f (fun k Hk => H k ltac:(lia))). lra.
  - pose proof (IH ltac:(lia) (fun k Hk => H k ltac:(lia))). pose proof (H n ltac:(lia)). lra.
Qed.

(* The pivot of column j, from the entries L j k, k < j. *)
Definition pivot (A L : nat -> nat -> R) (j : nat) : R :=
  A j j - sum j (fun k => L j k ^ 2).

(* Entry i of column j, from the columns k < j of L. *)
Definition column (A L : nat -> nat -> R) (j i : nat) : R :=
  if (i <? j)%nat then 0
  else if (i =? j)%nat then sqrt (pivot A L j)
  else (A i j - sum j (fun k => L i k * L j k)) / sqrt (pivot A L j).

(* The factor after columns 0, ..., m - 1; later columns are zero. *)
Fixpoint factor (A : nat -> nat -> R) (m : nat) : nat -> nat -> R :=
  match m with
  | O => fun _ _ => 0
  | S m' => fun i k => if (k =? m')%nat then column A (factor A m') m' i else factor A m' i k
  end.

(* The Cholesky factor of A: column k computed from columns 0, ..., k - 1. Only the entries
   A i j with j <= i are read. *)
Definition chol (A : nat -> nat -> R) (i k : nat) : R := factor A (S k) i k.

(* The pivot of column j of the factorization. *)
Definition piv (A : nat -> nat -> R) (j : nat) : R := pivot A (chol A) j.

Lemma factor_eq (A : nat -> nat -> R) (m i k : nat) :
  (k < m)%nat -> factor A m i k = chol A i k.
Proof.
  revert i k. induction m as [| m IH]; intros i k Hk; [lia |].
  destruct (Nat.eq_dec k m) as [-> | Hne]; [reflexivity |].
  simpl. replace (k =? m)%nat with false by (symmetry; apply Nat.eqb_neq; exact Hne).
  apply IH. lia.
Qed.

Lemma column_congr (A L L' : nat -> nat -> R) (j i : nat) :
  (forall i' k, (k < j)%nat -> L i' k = L' i' k) -> column A L j i = column A L' j i.
Proof.
  intro H.
  assert (Hp : pivot A L j = pivot A L' j).
  { unfold pivot. f_equal. apply sum_ext. intros k Hk. rewrite H by exact Hk. reflexivity. }
  assert (Hs : sum j (fun k => L i k * L j k) = sum j (fun k => L' i k * L' j k)).
  { apply sum_ext. intros k Hk. rewrite !H by exact Hk. reflexivity. }
  unfold column. rewrite Hp, Hs. reflexivity.
Qed.

Lemma chol_eq (A : nat -> nat -> R) (i j : nat) : chol A i j = column A (chol A) j i.
Proof.
  unfold chol at 1. simpl. rewrite Nat.eqb_refl.
  apply column_congr. intros i' k Hk. apply factor_eq. exact Hk.
Qed.

Lemma chol_upper (A : nat -> nat -> R) (i j : nat) : (i < j)%nat -> chol A i j = 0.
Proof.
  intro H. rewrite chol_eq. unfold column.
  replace (i <? j)%nat with true by (symmetry; apply Nat.ltb_lt; exact H). reflexivity.
Qed.

Lemma chol_diag (A : nat -> nat -> R) (j : nat) : chol A j j = sqrt (piv A j).
Proof.
  rewrite chol_eq. unfold column, piv. rewrite Nat.ltb_irrefl, Nat.eqb_refl. reflexivity.
Qed.

Lemma chol_lower (A : nat -> nat -> R) (i j : nat) :
  (j < i)%nat ->
  chol A i j = (A i j - sum j (fun k => chol A i k * chol A j k)) / sqrt (piv A j).
Proof.
  intro H. rewrite chol_eq. unfold column, piv.
  replace (i <? j)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
  replace (i =? j)%nat with false by (symmetry; apply Nat.eqb_neq; lia). reflexivity.
Qed.

(* Entry (i, j), j <= i, of L L^T is A i j once the pivot of column j is positive. *)
Lemma entry (A : nat -> nat -> R) (i j : nat) :
  (j <= i)%nat -> 0 < piv A j ->
  sum (S j) (fun k => chol A i k * chol A j k) = A i j.
Proof.
  intros Hji Hp. pose proof (sqrt_lt_R0 _ Hp) as Hs. simpl. rewrite chol_diag.
  destruct (Nat.eq_dec i j) as [-> | Hne].
  - rewrite chol_diag, sqrt_sqrt by lra. unfold piv, pivot.
    rewrite <- (sum_ext j (fun k => chol A j k ^ 2)) by (intros; ring). ring.
  - rewrite chol_lower by lia. field. lra.
Qed.

(* Layer A, correctness: when every pivot is positive, L L^T = A on the lower triangle. *)
Theorem product (A : nat -> nat -> R) (n : nat) :
  (forall j, (j < n)%nat -> 0 < piv A j) ->
  forall i j, (j <= i)%nat -> (i < n)%nat ->
  sum n (fun k => chol A i k * chol A j k) = A i j.
Proof.
  intros Hp i j Hji Hi.
  rewrite (sum_trunc _ (S j) n) by
    (lia || (intros k Hk _; rewrite (chol_upper A j k) by lia; ring)).
  apply entry; [exact Hji | apply Hp; lia].
Qed.

Lemma sum_update (f x : nat -> R) (m : nat) (c : R) (N : nat) :
  (m < N)%nat ->
  sum N (fun i => f i * (if (i =? m)%nat then x i - c else x i)) =
  sum N (fun i => f i * x i) - c * f m.
Proof.
  intro Hm.
  rewrite (sum_ext N _ (fun i => f i * x i - (if (i =? m)%nat then c * f i else 0))).
  - rewrite sum_minus. f_equal.
    rewrite (sum_only _ N m Hm).
    + rewrite Nat.eqb_refl. reflexivity.
    + intros k _ Hk. replace (k =? m)%nat with false by (symmetry; apply Nat.eqb_neq; exact Hk).
      reflexivity.
  - intros i _. destruct (i =? m)%nat; ring.
Qed.

(* Back substitution: a vector with x j = 1, zero after j, and L^T x = 0 in rows m < j. *)
Lemma back (L : nat -> nat -> R) (j : nat) :
  (forall i k, (i < k)%nat -> L i k = 0) ->
  (forall m, (m < j)%nat -> L m m <> 0) ->
  forall s, (s <= j)%nat ->
  exists x : nat -> R, x j = 1 /\ (forall i, (j < i)%nat -> x i = 0) /\
    forall m, (j - s <= m)%nat -> (m < j)%nat -> sum (S j) (fun i => L i m * x i) = 0.
Proof.
  intros Hu Hd s. induction s as [| s IH]; intro Hs.
  - exists (fun i => if (i =? j)%nat then 1 else 0). split; [| split].
    + rewrite Nat.eqb_refl. reflexivity.
    + intros i Hi. replace (i =? j)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
      reflexivity.
    + intros m Hm Hmj. lia.
  - destruct (IH ltac:(lia)) as [x [Hx1 [Hx0 Hxe]]].
    set (m0 := (j - S s)%nat).
    set (c := sum (S j) (fun i => L i m0 * x i) / L m0 m0).
    exists (fun i => if (i =? m0)%nat then x i - c else x i). split; [| split].
    + replace (j =? m0)%nat with false by (symmetry; apply Nat.eqb_neq; unfold m0; lia).
      exact Hx1.
    + intros i Hi. replace (i =? m0)%nat with false by (symmetry; apply Nat.eqb_neq; unfold m0; lia).
      apply Hx0. exact Hi.
    + intros m Hm Hmj. rewrite sum_update by (unfold m0; lia).
      destruct (Nat.lt_ge_cases m0 m) as [Hlt | Hge].
      * rewrite Hxe by (unfold m0 in Hlt; lia). rewrite Hu by exact Hlt. ring.
      * replace m with m0 by lia. unfold c. field. apply Hd. unfold m0; lia.
Qed.

(* The quadratic form of a vector supported on 0, ..., j once the pivots before j are positive:
   the squares of L^T x in rows m < j plus the pivot of column j. *)
Lemma quad (A : nat -> nat -> R) (n j : nat) (x : nat -> R) :
  (j < n)%nat ->
  (forall i k, (i < n)%nat -> (k < n)%nat -> A i k = A k i) ->
  (forall k, (k < j)%nat -> 0 < piv A k) ->
  (forall i, (j < i)%nat -> x i = 0) ->
  sum n (fun i => sum n (fun k => x i * A i k * x k)) =
  sum j (fun m => sum (S j) (fun i => chol A i m * x i) ^ 2) + piv A j * x j ^ 2.
Proof.
  intros Hjn Hs Hp Hx.
  set (G := fun i k => sum j (fun m => chol A i m * chol A k m)).
  assert (Hlow : forall i k, (i <= j)%nat -> (k <= i)%nat -> (k < j)%nat -> A i k = G i k).
  { intros i k Hi Hki Hkj. rewrite <- (entry A i k Hki (Hp k Hkj)). unfold G.
    symmetry. apply sum_trunc; [lia |]. intros m Hm _. rewrite (chol_upper A k m) by lia. ring. }
  assert (HG : forall i k, (i <= j)%nat -> (k <= j)%nat -> ~ (i = j /\ k = j) -> A i k = G i k).
  { intros i k Hi Hk Hne. destruct (Nat.le_ge_cases k i) as [Hki | Hik].
    - apply Hlow; lia.
    - rewrite Hs by lia. rewrite Hlow by lia. unfold G. apply sum_ext. intros; ring. }
  assert (Hjj : A j j = G j j + piv A j).
  { unfold G, piv, pivot. rewrite (sum_ext j (fun k => chol A j k ^ 2)
      (fun m => chol A j m * chol A j m)) by (intros; ring). ring. }
  assert (Hlhs : sum n (fun i => sum n (fun k => x i * A i k * x k)) =
                 sum (S j) (fun i => sum (S j) (fun k => x i * A i k * x k))).
  { rewrite (sum_trunc _ (S j) n) by
      (lia || (intros i Hi _; apply sum_zero; intros k _; rewrite (Hx i) by lia; ring)).
    apply sum_ext. intros i _. apply sum_trunc; [lia |].
    intros k Hk _. rewrite (Hx k) by lia. ring. }
  assert (Hrhs : sum j (fun m => sum (S j) (fun i => chol A i m * x i) ^ 2) =
                 sum (S j) (fun i => sum (S j) (fun k => x i * G i k * x k))).
  { rewrite (sum_ext j _ (fun m => sum (S j) (fun i => sum (S j)
      (fun k => x i * chol A i m * chol A k m * x k)))).
    - rewrite sum_comm. apply sum_ext. intros i _. rewrite sum_comm. apply sum_ext.
      intros k _. unfold G. rewrite <- sum_scal_l, <- sum_scal_r. apply sum_ext. intros; ring.
    - intros m _. rewrite pow2_mult, sum_mul_sum. apply sum_ext. intros i _. apply sum_ext.
      intros k _. ring. }
  assert (Hdiff : sum (S j) (fun i => sum (S j) (fun k => x i * A i k * x k)) -
                  sum (S j) (fun i => sum (S j) (fun k => x i * G i k * x k)) =
                  piv A j * x j ^ 2).
  { rewrite <- sum_minus. rewrite (sum_only _ (S j) j); [| lia |].
    - rewrite <- sum_minus. rewrite (sum_only _ (S j) j); [| lia |].
      + rewrite Hjj. ring.
      + intros k Hk Hkj. rewrite (HG j k) by (lia || (intros [_ E]; exact (Hkj E))). ring.
    - intros i Hi Hij. rewrite <- sum_minus. apply sum_zero. intros k Hk.
      rewrite (HG i k) by (lia || (intros [E _]; exact (Hij E))). ring. }
  lra.
Qed.

(* Layer A, existence: every pivot of a symmetric positive definite matrix is positive, so the
   factorization succeeds in exact arithmetic. *)
Theorem pivot_pos (A : nat -> nat -> R) (n : nat) :
  (forall i k, (i < n)%nat -> (k < n)%nat -> A i k = A k i) ->
  (forall x : nat -> R, (exists i, (i < n)%nat /\ x i <> 0) ->
     0 < sum n (fun i => sum n (fun k => x i * A i k * x k))) ->
  forall j, (j < n)%nat -> 0 < piv A j.
Proof.
  intros Hs Hpd j. induction j as [j IH] using (well_founded_induction Wf_nat.lt_wf). intro Hjn.
  assert (Hp : forall k, (k < j)%nat -> 0 < piv A k) by (intros; apply IH; lia).
  destruct (back (chol A) j (fun i k H => chol_upper A i k H)
    (fun m Hm => ltac:(rewrite chol_diag; pose proof (sqrt_lt_R0 _ (Hp m Hm)); lra)) j
    (Nat.le_refl j)) as [x [Hx1 [Hx0 Hxe]]].
  pose proof (quad A n j x Hjn Hs Hp Hx0) as Hq.
  assert (Hz : sum j (fun m => sum (S j) (fun i => chol A i m * x i) ^ 2) = 0).
  { apply sum_zero. intros m Hm. rewrite Hxe by lia. ring. }
  assert (Hne : x j <> 0) by (rewrite Hx1; lra).
  assert (H := Hpd x (ex_intro _ j (conj Hjn Hne))).
  rewrite Hq, Hz, Hx1 in H. lra.
Qed.

(* Layer A, converse: a symmetric matrix whose pivots are all positive is positive definite, so
   the factorization succeeds in exact arithmetic exactly on symmetric positive definite
   matrices. *)
Theorem pos_def (A : nat -> nat -> R) (n : nat) :
  (forall i k, (i < n)%nat -> (k < n)%nat -> A i k = A k i) ->
  (forall j, (j < n)%nat -> 0 < piv A j) ->
  forall x : nat -> R, (exists i, (i < n)%nat /\ x i <> 0) ->
  0 < sum n (fun i => sum n (fun k => x i * A i k * x k)).
Proof.
  intros Hs Hp x [i0 [Hi0 Hx0]].
  set (v := fun m => sum n (fun i => chol A i m * x i)).
  assert (HA : forall i k, (i < n)%nat -> (k < n)%nat ->
                 A i k = sum n (fun m => chol A i m * chol A k m)).
  { intros i k Hi Hk. destruct (Nat.le_ge_cases k i) as [Hki | Hik].
    - symmetry. apply product; assumption.
    - rewrite Hs by assumption. rewrite <- (product A n Hp k i Hik Hk).
      apply sum_ext. intros; ring. }
  assert (Hq : sum n (fun i => sum n (fun k => x i * A i k * x k)) = sum n (fun m => v m ^ 2)).
  { transitivity (sum n (fun i => sum n (fun k => sum n
      (fun m => x i * chol A i m * chol A k m * x k)))).
    - apply sum_ext. intros i Hi. apply sum_ext. intros k Hk. rewrite HA by assumption.
      rewrite <- sum_scal_l, <- sum_scal_r. apply sum_ext. intros; ring.
    - transitivity (sum n (fun i => sum n (fun m => sum n
        (fun k => x i * chol A i m * chol A k m * x k)))).
      + apply sum_ext. intros i _. apply sum_comm.
      + rewrite sum_comm. apply sum_ext. intros m _. unfold v. rewrite pow2_mult, sum_mul_sum.
        apply sum_ext. intros i _. apply sum_ext. intros k _. ring. }
  rewrite Hq.
  destruct (Rlt_le_dec 0 (sum n (fun m => v m ^ 2))) as [Hpos | Hle]; [exact Hpos | exfalso].
  assert (Hv0 : forall m, (m < n)%nat -> v m = 0).
  { intros m Hm.
    pose proof (sum_ge n (fun m => v m ^ 2) m Hm (fun k _ => pow2_ge_0 (v k))) as Hge.
    pose proof (pow2_ge_0 (v m)).
    assert (Hsq : v m ^ 2 = 0) by lra.
    rewrite pow2_mult in Hsq. destruct (Rmult_integral _ _ Hsq); assumption. }
  (* With v = 0, back substitution from the last row gives x = 0. *)
  assert (Hall : forall t, (t <= n)%nat -> forall i, (n - t <= i)%nat -> (i < n)%nat -> x i = 0).
  { intro t. induction t as [| t IH]; intros Ht i Hi Hin; [lia |].
    destruct (Nat.eq_dec i (n - S t)) as [-> | Hne]; [| apply IH; lia].
    assert (Hvi : v (n - S t)%nat = chol A (n - S t) (n - S t) * x (n - S t)%nat).
    { unfold v. apply (sum_only (fun i => chol A i (n - S t)%nat * x i) n (n - S t)); [lia |].
      intros k Hk Hkn.
      destruct (Nat.lt_ge_cases k (n - S t)) as [Hlt | Hge].
      - rewrite (chol_upper A k) by exact Hlt. ring.
      - rewrite (IH ltac:(lia) k) by lia. ring. }
    rewrite Hv0, chol_diag in Hvi by lia.
    pose proof (sqrt_lt_R0 _ (Hp (n - S t)%nat ltac:(lia))).
    destruct (Rmult_integral _ _ (eq_sym Hvi)); [lra | assumption]. }
  apply Hx0. apply (Hall n (Nat.le_refl n)); lia.
Qed.
