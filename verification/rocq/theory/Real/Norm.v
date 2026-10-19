From Stdlib Require Import Reals Lra Lia Psatz List.
Import ListNotations.
Open Scope R_scope.

(* norm1 x = |x0| + ... + |x(n-1)| *)
Fixpoint norm1 (x : list R) : R :=
  match x with [] => 0 | a :: t => Rabs a + norm1 t end.

(* sumsq x = x0^2 + ... + x(n-1)^2 *)
Fixpoint sumsq (x : list R) : R :=
  match x with [] => 0 | a :: t => a ^ 2 + sumsq t end.

Definition norm2 (x : list R) : R := sqrt (sumsq x).

(* norm_inf x = max |xi|, 0 for the empty vector *)
Fixpoint norm_inf (x : list R) : R :=
  match x with [] => 0 | a :: t => Rmax (Rabs a) (norm_inf t) end.

(* x without its entry k *)
Definition remove {A : Type} (k : nat) (x : list A) : list A := firstn k x ++ skipn (S k) x.

(* The entrywise sum, as long as the shorter of x and y. *)
Fixpoint add (x y : list R) : list R :=
  match x, y with a :: x', b :: y' => (a + b) :: add x' y' | _, _ => [] end.

Fixpoint dot (x y : list R) : R :=
  match x, y with a :: x', b :: y' => a * b + dot x' y' | _, _ => 0 end.

Lemma norm1_nonneg (x : list R) : 0 <= norm1 x.
Proof. induction x as [| a x IH]; simpl; [lra | pose proof (Rabs_pos a); lra]. Qed.

Lemma sumsq_nonneg (x : list R) : 0 <= sumsq x.
Proof. induction x as [| a x IH]; cbn [sumsq]; [lra | pose proof (pow2_ge_0 a); lra]. Qed.

Lemma norm2_nonneg (x : list R) : 0 <= norm2 x.
Proof. apply sqrt_pos. Qed.

Lemma norm_inf_nonneg (x : list R) : 0 <= norm_inf x.
Proof.
  induction x as [| a x IH]; simpl; [lra |].
  eapply Rle_trans; [apply Rabs_pos | apply Rmax_l].
Qed.

Lemma norm_inf_ge (x : list R) (a : R) : In a x -> Rabs a <= norm_inf x.
Proof.
  induction x as [| b x IH]; intro H; [destruct H |]. simpl.
  destruct H as [<- | H]; [apply Rmax_l |].
  eapply Rle_trans; [exact (IH H) | apply Rmax_r].
Qed.

Lemma norm2_sq (x : list R) : norm2 x * norm2 x = sumsq x.
Proof. apply sqrt_sqrt, sumsq_nonneg. Qed.

Lemma sumsq_app (x y : list R) : sumsq (x ++ y) = sumsq x + sumsq y.
Proof. induction x as [| a x IH]; cbn [sumsq app]; [ring | rewrite IH; ring]. Qed.

(* 2 d <= p + q for nonnegative p and q with d^2 <= p q. *)
Lemma two_mul_le (p q d : R) : 0 <= p -> 0 <= q -> d * d <= p * q -> 2 * d <= p + q.
Proof.
  intros Hp Hq Hd.
  destruct (Rle_dec (p + q + 2 * d) 0) as [H | H]; [lra |]. apply Rnot_le_lt in H.
  assert (H1 : 0 <= (p + q - 2 * d) * (p + q + 2 * d)).
  { replace ((p + q - 2 * d) * (p + q + 2 * d)) with ((p - q) ^ 2 + 4 * (p * q - d * d))
      by ring.
    pose proof (pow2_ge_0 (p - q)). lra. }
  destruct (Rle_dec 0 (p + q - 2 * d)) as [H2 | H2]; [lra |]. apply Rnot_le_lt in H2.
  pose proof (Rmult_lt_compat_r _ _ _ H H2). lra.
Qed.

