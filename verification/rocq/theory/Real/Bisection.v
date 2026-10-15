From Stdlib Require Import Reals Lra Psatz Ranalysis5.
Open Scope R_scope.

Definition sgn_pos (x : R) : bool := if Rlt_dec 0 x then true else false.

Definition step (f : R -> R) (p : R * R) : R * R :=
  let m := (fst p + snd p) / 2 in
  if Req_dec_T (f m) 0 then (m, m)
  else if Bool.eqb (sgn_pos (f m)) (sgn_pos (f (fst p))) then (m, snd p) else (fst p, m).

Fixpoint iter (f : R -> R) (a b : R) (n : nat) : R * R :=
  match n with
  | O => (a, b)
  | S k => step f (iter f a b k)
  end.

Definition SignChange (f : R -> R) (a b : R) : Prop :=
  f a * f b < 0 \/ (a = b /\ f a = 0).

Definition Bracket (f : R -> R) (p : R * R) : Prop :=
  fst p <= snd p /\ SignChange f (fst p) (snd p).

Lemma sgn_pos_true x : sgn_pos x = true <-> 0 < x.
Proof. unfold sgn_pos; destruct (Rlt_dec 0 x); split; auto; discriminate. Qed.

Lemma sgn_pos_false x : sgn_pos x = false <-> x <= 0.
Proof. unfold sgn_pos; destruct (Rlt_dec 0 x); split; intro; try discriminate; lra. Qed.

Lemma step_le f p : fst p <= snd p -> fst (step f p) <= snd (step f p).
Proof.
  intro; unfold step; destruct (Req_dec_T _ _); [simpl; lra |].
  destruct (Bool.eqb _ _); simpl; lra.
Qed.

Lemma step_nested f p : fst p <= snd p -> fst p <= fst (step f p) /\ snd (step f p) <= snd p.
Proof.
  intro; unfold step; destruct (Req_dec_T _ _); [simpl; lra |].
  destruct (Bool.eqb _ _); simpl; lra.
Qed.

Lemma step_width f p : fst p <= snd p -> snd (step f p) - fst (step f p) <= (snd p - fst p) / 2.
Proof.
  intro; unfold step; destruct (Req_dec_T _ _); [simpl; lra |].
  destruct (Bool.eqb _ _); simpl; lra.
Qed.

Lemma step_bracket f p : Bracket f p -> Bracket f (step f p).
Proof.
  intros [Hle Hs]. unfold step. set (m := (fst p + snd p) / 2).
  assert (Hm1 : fst p <= m) by (unfold m; lra).
  assert (Hm2 : m <= snd p) by (unfold m; lra).
  destruct (Req_dec_T (f m) 0) as [H0 | H0].
  { unfold Bracket, SignChange; simpl; split; [lra | right; auto]. }
  destruct Hs as [Hs | [Heq Hfa]].
  2: { exfalso. apply H0. unfold m. rewrite <- Heq.
       replace ((fst p + fst p) / 2) with (fst p) by lra. exact Hfa. }
  assert (Hfa0 : f (fst p) <> 0) by (intro E; rewrite E in Hs; lra).
  destruct (Bool.eqb (sgn_pos (f m)) (sgn_pos (f (fst p)))) eqn:E;
    unfold Bracket, SignChange; simpl; split; try assumption; left.
  - apply Bool.eqb_prop in E.
    destruct (sgn_pos (f m)) eqn:Em; symmetry in E.
    + apply sgn_pos_true in Em. apply sgn_pos_true in E.
      assert (f (snd p) < 0) by (destruct (Rlt_dec (f (snd p)) 0); [assumption | nra]).
      nra.
    + apply sgn_pos_false in Em. apply sgn_pos_false in E.
      assert (f m < 0) by lra. assert (f (fst p) < 0) by lra.
      assert (0 < f (snd p)) by (destruct (Rlt_dec 0 (f (snd p))); [assumption | nra]).
      nra.
  - apply Bool.eqb_false_iff in E.
    destruct (sgn_pos (f m)) eqn:Em; destruct (sgn_pos (f (fst p))) eqn:Ea; try congruence.
    + apply sgn_pos_true in Em. apply sgn_pos_false in Ea.
      assert (f (fst p) < 0) by lra. nra.
    + apply sgn_pos_false in Em. apply sgn_pos_true in Ea.
      assert (f m < 0) by lra. nra.
