From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Float Require Euler.
Open Scope R_scope.

Section Model.

Variable plus_nan mult_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).
Local Abbreviation rnd x := (round radix2 fexp ZnearestE x).
Local Abbreviation fstep := (Diana.Float.Euler.fstep plus_nan mult_nan).

Theorem finite_iff (h y f : b64) :
  fin (fstep h y f) <->
  fin h /\ fin y /\ fin f /\ Rabs (rnd (r h * r f)) < bpow radix2 emax /\
  Rabs (rnd (r y + rnd (r h * r f))) < bpow radix2 emax.
Proof.
  split.
  - intro H. destruct (Diana.Float.Euler.finite_result _ _ _ _ _ H) as [Hh [Hy [Hf Hm]]].
    destruct (fmul_value _ _ Hm) as [_ [_ Hvm]].
    unfold Diana.Float.Euler.fstep in H.
    repeat split; try assumption.
    + exact (proj1 (fmul_finite_iff h f Hh Hf) Hm).
    + rewrite <- Hvm. exact (proj1 (fadd_finite_iff y _ Hy Hm) H).
  - intros [Hh [Hy [Hf [Hp Hs]]]].
    assert (Hm : fin (Diana.Float.Sum.fmul mult_nan h f))
      by exact (proj2 (fmul_finite_iff h f Hh Hf) Hp).
    destruct (fmul_value _ _ Hm) as [_ [_ Hvm]].
    unfold Diana.Float.Euler.fstep.
    apply (proj2 (fadd_finite_iff y _ Hy Hm)). rewrite Hvm. exact Hs.
Qed.

End Model.