Lemma sqrt_mul_sq (c s : R) : 0 <= s -> sqrt (c ^ 2 * s) = Rabs c * sqrt s.
Proof.
  intro Hs. rewrite sqrt_mult_alt by apply pow2_ge_0. f_equal.
  rewrite <- sqrt_Rsqr_abs. unfold Rsqr. f_equal. ring.
Qed.

Lemma remove_split {A : Type} (x : list A) (k : nat) (d : A) :
  (k < length x)%nat -> x = firstn k x ++ nth k x d :: skipn (S k) x.
Proof.
  revert k. induction x as [| a x IH]; intros k Hk; simpl in Hk; [lia |].
  destruct k as [| k]; simpl; [reflexivity |]. f_equal. apply IH. lia.
Qed.

Lemma sumsq_scale (c : R) (x : list R) :
  sumsq (map (fun a => a / c) x) = sumsq x / c ^ 2 \/ c = 0.
Proof.
  destruct (Req_dec c 0) as [-> | Hc]; [right; reflexivity | left].
  induction x as [| a x IH]; cbn [sumsq map]; [field; exact Hc |]. rewrite IH. field. exact Hc.
Qed.

(* Layer A, exact-arithmetic correctness of the scaled 2-norm of diana_norm_2: with m = |x_k|
   nonzero, m * sqrt (1 + sum over i <> k of (x_i / m)^2) is the 2-norm. *)
Theorem scale (x : list R) (k : nat) :
  (k < length x)%nat -> nth k x 0 <> 0 ->
  Rabs (nth k x 0) * sqrt (1 + sumsq (map (fun a => a / Rabs (nth k x 0)) (remove k x)))
  = norm2 x.
Proof.
  intros Hk H0. set (m := Rabs (nth k x 0)).
  assert (Hm : 0 < m) by (apply Rabs_pos_lt; exact H0).
  assert (Hx : sumsq x = nth k x 0 ^ 2 + sumsq (remove k x)).
  { rewrite (remove_split x k 0 Hk) at 1. unfold remove.
    rewrite !sumsq_app. cbn [sumsq]. ring. }
  destruct (sumsq_scale m (remove k x)) as [Hs | Hs]; [| lra].
  rewrite Hs. unfold norm2. rewrite Hx.
  rewrite <- (Rabs_pos_eq m) at 1 by lra.
  rewrite <- sqrt_mul_sq by (pose proof (sumsq_nonneg (remove k x));
    apply Rplus_le_le_0_compat; [lra | apply Rmult_le_pos; [lra |];
    left; apply Rinv_0_lt_compat; nra]).
  f_equal. replace (nth k x 0 ^ 2) with (m ^ 2)
    by (unfold m; rewrite <- (pow2_abs (nth k x 0)); reflexivity).
  field. lra.
Qed.

Lemma norm_inf_le_norm2 (x : list R) : norm_inf x <= norm2 x.
Proof.
  unfold norm2. induction x as [| a x IH]; cbn [norm_inf sumsq]; [rewrite sqrt_0; lra |].
  pose proof (sumsq_nonneg x). pose proof (pow2_ge_0 a). apply Rmax_lub.
  - rewrite <- (sqrt_pow2 (Rabs a)) by apply Rabs_pos. apply sqrt_le_1_alt.
    rewrite pow2_abs. lra.
  - eapply Rle_trans; [exact IH |]. apply sqrt_le_1_alt. lra.
Qed.

Lemma sumsq_le_norm1 (x : list R) : sumsq x <= norm1 x ^ 2.
Proof.
  induction x as [| a x IH]; cbn [sumsq norm1]; [lra |].
  pose proof (norm1_nonneg x). pose proof (Rabs_pos a).
  rewrite <- (pow2_abs a). nra.
Qed.