Qed.

Lemma iter_le_sub f a b n :
  a <= b ->
  a <= fst (iter f a b n) /\ fst (iter f a b n) <= snd (iter f a b n) /\ snd (iter f a b n) <= b.
Proof.
  intro; induction n as [| n [H1 [H2 H3]]]; simpl; [lra |].
  pose proof (step_nested f _ H2). pose proof (step_le f _ H2). lra.
Qed.

Theorem bracket_width f a b n :
  a <= b -> SignChange f a b ->
  Bracket f (iter f a b n) /\ snd (iter f a b n) - fst (iter f a b n) <= (b - a) / 2 ^ n.
Proof.
  intros Hab Hs. induction n as [| n [Hb Hw]]; simpl.
  - split; [split; simpl; auto | lra].
  - split; [apply step_bracket; exact Hb |].
    pose proof (step_width f _ (proj1 Hb)).
    assert (H2n : 2 ^ n <> 0) by (apply pow_nonzero; lra).
    assert (E : (b - a) / (2 * 2 ^ n) = (b - a) / 2 ^ n / 2) by (field; exact H2n).
    rewrite E. lra.
Qed.

Theorem converge f a b n :
  a <= b ->
  (forall x, a <= x <= b -> continuity_pt f x) ->
  SignChange f a b ->
  exists x, fst (iter f a b n) <= x <= snd (iter f a b n) /\ f x = 0 /\
    Rabs ((fst (iter f a b n) + snd (iter f a b n)) / 2 - x) <= (b - a) / 2 ^ S n.
Proof.
  intros Hab Hf Hs.
  destruct (bracket_width f a b n Hab Hs) as [[Hle Hb] Hw].
  destruct (iter_le_sub f a b n Hab) as [Ha [_ Hb']].
  set (p := iter f a b n) in *.
  assert (Hroot : exists x, fst p <= x <= snd p /\ f x = 0).
  { destruct Hb as [Hb | [Heq H0]].
    - assert (Hlt : fst p < snd p).
      { destruct (Rlt_dec (fst p) (snd p)); [assumption |].
        assert (E : fst p = snd p) by lra. rewrite E in Hb. nra. }
      assert (Hc : forall x, fst p <= x <= snd p -> continuity_pt f x)
        by (intros x Hx; apply Hf; lra).
      destruct (Rlt_dec (f (fst p)) 0) as [Hneg | Hnneg].
      + assert (Hpos : 0 < f (snd p)) by nra.
        destruct (IVT_interv f (fst p) (snd p) Hc Hlt Hneg Hpos) as [x [Hx Hfx]].
        exists x; auto.
      + assert (Hpos : 0 < f (fst p)).
        { assert (f (fst p) <> 0) by (intro E; rewrite E in Hb; lra). lra. }
        assert (Hneg : f (snd p) < 0) by nra.
        assert (Hc' : forall x, fst p <= x <= snd p -> continuity_pt (fun y => - f y) x)
          by (intros x Hx; apply continuity_pt_opp; auto).
        destruct (IVT_interv (fun y => - f y) (fst p) (snd p) Hc' Hlt
                    ltac:(simpl; lra) ltac:(simpl; lra)) as [x [Hx Hfx]].
        exists x; split; [exact Hx | lra].
    - exists (fst p). split; [lra | exact H0]. }
  destruct Hroot as [x [Hx Hfx]].
  exists x. split; [exact Hx | split; [exact Hfx |]].
  assert (H2n : 2 ^ n <> 0) by (apply pow_nonzero; lra).
  assert (E : (b - a) / 2 ^ S n = (b - a) / 2 ^ n / 2)
    by (replace (2 ^ S n) with (2 * 2 ^ n) by (simpl; ring); field; exact H2n).
  rewrite E. apply Rabs_le. lra.
Qed.
