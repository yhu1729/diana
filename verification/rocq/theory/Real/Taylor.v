From Stdlib Require Import Reals Lra Lia Psatz Factorial.
From Coquelicot Require Import Coquelicot.
From Diana.Real Require Import Quadrature.
Open Scope R_scope.

Lemma der_val (f : R -> R) (x l l' : R) : l = l' -> is_derive f x l -> is_derive f x l'.
Proof. intros <- H. exact H. Qed.

Lemma der_const (c x : R) : is_derive (fun _ => c) x 0.
Proof. exact (is_derive_const c x). Qed.

Lemma der_id (x : R) : is_derive (fun t => t) x 1.
Proof. exact (is_derive_id x). Qed.

Lemma der_add (f g : R -> R) (x a b : R) :
  is_derive f x a -> is_derive g x b -> is_derive (fun t => f t + g t) x (a + b).
Proof. exact (is_derive_plus f g x a b). Qed.

Lemma der_sub (f g : R -> R) (x a b : R) :
  is_derive f x a -> is_derive g x b -> is_derive (fun t => f t - g t) x (a - b).
Proof. exact (is_derive_minus f g x a b). Qed.

Lemma der_scal (f : R -> R) (k x a : R) :
  is_derive f x a -> is_derive (fun t => k * f t) x (k * a).
Proof. exact (is_derive_scal f x k a). Qed.

Lemma der_mul (f g : R -> R) (x a b : R) :
  is_derive f x a -> is_derive g x b -> is_derive (fun t => f t * g t) x (a * g x + f x * b).
Proof. exact (Derive.is_derive_mult f g x a b). Qed.

Lemma fact_pos_R (n : nat) : 0 < INR (fact n).
Proof. apply lt_0_INR, lt_O_fact. Qed.

Lemma der_mono (k a x : R) (n : nat) :
  is_derive (fun y => k * (y - a) ^ S n / INR (fact (S n))) x (k * (x - a) ^ n / INR (fact n)).
Proof.
  pose proof (fact_pos_R n) as Hn.
  pose proof (fact_pos_R (S n)) as Hn1.
  apply (is_derive_ext (fun y => k / INR (fact (S n)) * (y - a) ^ S n));
    [intro t; change (k / INR (fact (S n)) * (t - a) ^ S n = k * (t - a) ^ S n / INR (fact (S n)));
     field; apply Rgt_not_eq; exact Hn1 |].
  apply (der_val _ _ (k / INR (fact (S n)) * (INR (S n) * (1 - 0) * (x - a) ^ pred (S n)))).
  - rewrite fact_simpl, mult_INR. simpl pred.
    assert (0 < INR (S n)) by (apply lt_0_INR; lia). field. lra.
  - apply der_scal. apply (is_derive_pow (fun y => y - a)).
    apply (der_sub (fun y => y) (fun _ => a)); [apply der_id | apply der_const].
Qed.

Fixpoint poly (c : nat -> R) (a x : R) (n : nat) : R :=
  match n with
  | O => 0
  | S n' => poly c a x n' + c n' * (x - a) ^ n' / INR (fact n')
  end.

Lemma poly_self (c : nat -> R) (a : R) (n : nat) : poly c a a (S n) = c 0%nat.
Proof.
  induction n as [| n IH].
  - simpl. field.
  - change (poly c a a (S (S n)))
      with (poly c a a (S n) + c (S n) * (a - a) ^ S n / INR (fact (S n))).
    rewrite IH. replace (a - a) with 0 by ring. rewrite pow_i by lia.
    pose proof (fact_pos_R (S n)). field. lra.
Qed.

Lemma poly_derive (c : nat -> R) (a x : R) (n : nat) :
  is_derive (fun x => poly c a x (S n)) x (poly (fun j => c (S j)) a x n).
Proof.
  induction n as [| n IH].
  - simpl. apply (is_derive_ext (fun _ => c 0%nat)); [intro t; simpl; field |].
    apply der_const.
  - change (poly (fun j => c (S j)) a x (S n))
      with (poly (fun j => c (S j)) a x n + c (S n) * (x - a) ^ n / INR (fact n)).
    apply (der_add (fun x => poly c a x (S n))
             (fun x => c (S n) * (x - a) ^ S n / INR (fact (S n)))); [exact IH |].
    apply der_mono.
Qed.

Theorem taylor_bound (f : nat -> R -> R) (a b M : R) (n : nat) :
  (forall j, (j < n)%nat -> forall x, a <= x <= b -> is_derive (f j) x (f (S j) x)) ->
  (forall x, a <= x <= b -> Rabs (f n x - f n a) <= M * (x - a)) ->
  forall x, a <= x <= b ->
  Rabs (f 0%nat x - poly (fun j => f j a) a x (S n)) <= M * (x - a) ^ S n / INR (fact (S n)).
Proof.
  revert f. induction n as [| n IH]; intros f Hf HM x Hx.
  - simpl. replace (f 0%nat x - (0 + f 0%nat a * 1 / 1)) with (f 0%nat x - f 0%nat a) by field.
    replace (M * ((x - a) * 1) / 1) with (M * (x - a)) by field. exact (HM x Hx).
  - assert (IH' := IH (fun j => f (S j)) (fun j Hj y Hy => Hf (S j) ltac:(lia) y Hy) HM).
    cbv beta in IH'.
    pose proof (fact_pos_R (S (S n))) as Hn2.
    apply (bound_of_derive (fun y => f 0%nat y - poly (fun j => f j a) a y (S (S n)))
             (fun y => f 1%nat y - poly (fun j => f (S j) a) a y (S n))
             (fun y => M * (y - a) ^ S (S n) / INR (fact (S (S n))))
             (fun y => M * (y - a) ^ S n / INR (fact (S n))) a x).
    + lra.
    + intros t Ht.
      apply (der_sub (f 0%nat) (fun y => poly (fun j => f j a) a y (S (S n)))).
      * exact (Hf 0%nat ltac:(lia) t ltac:(lra)).
      * exact (poly_derive (fun j => f j a) a t (S n)).
    + intros t _. apply der_mono.
    + intros t Ht. exact (IH' t ltac:(lra)).
    + rewrite poly_self. replace (f 0%nat a - f 0%nat a) with 0 by ring.
      replace (a - a) with 0 by ring. rewrite pow_i by lia. rewrite Rabs_R0. right. field. lra.
Qed.
