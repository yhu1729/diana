From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core Plus_error Relative IEEE754.BinarySingleNaN IEEE754.Binary.
Import ListNotations.
Open Scope R_scope.

Abbreviation prec := 53%Z.
Abbreviation emax := 1024%Z.
Abbreviation emin := (-1074)%Z.
Abbreviation fexp := (FLT_exp emin prec).
Abbreviation b64 := (binary_float prec emax).

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Definition u : R := bpow radix2 (-53).
Definition eta : R := bpow radix2 (-1075).
Definition gamma (k : nat) : R := INR k * u / (1 - INR k * u).

Lemma u_pos : 0 < u.
Proof. apply bpow_gt_0. Qed.

Lemma eta_pos : 0 < eta.
Proof. apply bpow_gt_0. Qed.

Lemma half_bpow (e : Z) : / 2 * bpow radix2 (e + 1) = bpow radix2 e.
Proof. rewrite bpow_plus, bpow_1. change (IZR (radix_val radix2)) with 2. field. Qed.

Lemma u_ro_u : u_ro radix2 prec = u.
Proof. unfold u_ro, u. exact (half_bpow (-53)). Qed.

Lemma half_emin : / 2 * bpow radix2 emin = eta.
Proof. unfold eta. exact (half_bpow (-1075)). Qed.

Lemma gamma_0 : gamma 0 = 0.
Proof. unfold gamma. simpl. field. Qed.

Lemma gamma_nonneg (k : nat) : INR k * u < 1 -> 0 <= gamma k.
Proof.
  intro Hk. unfold gamma, Rdiv. apply Rmult_le_pos.
  - apply Rmult_le_pos; [apply pos_INR | left; apply u_pos].
  - left. apply Rinv_0_lt_compat. lra.
Qed.

Lemma gamma_step (k : nat) :
  INR (S k) * u < 1 -> gamma k * (1 + u) + u <= gamma (S k).
Proof.
  intro Hk. rewrite S_INR in Hk. unfold gamma. rewrite S_INR.
  pose proof u_pos as Hu. pose proof (pos_INR k) as Hk0.
  set (a := INR k * u) in *.
  assert (Ha : 0 <= a) by (unfold a; nra).
  replace ((INR k + 1) * u) with (a + u) by (unfold a; ring).
  replace ((INR k + 1) * u) with (a + u) in Hk by (unfold a; ring).
  replace (a / (1 - a) * (1 + u) + u) with ((a + u) / (1 - a)) by (field; lra).
  unfold Rdiv. apply Rmult_le_compat_l; [lra |].
  apply Rinv_le_contravar; lra.
Qed.

Lemma u_le_gamma_1 : 2 * u < 1 -> u <= gamma 1.
Proof.
  intro H2. pose proof (gamma_step 0) as Hs. rewrite gamma_0 in Hs.
  assert (INR 1 * u < 1) by (simpl; lra). lra.
Qed.

Lemma add_error (x y : R) :
  generic_format radix2 fexp x -> generic_format radix2 fexp y ->
  exists d, Rabs d <= u /\ round radix2 fexp ZnearestE (x + y) = (x + y) * (1 + d).
Proof.
  intros Hx Hy.
  destruct (FLT_plus_error_N_ex radix2 emin prec (fun z => negb (Z.even z)) x y Hx Hy)
    as [d [Hd Hr]].
  exists d. split; [| exact Hr]. rewrite u_ro_u in Hd. eapply Rle_trans; [exact Hd |].
  pose proof u_pos. apply Rmult_le_reg_r with (1 + u); [lra |].
  unfold Rdiv. rewrite Rmult_assoc, Rinv_l by lra. nra.
Qed.

Lemma round_error (x : R) :
  exists e d, Rabs e <= u /\ Rabs d <= eta /\
  round radix2 fexp ZnearestE x = x * (1 + e) + d.
Proof.
  destruct (error_N_FLT radix2 emin prec ltac:(lia) (fun z => negb (Z.even z)) x)
    as [e [d [He [Hd [_ Hr]]]]].
  exists e, d. rewrite half_emin in Hd. split; [| split; [exact Hd | exact Hr]].
  unfold u. rewrite <- (half_bpow (-53)). exact He.
