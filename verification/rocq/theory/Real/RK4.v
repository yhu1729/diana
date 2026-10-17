From Stdlib Require Import Reals Lra Lia Psatz Factorial FunctionalExtensionality.
From Coquelicot Require Import Coquelicot.
From Diana.Real Require Import Quadrature Vector OneStep Taylor.
Open Scope R_scope.

Definition slope1 (F : R -> (nat -> R) -> nat -> R) (t : R) (y : nat -> R) : nat -> R :=
  F t y.

Definition slope2 (F : R -> (nat -> R) -> nat -> R) (t : R) (y : nat -> R) (h : R)
  : nat -> R := F (t + h / 2) (fun i => y i + h / 2 * slope1 F t y i).

Definition slope3 (F : R -> (nat -> R) -> nat -> R) (t : R) (y : nat -> R) (h : R)
  : nat -> R := F (t + h / 2) (fun i => y i + h / 2 * slope2 F t y h i).

Definition slope4 (F : R -> (nat -> R) -> nat -> R) (t : R) (y : nat -> R) (h : R)
  : nat -> R := F (t + h) (fun i => y i + h * slope3 F t y h i).

Definition incT (F : R -> (nat -> R) -> nat -> R) (t : R) (y : nat -> R) (h : R)
  : nat -> R :=
  fun i => / 6 * (slope1 F t y i + 2 * slope2 F t y h i + 2 * slope3 F t y h i
                  + slope4 F t y h i).

Definition rk4 (F : R -> (nat -> R) -> nat -> R) (t0 h : R) (y0 : nat -> R) (k : nat)
  : nat -> R := iterate (fun t y => incT F t y h) t0 h y0 k.

Definition inc (G : (nat -> R) -> nat -> R) (y : nat -> R) (h : R) : nat -> R :=
  incT (fun _ => G) 0 y h.

Lemma vnorm_step (d : nat) (y z a b : nat -> R) (c : R) :
  0 <= c ->
  vnorm d (fun i => (y i + c * a i) - (z i + c * b i))
    <= vnorm d (fun i => y i - z i) + c * vnorm d (fun i => a i - b i).
Proof.
  intro Hc. pose proof (vnorm_nonneg d (fun i => y i - z i)).
  pose proof (vnorm_nonneg d (fun i => a i - b i)).
  apply vnorm_le; [nra |]. intros i Hi.
  pose proof (vnorm_ge d (fun i => y i - z i) i Hi) as A1.
  pose proof (vnorm_ge d (fun i => a i - b i) i Hi) as A2. cbv beta in A1, A2.
  replace (y i + c * a i - (z i + c * b i)) with ((y i - z i) + c * (a i - b i)) by ring.
  eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult, (Rabs_pos_eq c) by lra.
  assert (c * Rabs (a i - b i) <= c * vnorm d (fun i => a i - b i))
    by (apply Rmult_le_compat_l; lra).
  lra.
Qed.

Theorem lipschitz (d : nat) (F : R -> (nat -> R) -> nat -> R) (t h L : R) :
  0 <= h -> 0 <= L ->
  (forall s, t <= s <= t + h -> forall y z,
     vnorm d (fun i => F s y i - F s z i) <= L * vnorm d (fun i => y i - z i)) ->
  forall y z,
  vnorm d (fun i => incT F t y h i - incT F t z h i)
    <= L * (1 + h * L / 2 + (h * L) ^ 2 / 6 + (h * L) ^ 3 / 24) * vnorm d (fun i => y i - z i).
Proof.
  intros Hh HL Hlip y z.
  set (e := vnorm d (fun i => y i - z i)).
  assert (He : 0 <= e) by apply vnorm_nonneg.
  set (D1 := vnorm d (fun i => slope1 F t y i - slope1 F t z i)).
  set (D2 := vnorm d (fun i => slope2 F t y h i - slope2 F t z h i)).
  set (D3 := vnorm d (fun i => slope3 F t y h i - slope3 F t z h i)).
  set (D4 := vnorm d (fun i => slope4 F t y h i - slope4 F t z h i)).
  assert (H1 : D1 <= L * e) by (apply Hlip; lra).
  assert (H2 : D2 <= L * (e + h / 2 * D1)).
  { eapply Rle_trans; [apply Hlip; lra |]. apply Rmult_le_compat_l; [lra |].
    apply vnorm_step. lra. }
  assert (H3 : D3 <= L * (e + h / 2 * D2)).
  { eapply Rle_trans; [apply Hlip; lra |]. apply Rmult_le_compat_l; [lra |].
    apply vnorm_step. lra. }
  assert (H4 : D4 <= L * (e + h * D3)).
  { eapply Rle_trans; [apply Hlip; lra |]. apply Rmult_le_compat_l; [lra |].
    apply vnorm_step. lra. }
  assert (B2 : D2 <= L * (e + h / 2 * (L * e))).
  { eapply Rle_trans; [exact H2 |]. apply Rmult_le_compat_l; [lra |].
    apply Rplus_le_compat_l, Rmult_le_compat_l; lra. }
  assert (B3 : D3 <= L * (e + h / 2 * (L * (e + h / 2 * (L * e))))).
  { eapply Rle_trans; [exact H3 |]. apply Rmult_le_compat_l; [lra |].
    apply Rplus_le_compat_l, Rmult_le_compat_l; lra. }
  assert (B4 : D4 <= L * (e + h * (L * (e + h / 2 * (L * (e + h / 2 * (L * e))))))).
  { eapply Rle_trans; [exact H4 |]. apply Rmult_le_compat_l; [lra |].
    apply Rplus_le_compat_l, Rmult_le_compat_l; lra. }
  assert (Hsum : vnorm d (fun i => incT F t y h i - incT F t z h i)
                 <= / 6 * (D1 + 2 * D2 + 2 * D3 + D4)).
  { pose proof (vnorm_nonneg d (fun i => slope1 F t y i - slope1 F t z i)) as N1.
    pose proof (vnorm_nonneg d (fun i => slope2 F t y h i - slope2 F t z h i)) as N2.
    pose proof (vnorm_nonneg d (fun i => slope3 F t y h i - slope3 F t z h i)) as N3.
    pose proof (vnorm_nonneg d (fun i => slope4 F t y h i - slope4 F t z h i)) as N4.
    fold D1 in N1. fold D2 in N2. fold D3 in N3. fold D4 in N4.
    apply vnorm_le; [lra |]. intros i Hi. unfold incT.
    pose proof (vnorm_ge d (fun i => slope1 F t y i - slope1 F t z i) i Hi) as A1.
    pose proof (vnorm_ge d (fun i => slope2 F t y h i - slope2 F t z h i) i Hi) as A2.
    pose proof (vnorm_ge d (fun i => slope3 F t y h i - slope3 F t z h i) i Hi) as A3.
    pose proof (vnorm_ge d (fun i => slope4 F t y h i - slope4 F t z h i) i Hi) as A4.
    cbv beta in A1, A2, A3, A4. fold D1 in A1. fold D2 in A2. fold D3 in A3. fold D4 in A4.
    set (a1 := slope1 F t y i - slope1 F t z i) in *.
    set (a2 := slope2 F t y h i - slope2 F t z h i) in *.
    set (a3 := slope3 F t y h i - slope3 F t z h i) in *.
    set (a4 := slope4 F t y h i - slope4 F t z h i) in *.
    replace (/ 6 * (slope1 F t y i + 2 * slope2 F t y h i + 2 * slope3 F t y h i
                    + slope4 F t y h i)
             - / 6 * (slope1 F t z i + 2 * slope2 F t z h i + 2 * slope3 F t z h i
                      + slope4 F t z h i))
      with (/ 6 * (a1 + 2 * a2 + 2 * a3 + a4)) by (unfold a1, a2, a3, a4; ring).
    rewrite Rabs_mult, (Rabs_pos_eq (/ 6)) by lra.
    apply Rmult_le_compat_l; [lra |].
    pose proof (Rabs_triang (a1 + 2 * a2 + 2 * a3) a4).
    pose proof (Rabs_triang (a1 + 2 * a2) (2 * a3)).
    pose proof (Rabs_triang a1 (2 * a2)).
    assert (T2 : Rabs (2 * a2) = 2 * Rabs a2) by (rewrite Rabs_mult, (Rabs_pos_eq 2); lra).
    assert (T3 : Rabs (2 * a3) = 2 * Rabs a3) by (rewrite Rabs_mult, (Rabs_pos_eq 2); lra).
    lra. }
  eapply Rle_trans; [exact Hsum |].
  assert (Hb : / 6 * (D1 + 2 * D2 + 2 * D3 + D4)
               <= / 6 * (L * e + 2 * (L * (e + h / 2 * (L * e)))
                         + 2 * (L * (e + h / 2 * (L * (e + h / 2 * (L * e)))))
                         + L * (e + h * (L * (e + h / 2 * (L * (e + h / 2 * (L * e)))))))) by lra.
  eapply Rle_trans; [exact Hb | right; field].
