From Stdlib Require Import Reals Lra Lia Psatz.
From Diana.Real Require Import Cholesky.
Open Scope R_scope.

(* Row i of forward substitution, from the entries x k, k < i. *)
Definition row (L : nat -> nat -> R) (b x : nat -> R) (i : nat) : R :=
  (b i - sum i (fun k => L i k * x k)) / L i i.

(* The solution after rows 0, ..., m - 1; later entries are zero. *)
Fixpoint solve (L : nat -> nat -> R) (b : nat -> R) (m : nat) : nat -> R :=
  match m with
  | O => fun _ => 0
  | S m' => fun i => if (i =? m')%nat then row L b (solve L b m') m' else solve L b m' i
  end.

(* Forward substitution, the solution of L x = b for a lower-triangular L: entry i is computed
   from the entries before it. Only the entries L i k with k <= i are read. *)
Definition fwd (L : nat -> nat -> R) (b : nat -> R) (i : nat) : R := solve L b (S i) i.

(* The mirrored matrix L (n - 1 - q) (n - 1 - p): the transpose with both indices reversed,
   lower triangular when L is. *)
Definition mirror (L : nat -> nat -> R) (n p q : nat) : R := L (n - 1 - q)%nat (n - 1 - p)%nat.

(* The vector with its indices reversed. *)
Definition mirrorv (b : nat -> R) (n p : nat) : R := b (n - 1 - p)%nat.

(* Back substitution, the solution of L^T x = b for a lower-triangular L: forward substitution
   on the mirrored system, so entry i is computed from the entries after it. *)
Definition bwd (L : nat -> nat -> R) (b : nat -> R) (n i : nat) : R :=
  fwd (mirror L n) (mirrorv b n) (n - 1 - i).

(* The comparison matrix: |L i i| on the diagonal, -|L i k| off it. *)
Definition cmp (L : nat -> nat -> R) (i k : nat) : R :=
  if (k =? i)%nat then Rabs (L i i) else - Rabs (L i k).

Lemma sum_le (n : nat) (f g : nat -> R) :
  (forall k, (k < n)%nat -> f k <= g k) -> sum n f <= sum n g.
Proof.
  induction n as [| n IH]; intro H; simpl; [lra |].
  pose proof (IH (fun k Hk => H k ltac:(lia))). pose proof (H n ltac:(lia)). lra.
Qed.

Lemma sum_Rabs (n : nat) (f : nat -> R) : Rabs (sum n f) <= sum n (fun k => Rabs (f k)).
Proof.
  induction n as [| n IH]; simpl; [rewrite Rabs_R0; lra |].
  eapply Rle_trans; [apply Rabs_triang | lra].
Qed.

Lemma sum_shift (n : nat) (f : nat -> R) : sum (S n) f = f O + sum n (fun k => f (S k)).
Proof.
  revert f. induction n as [| n IH]; intro f; [cbn [sum]; ring |].
  change (sum (S (S n)) f) with (sum (S n) f + f (S n)). rewrite IH. cbn [sum]. ring.
Qed.

Lemma sum_rev (n : nat) (f : nat -> R) : sum n (fun q => f (n - 1 - q)%nat) = sum n f.
Proof.
  revert f. induction n as [| n IH]; intro f; [reflexivity |].
  rewrite (sum_shift n f). cbn [sum].
  replace (S n - 1 - n)%nat with O by lia.
  rewrite (sum_ext n (fun q => f (S n - 1 - q)%nat)
             (fun q => (fun k => f (S k)) (n - 1 - q)%nat)) by (intros q Hq; f_equal; lia).
  rewrite (IH (fun k => f (S k))). ring.
Qed.

Lemma sum_split (m n : nat) (f : nat -> R) :
  (m <= n)%nat -> sum n f = sum m f + sum (n - m) (fun t => f (m + t)%nat).
Proof.
  intro Hmn. replace n with (m + (n - m))%nat at 1 by lia.
  generalize (n - m)%nat. intro d.
  induction d as [| d IH].
  - rewrite Nat.add_0_r. cbn [sum]. ring.
  - rewrite Nat.add_succ_r. cbn [sum]. rewrite IH. ring.
Qed.

Lemma solve_eq (L : nat -> nat -> R) (b : nat -> R) (m i : nat) :
  (i < m)%nat -> solve L b m i = fwd L b i.
Proof.
  revert i. induction m as [| m IH]; intros i Hi; [lia |].
  destruct (Nat.eq_dec i m) as [-> | Hne]; [reflexivity |].
  simpl. replace (i =? m)%nat with false by (symmetry; apply Nat.eqb_neq; exact Hne).
  apply IH. lia.
Qed.

Lemma row_congr (L : nat -> nat -> R) (b x x' : nat -> R) (i : nat) :
  (forall k, (k < i)%nat -> x k = x' k) -> row L b x i = row L b x' i.
Proof.
  intro H. unfold row. f_equal. f_equal. apply sum_ext. intros k Hk. rewrite H by exact Hk.
  reflexivity.
Qed.

Lemma fwd_eq (L : nat -> nat -> R) (b : nat -> R) (i : nat) : fwd L b i = row L b (fwd L b) i.
Proof.
  unfold fwd at 1. simpl. rewrite Nat.eqb_refl.
  apply row_congr. intros k Hk. apply solve_eq. exact Hk.
Qed.

Lemma fwd_congr (L L' : nat -> nat -> R) (b b' : nat -> R) (m : nat) :
  (forall p q, (q <= p)%nat -> (p < m)%nat -> L p q = L' p q) ->
  (forall p, (p < m)%nat -> b p = b' p) ->
  forall i, (i < m)%nat -> fwd L b i = fwd L' b' i.
Proof.
  intros HL Hb i. induction i as [i IH] using (well_founded_induction Wf_nat.lt_wf). intro Hi.
  rewrite (fwd_eq L), (fwd_eq L'). unfold row.
  rewrite Hb, (HL i i) by lia. f_equal. f_equal. apply sum_ext. intros k Hk.
  rewrite (HL i k), IH by lia. reflexivity.
Qed.

Lemma fwd_zero (L : nat -> nat -> R) (i : nat) : fwd L (fun _ => 0) i = 0.
Proof.
  induction i as [i IH] using (well_founded_induction Wf_nat.lt_wf).
  rewrite fwd_eq. unfold row. rewrite sum_zero by (intros k Hk; rewrite IH by exact Hk; ring).
  unfold Rdiv. ring.
Qed.

(* Layer A, forward substitution solves each row: once L i i <> 0,
   sum_{k <= i} L i k * x k = b i for x = fwd L b. *)
Theorem forward_solve (L : nat -> nat -> R) (b : nat -> R) (i : nat) :
  L i i <> 0 -> sum (S i) (fun k => L i k * fwd L b k) = b i.
Proof.
  intro Hd. cbn [sum]. rewrite (fwd_eq L b i). unfold row. field. exact Hd.
Qed.

(* Layer A, forward error from the residual: if y leaves residuals bounded by rho, then
   |x i - y i| is at most the forward substitution of rho with the comparison matrix. *)
Theorem forward_perturb (L : nat -> nat -> R) (b y rho : nat -> R) (n : nat) :
  (forall i, (i < n)%nat -> L i i <> 0) ->
  (forall i, (i < n)%nat -> Rabs (b i - sum (S i) (fun k => L i k * y k)) <= rho i) ->
  forall i, (i < n)%nat -> Rabs (fwd L b i - y i) <= fwd (cmp L) rho i.
Proof.
  intros Hd Hr i. induction i as [i IH] using (well_founded_induction Wf_nat.lt_wf). intro Hi.
  pose proof (Hd i Hi) as Hdi.
  assert (Hrow : L i i * (fwd L b i - y i) =
                 (b i - sum (S i) (fun k => L i k * y k)) -
                 sum i (fun k => L i k * (fwd L b k - y k))).
  { pose proof (forward_solve L b i Hdi) as Hs. cbn [sum] in Hs |- *.
    rewrite (sum_ext i (fun k => L i k * (fwd L b k - y k))
               (fun k => L i k * fwd L b k - L i k * y k)) by (intros; ring).
    rewrite sum_minus. lra. }
  assert (Hz : fwd (cmp L) rho i =
               (rho i + sum i (fun k => Rabs (L i k) * fwd (cmp L) rho k)) / Rabs (L i i)).
  { rewrite (fwd_eq (cmp L) rho i). unfold row.
    replace (cmp L i i) with (Rabs (L i i)) by (unfold cmp; rewrite Nat.eqb_refl; reflexivity).
    assert (E : sum i (fun k => cmp L i k * fwd (cmp L) rho k) =
                -1 * sum i (fun k => Rabs (L i k) * fwd (cmp L) rho k)).
    { rewrite <- sum_scal_l. apply sum_ext. intros k Hk. unfold cmp.
      replace (k =? i)%nat with false by (symmetry; apply Nat.eqb_neq; lia). ring. }
    rewrite E. f_equal. ring. }
  assert (Hb : Rabs (L i i) * Rabs (fwd L b i - y i) <=
               rho i + sum i (fun k => Rabs (L i k) * fwd (cmp L) rho k)).
  { rewrite <- Rabs_mult, Hrow. unfold Rminus at 1.
    eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_Ropp.
    apply Rplus_le_compat; [apply Hr; exact Hi |].
    eapply Rle_trans; [apply sum_Rabs |].
    apply sum_le. intros k Hk. rewrite Rabs_mult.
    apply Rmult_le_compat_l; [apply Rabs_pos |]. apply IH; lia. }
  pose proof (Rabs_pos_lt _ Hdi) as Hpos.
  rewrite Hz. apply (Rmult_le_reg_l (Rabs (L i i))); [exact Hpos |].
  replace (Rabs (L i i) * ((rho i + sum i (fun k => Rabs (L i k) * fwd (cmp L) rho k)) /
                           Rabs (L i i)))
    with (rho i + sum i (fun k => Rabs (L i k) * fwd (cmp L) rho k)) by (field; lra).
  exact Hb.
Qed.

(* Layer A, uniqueness: forward substitution gives the only solution of L x = b on the indices
   below n when the diagonal has no zero. *)
Theorem forward_unique (L : nat -> nat -> R) (b y : nat -> R) (n : nat) :
  (forall i, (i < n)%nat -> L i i <> 0) ->
  (forall i, (i < n)%nat -> sum (S i) (fun k => L i k * y k) = b i) ->
  forall i, (i < n)%nat -> y i = fwd L b i.
Proof.
  intros Hd Hy i Hi.
  assert (Hr : forall j, (j < n)%nat -> Rabs (b j - sum (S j) (fun k => L j k * y k)) <= 0).
  { intros j Hj. rewrite Hy by exact Hj. unfold Rminus. rewrite Rplus_opp_r, Rabs_R0. lra. }
  pose proof (forward_perturb L b y (fun _ => 0) n Hd Hr i Hi) as H.
  rewrite fwd_zero in H.
  pose proof (Rle_abs (fwd L b i - y i)). pose proof (Rle_abs (- (fwd L b i - y i))).
  rewrite Rabs_Ropp in *. lra.
Qed.

Lemma sum_mirror (g : nat -> R) (i n : nat) :
  (i < n)%nat ->
  sum (S (n - 1 - i)) (fun q => g (n - 1 - q)%nat) = sum (n - i) (fun t => g (i + t)%nat).
Proof.
  intro Hi. replace (S (n - 1 - i)) with (n - i)%nat by lia.
  rewrite <- (sum_rev (n - i) (fun t => g (i + t)%nat)).
  apply sum_ext. intros q Hq. f_equal. lia.
Qed.

(* Layer A, back substitution solves each row: once L i i <> 0,
   sum_{i <= k < n} L k i * x k = b i for x = bwd L b n, that is L^T x = b in row i. *)
Theorem back_solve (L : nat -> nat -> R) (b : nat -> R) (n i : nat) :
  (i < n)%nat -> L i i <> 0 ->
  sum (n - i) (fun t => L (i + t)%nat i * bwd L b n (i + t)) = b i.
Proof.
  intros Hi Hd.
  assert (Hp : (n - 1 - (n - 1 - i))%nat = i) by lia.
  assert (Hdm : mirror L n (n - 1 - i) (n - 1 - i) <> 0) by (unfold mirror; rewrite Hp; exact Hd).
  pose proof (forward_solve (mirror L n) (mirrorv b n) (n - 1 - i) Hdm) as H.
  assert (Hb : mirrorv b n (n - 1 - i) = b i) by (unfold mirrorv; rewrite Hp; reflexivity).
  rewrite Hb in H. rewrite <- H.
  transitivity (sum (S (n - 1 - i)) (fun q => (fun k => L k i * bwd L b n k) (n - 1 - q)%nat)).
  { symmetry. exact (sum_mirror (fun k => L k i * bwd L b n k) i n Hi). }
  apply sum_ext. intros q Hq. cbv beta. unfold mirror, bwd. rewrite Hp.
  replace (n - 1 - (n - 1 - q))%nat with q by lia. reflexivity.
Qed.

Lemma mirror_back (L : nat -> nat -> R) (y : nat -> R) (n p : nat) :
  (p < n)%nat ->
  sum (S p) (fun q => mirror L n p q * y (n - 1 - q)%nat) =
  sum (n - (n - 1 - p)) (fun t => L (n - 1 - p + t)%nat (n - 1 - p)%nat * y (n - 1 - p + t)%nat).
Proof.
  intro Hp.
  transitivity (sum (S (n - 1 - (n - 1 - p)))
                  (fun q => (fun k => L k (n - 1 - p)%nat * y k) (n - 1 - q)%nat)).
  - replace (S (n - 1 - (n - 1 - p))) with (S p) by lia. reflexivity.
  - exact (sum_mirror (fun k => L k (n - 1 - p)%nat * y k) (n - 1 - p) n ltac:(lia)).
Qed.

Lemma cmp_mirror (L : nat -> nat -> R) (n : nat) :
  forall p q, (q <= p)%nat -> (p < n)%nat -> cmp (mirror L n) p q = mirror (cmp L) n p q.
Proof.
  intros p q Hqp Hp. unfold cmp, mirror.
  destruct (Nat.eq_dec q p) as [-> | Hne].
  - rewrite !Nat.eqb_refl. reflexivity.
  - replace (q =? p)%nat with false by (symmetry; apply Nat.eqb_neq; exact Hne).
    replace (n - 1 - p =? n - 1 - q)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
    reflexivity.
Qed.

(* Layer A, back-substitution forward error from the residual, as forward_perturb: |x i - y i|
   is at most the back substitution of rho with the comparison matrix. *)
Theorem back_perturb (L : nat -> nat -> R) (b y rho : nat -> R) (n : nat) :
  (forall i, (i < n)%nat -> L i i <> 0) ->
  (forall i, (i < n)%nat ->
     Rabs (b i - sum (n - i) (fun t => L (i + t)%nat i * y (i + t)%nat)) <= rho i) ->
  forall i, (i < n)%nat -> Rabs (bwd L b n i - y i) <= bwd (cmp L) rho n i.
Proof.
  intros Hd Hr i Hi.
  assert (Hdm : forall p, (p < n)%nat -> mirror L n p p <> 0) by (intros; apply Hd; lia).
  assert (Hrm : forall p, (p < n)%nat ->
            Rabs (mirrorv b n p - sum (S p) (fun q => mirror L n p q * mirrorv y n q))
            <= mirrorv rho n p).
  { intros p Hp. unfold mirrorv. rewrite mirror_back by exact Hp. apply Hr. lia. }
  pose proof (forward_perturb (mirror L n) (mirrorv b n) (mirrorv y n) (mirrorv rho n) n
                Hdm Hrm (n - 1 - i) ltac:(lia)) as H.
  assert (Hy : mirrorv y n (n - 1 - i) = y i)
    by (unfold mirrorv; replace (n - 1 - (n - 1 - i))%nat with i by lia; reflexivity).
  rewrite Hy in H.
  unfold bwd.
  rewrite <- (fwd_congr (cmp (mirror L n)) (mirror (cmp L) n) (mirrorv rho n) (mirrorv rho n) n
                (cmp_mirror L n) (fun p _ => eq_refl) (n - 1 - i)) by lia.
  exact H.
Qed.

(* Layer A, uniqueness of the back-substitution solution of L^T x = b. *)
Theorem back_unique (L : nat -> nat -> R) (b y : nat -> R) (n : nat) :
  (forall i, (i < n)%nat -> L i i <> 0) ->
  (forall i, (i < n)%nat -> sum (n - i) (fun t => L (i + t)%nat i * y (i + t)%nat) = b i) ->
  forall i, (i < n)%nat -> y i = bwd L b n i.
Proof.
  intros Hd Hy i Hi.
  assert (Hr : forall j, (j < n)%nat ->
            Rabs (b j - sum (n - j) (fun t => L (j + t)%nat j * y (j + t)%nat)) <= 0).
  { intros j Hj. rewrite Hy by exact Hj. unfold Rminus. rewrite Rplus_opp_r, Rabs_R0. lra. }
  pose proof (back_perturb L b y (fun _ => 0) n Hd Hr i Hi) as H.
  assert (H0 : bwd (cmp L) (fun _ => 0) n i = 0)
    by exact (fwd_zero (mirror (cmp L) n) (n - 1 - i)).
  rewrite H0 in H.
  pose proof (Rle_abs (bwd L b n i - y i)). pose proof (Rle_abs (- (bwd L b n i - y i))).
  rewrite Rabs_Ropp in *. lra.
Qed.

(* Layer A, solving with the Cholesky factor: for a symmetric A whose pivots are positive,
   x = bwd L (fwd L b) n with L = chol A solves A x = b. *)
Theorem cholesky_solve (A : nat -> nat -> R) (n : nat) (b : nat -> R) :
  (forall i k, (i < n)%nat -> (k < n)%nat -> A i k = A k i) ->
  (forall j, (j < n)%nat -> 0 < piv A j) ->
  forall i, (i < n)%nat ->
  sum n (fun k => A i k * bwd (chol A) (fwd (chol A) b) n k) = b i.
Proof.
  intros Hs Hp i Hi.
  assert (Hd : forall j, (j < n)%nat -> chol A j j <> 0).
  { intros j Hj. rewrite chol_diag. pose proof (sqrt_lt_R0 _ (Hp j Hj)). lra. }
  assert (HA : forall i k, (i < n)%nat -> (k < n)%nat ->
                 A i k = sum n (fun m => chol A i m * chol A k m)).
  { intros i' k Hi' Hk. destruct (Nat.le_ge_cases k i') as [Hki | Hik].
    - symmetry. apply product; assumption.
    - rewrite Hs by assumption. rewrite <- (product A n Hp k i' Hik Hk).
      apply sum_ext. intros; ring. }
  assert (Hcol : forall m, (m < n)%nat ->
            sum n (fun k => chol A k m * bwd (chol A) (fwd (chol A) b) n k) = fwd (chol A) b m).
  { intros m Hm. rewrite (sum_split m n) by lia.
    rewrite sum_zero by (intros k Hk; rewrite (chol_upper A k m) by exact Hk; ring).
    rewrite Rplus_0_l. apply back_solve; [exact Hm | apply Hd; exact Hm]. }
  transitivity (sum n (fun k => sum n (fun m =>
    chol A i m * (chol A k m * bwd (chol A) (fwd (chol A) b) n k)))).
  { apply sum_ext. intros k Hk. rewrite HA by assumption. rewrite <- sum_scal_r.
    apply sum_ext. intros; ring. }
  rewrite sum_comm.
  transitivity (sum n (fun m => chol A i m * fwd (chol A) b m)).
  { apply sum_ext. intros m Hm. rewrite sum_scal_l, Hcol by exact Hm. reflexivity. }
  rewrite (sum_trunc _ (S i) n) by
    (lia || (intros m Hm _; rewrite (chol_upper A i m) by lia; ring)).
  apply forward_solve. apply Hd. exact Hi.
Qed.
