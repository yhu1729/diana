From VST.floyd Require Import proofauto.

Ltac join_zero t :=
  lazymatch goal with
  | |- semax _ (PROPx _ (LOCALx ?Q (SEPx ?R))) _ _ =>
      forward_if (PROPx [] (LOCALx (temp t (Vint Int.zero) :: Q) (SEPx R)))
  end.
