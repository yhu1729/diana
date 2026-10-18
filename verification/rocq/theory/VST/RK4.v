From VST.floyd Require Import proofauto.
From Diana.Float Require Euler RK4 Trapezoidal.
From Diana.VST Require Euler.

Definition c_half : float := Float.of_bits (Int64.repr 4602678819172646912).
Definition c_two : float := Float.of_bits (Int64.repr 4611686018427387904).
Definition c_six : float := Float.of_bits (Int64.repr 4618441417868443648).

Lemma c_half_eq : c_half = Diana.Float.Trapezoidal.half.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_two_eq : c_two = Diana.Float.RK4.two.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_six_eq : c_six = Diana.Float.RK4.six.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Definition c_coef (s : Z) (h : float) : float := if Z.eqb s 4 then h else Float.mul c_half h.

Definition c_stage (s : Z) (h : float) (ys ks : list float) : list float :=
  Diana.VST.Euler.c_euler (c_coef s h) ys ks.

Definition stage_status (s : Z) (h : float) (ys ks : list float) : Z :=
  if forallb (Binary.is_finite 53 1024) (c_stage s h ys ks) then 0
  else if (Binary.is_finite 53 1024 h && forallb (Binary.is_finite 53 1024) ys &&
           forallb (Binary.is_finite 53 1024) ks)%bool
  then -5 else -1.

Lemma c_stage_model (s : Z) (h : float) (ys ks : list float) :
  c_stage s h ys ks = Diana.Float.RK4.frk4_stage Float.binop_nan Float.binop_nan s h ys ks.
Proof.
  unfold c_stage, Diana.Float.RK4.frk4_stage. rewrite Diana.VST.Euler.c_euler_model.
  f_equal. unfold c_coef, Diana.Float.RK4.coef. rewrite c_half_eq. reflexivity.
Qed.

Definition c_step (h y a b c e : float) : float :=
  Float.add y (Float.div (Float.mul h (Float.add (Float.add a e) (Float.mul c_two (Float.add b c))))
                 c_six).

Fixpoint c_rk4 (h : float) (ys k1s k2s k3s k4s : list float) : list float :=
  match ys, k1s, k2s, k3s, k4s with
  | y :: ys', a :: k1s', b :: k2s', c :: k3s', e :: k4s' =>
      c_step h y a b c e :: c_rk4 h ys' k1s' k2s' k3s' k4s'
  | _, _, _, _, _ => nil
  end.

Definition rk4_status (h : float) (ys k1s k2s k3s k4s : list float) : Z :=
  if forallb (Binary.is_finite 53 1024) (c_rk4 h ys k1s k2s k3s k4s) then 0
  else if (Binary.is_finite 53 1024 h && forallb (Binary.is_finite 53 1024) ys &&
           forallb (Binary.is_finite 53 1024) k1s && forallb (Binary.is_finite 53 1024) k2s &&
           forallb (Binary.is_finite 53 1024) k3s && forallb (Binary.is_finite 53 1024) k4s)%bool
  then -5 else -1.

Lemma c_rk4_model (h : float) (ys k1s k2s k3s k4s : list float) :
  c_rk4 h ys k1s k2s k3s k4s =
  Diana.Float.RK4.frk4_step Float.binop_nan Float.binop_nan Float.binop_nan h ys k1s k2s k3s k4s.
Proof.
  revert k1s k2s k3s k4s.
  induction ys as [| y ys IH]; intros [| a k1s] [| b k2s] [| c k3s] [| e k4s]; try reflexivity.
  cbn [c_rk4 Diana.Float.RK4.frk4_step]. f_equal; [| apply IH].
  unfold c_step, Diana.Float.RK4.fstep, Diana.Float.RK4.fslope.
  rewrite c_two_eq, c_six_eq. reflexivity.
Qed.

Lemma Zlength_c_rk4 (h : float) (ys k1s k2s k3s k4s : list float) :
  Zlength k1s = Zlength ys -> Zlength k2s = Zlength ys -> Zlength k3s = Zlength ys ->
  Zlength k4s = Zlength ys -> Zlength (c_rk4 h ys k1s k2s k3s k4s) = Zlength ys.
Proof.
  revert k1s k2s k3s k4s.
  induction ys as [| y ys IH]; intros k1s k2s k3s k4s H1 H2 H3 H4; [reflexivity |].
  pose proof (Zlength_nonneg ys).
  destruct k1s as [| a k1s]; [rewrite Zlength_nil, Zlength_cons in H1; lia |].
  destruct k2s as [| b k2s]; [rewrite Zlength_nil, Zlength_cons in H2; lia |].
  destruct k3s as [| c k3s]; [rewrite Zlength_nil, Zlength_cons in H3; lia |].
  destruct k4s as [| e k4s]; [rewrite Zlength_nil, Zlength_cons in H4; lia |].
  rewrite !Zlength_cons in *. cbn [c_rk4]. rewrite Zlength_cons, IH by lia. reflexivity.
Qed.

Lemma Znth_c_rk4 (h : float) (ys k1s k2s k3s k4s : list float) (i : Z) :
  Zlength k1s = Zlength ys -> Zlength k2s = Zlength ys -> Zlength k3s = Zlength ys ->
  Zlength k4s = Zlength ys -> 0 <= i < Zlength ys ->
  Znth i (c_rk4 h ys k1s k2s k3s k4s) =
  c_step h (Znth i ys) (Znth i k1s) (Znth i k2s) (Znth i k3s) (Znth i k4s).
Proof.
  revert k1s k2s k3s k4s i.
  induction ys as [| y ys IH]; intros k1s k2s k3s k4s i H1 H2 H3 H4 Hi.
  { rewrite Zlength_nil in Hi. lia. }
  pose proof (Zlength_nonneg ys).
  destruct k1s as [| a k1s]; [rewrite Zlength_nil, Zlength_cons in H1; lia |].
  destruct k2s as [| b k2s]; [rewrite Zlength_nil, Zlength_cons in H2; lia |].
  destruct k3s as [| c k3s]; [rewrite Zlength_nil, Zlength_cons in H3; lia |].
  destruct k4s as [| e k4s]; [rewrite Zlength_nil, Zlength_cons in H4; lia |].
  rewrite !Zlength_cons in *. cbn [c_rk4].
  destruct (Z.eq_dec i 0) as [-> | Hne].
  - rewrite !Znth_0_cons. reflexivity.
  - rewrite !Znth_pos_cons by lia. apply IH; lia.
Qed.
