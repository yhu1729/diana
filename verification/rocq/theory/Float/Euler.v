From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
Import ListNotations.
Open Scope R_scope.

Section Model.

Variable plus_nan mult_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fadd := (Diana.Float.Sum.fadd plus_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

Definition fstep (h y f : b64) : b64 := fadd y (fmul h f).

Definition feuler (h : b64) (ys fs : list b64) : list b64 :=
  map (fun p => fstep h (fst p) (snd p)) (combine ys fs).

Theorem finite_result (h y f : b64) :
  fin (fstep h y f) -> fin h /\ fin y /\ fin f /\ fin (fmul h f).
Proof.
  intro H. unfold fstep in H.
  destruct (fadd_finite_inv _ _ H) as [Hy Hm].
  destruct (fmul_value _ _ Hm) as [Hh [Hf _]].
  repeat split; assumption.
Qed.

Theorem forward_error (h y f : b64) :
  fin (fstep h y f) ->
  Rabs (r (fstep h y f) - (r y + r h * r f))
    <= u * Rabs (r y + r h * r f) + (1 + u) * (u * Rabs (r h * r f) + eta).
Proof.
  intro H. unfold fstep in H |- *.
  destruct (fadd_finite_inv _ _ H) as [Hy Hm].
  destruct (fmul_value _ _ Hm) as [_ [_ Hvm]].
  rewrite (fadd_value _ _ H).
  destruct (add_error (r y) (r (fmul h f)) (generic_format_B2R prec emax y)
              (generic_format_B2R prec emax _)) as [e2 [He2 Hr2]].
  rewrite Hr2.
  destruct (round_error (r h * r f)) as [e1 [d1 [He1 [Hd1 Hr1]]]].
  rewrite Hvm, Hr1 in *.
  pose proof u_pos as Hu. pose proof eta_pos as Heta.
  set (p := r h * r f) in *.
  set (m := p * (1 + e1) + d1) in *.
  assert (Hmp : Rabs (m - p) <= u * Rabs p + eta).
  { unfold m. replace (p * (1 + e1) + d1 - p) with (e1 * p + d1) by ring.
    eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult.
    assert (Rabs e1 * Rabs p <= u * Rabs p)
      by (apply Rmult_le_compat_r; [apply Rabs_pos | exact He1]).
    lra. }
  replace ((r y + m) * (1 + e2) - (r y + p)) with ((m - p) * (1 + e2) + e2 * (r y + p))
    by ring.
  eapply Rle_trans; [apply Rabs_triang |]. rewrite !Rabs_mult.
  assert (H1e : Rabs (1 + e2) <= 1 + u).
  { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_R1. lra. }
  assert (T1 : Rabs (m - p) * Rabs (1 + e2) <= (u * Rabs p + eta) * (1 + u))
    by (apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | exact Hmp | exact H1e]).
  assert (T2 : Rabs e2 * Rabs (r y + p) <= u * Rabs (r y + p))
    by (apply Rmult_le_compat_r; [apply Rabs_pos | exact He2]).
  lra.
Qed.

End Model.