Lemma norm2_le_norm1 (x : list R) : norm2 x <= norm1 x.
Proof.
  unfold norm2. rewrite <- (sqrt_pow2 (norm1 x)) by apply norm1_nonneg.
  apply sqrt_le_1_alt, sumsq_le_norm1.
Qed.

Lemma norm1_le (x : list R) : norm1 x <= INR (length x) * norm_inf x.
Proof.
  induction x as [| a x IH]; cbn [length norm1 norm_inf]; [simpl; lra |].
  rewrite S_INR. pose proof (norm_inf_nonneg x). pose proof (pos_INR (length x)).
  pose proof (Rmax_l (Rabs a) (norm_inf x)). pose proof (Rmax_r (Rabs a) (norm_inf x)).
  nra.
Qed.

(* Layer A, equivalence of the three norms: |x|_inf <= |x|_2 <= |x|_1 <= n |x|_inf. *)
Theorem equiv (x : list R) :
  norm_inf x <= norm2 x /\ norm2 x <= norm1 x /\ norm1 x <= INR (length x) * norm_inf x.
Proof. split; [apply norm_inf_le_norm2 | split; [apply norm2_le_norm1 | apply norm1_le]]. Qed.

Lemma norm1_sq_le (x : list R) : norm1 x ^ 2 <= INR (length x) * sumsq x.
Proof.
  induction x as [| a x IH]; cbn [length norm1 sumsq]; [simpl; lra |].
  rewrite S_INR. pose proof (norm1_nonneg x) as HN. pose proof (sumsq_nonneg x) as HS.
  pose proof (pos_INR (length x)) as Hn. pose proof (Rabs_pos a) as Ha.
  rewrite <- (pow2_abs a).
  set (N := norm1 x) in *. set (S := sumsq x) in *. set (n := INR (length x)) in *.
  set (b := Rabs a) in *.
  assert (Hm : 2 * (b * N) <= n * b ^ 2 + S).
  { apply two_mul_le; [apply Rmult_le_pos; [lra | apply pow2_ge_0] | lra |].
    replace (b * N * (b * N)) with (b ^ 2 * N ^ 2) by ring.
    replace (n * b ^ 2 * S) with (b ^ 2 * (n * S)) by ring.
    apply Rmult_le_compat_l; [apply pow2_ge_0 | exact IH]. }
  nra.
Qed.

Lemma sumsq_le_norm_inf (x : list R) : sumsq x <= INR (length x) * norm_inf x ^ 2.
Proof.
  induction x as [| a x IH]; cbn [length sumsq norm_inf]; [simpl; lra |].
  rewrite S_INR. pose proof (norm_inf_nonneg x). pose proof (pos_INR (length x)).
  pose proof (Rabs_pos a).
  pose proof (Rmax_l (Rabs a) (norm_inf x)) as Ha. pose proof (Rmax_r (Rabs a) (norm_inf x)) as Hn.
  set (M := Rmax (Rabs a) (norm_inf x)) in *.
  assert (Ha2 : a ^ 2 <= M ^ 2) by (rewrite <- (pow2_abs a); nra).
  assert (Hn2 : norm_inf x ^ 2 <= M ^ 2) by nra.
  nra.
Qed.

(* Layer A, the Cauchy-Schwarz bounds |x|_1 <= sqrt n |x|_2 and |x|_2 <= sqrt n |x|_inf. *)
Theorem cauchy (x : list R) :
  norm1 x <= sqrt (INR (length x)) * norm2 x /\
  norm2 x <= sqrt (INR (length x)) * norm_inf x.
Proof.
  pose proof (pos_INR (length x)). pose proof (sumsq_nonneg x). split.
  - unfold norm2. rewrite <- sqrt_mult by assumption.
    rewrite <- (sqrt_pow2 (norm1 x)) by apply norm1_nonneg.
    apply sqrt_le_1_alt, norm1_sq_le.
  - unfold norm2. rewrite <- (sqrt_pow2 (norm_inf x)) by apply norm_inf_nonneg.
    rewrite <- sqrt_mult by (try assumption; apply pow2_ge_0).
    apply sqrt_le_1_alt, sumsq_le_norm_inf.