Qed.

Lemma exp_ge_poly (x : R) (n : nat) : 0 <= x -> poly (fun _ => 1) 0 x n <= exp x.
Proof.
  revert x. induction n as [| n IH]; intros x Hx.
  - simpl. pose proof (exp_pos x). lra.
  - assert (Hg : exp 0 - poly (fun _ => 1) 0 0 (S n) <= exp x - poly (fun _ => 1) 0 x (S n)).
    { apply (nondecreasing_of_derive (fun t => exp t - poly (fun _ => 1) 0 t (S n))
               (fun t => exp t - poly (fun _ => 1) 0 t n) 0 x Hx).
      - intros t _. apply der_sub; [apply is_derive_exp |].
        exact (poly_derive (fun _ => 1) 0 t n).
      - intros t Ht. pose proof (IH t ltac:(lra)). lra. }
    rewrite poly_self, exp_0 in Hg. lra.
Qed.

Lemma exp_pow_nat (x : R) (k : nat) : exp x ^ k = exp (INR k * x).
Proof.
  induction k as [| k IH].
  - simpl. rewrite Rmult_0_l, exp_0. reflexivity.
  - rewrite S_INR. replace ((INR k + 1) * x) with (x + INR k * x) by ring.
    rewrite exp_plus, <- IH. reflexivity.
Qed.

Lemma grid (t0 h : R) (N k : nat) (s : R) :
  0 <= h -> (k < N)%nat -> t0 + INR k * h <= s <= t0 + INR k * h + h ->
  t0 <= s <= t0 + INR N * h.