Qed.

Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

Fixpoint rsum (m : list b64) : R :=
  match m with [] => 0 | a :: t => r a + rsum t end.

Fixpoint rabs_sum (m : list b64) : R :=
  match m with [] => 0 | a :: t => Rabs (r a) + rabs_sum t end.

Lemma rabs_sum_nonneg (m : list b64) : 0 <= rabs_sum m.
Proof. induction m as [|a m IH]; simpl; [lra | pose proof (Rabs_pos (r a)); lra]. Qed.

Lemma rsum_abs (m : list b64) : Rabs (rsum m) <= rabs_sum m.
Proof.
  induction m as [|a m IH]; simpl.
  - rewrite Rabs_R0. lra.
  - eapply Rle_trans; [apply Rabs_triang | lra].
Qed.

Section Op.

Variable plus_nan mult_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Definition fadd (x y : b64) : b64 := Bplus prec emax _ _ plus_nan mode_NE x y.
Definition fmul (x y : b64) : b64 := Bmult prec emax _ _ mult_nan mode_NE x y.

Lemma fadd_finite_inv (x y : b64) : fin (fadd x y) -> fin x /\ fin y.
Proof.
  unfold fadd, Bplus. rewrite is_finite_BSN2B.
  destruct x as [sx|sx|sx plx Hx|sx mx ex Hx]; destruct y as [sy|sy|sy ply Hy|sy my ey Hy];
    intro H; try (split; reflexivity); simpl in H; try discriminate.
  destruct (Bool.eqb sx sy); discriminate.
Qed.

Lemma fadd_value (x y : b64) :
  fin (fadd x y) -> r (fadd x y) = round radix2 fexp ZnearestE (r x + r y).
Proof.
  intro H. destruct (fadd_finite_inv x y H) as [Hx Hy].
  pose proof (Bplus_correct prec emax _ _ plus_nan mode_NE x y Hx Hy) as Hc.
  change (SpecFloat.fexp 53 1024) with fexp in Hc.
  change (round_mode mode_NE) with ZnearestE in Hc.
  revert Hc. case Rlt_bool; intro Hc.
  - exact (proj1 Hc).
  - exfalso. destruct Hc as [Hovf _]. unfold fadd in H.
    rewrite <- is_finite_B2FF, Hovf in H. discriminate.
Qed.

Lemma fmul_value (x y : b64) :
  fin (fmul x y) -> fin x /\ fin y /\ r (fmul x y) = round radix2 fexp ZnearestE (r x * r y).
Proof.
  intro H. pose proof (Bmult_correct prec emax _ _ mult_nan mode_NE x y) as Hc.
  change (SpecFloat.fexp 53 1024) with fexp in Hc.
  change (round_mode mode_NE) with ZnearestE in Hc.
  revert Hc. case Rlt_bool; intro Hc.
  - destruct Hc as [Hv [Hf _]]. unfold fmul in H. rewrite Hf in H.
    destruct (andb_prop _ _ H) as [Hx Hy]. auto.
  - exfalso. unfold fmul in H. rewrite <- is_finite_B2FF, Hc in H. discriminate.
Qed.

Lemma fold_finite_inv (m : list b64) (s : b64) :
  fin (fold_left fadd m s) -> fin s /\ Forall (fun x => fin x) m.
Proof.
  revert s. induction m as [|a m IH]; intros s H; simpl in H.
  - split; [exact H | constructor].
  - destruct (IH _ H) as [Hs Hm]. destruct (fadd_finite_inv _ _ Hs) as [H1 H2].
    split; [exact H1 | constructor; assumption].
Qed.

Lemma fold_error (m : list b64) :
  forall (s : b64) (X Rb : R) (j : nat),
  fin (fold_left fadd m s) ->
  Rabs (r s - X) <= gamma (S j) * Rb + (1 + gamma j) * eta ->
  Rabs X <= Rb ->
  INR (S j + length m) * u < 1 ->
  Rabs (r (fold_left fadd m s) - (X + rsum m))
    <= gamma (S j + length m) * (Rb + rabs_sum m) + (1 + gamma (j + length m)) * eta.