Qed.

Lemma dot_sq_le (x y : list R) : dot x y * dot x y <= sumsq x * sumsq y.
Proof.
  revert y. induction x as [| a x IH]; intro y; [cbn [dot sumsq]; lra |].
  destruct y as [| b y]; cbn [dot sumsq]; [lra |].
  - specialize (IH y). pose proof (sumsq_nonneg x). pose proof (sumsq_nonneg y).
    set (d := dot x y) in *. set (P := sumsq x) in *. set (Q := sumsq y) in *.
    assert (H2 : 2 * (a * b * d) <= a ^ 2 * Q + b ^ 2 * P).
    { apply two_mul_le; [nra | nra |].
      replace (a * b * d * (a * b * d)) with (a ^ 2 * b ^ 2 * (d * d)) by ring.
      replace (a ^ 2 * Q * (b ^ 2 * P)) with (a ^ 2 * b ^ 2 * (P * Q)) by ring.
      apply Rmult_le_compat_l; [nra | exact IH]. }
    nra.
Qed.

Lemma sumsq_add (x y : list R) :
  length x = length y -> sumsq (add x y) = sumsq x + 2 * dot x y + sumsq y.
Proof.
  revert y. induction x as [| a x IH]; intros y Hl; destruct y as [| b y];
    cbn [add sumsq dot length] in *; try discriminate; [ring |].
  rewrite IH by lia. ring.
Qed.

Lemma norm1_triangle (x y : list R) : norm1 (add x y) <= norm1 x + norm1 y.
Proof.
  revert y. induction x as [| a x IH]; intro y.
  - cbn [add norm1]. pose proof (norm1_nonneg y). lra.
  - destruct y as [| b y]; cbn [add norm1].
    + pose proof (norm1_nonneg (a :: x)). cbn [norm1] in *. lra.
    + specialize (IH y). pose proof (Rabs_triang a b). lra.
Qed.

Lemma norm_inf_triangle (x y : list R) : norm_inf (add x y) <= norm_inf x + norm_inf y.
Proof.
  revert y. induction x as [| a x IH]; intro y.
  - cbn [add norm_inf]. pose proof (norm_inf_nonneg y). lra.
  - destruct y as [| b y]; cbn [add norm_inf].
    + pose proof (norm_inf_nonneg (a :: x)). cbn [norm_inf] in *. lra.
    + specialize (IH y). apply Rmax_lub.
      * eapply Rle_trans; [apply Rabs_triang |].
        apply Rplus_le_compat; apply Rmax_l.
      * eapply Rle_trans; [exact IH |]. apply Rplus_le_compat; apply Rmax_r.
Qed.

Lemma norm2_triangle (x y : list R) :
  length x = length y -> norm2 (add x y) <= norm2 x + norm2 y.
Proof.
  intro Hl. pose proof (norm2_nonneg x) as Hx. pose proof (norm2_nonneg y) as Hy.
  unfold norm2 at 1. rewrite <- (sqrt_pow2 (norm2 x + norm2 y)) by lra.
  apply sqrt_le_1_alt. rewrite sumsq_add by exact Hl.
  pose proof (norm2_sq x) as Sx. pose proof (norm2_sq y) as Sy.
  pose proof (dot_sq_le x y) as Hc.
  assert (Hd : dot x y <= norm2 x * norm2 y).
  { destruct (Rle_dec (dot x y) 0) as [Hn | Hn].
    - pose proof (Rmult_le_pos _ _ Hx Hy). lra.
    - apply Rsqr_incr_0_var; [unfold Rsqr | apply Rmult_le_pos; assumption].
      rewrite <- Sx, <- Sy in Hc. nra. }
  rewrite <- Sx, <- Sy. nra.
Qed.

