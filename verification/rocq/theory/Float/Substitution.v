From Stdlib Require Import Reals ZArith Lia Lra Psatz.
From Flocq Require Import Core Relative IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Float Require Cholesky.
From Diana.Real Require Import Cholesky Substitution.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Section Model.

Variable sub_nan mult_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fsub := (Diana.Float.Cholesky.fsub sub_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fdiv := (Diana.Float.Sum.fdiv div_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

(* c - g 0 * h 0 - ... - g (k-1) * h (k-1), each product rounded, subtracted in order. *)
Fixpoint fdotv (g h : nat -> b64) (c : b64) (k : nat) : b64 :=
  match k with
  | O => c
  | S k' => fsub (fdotv g h c k') (fmul (g k') (h k'))
  end.

(* Row i of the binary64 forward substitution, from the entries x k, k < i. *)
Definition frow (L : nat -> nat -> b64) (b x : nat -> b64) (i : nat) : b64 :=
  fdiv (fdotv (L i) x (b i) i) (L i i).

Fixpoint fsolve (L : nat -> nat -> b64) (b : nat -> b64) (m : nat) : nat -> b64 :=
  match m with
  | O => fun _ => Diana.Float.Cholesky.fzero
  | S m' => fun i => if (i =? m')%nat then frow L b (fsolve L b m') m' else fsolve L b m' i
  end.

(* The binary64 model of diana_forward_substitution: entry i of the solution in the C's
   operation order; L i k is l[i + k*n] and b i is b[i]. *)
Definition ffwd (L : nat -> nat -> b64) (b : nat -> b64) (i : nat) : b64 := fsolve L b (S i) i.

Definition fmirror (L : nat -> nat -> b64) (n p q : nat) : b64 := L (n - 1 - q)%nat (n - 1 - p)%nat.
Definition fmirrorv (b : nat -> b64) (n p : nat) : b64 := b (n - 1 - p)%nat.

(* The binary64 model of diana_transpose_substitution: forward substitution on the mirrored system,
   which is the C's order, the products subtracted from k = n - 1 down to i + 1 (fbwd_eq). *)
Definition fbwd (L : nat -> nat -> b64) (b : nat -> b64) (n i : nat) : b64 :=
  ffwd (fmirror L n) (fmirrorv b n) (n - 1 - i).

(* The real data of the binary64 inputs. *)
Definition rmat (L : nat -> nat -> b64) (i k : nat) : R := r (L i k).
Definition rvec (b : nat -> b64) (i : nat) : R := r (b i).

(* The backward-error bound of row i of each solve (forward_backward_error,
   back_backward_error). *)
Definition fwd_bound (L : nat -> nat -> b64) (b : nat -> b64) (i : nat) : R :=
  gamma (S i) * sum (S i) (fun k => Rabs (r (L i k) * r (ffwd L b k)))
  + (1 + gamma (S i)) * (INR i + Rabs (r (L i i))) * eta.

Definition bwd_bound (L : nat -> nat -> b64) (b : nat -> b64) (n i : nat) : R :=
  gamma (n - i) * sum (n - i) (fun t => Rabs (r (L (i + t)%nat i) * r (fbwd L b n (i + t))))
  + (1 + gamma (n - i)) * (INR (n - 1 - i) + Rabs (r (L i i))) * eta.

Lemma fdotv_fdot (g h : nat -> b64) (c : b64) (k : nat) :
  fdotv g h c k =
  Diana.Float.Cholesky.fdot sub_nan mult_nan (fun i m => if (i =? 0)%nat then g m else h m)
    c 0 1 k.
Proof. induction k as [| k IH]; [reflexivity |]. simpl. rewrite IH. reflexivity. Qed.

Lemma fdotv_congr (g g' h h' : nat -> b64) (c : b64) (k : nat) :
  (forall m, (m < k)%nat -> g m = g' m) -> (forall m, (m < k)%nat -> h m = h' m) ->
  fdotv g h c k = fdotv g' h' c k.
Proof.
  induction k as [| k IH]; intros Hg Hh; [reflexivity |]. simpl.
  rewrite IH by (intros; (apply Hg || apply Hh); lia). rewrite Hg, Hh by lia. reflexivity.
Qed.

Lemma fsolve_eq (L : nat -> nat -> b64) (b : nat -> b64) (m i : nat) :
  (i < m)%nat -> fsolve L b m i = ffwd L b i.
Proof.
  revert i. induction m as [| m IH]; intros i Hi; [lia |].
  destruct (Nat.eq_dec i m) as [-> | Hne]; [reflexivity |].
  simpl. replace (i =? m)%nat with false by (symmetry; apply Nat.eqb_neq; exact Hne).
  apply IH. lia.
Qed.

Lemma ffwd_eq (L : nat -> nat -> b64) (b : nat -> b64) (i : nat) :
  ffwd L b i = fdiv (fdotv (L i) (ffwd L b) (b i) i) (L i i).
Proof.
  unfold ffwd at 1. simpl. rewrite Nat.eqb_refl. unfold frow. f_equal.
  apply fdotv_congr; [reflexivity |]. intros k Hk. apply fsolve_eq. exact Hk.
Qed.

(* The C's back-substitution order: x i = (b i - L (n-1) i * x (n-1) - ... - L (i+1) i * x (i+1))
   / L i i, the products rounded and subtracted from k = n - 1 down. *)
Lemma fbwd_eq (L : nat -> nat -> b64) (b : nat -> b64) (n i : nat) :
  (i < n)%nat ->
  fbwd L b n i =
  fdiv (fdotv (fun t => L (n - 1 - t)%nat i) (fun t => fbwd L b n (n - 1 - t)) (b i) (n - 1 - i))
    (L i i).
Proof.
  intro Hi. assert (Hp : (n - 1 - (n - 1 - i))%nat = i) by lia.
  unfold fbwd at 1. rewrite ffwd_eq.
  replace (fmirrorv b n (n - 1 - i)) with (b i) by (unfold fmirrorv; rewrite Hp; reflexivity).
  replace (fmirror L n (n - 1 - i) (n - 1 - i)) with (L i i)
    by (unfold fmirror; rewrite Hp; reflexivity).
  f_equal. apply fdotv_congr.
  - intros t Ht. unfold fmirror. rewrite Hp. reflexivity.
  - intros t Ht. unfold fbwd. f_equal. lia.
Qed.

(* Rounding error of one row: c minus k rounded products, then a correctly rounded division. *)
Lemma row_error (g h : nat -> b64) (c d : b64) (k : nat) :
  fin (fdiv (fdotv g h c k) d) -> r d <> 0 -> INR (S k) * u < 1 ->
  Rabs (r c - (sum k (fun m => r (g m) * r (h m)) + r d * r (fdiv (fdotv g h c k) d)))
    <= gamma (S k) * (sum k (fun m => Rabs (r (g m) * r (h m)))
                      + Rabs (r d * r (fdiv (fdotv g h c k) d)))
       + (1 + gamma (S k)) * (INR k + Rabs (r d)) * eta.
Proof.
  intros Hf Hd Hk.
  rewrite (Rmult_comm (r d) (r (fdiv (fdotv g h c k) d))).
  pose proof (Diana.Float.Cholesky.gamma_lt _ Hk) as Hk0.
  pose proof u_pos as Hu. pose proof eta_pos as Heta.
  assert (Hu1 : u < 1).
  { eapply Rle_lt_trans; [| exact Hk]. rewrite S_INR. pose proof (pos_INR k). nra. }
  pose proof (gamma_nonneg _ Hk0) as Hg0. pose proof (gamma_nonneg _ Hk) as Hg1.
  pose proof (gamma_mono k (S k) ltac:(lia) Hk) as M01.
  set (s := fdotv g h c k) in *.
  set (x := fdiv s d) in *.
  assert (Hs : fin s) by (apply (fdiv_finite_inv (div_nan := div_nan) s d); exact Hf).
  destruct (Diana.Float.Cholesky.dot_error sub_nan mult_nan
              (fun i m => if (i =? 0)%nat then g m else h m) c 0 1 k
              ltac:(rewrite <- fdotv_fdot; exact Hs) Hk0) as [F [HF Hb]].
  rewrite <- fdotv_fdot in Hb. fold s in Hb.
  set (S0 := sum k (fun m => r (g m) * r (h m))).
  set (A0 := sum k (fun m => Rabs (r (g m) * r (h m)))).
  change (Rabs (r c - S0 - r s * F) <= gamma k * A0 + (1 + gamma k) * INR k * eta) in Hb.
  assert (HA0 : 0 <= A0) by (apply sum_nonneg; intros; apply Rabs_pos).
  destruct (Diana.Float.Cholesky.div_error div_nan s d Hf Hd) as [dv [ev [Hdv [Hev Hrv]]]].
  fold x in Hrv.
  assert (Hnz : 1 + dv <> 0) by (pose proof (Rabs_le_inv _ _ Hdv); lra).
  assert (Hsr : r s = (r x - ev) * r d / (1 + dv)).
  { rewrite Hrv. field. split; assumption. }
  pose proof (Diana.Float.Cholesky.factor_div F dv k HF Hdv Hk) as H1.
  set (G := F / (1 + dv)) in *.
  replace (r c - (S0 + r x * r d)) with
    ((r c - S0 - r s * F) + r x * r d * (G - 1) - ev * r d * G)
    by (rewrite Hsr; unfold G; field; exact Hnz).
  assert (HG1 : Rabs G <= 1 + gamma (S k)).
  { replace G with ((G - 1) + 1) by ring. eapply Rle_trans; [apply Rabs_triang |].
    rewrite Rabs_R1. lra. }
  assert (T2 : Rabs (r x * r d * (G - 1)) <= Rabs (r x * r d) * gamma (S k)).
  { rewrite (Rabs_mult (r x * r d)). apply Rmult_le_compat_l; [apply Rabs_pos | exact H1]. }
  assert (T3 : Rabs (ev * r d * G) <= eta * Rabs (r d) * (1 + gamma (S k))).
  { rewrite !Rabs_mult. apply Rmult_le_compat; [| apply Rabs_pos | | exact HG1].
    - apply Rmult_le_pos; apply Rabs_pos.
    - apply Rmult_le_compat_r; [apply Rabs_pos | exact Hev]. }
  assert (G1 : gamma k * A0 <= gamma (S k) * A0) by (apply Rmult_le_compat_r; lra).
  assert (G2 : (1 + gamma k) * INR k * eta <= (1 + gamma (S k)) * INR k * eta).
  { apply Rmult_le_compat_r; [lra |]. apply Rmult_le_compat_r; [apply pos_INR | lra]. }
  assert (G4 : Rabs (r x * r d) * gamma (S k) = gamma (S k) * Rabs (r x * r d)) by ring.
  assert (G5 : eta * Rabs (r d) * (1 + gamma (S k)) = (1 + gamma (S k)) * Rabs (r d) * eta)
    by ring.
  unfold Rminus at 1.
  eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_Ropp.
  eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
  rewrite Rmult_plus_distr_l, !Rmult_plus_distr_r.
  lra.
Qed.

(* Layer B, backward error of forward substitution, row i (Higham, Accuracy and Stability of
   Numerical Algorithms, chapter 8, with the underflow terms): when the computed x i is finite
   and L i i is not zero,
   |b i - sum_{k <= i} L i k * x k|
     <= gamma (i + 1) * sum_{k <= i} |L i k * x k| + (1 + gamma (i + 1)) * (i + |L i i|) * eta,
   so x solves (L + dL) x = b with |dL i k| <= gamma (i + 1) * |L i k|, up to underflow. *)
Theorem forward_backward_error (L : nat -> nat -> b64) (b : nat -> b64) (i : nat) :
  fin (ffwd L b i) -> r (L i i) <> 0 -> INR (S i) * u < 1 ->
  Rabs (r (b i) - sum (S i) (fun k => r (L i k) * r (ffwd L b k))) <= fwd_bound L b i.
Proof.
  intros Hf Hd Hk. unfold fwd_bound. cbn [sum].
  rewrite (ffwd_eq L b i) in Hf |- *.
  apply row_error; assumption.
Qed.

(* Layer B, forward error of forward substitution: when every computed entry is finite and the
   diagonal has no zero (the C's DIANA_OK), the exact solution x of L x = b on the binary64
   data satisfies |x i - x^ i| <= z i, z the forward substitution of the row bounds with the
   comparison matrix: |x - x^| <= M(L)^-1 (gamma |L| |x^| + underflow). *)
Theorem forward_forward_error (L : nat -> nat -> b64) (b : nat -> b64) (n : nat) :
  (forall i, (i < n)%nat -> r (L i i) <> 0) ->
  (forall i, (i < n)%nat -> fin (ffwd L b i)) ->
  INR n * u < 1 ->
  forall i, (i < n)%nat ->
  Rabs (fwd (rmat L) (rvec b) i - r (ffwd L b i)) <= fwd (cmp (rmat L)) (fwd_bound L b) i.
Proof.
  intros Hd Hf Hn.
  apply forward_perturb; [exact Hd |].
  intros i Hi. apply forward_backward_error; [apply Hf; exact Hi | apply Hd; exact Hi |].
  eapply Rle_lt_trans; [| exact Hn]. apply Rmult_le_compat_r; [left; apply u_pos |].
  apply le_INR. lia.
Qed.

(* Layer B, backward error of back substitution, row i: when the computed x i is finite and
   L i i is not zero,
   |b i - sum_{i <= k < n} L k i * x k|
     <= gamma (n - i) * sum_{i <= k < n} |L k i * x k|
        + (1 + gamma (n - i)) * (n - 1 - i + |L i i|) * eta. *)
Theorem back_backward_error (L : nat -> nat -> b64) (b : nat -> b64) (n i : nat) :
  (i < n)%nat -> fin (fbwd L b n i) -> r (L i i) <> 0 -> INR (n - i) * u < 1 ->
  Rabs (r (b i) - sum (n - i) (fun t => r (L (i + t)%nat i) * r (fbwd L b n (i + t))))
    <= bwd_bound L b n i.
Proof.
  intros Hi Hf Hd Hk.
  assert (Hp : (n - 1 - (n - 1 - i))%nat = i) by lia.
  assert (Hs : S (n - 1 - i) = (n - i)%nat) by lia.
  assert (Hdm : r (fmirror L n (n - 1 - i) (n - 1 - i)) <> 0)
    by (unfold fmirror; rewrite Hp; exact Hd).
  pose proof (forward_backward_error (fmirror L n) (fmirrorv b n) (n - 1 - i) Hf Hdm
                ltac:(rewrite Hs; exact Hk)) as H.
  unfold fwd_bound in H.
  assert (E : forall (f : R -> R),
            sum (S (n - 1 - i)) (fun q => f (r (fmirror L n (n - 1 - i) q) *
                                            r (ffwd (fmirror L n) (fmirrorv b n) q))) =
            sum (n - i) (fun t => f (r (L (i + t)%nat i) * r (fbwd L b n (i + t))))).
  { intro f.
    transitivity (sum (S (n - 1 - i))
                    (fun q => (fun k => f (r (L k i) * r (fbwd L b n k))) (n - 1 - q)%nat)).
    - apply sum_ext. intros q Hq. cbv beta. unfold fmirror, fbwd. rewrite Hp.
      replace (n - 1 - (n - 1 - q))%nat with q by lia. reflexivity.
    - exact (sum_mirror (fun k => f (r (L k i) * r (fbwd L b n k))) i n Hi). }
  rewrite (E (fun v => v)), (E Rabs) in H.
  assert (Hb : fmirrorv b n (n - 1 - i) = b i) by (unfold fmirrorv; rewrite Hp; reflexivity).
  assert (Hl : fmirror L n (n - 1 - i) (n - 1 - i) = L i i)
    by (unfold fmirror; rewrite Hp; reflexivity).
  rewrite Hb, Hl, Hs in H. unfold bwd_bound. exact H.
Qed.

(* Layer B, forward error of back substitution, as forward_forward_error: the exact solution x
   of L^T x = b satisfies |x i - x^ i| <= z i, z the back substitution of the row bounds with the
   comparison matrix. *)
Theorem back_forward_error (L : nat -> nat -> b64) (b : nat -> b64) (n : nat) :
  (forall i, (i < n)%nat -> r (L i i) <> 0) ->
  (forall i, (i < n)%nat -> fin (fbwd L b n i)) ->
  INR n * u < 1 ->
  forall i, (i < n)%nat ->
  Rabs (bwd (rmat L) (rvec b) n i - r (fbwd L b n i)) <= bwd (cmp (rmat L)) (bwd_bound L b n) n i.
Proof.
  intros Hd Hf Hn.
  apply (back_perturb (rmat L) (rvec b) (fun k => r (fbwd L b n k))); [exact Hd |].
  intros i Hi. apply back_backward_error; [exact Hi | apply Hf; exact Hi | apply Hd; exact Hi |].
  eapply Rle_lt_trans; [| exact Hn]. apply Rmult_le_compat_r; [left; apply u_pos |].
  apply le_INR. lia.
Qed.

End Model.
