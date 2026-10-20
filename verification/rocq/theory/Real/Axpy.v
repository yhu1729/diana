From Stdlib Require Import Reals Lra Lia List.
From Diana.Real Require Import Norm.
Import ListNotations.
Open Scope R_scope.

(* axpy a x y = a x + y entrywise, as long as the shorter of x and y, the exact value of
   diana_axpy. *)
Definition axpy (a : R) (x y : list R) : list R := add (map (Rmult a) x) y.

Lemma axpy_zero (x y : list R) : length x = length y -> axpy 0 x y = y.
Proof.
  revert y. induction x as [| p x IH]; intros [| q y] Hl; try discriminate; [reflexivity |].
  unfold axpy in *. cbn [map add]. rewrite IH by (simpl in Hl; lia). f_equal. ring.
Qed.

(* Layer A, the update is bounded in each norm: |a x + y| <= |a| |x| + |y|. *)
Theorem bound (a : R) (x y : list R) :
  length x = length y ->
  norm1 (axpy a x y) <= Rabs a * norm1 x + norm1 y /\
  norm2 (axpy a x y) <= Rabs a * norm2 x + norm2 y /\
  norm_inf (axpy a x y) <= Rabs a * norm_inf x + norm_inf y.
Proof.
  intro Hl. unfold axpy.
  assert (Hl' : length (map (Rmult a) x) = length y) by (rewrite length_map; exact Hl).
  destruct (triangle (map (Rmult a) x) y Hl') as [H1 [H2 H3]].
  destruct (homogeneous a x) as [E1 [E2 E3]].
  rewrite E1 in H1. rewrite E2 in H2. rewrite E3 in H3. auto.
Qed.

(* Layer A, two updates along the same x compose: axpy a x (axpy b x y) = axpy (a + b) x y. *)
Theorem compose (a b : R) (x y : list R) : axpy a x (axpy b x y) = axpy (a + b) x y.
Proof.
  unfold axpy. revert y. induction x as [| p x IH]; intros [| q y]; try reflexivity.
  cbn [map add]. rewrite IH. f_equal. ring.
Qed.

(* Layer A, a zero coefficient leaves y, so the update by -a undoes the update by a. *)
Theorem inverse (a : R) (x y : list R) :
  length x = length y -> axpy 0 x y = y /\ axpy (- a) x (axpy a x y) = y.
Proof.
  intro Hl. split; [apply axpy_zero; exact Hl |].
  rewrite compose. replace (- a + a) with 0 by ring. apply axpy_zero. exact Hl.
Qed.