Proof.
  induction m as [|a m IH]; intros s X Rb j Hfin He HX Hn; simpl in Hfin |- *.
  - rewrite !Nat.add_0_r, !Rplus_0_r. exact He.
  - assert (Hsa : fin (fadd s a)) by exact (proj1 (fold_finite_inv _ _ Hfin)).
    destruct (fadd_finite_inv _ _ Hsa) as [Hs Ha].
    pose proof (fadd_value _ _ Hsa) as Hv.
    destruct (add_error (r s) (r a) (generic_format_B2R prec emax s) (generic_format_B2R prec emax a))
      as [d [Hd Hrd]].
    replace (X + (r a + rsum m)) with (X + r a + rsum m) by ring.
    replace (Rb + (Rabs (r a) + rabs_sum m)) with (Rb + Rabs (r a) + rabs_sum m) by ring.
    replace (S j + S (length m))%nat with (S (S j) + length m)%nat by lia.
    replace (j + S (length m))%nat with (S j + length m)%nat by lia.
    replace (S j + length (a :: m))%nat with (S (S j) + length m)%nat in Hn by (simpl; lia).
    apply IH; [exact Hfin | | | exact Hn].
    + rewrite Hv, Hrd.
      assert (Hn1 : INR (S (S j)) * u < 1).
      { eapply Rle_lt_trans; [| exact Hn]. apply Rmult_le_compat_r; [left; apply u_pos |].
        apply le_INR. lia. }
      assert (Hn0 : INR (S j) * u < 1).
      { eapply Rle_lt_trans; [| exact Hn1]. apply Rmult_le_compat_r; [left; apply u_pos |].
        apply le_INR. lia. }
      pose proof (gamma_step _ Hn1) as Hg1. pose proof (gamma_step _ Hn0) as Hg0.
      pose proof (gamma_nonneg _ Hn0) as Hg1p.
      pose proof u_pos as Hu. pose proof eta_pos as Heta.
      pose proof (Rabs_pos (r a)) as Hap.
      set (e := r s - X) in *.
      set (E := gamma (S j) * Rb + (1 + gamma j) * eta) in *.
      assert (HRb : 0 <= Rb) by (eapply Rle_trans; [apply Rabs_pos | exact HX]).
      replace ((r s + r a) * (1 + d) - (X + r a)) with (e + d * (e + X + r a)) by (unfold e; ring).
      assert (Hdterm : Rabs (d * (e + X + r a)) <= u * (E + Rb + Rabs (r a))).
      { rewrite Rabs_mult. apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | exact Hd |].
        eapply Rle_trans; [apply Rabs_triang |]. apply Rplus_le_compat; [| lra].
        eapply Rle_trans; [apply Rabs_triang | lra]. }
      eapply Rle_trans; [apply Rabs_triang |].
      assert (H1 : (gamma (S j) * (1 + u) + u) * (Rb + Rabs (r a))
                   <= gamma (S (S j)) * (Rb + Rabs (r a)))
        by (apply Rmult_le_compat_r; lra).
      assert (H2 : (gamma j * (1 + u) + u) * eta <= gamma (S j) * eta)
        by (apply Rmult_le_compat_r; lra).
      assert (H3 : 0 <= gamma (S j) * (1 + u) * Rabs (r a))
        by (apply Rmult_le_pos; [apply Rmult_le_pos; lra | exact Hap]).
      unfold E in *. nra.
    + eapply Rle_trans; [apply Rabs_triang | lra].
Qed.

End Op.

Arguments fadd_finite_inv {plus_nan} x y _.
Arguments fadd_value {plus_nan} x y _.
Arguments fmul_value {mult_nan} x y _.
Arguments fold_finite_inv {plus_nan} m s _.
Arguments fold_error {plus_nan} m s X Rb j _ _ _ _.
