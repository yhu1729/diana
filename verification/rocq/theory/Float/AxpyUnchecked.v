From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Float Require Axpy EulerUnchecked.
Open Scope R_scope.

Section Model.

Variable plus_nan mult_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).
Local Abbreviation rnd x := (round radix2 fexp ZnearestE x).
Local Abbreviation fupdate := (Diana.Float.Axpy.fupdate plus_nan mult_nan).

Theorem finite_iff (a x y : b64) :
  fin (fupdate a x y) <->
  fin a /\ fin x /\ fin y /\ Rabs (rnd (r a * r x)) < bpow radix2 emax /\
  Rabs (rnd (r y + rnd (r a * r x))) < bpow radix2 emax.
Proof.
  rewrite Diana.Float.Axpy.fupdate_fstep.
  rewrite (Diana.Float.EulerUnchecked.finite_iff plus_nan mult_nan a y x).
  tauto.
Qed.

End Model.