(* Layer A, the triangle inequality of each norm for vectors of equal length. *)
Theorem triangle (x y : list R) :
  length x = length y ->
  norm1 (add x y) <= norm1 x + norm1 y /\ norm2 (add x y) <= norm2 x + norm2 y /\
  norm_inf (add x y) <= norm_inf x + norm_inf y.
Proof.
  intro Hl. split; [apply norm1_triangle |].
  split; [apply norm2_triangle; exact Hl | apply norm_inf_triangle].
Qed.

(* Layer A, absolute homogeneity of each norm. *)
Theorem homogeneous (c : R) (x : list R) :
  norm1 (map (Rmult c) x) = Rabs c * norm1 x /\ norm2 (map (Rmult c) x) = Rabs c * norm2 x /\
  norm_inf (map (Rmult c) x) = Rabs c * norm_inf x.
Proof.
  split; [| split].
  - induction x as [| a x IH]; simpl; [ring | rewrite IH, Rabs_mult; ring].
  - unfold norm2. rewrite <- sqrt_mul_sq by apply sumsq_nonneg. f_equal.
    induction x as [| a x IH]; cbn [sumsq map]; [ring | rewrite IH; ring].
  - induction x as [| a x IH]; simpl; [ring |].
    rewrite IH, Rabs_mult. apply RmaxRmult. apply Rabs_pos.
Qed.

Lemma abs_zero (a : R) : Rabs a = 0 -> a = 0.
Proof.
  intro H. destruct (Req_dec a 0) as [E | E]; [exact E |].
  exfalso. exact (Rabs_no_R0 a E H).
Qed.

Lemma sumsq_zero (x : list R) : sumsq x = 0 <-> Forall (fun a => a = 0) x.
Proof.
  induction x as [| a x IH]; cbn [sumsq]; [split; [constructor | reflexivity] |].
  pose proof (sumsq_nonneg x) as Hs. pose proof (pow2_ge_0 a) as Ha. split.
  - intro E. constructor; [| apply IH; lra].
    apply Rsqr_0_uniq. unfold Rsqr. replace (a * a) with (a ^ 2) by ring. lra.
  - intro E. inversion E as [| ? ? E0 E1]. subst a. rewrite (proj2 IH E1). ring.
Qed.

(* Layer A, each norm vanishes exactly on the zero vector. *)
Theorem definite (x : list R) :
  (norm1 x = 0 <-> Forall (fun a => a = 0) x) /\
  (norm2 x = 0 <-> Forall (fun a => a = 0) x) /\
  (norm_inf x = 0 <-> Forall (fun a => a = 0) x).
Proof.
  split; [| split].
  - induction x as [| a x IH]; cbn [norm1]; [split; [constructor | reflexivity] |].
    pose proof (norm1_nonneg x) as Hn. pose proof (Rabs_pos a) as Ha. split.
    + intro E. constructor; [apply abs_zero; lra | apply IH; lra].
    + intro E. inversion E as [| ? ? E0 E1]. subst a.
      rewrite (proj2 IH E1), Rabs_R0. ring.
  - unfold norm2. rewrite <- sumsq_zero. pose proof (sumsq_nonneg x) as Hs. split; intro E.
    + apply sqrt_eq_0; assumption.
    + rewrite E. apply sqrt_0.
  - induction x as [| a x IH]; cbn [norm_inf]; [split; [constructor | reflexivity] |].
    pose proof (norm_inf_nonneg x) as Hn. pose proof (Rabs_pos a) as Ha. split.
    + intro E. pose proof (Rmax_l (Rabs a) (norm_inf x)).
      pose proof (Rmax_r (Rabs a) (norm_inf x)).
      constructor; [apply abs_zero; lra | apply IH; lra].
    + intro E. inversion E as [| ? ? E0 E1]. subst a.
      rewrite (proj2 IH E1), Rabs_R0. apply Rmax_left. lra.
Qed.