Proof.
  intros Hh Hk Hs.
  assert (Hk' : INR k + 1 <= INR N) by (rewrite <- S_INR; apply le_INR; lia).
  assert (0 <= INR k * h) by (apply Rmult_le_pos; [apply pos_INR | lra]).
  assert ((INR k + 1) * h <= INR N * h) by (apply Rmult_le_compat_r; lra).
  lra.
Qed.

Theorem global_error (d : nat) (F : R -> (nat -> R) -> nat -> R) (Y : R -> nat -> R)
  (t0 h L tau : R) (N : nat) :
  0 < h -> 0 < L -> 0 <= tau ->
  (forall s, t0 <= s <= t0 + INR N * h -> forall y z,
     vnorm d (fun i => F s y i - F s z i) <= L * vnorm d (fun i => y i - z i)) ->
  (forall k, (k < N)%nat ->
     vnorm d (fun i => Y (t0 + INR (S k) * h) i - Y (t0 + INR k * h) i
                       - h * incT F (t0 + INR k * h) (Y (t0 + INR k * h)) h i) <= tau) ->
  forall k, (k <= N)%nat ->
  vnorm d (fun i => rk4 F t0 h (Y t0) k i - Y (t0 + INR k * h) i)
    <= tau / (h * L) * (exp (L * (INR k * h)) - 1).
Proof.
  intros Hh HL Ht Hlip Htr k Hk.
  set (x := h * L).
  assert (Hx : 0 < x) by (unfold x; nra).
  set (K := L * (1 + h * L / 2 + (h * L) ^ 2 / 6 + (h * L) ^ 3 / 24)).
  assert (HK : 0 < K).
  { unfold K. apply Rmult_lt_0_compat; [lra |].
    assert (0 <= h * L / 2 + (h * L) ^ 2 / 6 + (h * L) ^ 3 / 24) by (fold x; nra). lra. }
  assert (Hlip' : forall j, (j < N)%nat -> forall y z,
            vnorm d (fun i => incT F (t0 + INR j * h) y h i - incT F (t0 + INR j * h) z h i)
              <= K * vnorm d (fun i => y i - z i)).
  { intros j Hj y z. apply (lipschitz d F (t0 + INR j * h) h L); [lra | lra |].
    intros s Hs. apply Hlip. exact (grid t0 h N j s ltac:(lra) Hj Hs). }
  pose proof (one_step_pow d (fun t y => incT F t y h) Y t0 h K tau N Hh HK Ht Hlip' Htr k Hk)
    as Hp.
  unfold rk4.
  assert (HT : 1 + h * K = poly (fun _ => 1) 0 x 5).
  { unfold K, x. simpl. field. }
  assert (He : 1 + h * K <= exp x) by (rewrite HT; apply exp_ge_poly; lra).
  assert (Hpow : (1 + h * K) ^ k <= exp (L * (INR k * h))).
  { eapply Rle_trans.
    - apply pow_incr. split; [| exact He]. assert (0 < h * K) by nra. lra.
    - rewrite exp_pow_nat. right. f_equal. unfold x. ring. }
  assert (HxK : x <= h * K).
  { unfold K, x. assert (0 <= h * L * (h * L / 2 + (h * L) ^ 2 / 6 + (h * L) ^ 3 / 24))
      by (apply Rmult_le_pos; [nra |]; fold x; nra). nra. }
  assert (Hnum : 0 <= exp (L * (INR k * h)) - 1).
  { assert (0 <= L * (INR k * h)) by (apply Rmult_le_pos; [lra |];
                                     apply Rmult_le_pos; [apply pos_INR | lra]).
    pose proof (exp_ineq1_le (L * (INR k * h))). lra. }
  eapply Rle_trans; [exact Hp |].
  assert (Hhk : 0 < h * K) by nra.
  apply (Rle_trans _ (tau * (exp (L * (INR k * h)) - 1) / (h * K))).
  - unfold Rdiv. apply Rmult_le_compat_r; [left; apply Rinv_0_lt_compat; lra |].
    apply Rmult_le_compat_l; lra.
  - fold x. apply (Rle_trans _ (tau * (exp (L * (INR k * h)) - 1) / x)).
    + unfold Rdiv. apply Rmult_le_compat_l; [nra |].
      apply Rinv_le_contravar; lra.
    + right. unfold x. field. lra.
Qed.

Record jet := mkjet { jv : nat -> R; jd1 : nat -> R; jd2 : nat -> R; jd3 : nat -> R }.

Section Jet.

Variable D : nat.
Variable G : (nat -> R) -> nat -> R.
Variable G1 : (nat -> R) -> (nat -> R) -> nat -> R.
Variable G2 : (nat -> R) -> (nat -> R) -> (nat -> R) -> nat -> R.
Variable G3 : (nat -> R) -> (nat -> R) -> (nat -> R) -> (nat -> R) -> nat -> R.

Definition japp (g : jet) : jet :=
  mkjet (G (jv g)) (G1 (jv g) (jd1 g))
    (fun i => G2 (jv g) (jd1 g) (jd1 g) i + G1 (jv g) (jd2 g) i)
    (fun i => G3 (jv g) (jd1 g) (jd1 g) (jd1 g) i + G2 (jv g) (jd2 g) (jd1 g) i
              + 2 * G2 (jv g) (jd1 g) (jd2 g) i + G1 (jv g) (jd3 g) i).

Definition jlin (y : nat -> R) (c s : R) (K : jet) : jet :=
  mkjet (fun i => y i + c * s * jv K i) (fun i => c * jv K i + c * s * jd1 K i)
    (fun i => 2 * c * jd1 K i + c * s * jd2 K i) (fun i => 3 * c * jd2 K i + c * s * jd3 K i).

Definition jet1 (y : nat -> R) : jet := mkjet (G y) (fun _ => 0) (fun _ => 0) (fun _ => 0).
Definition jet2 (y : nat -> R) (s : R) : jet := japp (jlin y (/ 2) s (jet1 y)).
Definition jet3 (y : nat -> R) (s : R) : jet := japp (jlin y (/ 2) s (jet2 y s)).
Definition jet4 (y : nat -> R) (s : R) : jet := japp (jlin y 1 s (jet3 y s)).

Definition comb (a b c e : nat -> R) : nat -> R := fun i => / 6 * (a i + 2 * b i + 2 * c i + e i).

Definition incjet (y : nat -> R) (s : R) : jet :=
  mkjet (comb (jv (jet1 y)) (jv (jet2 y s)) (jv (jet3 y s)) (jv (jet4 y s)))
    (comb (jd1 (jet1 y)) (jd1 (jet2 y s)) (jd1 (jet3 y s)) (jd1 (jet4 y s)))
    (comb (jd2 (jet1 y)) (jd2 (jet2 y s)) (jd2 (jet3 y s)) (jd2 (jet4 y s)))
    (comb (jd3 (jet1 y)) (jd3 (jet2 y s)) (jd3 (jet3 y s)) (jd3 (jet4 y s))).

Definition E2 (y : nat -> R) : nat -> R := G1 y (G y).
Definition E3 (y : nat -> R) : nat -> R := fun i => G2 y (G y) (G y) i + G1 y (E2 y) i.
Definition E4 (y : nat -> R) : nat -> R :=
  fun i => G3 y (G y) (G y) (G y) i + G2 y (E2 y) (G y) i + 2 * G2 y (G y) (E2 y) i
           + G1 y (E3 y) i.

Definition curve (g : R -> nat -> R) (g' : nat -> R) (s : R) : Prop :=
  forall j, (j < D)%nat -> is_derive (fun r => g r j) s (g' j).

Definition chain (J : R -> jet) (s : R) : Prop :=
  curve (fun r => jv (J r)) (jd1 (J s)) s /\ curve (fun r => jd1 (J r)) (jd2 (J s)) s /\
  curve (fun r => jd2 (J r)) (jd3 (J s)) s.

Hypothesis HG : forall g g' s, curve g g' s ->
  forall i, (i < D)%nat -> is_derive (fun r => G (g r) i) s (G1 (g s) g' i).
Hypothesis HG1 : forall g g' u u' s, curve g g' s -> curve u u' s ->
  forall i, (i < D)%nat ->
  is_derive (fun r => G1 (g r) (u r) i) s (G2 (g s) g' (u s) i + G1 (g s) u' i).
Hypothesis HG2 : forall g g' u u' v v' s, curve g g' s -> curve u u' s -> curve v v' s ->
  forall i, (i < D)%nat ->
  is_derive (fun r => G2 (g r) (u r) (v r) i) s
    (G3 (g s) g' (u s) (v s) i + G2 (g s) u' (v s) i + G2 (g s) (u s) v' i).

Lemma chain_app (J : R -> jet) (s : R) : chain J s -> chain (fun r => japp (J r)) s.
Proof.
  intros [H0 [H1 H2]]. split; [| split]; intros i Hi; cbn [japp jv jd1 jd2 jd3].
  - exact (HG _ _ _ H0 i Hi).
  - exact (HG1 _ _ _ _ _ H0 H1 i Hi).
  - apply (der_val _ _ ((G3 (jv (J s)) (jd1 (J s)) (jd1 (J s)) (jd1 (J s)) i
                          + G2 (jv (J s)) (jd2 (J s)) (jd1 (J s)) i
                          + G2 (jv (J s)) (jd1 (J s)) (jd2 (J s)) i)
                         + (G2 (jv (J s)) (jd1 (J s)) (jd2 (J s)) i
                            + G1 (jv (J s)) (jd3 (J s)) i))); [ring |].
    apply (der_add (fun r => G2 (jv (J r)) (jd1 (J r)) (jd1 (J r)) i)
             (fun r => G1 (jv (J r)) (jd2 (J r)) i)).
    + exact (HG2 _ _ _ _ _ _ _ H0 H1 H1 i Hi).
    + exact (HG1 _ _ _ _ _ H0 H2 i Hi).
Qed.

Lemma der_lin (c s : R) (f : R -> R) (a b : R) :
  is_derive f s b -> f s = a -> is_derive (fun r => c * r * f r) s (c * a + c * s * b).
Proof.
  intros Hf Ha.
  apply (is_derive_ext (fun r => (c * r) * f r)); [intro t; reflexivity |].
  apply (der_val _ _ ((c * 1) * f s + c * s * b)); [rewrite Ha; ring |].
  apply (der_mul (fun r => c * r) f). - apply der_scal, der_id. - exact Hf.
Qed.

Lemma chain_lin (y : nat -> R) (c : R) (K : R -> jet) (s : R) :
  chain K s -> chain (fun r => jlin y c r (K r)) s.
Proof.
  intros [H0 [H1 H2]]. split; [| split]; intros i Hi; cbn [jlin jv jd1 jd2 jd3].
  - apply (der_val _ _ (0 + (c * jv (K s) i + c * s * jd1 (K s) i))); [ring |].
    apply (der_add (fun _ => y i) (fun r => c * r * jv (K r) i)); [apply der_const |].
    exact (der_lin c s (fun r => jv (K r) i) _ _ (H0 i Hi) eq_refl).
  - apply (der_val _ _ (c * jd1 (K s) i + (c * jd1 (K s) i + c * s * jd2 (K s) i))); [ring |].
    apply (der_add (fun r => c * jv (K r) i) (fun r => c * r * jd1 (K r) i)).
    + exact (der_scal _ c s _ (H0 i Hi)).
    + exact (der_lin c s (fun r => jd1 (K r) i) _ _ (H1 i Hi) eq_refl).
  - apply (der_val _ _ (2 * c * jd2 (K s) i + (c * jd2 (K s) i + c * s * jd3 (K s) i)));
      [ring |].
    apply (der_add (fun r => 2 * c * jd1 (K r) i) (fun r => c * r * jd2 (K r) i)).
    + exact (der_scal _ (2 * c) s _ (H1 i Hi)).
    + exact (der_lin c s (fun r => jd2 (K r) i) _ _ (H2 i Hi) eq_refl).
Qed.

Lemma chain_jet1 (y : nat -> R) (s : R) : chain (fun _ => jet1 y) s.
Proof. split; [| split]; intros i Hi; cbn; apply der_const. Qed.

Lemma chain_comb (A B C E : R -> nat -> R) (A' B' C' E' : nat -> R) (s : R) :
  curve A A' s -> curve B B' s -> curve C C' s -> curve E E' s ->
  curve (fun r => comb (A r) (B r) (C r) (E r)) (comb A' B' C' E') s.
Proof.
  intros HA HB HC HE i Hi. unfold comb.
  apply der_scal.
  apply (der_add (fun r => A r i + 2 * B r i + 2 * C r i) (fun r => E r i)); [| exact (HE i Hi)].
  apply (der_add (fun r => A r i + 2 * B r i) (fun r => 2 * C r i));
    [| exact (der_scal _ 2 s _ (HC i Hi))].
  apply (der_add (fun r => A r i) (fun r => 2 * B r i)); [exact (HA i Hi) |].
  exact (der_scal _ 2 s _ (HB i Hi)).
Qed.

Lemma chain_inc (y : nat -> R) (s : R) : chain (incjet y) s.
Proof.
  pose proof (chain_jet1 y s) as Ha.
  assert (Hb : chain (jet2 y) s) by exact (chain_app _ s (chain_lin y (/ 2) _ s Ha)).
  assert (Hc : chain (jet3 y) s) by exact (chain_app _ s (chain_lin y (/ 2) _ s Hb)).
  assert (He : chain (jet4 y) s) by exact (chain_app _ s (chain_lin y 1 _ s Hc)).
  destruct Ha as [a0 [a1 a2]]. destruct Hb as [b0 [b1 b2]].
  destruct Hc as [c0 [c1 c2]]. destruct He as [e0 [e1 e2]].
  split; [| split]; apply chain_comb; assumption.
Qed.

Lemma incjet_v (y : nat -> R) (s : R) : jv (incjet y s) = inc G y s.
Proof.
  assert (H2 : jv (jet2 y s) = slope2 (fun _ => G) 0 y s).
  { unfold jet2, japp, jlin, jet1, slope2, slope1. cbn [jv]. f_equal.
    extensionality i. field. }
  assert (H3 : jv (jet3 y s) = slope3 (fun _ => G) 0 y s).
  { unfold jet3, slope3. unfold japp at 1, jlin at 1. cbn [jv]. rewrite H2. f_equal.
    extensionality i. field. }
  assert (H4 : jv (jet4 y s) = slope4 (fun _ => G) 0 y s).
  { unfold jet4, slope4. unfold japp at 1, jlin at 1. cbn [jv]. rewrite H3. f_equal.
    extensionality i. ring. }
  unfold incjet, inc, incT. cbn [jv]. rewrite H2, H3, H4. reflexivity.
Qed.

Theorem inc_deriv (y : nat -> R) (s : R) :
  forall i, (i < D)%nat ->
  is_derive (fun r => inc G y r i) s (jd1 (incjet y s) i) /\
  is_derive (fun r => jd1 (incjet y r) i) s (jd2 (incjet y s) i) /\
  is_derive (fun r => jd2 (incjet y r) i) s (jd3 (incjet y s) i).
Proof.
  intros i Hi. destruct (chain_inc y s) as [P0 [P1 P2]].
  split; [| split; [exact (P1 i Hi) | exact (P2 i Hi)]].
  apply (is_derive_ext (fun r => jv (incjet y r) i)); [intro r; rewrite incjet_v; reflexivity |].
  exact (P0 i Hi).
Qed.

Hypothesis LG1 : forall x a b p q i,
  G1 x (fun j => p * a j + q * b j) i = p * G1 x a i + q * G1 x b i.
Hypothesis LG2a : forall x a a' b p q i,
  G2 x (fun j => p * a j + q * a' j) b i = p * G2 x a b i + q * G2 x a' b i.
Hypothesis LG2b : forall x a b b' p q i,
  G2 x a (fun j => p * b j + q * b' j) i = p * G2 x a b i + q * G2 x a b' i.
Hypothesis LG3a : forall x a a' b e p q i,
  G3 x (fun j => p * a j + q * a' j) b e i = p * G3 x a b e i + q * G3 x a' b e i.
Hypothesis LG3b : forall x a b b' e p q i,
  G3 x a (fun j => p * b j + q * b' j) e i = p * G3 x a b e i + q * G3 x a b' e i.
Hypothesis LG3c : forall x a b e e' p q i,
  G3 x a b (fun j => p * e j + q * e' j) i = p * G3 x a b e i + q * G3 x a b e' i.

Lemma scal_split (p : R) (a : nat -> R) : (fun j => p * a j) = (fun j => p * a j + 0 * a j).
Proof. extensionality j. ring. Qed.

Lemma add_split (a b : nat -> R) : (fun j => a j + b j) = (fun j => 1 * a j + 1 * b j).
Proof. extensionality j. ring. Qed.

Lemma zero_split (a : nat -> R) : (fun _ : nat => 0) = (fun j => 0 * a j + 0 * a j).
Proof. extensionality j. ring. Qed.

Lemma g1_scal x a p : G1 x (fun j => p * a j) = fun i => p * G1 x a i.
Proof. rewrite scal_split. extensionality i. rewrite LG1. ring. Qed.
Lemma g1_add x a b : G1 x (fun j => a j + b j) = fun i => G1 x a i + G1 x b i.
Proof. rewrite add_split. extensionality i. rewrite LG1. ring. Qed.
Lemma g1_z x : G1 x (fun _ => 0) = fun _ => 0.
Proof. rewrite (zero_split x). extensionality i. rewrite LG1. ring. Qed.

Lemma g2_scal1 x a b p : G2 x (fun j => p * a j) b = fun i => p * G2 x a b i.
Proof. rewrite scal_split. extensionality i. rewrite LG2a. ring. Qed.
Lemma g2_add1 x a a' b : G2 x (fun j => a j + a' j) b = fun i => G2 x a b i + G2 x a' b i.
Proof. rewrite add_split. extensionality i. rewrite LG2a. ring. Qed.
Lemma g2_z1 x b : G2 x (fun _ => 0) b = fun _ => 0.
Proof. rewrite (zero_split x). extensionality i. rewrite LG2a. ring. Qed.
Lemma g2_scal2 x a b p : G2 x a (fun j => p * b j) = fun i => p * G2 x a b i.
Proof. rewrite scal_split. extensionality i. rewrite LG2b. ring. Qed.
Lemma g2_add2 x a b b' : G2 x a (fun j => b j + b' j) = fun i => G2 x a b i + G2 x a b' i.
Proof. rewrite add_split. extensionality i. rewrite LG2b. ring. Qed.
Lemma g2_z2 x a : G2 x a (fun _ => 0) = fun _ => 0.
Proof. rewrite (zero_split x). extensionality i. rewrite LG2b. ring. Qed.

Lemma g3_scal1 x a b e p : G3 x (fun j => p * a j) b e = fun i => p * G3 x a b e i.
Proof. rewrite scal_split. extensionality i. rewrite LG3a. ring. Qed.
Lemma g3_scal2 x a b e p : G3 x a (fun j => p * b j) e = fun i => p * G3 x a b e i.
Proof. rewrite scal_split. extensionality i. rewrite LG3b. ring. Qed.
Lemma g3_scal3 x a b e p : G3 x a b (fun j => p * e j) = fun i => p * G3 x a b e i.
Proof. rewrite scal_split. extensionality i. rewrite LG3c. ring. Qed.

Lemma lin0 (y : nat -> R) (c : R) (K : jet) :
  jlin y c 0 K =
  mkjet y (fun i => c * jv K i) (fun i => 2 * c * jd1 K i) (fun i => 3 * c * jd2 K i).
Proof. unfold jlin. f_equal; extensionality i; ring. Qed.

Ltac lin_simpl :=
  repeat (rewrite ?g1_add, ?g1_scal, ?g1_z, ?g2_add1, ?g2_add2, ?g2_scal1, ?g2_scal2,
            ?g2_z1, ?g2_z2, ?g3_scal1, ?g3_scal2, ?g3_scal3; cbv beta).

Lemma jet2_0 (y : nat -> R) :
  jet2 y 0 = mkjet (G y) (fun i => / 2 * G1 y (G y) i) (fun i => / 4 * G2 y (G y) (G y) i)
               (fun i => / 8 * G3 y (G y) (G y) (G y) i).
Proof.
  unfold jet2. rewrite lin0. unfold jet1, japp. cbn [jv jd1 jd2 jd3].
  replace (fun i : nat => 2 * / 2 * 0) with (fun _ : nat => 0) by (extensionality i; ring).
  replace (fun i : nat => 3 * / 2 * 0) with (fun _ : nat => 0) by (extensionality i; ring).
  lin_simpl. f_equal; extensionality i; field.
Qed.

Lemma jet3_0 (y : nat -> R) :
  jet3 y 0 =
  mkjet (G y) (fun i => / 2 * G1 y (G y) i)
    (fun i => / 4 * G2 y (G y) (G y) i + / 2 * G1 y (G1 y (G y)) i)
    (fun i => / 8 * G3 y (G y) (G y) (G y) i + / 4 * G2 y (G1 y (G y)) (G y) i
              + / 2 * G2 y (G y) (G1 y (G y)) i + 3 / 8 * G1 y (G2 y (G y) (G y)) i).
Proof.
  unfold jet3. rewrite lin0, jet2_0. unfold japp. cbn [jv jd1 jd2 jd3].
  lin_simpl. f_equal; extensionality i; field.
Qed.

Lemma jet4_0 (y : nat -> R) :
  jet4 y 0 =
  mkjet (G y) (fun i => G1 y (G y) i)
    (fun i => G2 y (G y) (G y) i + G1 y (G1 y (G y)) i)
    (fun i => G3 y (G y) (G y) (G y) i + G2 y (G1 y (G y)) (G y) i
              + 2 * G2 y (G y) (G1 y (G y)) i + 3 / 4 * G1 y (G2 y (G y) (G y)) i
              + 3 / 2 * G1 y (G1 y (G1 y (G y))) i).
Proof.
  unfold jet4. rewrite lin0, jet3_0. unfold japp. cbn [jv jd1 jd2 jd3].
  lin_simpl. f_equal; extensionality i; field.
Qed.

Theorem order_conditions (y : nat -> R) :
  jv (incjet y 0) = G y /\
  (forall i, jd1 (incjet y 0) i = / 2 * E2 y i) /\
  (forall i, jd2 (incjet y 0) i = / 3 * E3 y i) /\
  (forall i, jd3 (incjet y 0) i = / 4 * E4 y i).
Proof.
  unfold incjet. rewrite jet2_0, jet3_0, jet4_0. unfold jet1, comb, E4, E3, E2.
  cbn [jv jd1 jd2 jd3]. lin_simpl.
  split; [| split; [| split]].
  - extensionality i. field.
  - intro i. field.
  - intro i. field.
  - intro i. field.
Qed.

Lemma poly5 (c : nat -> R) (a x : R) :
  poly c a x 5 = c 0%nat + c 1%nat * (x - a) + c 2%nat * (x - a) ^ 2 / 2
                 + c 3%nat * (x - a) ^ 3 / 6 + c 4%nat * (x - a) ^ 4 / 24.
Proof. simpl. field. Qed.

Lemma poly4 (c : nat -> R) (a x : R) :
  poly c a x 4 = c 0%nat + c 1%nat * (x - a) + c 2%nat * (x - a) ^ 2 / 2
                 + c 3%nat * (x - a) ^ 3 / 6.
Proof. simpl. field. Qed.

Theorem local_error (Y : R -> nat -> R) (t h M5 N4 : R) :
  0 <= h -> 0 <= M5 -> 0 <= N4 ->
  (forall i, (i < D)%nat -> forall s, t <= s <= t + h ->
     is_derive (fun r => Y r i) s (G (Y s) i)) ->
  (forall i, (i < D)%nat -> forall s, t <= s <= t + h ->
     Rabs (E4 (Y s) i - E4 (Y t) i) <= M5 * (s - t)) ->
  (forall i, (i < D)%nat -> forall s, 0 <= s <= h ->
     Rabs (jd3 (incjet (Y t) s) i - jd3 (incjet (Y t) 0) i) <= N4 * s) ->
  vnorm D (fun i => Y (t + h) i - Y t i - h * inc G (Y t) h i) <= (M5 / 120 + N4 / 24) * h ^ 5.
Proof.
  intros Hh HM0 HN0 HY HM HN.
  assert (C0 : forall s, t <= s <= t + h -> curve Y (G (Y s)) s)
    by (intros s Hs j Hj; exact (HY j Hj s Hs)).
  assert (C1 : forall s, t <= s <= t + h -> curve (fun r => G (Y r)) (E2 (Y s)) s)
    by (intros s Hs j Hj; exact (HG _ _ _ (C0 s Hs) j Hj)).
  assert (C2 : forall s, t <= s <= t + h -> curve (fun r => E2 (Y r)) (E3 (Y s)) s)
    by (intros s Hs j Hj; exact (HG1 _ _ _ _ _ (C0 s Hs) (C1 s Hs) j Hj)).
  assert (C3 : forall s, t <= s <= t + h -> curve (fun r => E3 (Y r)) (E4 (Y s)) s).
  { intros s Hs j Hj. unfold E3, E4.
    apply (der_val _ _ ((G3 (Y s) (G (Y s)) (G (Y s)) (G (Y s)) j
                         + G2 (Y s) (E2 (Y s)) (G (Y s)) j + G2 (Y s) (G (Y s)) (E2 (Y s)) j)
                        + (G2 (Y s) (G (Y s)) (E2 (Y s)) j + G1 (Y s) (E3 (Y s)) j)));
      [unfold E3; ring |].
    apply (der_add (fun r => G2 (Y r) (G (Y r)) (G (Y r)) j) (fun r => G1 (Y r) (E2 (Y r)) j)).
    - exact (HG2 _ _ _ _ _ _ _ (C0 s Hs) (C1 s Hs) (C1 s Hs) j Hj).
    - exact (HG1 _ _ _ _ _ (C0 s Hs) (C2 s Hs) j Hj). }
  destruct (order_conditions (Y t)) as [O0 [O1 [O2 O3]]].
  assert (Hpos : 0 <= (M5 / 120 + N4 / 24) * h ^ 5)
    by (apply Rmult_le_pos; [lra | apply pow_le; lra]).
  apply vnorm_le; [exact Hpos |]. intros i Hi.
  set (fY := fun j : nat => match j with
                            | O => fun r => Y r i
                            | 1%nat => fun r => G (Y r) i
                            | 2%nat => fun r => E2 (Y r) i
                            | 3%nat => fun r => E3 (Y r) i
                            | _ => fun r => E4 (Y r) i
                            end).
  assert (TY : Rabs (fY 0%nat (t + h) - poly (fun j => fY j t) t (t + h) 5)
               <= M5 * (t + h - t) ^ 5 / INR (fact 5)).
  { apply (taylor_bound fY t (t + h) M5 4).
    - intros j Hj x Hx. destruct j as [| [| [| [| j]]]]; [| | | | lia]; cbn.
      + exact (HY i Hi x Hx).
      + exact (C1 x Hx i Hi).
      + exact (C2 x Hx i Hi).
      + exact (C3 x Hx i Hi).
    - intros x Hx. exact (HM i Hi x Hx).
    - lra. }
  set (fP := fun j : nat => match j with
                            | O => fun s => jv (incjet (Y t) s) i
                            | 1%nat => fun s => jd1 (incjet (Y t) s) i
                            | 2%nat => fun s => jd2 (incjet (Y t) s) i
                            | _ => fun s => jd3 (incjet (Y t) s) i
                            end).
  assert (TP : Rabs (fP 0%nat h - poly (fun j => fP j 0) 0 h 4)
               <= N4 * (h - 0) ^ 4 / INR (fact 4)).
  { apply (taylor_bound fP 0 h N4 3).
    - intros j Hj x Hx. destruct (chain_inc (Y t) x) as [P0 [P1 P2]].
      destruct j as [| [| [| j]]]; [| | | lia]; cbn.
      + exact (P0 i Hi).
      + exact (P1 i Hi).
      + exact (P2 i Hi).
    - intros x Hx. rewrite Rminus_0_r. exact (HN i Hi x Hx).
    - lra. }
  rewrite poly5 in TY. rewrite poly4 in TP. unfold fY in TY. unfold fP in TP.
  cbv beta iota in TY, TP.
  rewrite O0, O1, O2, O3 in TP.
  rewrite (incjet_v (Y t) h) in TP.
  replace (t + h - t) with h in TY by ring. replace (h - 0) with h in TP by ring.
  replace (INR (fact 5)) with 120 in TY by (simpl; ring).
  replace (INR (fact 4)) with 24 in TP by (simpl; ring).
  set (PY := Y t i + G (Y t) i * h + E2 (Y t) i * h ^ 2 / 2 + E3 (Y t) i * h ^ 3 / 6
             + E4 (Y t) i * h ^ 4 / 24) in TY.
  set (PP := G (Y t) i + / 2 * E2 (Y t) i * h + / 3 * E3 (Y t) i * h ^ 2 / 2
             + / 4 * E4 (Y t) i * h ^ 3 / 6) in TP.
  replace (Y (t + h) i - Y t i - h * inc G (Y t) h i)
    with ((Y (t + h) i - PY) - h * (inc G (Y t) h i - PP)) by (unfold PY, PP; field).
  eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_Ropp, Rabs_mult, (Rabs_pos_eq h) by lra.
  assert (h * Rabs (inc G (Y t) h i - PP) <= h * (N4 * h ^ 4 / 24))
    by (apply Rmult_le_compat_l; [lra | exact TP]).
  apply (Rle_trans _ (M5 * h ^ 5 / 120 + h * (N4 * h ^ 4 / 24))); [lra | right; field].
Qed.

End Jet.

Definition auto (d : nat) (F : R -> (nat -> R) -> nat -> R) (z : nat -> R) : nat -> R :=
  fun i => if Nat.ltb i d then F (z d) z i else 1.

Definition aug (d : nat) (t : R) (y : nat -> R) : nat -> R :=
  fun i => if Nat.ltb i d then y i else t.

Definition local (d : nat) (F : R -> (nat -> R) -> nat -> R) (s : R) : Prop :=
  forall y y', (forall j, (j < d)%nat -> y j = y' j) ->
  forall i, (i < d)%nat -> F s y i = F s y' i.

Lemma auto_lt (d : nat) F (w : nat -> R) (i : nat) :
  (i < d)%nat -> auto d F w i = F (w d) w i.
Proof. intro Hi. unfold auto. destruct (Nat.ltb_spec i d); [reflexivity | lia]. Qed.

Lemma auto_d (d : nat) F (w : nat -> R) : auto d F w d = 1.
Proof. unfold auto. destruct (Nat.ltb_spec d d); [lia | reflexivity]. Qed.

Lemma aug_lt (d : nat) (t : R) (y : nat -> R) (i : nat) : (i < d)%nat -> aug d t y i = y i.
Proof. intro Hi. unfold aug. destruct (Nat.ltb_spec i d); [reflexivity | lia]. Qed.

Lemma aug_d (d : nat) (t : R) (y : nat -> R) : aug d t y d = t.
Proof. unfold aug. destruct (Nat.ltb_spec d d); [lia | reflexivity]. Qed.

Theorem inc_autonomous (d : nat) (F : R -> (nat -> R) -> nat -> R) (t : R) (y : nat -> R)
  (h : R) :
  0 <= h -> (forall s, t <= s <= t + h -> local d F s) ->
  (forall i, (i < d)%nat -> inc (auto d F) (aug d t y) h i = incT F t y h i) /\
  inc (auto d F) (aug d t y) h d = 1.
Proof.
  intros Hh Hloc.
  set (z := aug d t y).
  set (G := auto d F).
  set (K1 := G z).
  set (Z2 := fun i => z i + h / 2 * K1 i).
  set (K2 := G Z2).
  set (Z3 := fun i => z i + h / 2 * K2 i).
  set (K3 := G Z3).
  set (Z4 := fun i => z i + h * K3 i).
  set (K4 := G Z4).
  assert (Hz : forall j, (j < d)%nat -> z j = y j) by (intros; apply aug_lt; lia).
  assert (Hzd : z d = t) by apply aug_d.
  assert (E1 : forall i, (i < d)%nat -> K1 i = slope1 F t y i).
  { intros i Hi. unfold K1, G. rewrite auto_lt, Hzd by lia.
    apply (Hloc t ltac:(lra) z y Hz i Hi). }
  assert (Z2d : Z2 d = t + h / 2) by (unfold Z2, K1, G; rewrite auto_d, Hzd; ring).
  assert (Z2j : forall j, (j < d)%nat -> Z2 j = y j + h / 2 * slope1 F t y j)
    by (intros j Hj; unfold Z2; rewrite Hz, E1 by lia; reflexivity).
  assert (E2' : forall i, (i < d)%nat -> K2 i = slope2 F t y h i).
  { intros i Hi. unfold K2, G. rewrite auto_lt, Z2d by lia. unfold slope2.
    apply (Hloc (t + h / 2) ltac:(lra) Z2 _ Z2j i Hi). }
  assert (Z3d : Z3 d = t + h / 2) by (unfold Z3, K2, G; rewrite auto_d, Hzd; ring).
  assert (Z3j : forall j, (j < d)%nat -> Z3 j = y j + h / 2 * slope2 F t y h j)
    by (intros j Hj; unfold Z3; rewrite Hz, E2' by lia; reflexivity).
  assert (E3' : forall i, (i < d)%nat -> K3 i = slope3 F t y h i).
  { intros i Hi. unfold K3, G. rewrite auto_lt, Z3d by lia. unfold slope3.
    apply (Hloc (t + h / 2) ltac:(lra) Z3 _ Z3j i Hi). }
  assert (Z4d : Z4 d = t + h) by (unfold Z4, K3, G; rewrite auto_d, Hzd; ring).
  assert (Z4j : forall j, (j < d)%nat -> Z4 j = y j + h * slope3 F t y h j)
    by (intros j Hj; unfold Z4; rewrite Hz, E3' by lia; reflexivity).
  assert (E4' : forall i, (i < d)%nat -> K4 i = slope4 F t y h i).
  { intros i Hi. unfold K4, G. rewrite auto_lt, Z4d by lia. unfold slope4.
    apply (Hloc (t + h) ltac:(lra) Z4 _ Z4j i Hi). }
  assert (Hinc : forall i, inc G z h i = / 6 * (K1 i + 2 * K2 i + 2 * K3 i + K4 i))
    by (intro i; reflexivity).
  split.
  - intros i Hi. rewrite Hinc, E1, E2', E3', E4' by exact Hi. reflexivity.
  - rewrite Hinc. unfold K1, K2, K3, K4, G. rewrite !auto_d. field.
Qed.

Lemma lipschitz_local (d : nat) (F : R -> (nat -> R) -> nat -> R) (s L : R) :
  (forall y z, vnorm d (fun i => F s y i - F s z i) <= L * vnorm d (fun i => y i - z i)) ->
  local d F s.
Proof.
  intros Hlip y y' Hy i Hi.
  assert (H0 : vnorm d (fun j => y j - y' j) <= 0).
  { apply vnorm_le; [lra |]. intros j Hj. rewrite Hy by exact Hj.
    replace (y' j - y' j) with 0 by ring. rewrite Rabs_R0. lra. }
  pose proof (vnorm_nonneg d (fun j => y j - y' j)) as Hn.
  assert (H1 : vnorm d (fun j => F s y j - F s y' j) <= 0).
  { eapply Rle_trans; [apply Hlip |]. replace (vnorm d (fun j => y j - y' j)) with 0 by lra.
    lra. }
  pose proof (vnorm_ge d (fun j => F s y j - F s y' j) i Hi) as H2. cbv beta in H2.
  pose proof (Rabs_pos (F s y i - F s y' i)).
  assert (Hz : Rabs (F s y i - F s y' i) = 0) by lra.
  apply Rabs_eq_0 in Hz. lra.
Qed.

Theorem convergence (d : nat) (F : R -> (nat -> R) -> nat -> R)
  (G1 : (nat -> R) -> (nat -> R) -> nat -> R)
  (G2 : (nat -> R) -> (nat -> R) -> (nat -> R) -> nat -> R)
  (G3 : (nat -> R) -> (nat -> R) -> (nat -> R) -> (nat -> R) -> nat -> R)
  (Y : R -> nat -> R) (t0 h L M5 N4 : R) (N : nat) :
  0 < h -> 0 < L -> 0 <= M5 -> 0 <= N4 ->
  (forall g g' s, curve (S d) g g' s -> forall i, (i < S d)%nat ->
     is_derive (fun r => auto d F (g r) i) s (G1 (g s) g' i)) ->
  (forall g g' u u' s, curve (S d) g g' s -> curve (S d) u u' s -> forall i, (i < S d)%nat ->
     is_derive (fun r => G1 (g r) (u r) i) s (G2 (g s) g' (u s) i + G1 (g s) u' i)) ->
  (forall g g' u u' v v' s, curve (S d) g g' s -> curve (S d) u u' s -> curve (S d) v v' s ->
     forall i, (i < S d)%nat ->
     is_derive (fun r => G2 (g r) (u r) (v r) i) s
       (G3 (g s) g' (u s) (v s) i + G2 (g s) u' (v s) i + G2 (g s) (u s) v' i)) ->
  (forall x a b p q i,
     G1 x (fun j => p * a j + q * b j) i = p * G1 x a i + q * G1 x b i) ->
  (forall x a a' b p q i,
     G2 x (fun j => p * a j + q * a' j) b i = p * G2 x a b i + q * G2 x a' b i) ->
  (forall x a b b' p q i,
     G2 x a (fun j => p * b j + q * b' j) i = p * G2 x a b i + q * G2 x a b' i) ->
  (forall x a a' b e p q i,
     G3 x (fun j => p * a j + q * a' j) b e i = p * G3 x a b e i + q * G3 x a' b e i) ->
  (forall x a b b' e p q i,
     G3 x a (fun j => p * b j + q * b' j) e i = p * G3 x a b e i + q * G3 x a b' e i) ->
  (forall x a b e e' p q i,
     G3 x a b (fun j => p * e j + q * e' j) i = p * G3 x a b e i + q * G3 x a b e' i) ->
  (forall i, (i < d)%nat -> forall s, t0 <= s <= t0 + INR N * h ->
     is_derive (fun r => Y r i) s (F s (Y s) i)) ->
  (forall s, t0 <= s <= t0 + INR N * h -> forall y z,
     vnorm d (fun i => F s y i - F s z i) <= L * vnorm d (fun i => y i - z i)) ->
  (forall k, (k < N)%nat -> forall i, (i < S d)%nat ->
     forall s, t0 + INR k * h <= s <= t0 + INR k * h + h ->
     Rabs (E4 (auto d F) G1 G2 G3 (aug d s (Y s)) i
           - E4 (auto d F) G1 G2 G3 (aug d (t0 + INR k * h) (Y (t0 + INR k * h))) i)
       <= M5 * (s - (t0 + INR k * h))) ->
  (forall k, (k < N)%nat -> forall i, (i < S d)%nat -> forall s, 0 <= s <= h ->
     Rabs (jd3 (incjet (auto d F) G1 G2 G3 (aug d (t0 + INR k * h) (Y (t0 + INR k * h))) s) i
           - jd3 (incjet (auto d F) G1 G2 G3 (aug d (t0 + INR k * h) (Y (t0 + INR k * h))) 0) i)
       <= N4 * s) ->
  forall k, (k <= N)%nat ->
  vnorm d (fun i => rk4 F t0 h (Y t0) k i - Y (t0 + INR k * h) i)
    <= (M5 / 120 + N4 / 24) * h ^ 4 / L * (exp (L * (INR k * h)) - 1).
Proof.
  intros Hh HL HM0 HN0 HG HG1 HG2 L1 L2a L2b L3a L3b L3c HY Hlip HM HN.
  set (tau := (M5 / 120 + N4 / 24) * h ^ 5).
  assert (Htau : 0 <= tau) by (unfold tau; apply Rmult_le_pos; [lra | apply pow_le; lra]).
  assert (Hloc : forall s, t0 <= s <= t0 + INR N * h -> local d F s)
    by (intros s Hs; exact (lipschitz_local d F s L (Hlip s Hs))).
  assert (Htr : forall k, (k < N)%nat ->
     vnorm d (fun i => Y (t0 + INR (S k) * h) i - Y (t0 + INR k * h) i
                       - h * incT F (t0 + INR k * h) (Y (t0 + INR k * h)) h i) <= tau).
  { intros k Hk.
    set (tk := t0 + INR k * h).
    set (Yh := fun r => aug d r (Y r)).
    assert (HYh : forall i, (i < S d)%nat -> forall s, tk <= s <= tk + h ->
              is_derive (fun r => Yh r i) s (auto d F (Yh s) i)).
    { intros i Hi s Hs. unfold Yh.
      destruct (Nat.eq_dec i d) as [-> | Hne].
      - rewrite auto_d. apply (is_derive_ext (fun r => r)); [intro r; symmetry; apply aug_d |].
        apply der_id.
      - assert (Hid : (i < d)%nat) by lia.
        rewrite auto_lt, aug_d by exact Hid.
        apply (is_derive_ext (fun r => Y r i)); [intro r; symmetry; apply aug_lt; exact Hid |].
        rewrite (Hloc s (grid t0 h N k s ltac:(lra) Hk Hs) (aug d s (Y s)) (Y s)
                   (fun j Hj => aug_lt d s (Y s) j Hj) i Hid).
        exact (HY i Hid s (grid t0 h N k s ltac:(lra) Hk Hs)). }
    pose proof (local_error (S d) (auto d F) G1 G2 G3 HG HG1 HG2 L1 L2a L2b L3a L3b L3c
                  Yh tk h M5 N4 ltac:(lra) HM0 HN0 HYh (HM k Hk) (HN k Hk)) as Hl.
    destruct (inc_autonomous d F tk (Y tk) h ltac:(lra)
                (fun s Hs => Hloc s (grid t0 h N k s ltac:(lra) Hk Hs))) as [Hinc _].
    apply vnorm_le; [exact Htau |]. intros i Hi.
    replace (t0 + INR (S k) * h) with (tk + h) by (unfold tk; rewrite S_INR; ring).
    eapply Rle_trans; [| exact Hl].
    pose proof (vnorm_ge (S d)
      (fun i => Yh (tk + h) i - Yh tk i - h * inc (auto d F) (Yh tk) h i) i ltac:(lia)) as Hg.
    cbv beta in Hg. unfold Yh in Hg.
    rewrite !aug_lt, Hinc in Hg by exact Hi. exact Hg. }
  intros k Hk.
  pose proof (global_error d F Y t0 h L tau N Hh HL Htau Hlip Htr k Hk) as Hg.
  eapply Rle_trans; [exact Hg |]. right. unfold tau. field. lra.
Qed.

Lemma linear_instance (d : nat) (a : R) :
  let F := fun (_ : R) (y : nat -> R) (i : nat) => a * y i in
  let G1 := fun (_ v : nat -> R) (i : nat) => if Nat.ltb i d then a * v i else 0 in
  let G2 := fun (_ _ _ : nat -> R) (_ : nat) => 0 in
  let G3 := fun (_ _ _ _ : nat -> R) (_ : nat) => 0 in
  (forall g g' s, curve (S d) g g' s -> forall i, (i < S d)%nat ->
     is_derive (fun r => auto d F (g r) i) s (G1 (g s) g' i)) /\
  (forall g g' u u' s, curve (S d) g g' s -> curve (S d) u u' s -> forall i, (i < S d)%nat ->
     is_derive (fun r => G1 (g r) (u r) i) s (G2 (g s) g' (u s) i + G1 (g s) u' i)) /\
  (forall g g' u u' v v' s, curve (S d) g g' s -> curve (S d) u u' s -> curve (S d) v v' s ->
     forall i, (i < S d)%nat ->
     is_derive (fun r => G2 (g r) (u r) (v r) i) s
       (G3 (g s) g' (u s) (v s) i + G2 (g s) u' (v s) i + G2 (g s) (u s) v' i)) /\
  (forall x a0 b p q i,
     G1 x (fun j => p * a0 j + q * b j) i = p * G1 x a0 i + q * G1 x b i).
Proof.
  intros F G1 G2 G3. split; [| split; [| split]].
  - intros g g' s Hg i Hi. unfold G1.
    destruct (Nat.ltb_spec i d) as [Hid | Hid].
    + apply (is_derive_ext (fun r => a * g r i)); [intro r; unfold F; rewrite auto_lt by lia;
        reflexivity |].
      apply der_scal. exact (Hg i Hi).
    + assert (i = d) by lia. subst i.
      apply (is_derive_ext (fun _ => 1)); [intro r; rewrite auto_d; reflexivity |].
      apply der_const.
  - intros g g' u u' s Hg Hu i Hi. unfold G1, G2.
    destruct (Nat.ltb_spec i d) as [Hid | Hid].
    + apply (der_val _ _ (a * u' i)); [ring |]. apply der_scal. exact (Hu i Hi).
    + apply (der_val _ _ 0); [ring |]. apply der_const.
  - intros. unfold G2, G3. apply (der_val _ _ 0); [ring |]. apply der_const.
  - intros x a0 b p q i. unfold G1. destruct (Nat.ltb i d); ring.
Qed.
