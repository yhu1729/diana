From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum Euler.
Import ListNotations.
Open Scope R_scope.

Section Model.

Variable plus_nan mult_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fadd := (Diana.Float.Sum.fadd plus_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

(* One component in the C's order, y + a * x: the Euler step fstep with a as the step size, y
   as the state and x as the slope. *)
Definition fupdate (a x y : b64) : b64 := fadd y (fmul a x).

Definition faxpy (a : b64) (xs ys : list b64) : list b64 :=
  map (fun p => fupdate a (fst p) (snd p)) (combine xs ys).

Lemma fupdate_fstep (a x y : b64) :
  fupdate a x y = Diana.Float.Euler.fstep plus_nan mult_nan a y x.
Proof. reflexivity. Qed.

Theorem finite_result (a x y : b64) :
  fin (fupdate a x y) -> fin a /\ fin x /\ fin y /\ fin (fmul a x).
Proof.
  intro H. rewrite fupdate_fstep in H.
  destruct (Diana.Float.Euler.finite_result plus_nan mult_nan a y x H) as [Ha [Hy [Hx Hm]]].
  auto.
Qed.

Theorem forward_error (a x y : b64) :
  fin (fupdate a x y) ->
  Rabs (r (fupdate a x y) - (r a * r x + r y))
    <= u * Rabs (r a * r x + r y) + (1 + u) * (u * Rabs (r a * r x) + eta).
Proof.
  intro H. rewrite fupdate_fstep in H |- *.
  rewrite (Rplus_comm (r a * r x) (r y)).
  exact (Diana.Float.Euler.forward_error plus_nan mult_nan a y x H).
Qed.

End Model.
