From Stdlib Require Import Reals ZArith Lia Lra Psatz.
From Flocq Require Import Core Relative IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Real Require Import Cholesky.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Section Model.

Variable sub_nan mult_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.
Variable sqrt_nan : b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fdiv := (Diana.Float.Sum.fdiv div_nan).
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

Definition fsub (x y : b64) : b64 := Bminus prec emax _ _ sub_nan mode_NE x y.
Definition fsqrt (x : b64) : b64 := Bsqrt prec emax _ _ sqrt_nan mode_NE x.
Definition fzero : b64 := B754_zero prec emax false.

(* The C test s > 0.0: s is not NaN and positive, possibly +inf. *)
Definition positive (x : b64) : Prop := Bcompare prec emax x fzero = Some Gt.

(* s - L i 0 * L j 0 - ... - L i (k-1) * L j (k-1), each product rounded, subtracted in order. *)
Fixpoint fdot (L : nat -> nat -> b64) (s : b64) (i j k : nat) : b64 :=
  match k with
  | O => s
  | S k' => fsub (fdot L s i j k') (fmul (L i k') (L j k'))
  end.

Definition fpivot (A L : nat -> nat -> b64) (j : nat) : b64 := fdot L (A j j) j j j.

Definition fcolumn (A L : nat -> nat -> b64) (j i : nat) : b64 :=
  if (i <? j)%nat then fzero
  else if (i =? j)%nat then fsqrt (fpivot A L j)
  else fdiv (fdot L (A i j) i j j) (fsqrt (fpivot A L j)).

Fixpoint ffactor (A : nat -> nat -> b64) (m : nat) : nat -> nat -> b64 :=
  match m with
  | O => fun _ _ => fzero
  | S m' => fun i k => if (k =? m')%nat then fcolumn A (ffactor A m') m' i else ffactor A m' i k
  end.

(* The binary64 model of the kernel: entry (i, k) of the factor, column k computed from columns
   0, ..., k - 1 in the C's operation order; A i j is a[i + j*n]. *)
Definition fchol (A : nat -> nat -> b64) (i k : nat) : b64 := ffactor A (S k) i k.

(* The pivot the C tests before column j. *)
Definition fpiv (A : nat -> nat -> b64) (j : nat) : b64 := fpivot A (fchol A) j.

Lemma fdot_congr (L L' : nat -> nat -> b64) (s : b64) (i j k : nat) :
  (forall i' k', (k' < k)%nat -> L i' k' = L' i' k') -> fdot L s i j k = fdot L' s i j k.
Proof.
  induction k as [| k IH]; intro H; simpl; [reflexivity |].
  rewrite IH by (intros; apply H; lia). rewrite !H by lia. reflexivity.
Qed.

Lemma ffactor_eq (A : nat -> nat -> b64) (m i k : nat) :
  (k < m)%nat -> ffactor A m i k = fchol A i k.
Proof.
  revert i k. induction m as [| m IH]; intros i k Hk; [lia |].
  destruct (Nat.eq_dec k m) as [-> | Hne]; [reflexivity |].
  simpl. replace (k =? m)%nat with false by (symmetry; apply Nat.eqb_neq; exact Hne).
  apply IH. lia.
Qed.

Lemma fcolumn_congr (A L L' : nat -> nat -> b64) (j i : nat) :
  (forall i' k, (k < j)%nat -> L i' k = L' i' k) -> fcolumn A L j i = fcolumn A L' j i.
Proof.
  intro H. unfold fcolumn, fpivot. rewrite !(fdot_congr L L') by exact H. reflexivity.
Qed.

Lemma fchol_eq (A : nat -> nat -> b64) (i j : nat) : fchol A i j = fcolumn A (fchol A) j i.
Proof.
  unfold fchol at 1. simpl. rewrite Nat.eqb_refl.
  apply fcolumn_congr. intros i' k Hk. apply ffactor_eq. exact Hk.
Qed.

Lemma fchol_upper (A : nat -> nat -> b64) (i j : nat) : (i < j)%nat -> fchol A i j = fzero.
Proof.
  intro H. rewrite fchol_eq. unfold fcolumn.
  replace (i <? j)%nat with true by (symmetry; apply Nat.ltb_lt; exact H). reflexivity.
Qed.

Lemma fchol_diag (A : nat -> nat -> b64) (j : nat) : fchol A j j = fsqrt (fpiv A j).
Proof.
  rewrite fchol_eq. unfold fcolumn, fpiv. rewrite Nat.ltb_irrefl, Nat.eqb_refl. reflexivity.
Qed.

Lemma fchol_lower (A : nat -> nat -> b64) (i j : nat) :
  (j < i)%nat -> fchol A i j = fdiv (fdot (fchol A) (A i j) i j j) (fchol A j j).
Proof.
  intro H. rewrite fchol_eq, fchol_diag. unfold fcolumn, fpiv.
  replace (i <? j)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
  replace (i =? j)%nat with false by (symmetry; apply Nat.eqb_neq; lia). reflexivity.
Qed.

(* Operations *)

Lemma fsub_finite_inv (x y : b64) : fin (fsub x y) -> fin x /\ fin y.
Proof.
  unfold fsub, Bminus. rewrite is_finite_BSN2B.
  destruct x as [sx|sx|sx plx Hx|sx mx ex Hx]; destruct y as [sy|sy|sy ply Hy|sy my ey Hy];
    intro H; try (split; reflexivity); simpl in H; try discriminate.
  destruct (Bool.eqb sx (negb sy)); discriminate.
Qed.

Lemma fsub_value (x y : b64) :
  fin (fsub x y) -> r (fsub x y) = round radix2 fexp ZnearestE (r x - r y).
Proof.
  intro H. destruct (fsub_finite_inv x y H) as [Hx Hy].
  pose proof (Bminus_correct prec emax _ _ sub_nan mode_NE x y Hx Hy) as Hc.
  change (SpecFloat.fexp 53 1024) with fexp in Hc.
  change (round_mode mode_NE) with ZnearestE in Hc.
  revert Hc. case Rlt_bool; intro Hc.
  - exact (proj1 Hc).
  - exfalso. destruct Hc as [Hovf _]. unfold fsub in H.
    rewrite <- is_finite_B2FF, Hovf in H. discriminate.
Qed.

Lemma positive_cases (x : b64) :
  positive x -> x = B754_infinity prec emax false \/ (fin x /\ 0 < r x).
Proof.
  unfold positive, fzero.
  destruct x as [s|s|s pl Hpl|s m e He]; destruct s; simpl; intro H; try discriminate.
  - left. reflexivity.
  - right. split; [reflexivity |]. apply F2R_gt_0. simpl. lia.
Qed.

Lemma finite_positive (x : b64) : fin x -> 0 < r x -> positive x.
Proof.
  intros Hx Hr. unfold positive.
  rewrite (Bcompare_correct prec emax x fzero Hx eq_refl).
  unfold fzero. simpl B2R. rewrite Rcompare_Gt by exact Hr. reflexivity.
Qed.

Lemma r_pos_ge_emin (x : b64) : fin x -> 0 < r x -> bpow radix2 emin <= r x.
Proof.
  destruct x as [s|s|s pl Hpl|s m e He]; intros Hf Hr; try discriminate.
  - simpl in Hr. lra.
  - destruct s.
    + exfalso.
      assert (H0 : r (B754_finite prec emax true m e He) < 0) by (apply F2R_lt_0; reflexivity).
      lra.
    + exact (bounded_ge_emin prec emax m e He).
Qed.

Lemma round_sqrt_ge (x : R) :
  bpow radix2 emin <= x -> bpow radix2 (-537) <= round radix2 fexp ZnearestE (sqrt x).
Proof.
  intro Hx.
  rewrite <- (round_generic radix2 fexp ZnearestE (bpow radix2 (-537))).
  - apply round_le; try typeclasses eauto.
    rewrite <- (sqrt_bpow radix2 (-537)). apply sqrt_le_1_alt. exact Hx.
  - apply generic_format_bpow. unfold FLT_exp. simpl. lia.
Qed.

(* Layer B, discharges the contract of diana_fp_sqrt in src/fp_sqrt.h, which WP assumes:
   for x > 0 (IEEE, so not NaN), a finite x gives the finite, positive, correctly rounded
   square root, and +inf gives +inf. *)
Theorem sqrt_contract (x : b64) :
  positive x ->
  (fin x -> fin (fsqrt x) /\ 0 < r (fsqrt x) /\
            r (fsqrt x) = round radix2 fexp ZnearestE (sqrt (r x))) /\
  (x = B754_infinity prec emax false -> fsqrt x = B754_infinity prec emax false).
Proof.
  intro Hp. split.
  - intro Hf. destruct (positive_cases x Hp) as [-> | [_ Hr]]; [discriminate |].
    pose proof (Bsqrt_correct prec emax _ _ sqrt_nan mode_NE x) as [Hv [Hfin _]].
    change (SpecFloat.fexp 53 1024) with fexp in Hv.
    change (round_mode mode_NE) with ZnearestE in Hv.
    split; [| split].
    + unfold fsqrt. rewrite Hfin.
      destruct x as [s|s|s pl Hpl|s m e He]; try discriminate; try (simpl in Hr; lra).
      destruct s; [| reflexivity].
      assert (H0 : r (B754_finite prec emax true m e He) < 0) by (apply F2R_lt_0; reflexivity).
      lra.
    + unfold fsqrt. rewrite Hv. pose proof (round_sqrt_ge (r x) (r_pos_ge_emin x Hf Hr)).
      pose proof (bpow_gt_0 radix2 (-537)). lra.
    + exact Hv.
  - intros ->. reflexivity.
Qed.

(* Classes of values met while subtracting squares from a finite pivot. *)
Definition pinf (x : b64) : Prop := x = B754_infinity prec emax false.
Definition bad (x : b64) : Prop := is_nan prec emax x = true \/ x = B754_infinity prec emax true.
Definition nonneg (x : b64) : Prop := is_nan prec emax x = true \/ Bsign prec emax x = false.

Lemma B2FF_ninf (z : b64) : B2FF prec emax z = F754_infinity true -> z = B754_infinity prec emax true.
Proof. intro H. apply (B2FF_inj prec emax). rewrite H. reflexivity. Qed.

Lemma fmul_sq_nonneg (x : b64) : nonneg (fmul x x).
Proof.
  unfold nonneg. destruct (is_nan prec emax (fmul x x)) eqn:Hn; [left; reflexivity | right].
  pose proof (Bmult_correct prec emax _ _ mult_nan mode_NE x x) as Hc.
  rewrite Bool.xorb_nilpotent in Hc.
  revert Hc. case Rlt_bool; intro Hc.
  - destruct Hc as [_ [_ Hs]]. exact (Hs Hn).
  - assert (E : B2FF prec emax (fmul x x) = B2FF prec emax (B754_infinity prec emax false))
      by exact Hc.
    rewrite (B2FF_inj prec emax _ _ E). reflexivity.
Qed.

Lemma fmul_sq_nonfinite (x : b64) :
  ~ fin x -> is_nan prec emax (fmul x x) = true \/ pinf (fmul x x).
Proof.
  intro Hx. unfold pinf, Diana.Float.Sum.fmul, Bmult.
  destruct x as [s|s|s pl Hpl|s m e He]; try (exfalso; apply Hx; reflexivity).
  - right. destruct s; reflexivity.
  - left. rewrite is_nan_BSN2B. reflexivity.
Qed.

Lemma fsub_nan_l (s p : b64) : is_nan prec emax s = true -> is_nan prec emax (fsub s p) = true.
Proof.
  intro H. unfold fsub, Bminus. rewrite is_nan_BSN2B.
  destruct s; try discriminate. destruct p; reflexivity.
Qed.

Lemma fsub_nan_r (s p : b64) : is_nan prec emax p = true -> is_nan prec emax (fsub s p) = true.
Proof.
  intro H. unfold fsub, Bminus. rewrite is_nan_BSN2B.
  destruct p; try discriminate. destruct s as [| [|] | |]; reflexivity.
Qed.

Lemma fsub_finite_cases (s p : b64) :
  fin s -> fin p -> Bsign prec emax p = false -> fin (fsub s p) \/ fsub s p = B754_infinity prec emax true.
Proof.
  intros Hs Hp Hsg.
  pose proof (Bminus_correct prec emax _ _ sub_nan mode_NE s p Hs Hp) as Hc.
  revert Hc. case Rlt_bool; intro Hc.
  - left. exact (proj1 (proj2 Hc)).
  - right. destruct Hc as [Hovf Hsign]. rewrite Hsg in Hsign. rewrite Hsign in Hovf.
    exact (B2FF_ninf _ Hovf).
Qed.

Lemma fsub_not_pinf (s p : b64) : ~ pinf s -> nonneg p -> ~ pinf (fsub s p).
Proof.
  unfold pinf, nonneg. intros Hs Hp E.
  destruct (is_nan prec emax s) eqn:Hsn.
  { pose proof (fsub_nan_l s p Hsn) as H. rewrite E in H. discriminate. }
  destruct (is_nan prec emax p) eqn:Hpn.
  { pose proof (fsub_nan_r s p Hpn) as H. rewrite E in H. discriminate. }
  destruct Hp as [Hp | Hp]; [discriminate |].
  destruct (is_finite prec emax s) eqn:Hsf.
  - destruct (is_finite prec emax p) eqn:Hpf.
    + destruct (fsub_finite_cases s p Hsf Hpf Hp) as [Hf | Hf]; rewrite E in Hf; discriminate.
    + destruct p as [sp|sp|sp plp Hplp|sp mp ep Hep]; try discriminate.
      simpl in Hp. subst sp.
      destruct s; try discriminate; unfold fsub, Bminus in E; simpl in E; discriminate.
  - destruct s as [ss|ss|ss pls Hpls|ss ms es Hes]; try discriminate.
    destruct ss; [| exact (Hs eq_refl)].
    destruct p as [sp|sp|sp plp Hplp|sp mp ep Hep]; try discriminate;
      unfold fsub, Bminus in E; simpl in E; try discriminate.
    simpl in Hp. subst sp. discriminate.
Qed.

Lemma fsub_bad (s p : b64) : bad s -> nonneg p -> bad (fsub s p).
Proof.
  unfold bad, nonneg. intros [Hs | Hs] Hp; [left; apply fsub_nan_l; exact Hs |].
  subst s. destruct (is_nan prec emax p) eqn:Hpn; [left; apply fsub_nan_r; exact Hpn |].
  destruct Hp as [Hp | Hp]; [discriminate |].
  destruct p as [sp|sp|sp plp Hplp|sp mp ep Hep]; try discriminate;
    unfold fsub, Bminus; simpl; try (right; reflexivity).
  simpl in Hp. subst sp. right. reflexivity.
Qed.

Lemma fsub_make_bad (s p : b64) :
  ~ pinf s -> is_nan prec emax p = true \/ pinf p -> bad (fsub s p).
Proof.
  unfold bad, pinf. intros Hs [Hp | Hp]; [left; apply fsub_nan_r; exact Hp |]. subst p.
  destruct (is_nan prec emax s) eqn:Hsn; [left; apply fsub_nan_l; exact Hsn |].
  destruct s as [ss|ss|ss pls Hpls|ss ms es Hes]; try discriminate;
    unfold fsub, Bminus; simpl; try (right; reflexivity).
  destruct ss; [right; reflexivity | exfalso; exact (Hs eq_refl)].
Qed.

Lemma positive_not_bad (x : b64) : positive x -> ~ bad x.
Proof.
  unfold positive, bad, fzero. intros Hp [Hn | Hn].
  - destruct x; try discriminate.
  - subst x. discriminate.
Qed.

Lemma fdot_not_pinf (L : nat -> nat -> b64) (s : b64) (i k : nat) :
  ~ pinf s -> ~ pinf (fdot L s i i k).
Proof.
  intro Hs. induction k as [| k IH]; simpl; [exact Hs |].
  apply fsub_not_pinf; [exact IH | apply fmul_sq_nonneg].
Qed.

Lemma fdot_bad (L : nat -> nat -> b64) (s : b64) (i k m : nat) :
  ~ pinf s -> (m < k)%nat -> ~ fin (L i m) -> bad (fdot L s i i k).
Proof.
  intros Hs Hm Hf. induction k as [| k IH]; [lia |]. simpl.
  destruct (Nat.eq_dec m k) as [-> | Hne].
  - apply fsub_make_bad; [apply fdot_not_pinf; exact Hs | apply fmul_sq_nonfinite; exact Hf].
  - apply fsub_bad; [apply IH; lia | apply fmul_sq_nonneg].
Qed.

Lemma fin_not_pinf (x : b64) : fin x -> ~ pinf x.
Proof. unfold pinf. intros H E. subst x. discriminate. Qed.

(* Layer B, finiteness: with finite inputs on and below the diagonal and every pivot positive
   (the C's DIANA_OK), every entry of the binary64 factor is finite. A non-finite L i j, j < i,
   would make the pivot of column i -inf or NaN; a pivot never overflows to +inf, since only
   squares are subtracted from the finite A j j. *)
Theorem finite_result (A : nat -> nat -> b64) (n : nat) :
  (forall i j, (j <= i)%nat -> (i < n)%nat -> fin (A i j)) ->
  (forall j, (j < n)%nat -> positive (fpiv A j)) ->
  forall i j, (i < n)%nat -> (j < n)%nat -> fin (fchol A i j).
Proof.
  intros HA Hp i j Hi Hj.
  destruct (Nat.lt_trichotomy i j) as [Hlt | [-> | Hgt]].
  - rewrite fchol_upper by exact Hlt. reflexivity.
  - rewrite fchol_diag.
    destruct (positive_cases _ (Hp j Hj)) as [Hinf | [Hf Hr]].
    + exfalso. revert Hinf. apply fdot_not_pinf, fin_not_pinf, HA; lia.
    + exact (proj1 (proj1 (sqrt_contract _ (Hp j Hj)) Hf)).
  - destruct (is_finite prec emax (fchol A i j)) eqn:Hf; [reflexivity | exfalso].
    apply (positive_not_bad _ (Hp i Hi)). unfold fpiv, fpivot.
    apply (fdot_bad _ _ i i j); [apply fin_not_pinf, HA; lia | exact Hgt |].
    rewrite Hf. discriminate.
Qed.

(* Rounding errors of the four operations. *)

Lemma sub_error (x y : b64) :
  fin (fsub x y) -> exists d, Rabs d <= u /\ r (fsub x y) = (r x - r y) * (1 + d).
Proof.
  intro H. rewrite (fsub_value x y H). replace (r x - r y) with (r x + - r y) by ring.
  apply add_error; [apply generic_format_B2R | apply generic_format_opp, generic_format_B2R].
Qed.

Lemma mul_error (x y : b64) :
  fin (fmul x y) ->
  exists d e, Rabs d <= u /\ Rabs e <= eta /\ r (fmul x y) = r x * r y * (1 + d) + e.
Proof.
  intro H. destruct (fmul_value x y H) as [_ [_ Hv]]. rewrite Hv.
  destruct (round_error (r x * r y)) as [d [e [Hd [He Hr]]]]. exists d, e. auto.
Qed.

Lemma div_error (x y : b64) :
  fin (fdiv x y) -> r y <> 0 ->
  exists d e, Rabs d <= u /\ Rabs e <= eta /\ r (fdiv x y) = r x / r y * (1 + d) + e.
Proof.
  intros H Hy. rewrite (fdiv_value x y H Hy).
  destruct (round_error (r x / r y)) as [d [e [Hd [He Hr]]]]. exists d, e. auto.
Qed.

Lemma sqrt_error (x : b64) :
  fin x -> 0 < r x -> exists d, Rabs d <= u /\ r (fsqrt x) = sqrt (r x) * (1 + d).
Proof.
  intros Hf Hr. pose proof (Bsqrt_correct prec emax _ _ sqrt_nan mode_NE x) as [Hv _].
  change (SpecFloat.fexp 53 1024) with fexp in Hv.
  change (round_mode mode_NE) with ZnearestE in Hv.
  unfold fsqrt. rewrite Hv.
  destruct (relative_error_N_FLT_ex radix2 emin prec ltac:(lia) (fun z => negb (Z.even z))
              (sqrt (r x))) as [d [Hd Hrd]].
  - rewrite Rabs_pos_eq by apply sqrt_pos.
    apply Rle_trans with (bpow radix2 (-537)); [apply bpow_le; lia |].
    rewrite <- (sqrt_bpow radix2 (-537)). apply sqrt_le_1_alt. exact (r_pos_ge_emin x Hf Hr).
  - exists d. split; [| exact Hrd]. unfold u. rewrite <- (half_bpow (-53)). exact Hd.
Qed.

(* Higham's factors: a product of k factors (1 + d)^(+-1), |d| <= u, is within gamma k of 1. *)

Lemma gamma_lt (k : nat) : INR (S k) * u < 1 -> INR k * u < 1.
Proof.
  intro H. eapply Rle_lt_trans; [| exact H]. apply Rmult_le_compat_r; [left; apply u_pos |].
  apply le_INR. lia.
Qed.

Lemma factor_mul (F d : R) (k : nat) :
  Rabs (F - 1) <= gamma k -> Rabs d <= u -> INR (S k) * u < 1 ->
  Rabs (F * (1 + d) - 1) <= gamma (S k).
Proof.
  intros HF Hd Hk. pose proof (gamma_step k Hk) as Hs. pose proof u_pos.
  pose proof (gamma_nonneg k (gamma_lt k Hk)) as Hg.
  replace (F * (1 + d) - 1) with ((F - 1) * (1 + d) + d) by ring.
  eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult.
  assert (H1 : Rabs (1 + d) <= 1 + u).
  { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_R1. lra. }
  assert (H2 : Rabs (F - 1) * Rabs (1 + d) <= gamma k * (1 + u))
    by (apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | exact HF | exact H1]).
  lra.
Qed.

Lemma factor_div (F d : R) (k : nat) :
  Rabs (F - 1) <= gamma k -> Rabs d <= u -> INR (S k) * u < 1 ->
  Rabs (F / (1 + d) - 1) <= gamma (S k).
Proof.
  intros HF Hd Hk. pose proof u_pos as Hu.
  pose proof (gamma_nonneg k (gamma_lt k Hk)) as Hg.
  assert (Hu1 : u < 1).
  { eapply Rle_lt_trans; [| exact Hk]. rewrite S_INR. pose proof (pos_INR k). nra. }
  assert (Hd1 : 1 - u <= Rabs (1 + d)).
  { pose proof (Rabs_triang_inv 1 (- d)) as H. rewrite Rabs_R1, Rabs_Ropp in H.
    replace (1 - - d) with (1 + d) in H by ring. lra. }
  assert (H1 : Rabs (F / (1 + d) - 1) <= (gamma k + u) / (1 - u)).
  { assert (Hnz : 1 + d <> 0) by (intro E; rewrite E, Rabs_R0 in Hd1; lra).
    replace (F / (1 + d) - 1) with ((F - 1 - d) / (1 + d)) by (field; exact Hnz).
    unfold Rdiv. rewrite Rabs_mult, Rabs_inv.
    apply Rmult_le_compat; [apply Rabs_pos | left; apply Rinv_0_lt_compat; lra | |].
    - replace (F - 1 - d) with ((F - 1) + - d) by ring.
      eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_Ropp. lra.
    - apply Rinv_le_contravar; lra. }
  assert (H2 : (gamma k + u) / (1 - u) <= gamma (S k)).
  { unfold gamma. rewrite S_INR. set (a := INR k * u).
    replace ((INR k + 1) * u) with (a + u) in * by (unfold a; ring).
    rewrite S_INR in Hk. replace ((INR k + 1) * u) with (a + u) in Hk by (unfold a; ring).
    assert (Ha : 0 <= a) by (unfold a; apply Rmult_le_pos; [apply pos_INR | lra]).
    assert (E : (a + u) / (1 - (a + u)) - (a / (1 - a) + u) / (1 - u)
                = a * u / ((1 - a) * (1 - u) * (1 - (a + u)))) by (field; repeat split; lra).
    assert (P : 0 <= a * u / ((1 - a) * (1 - u) * (1 - (a + u)))).
    { apply Rmult_le_pos; [nra |]. left. apply Rinv_0_lt_compat.
      apply Rmult_lt_0_compat; [apply Rmult_lt_0_compat |]; lra. }
    lra. }
  lra.
Qed.

(* The subtractions s - L i 0 * L j 0 - ... of the C: their backward error. *)
Lemma dot_error (L : nat -> nat -> b64) (c : b64) (i j k : nat) :
  fin (fdot L c i j k) -> INR k * u < 1 ->
  exists F, Rabs (F - 1) <= gamma k /\
    Rabs (r c - sum k (fun m => r (L i m) * r (L j m)) - r (fdot L c i j k) * F)
      <= gamma k * sum k (fun m => Rabs (r (L i m) * r (L j m))) + (1 + gamma k) * INR k * eta.
Proof.
  induction k as [| k IH]; intros Hf Hk.
  - exists 1. simpl. rewrite gamma_0.
    replace (r c - 0 - r c * 1) with 0 by ring. replace (1 - 1) with 0 by ring.
    rewrite Rabs_R0. lra.
  - simpl in Hf. destruct (fsub_finite_inv _ _ Hf) as [Hs Hq].
    pose proof (gamma_lt k Hk) as Hk0.
    destruct (IH Hs Hk0) as [F [HF Hb]].
    destruct (sub_error _ _ Hf) as [e [He Hre]].
    destruct (mul_error _ _ Hq) as [dl [el [Hdl [Hel Hrq]]]].
    exists (F / (1 + e)). split; [apply factor_div; assumption |].
    pose proof u_pos as Hu. pose proof eta_pos as Heta.
    assert (Hu1 : u < 1).
    { eapply Rle_lt_trans; [| exact Hk]. rewrite S_INR. pose proof (pos_INR k). nra. }
    assert (Hnz : 1 + e <> 0) by (pose proof (Rabs_le_inv _ _ He); lra).
    pose proof (gamma_step k Hk) as Hgs. pose proof (gamma_nonneg k Hk0) as Hg.
    pose proof (factor_mul F dl k HF Hdl Hk) as HFm.
    simpl sum. change (fdot L c i j (S k)) with (fsub (fdot L c i j k) (fmul (L i k) (L j k))).
    set (t := r (L i k) * r (L j k)) in *.
    set (s := fdot L c i j k) in *.
    set (S0 := sum k (fun m => r (L i m) * r (L j m))) in *.
    set (A0 := sum k (fun m => Rabs (r (L i m) * r (L j m)))) in *.
    rewrite Hre, Hrq.
    replace (r c - (S0 + t) - (r s - (t * (1 + dl) + el)) * (1 + e) * (F / (1 + e)))
      with ((r c - S0 - r s * F) + t * (F * (1 + dl) - 1) + F * el) by (field; exact Hnz).
    assert (HF1 : Rabs F <= 1 + gamma k).
    { replace F with ((F - 1) + 1) by ring. eapply Rle_trans; [apply Rabs_triang |].
      rewrite Rabs_R1. lra. }
    assert (T2 : Rabs (t * (F * (1 + dl) - 1)) <= Rabs t * gamma (S k)).
    { rewrite Rabs_mult. apply Rmult_le_compat_l; [apply Rabs_pos | exact HFm]. }
    assert (T3 : Rabs (F * el) <= (1 + gamma k) * eta).
    { rewrite Rabs_mult. apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | exact HF1 |
        exact Hel]. }
    assert (HA0 : 0 <= A0) by (apply sum_nonneg; intros; apply Rabs_pos).
    pose proof (gamma_mono k (S k) ltac:(lia) Hk) as Hmono.
    assert (G1 : gamma k * A0 <= gamma (S k) * A0) by (apply Rmult_le_compat_r; lra).
    assert (G2 : (1 + gamma k) * INR k * eta <= (1 + gamma (S k)) * INR k * eta).
    { apply Rmult_le_compat_r; [lra |]. apply Rmult_le_compat_r; [apply pos_INR | lra]. }
    assert (G3 : (1 + gamma k) * eta <= (1 + gamma (S k)) * eta)
      by (apply Rmult_le_compat_r; lra).
    rewrite S_INR.
    eapply Rle_trans; [apply Rabs_triang |].
    eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
    nra.
Qed.

Lemma fpiv_finite (A : nat -> nat -> b64) (j : nat) :
  fin (A j j) -> positive (fpiv A j) -> fin (fpiv A j) /\ 0 < r (fpiv A j).
Proof.
  intros HA Hp. destruct (positive_cases _ Hp) as [Hinf | H]; [| exact H].
  exfalso. revert Hinf. unfold fpiv, fpivot. apply fdot_not_pinf, fin_not_pinf, HA.
Qed.

(* Layer B, backward error: with finite inputs on and below the diagonal and every pivot
   positive, each entry i >= j of the binary64 factor L satisfies
   |A i j - sum_{k<=j} L i k * L j k|
     <= gamma (j + 2) * sum_{k<=j} |L i k * L j k| + (1 + gamma (j + 2)) * (j + |L j j|) * eta,
   Higham's componentwise bound (gamma (n + 1) for the whole matrix) with the underflow terms of
   the products and of the division. *)
Theorem backward_error (A : nat -> nat -> b64) (n i j : nat) :
  (forall i j, (j <= i)%nat -> (i < n)%nat -> fin (A i j)) ->
  (forall j, (j < n)%nat -> positive (fpiv A j)) ->
  (j <= i)%nat -> (i < n)%nat -> INR (S (S j)) * u < 1 ->
  Rabs (r (A i j) - sum (S j) (fun k => r (fchol A i k) * r (fchol A j k)))
    <= gamma (S (S j)) * sum (S j) (fun k => Rabs (r (fchol A i k) * r (fchol A j k)))
       + (1 + gamma (S (S j))) * (INR j + Rabs (r (fchol A j j))) * eta.
Proof.
  intros HA Hp Hji Hi Hk.
  pose proof (gamma_lt _ Hk) as Hk1. pose proof (gamma_lt _ Hk1) as Hk0.
  pose proof u_pos as Hu. pose proof eta_pos as Heta.
  assert (Hu1 : u < 1).
  { eapply Rle_lt_trans; [| exact Hk]. rewrite !S_INR. pose proof (pos_INR j). nra. }
  pose proof (gamma_nonneg _ Hk0) as Hg0. pose proof (gamma_nonneg _ Hk1) as Hg1.
  pose proof (gamma_nonneg _ Hk) as Hg2.
  pose proof (gamma_mono j (S j) ltac:(lia) Hk1) as M01.
  pose proof (gamma_mono (S j) (S (S j)) ltac:(lia) Hk) as M12.
  simpl sum.
  set (L := fchol A).
  destruct (fpiv_finite A j (HA j j ltac:(lia) ltac:(lia)) (Hp j ltac:(lia))) as [Hpf Hpr].
  assert (HdL : L j j = fsqrt (fpiv A j)) by apply fchol_diag.
  destruct (sqrt_error _ Hpf Hpr) as [ds [Hds Hrds]].
  set (d := L j j) in *.
  assert (Hdpos : 0 < r d).
  { rewrite HdL. exact (proj1 (proj2 (proj1 (sqrt_contract _ (Hp j ltac:(lia))) Hpf))). }
  simpl sum.
  set (S0 := sum j (fun m => r (L i m) * r (L j m))).
  set (A0 := sum j (fun m => Rabs (r (L i m) * r (L j m)))).
  assert (HA0 : 0 <= A0) by (apply sum_nonneg; intros; apply Rabs_pos).
  destruct (Nat.eq_dec i j) as [-> | Hne].
  - (* diagonal: d = fl(sqrt s), so s = d^2 / (1 + ds)^2 *)
    fold d.
    destruct (dot_error L (A j j) j j j Hpf Hk0) as [F [HF Hb]].
    change (fdot L (A j j) j j j) with (fpiv A j) in Hb. fold S0 A0 in Hb.
    assert (Hnz : 1 + ds <> 0) by (pose proof (Rabs_le_inv _ _ Hds); lra).
    assert (Hs : r (fpiv A j) = r d * r d / ((1 + ds) * (1 + ds))).
    { rewrite HdL, Hrds. field_simplify_eq; [| exact Hnz].
      rewrite <- (sqrt_sqrt (r (fpiv A j))) at 1 by lra. ring. }
    pose proof (factor_div F ds j HF Hds Hk1) as H1.
    pose proof (factor_div (F / (1 + ds)) ds (S j) H1 Hds Hk) as H2.
    set (H := F / (1 + ds) / (1 + ds)) in *.
    replace (r (A j j) - (S0 + r d * r d)) with
      ((r (A j j) - S0 - r (fpiv A j) * F) + r d * r d * (H - 1))
      by (rewrite Hs; unfold H; field; exact Hnz).
    assert (T2 : Rabs (r d * r d * (H - 1)) <= Rabs (r d * r d) * gamma (S (S j))).
    { rewrite (Rabs_mult (r d * r d)). apply Rmult_le_compat_l; [apply Rabs_pos | exact H2]. }
    assert (G1 : gamma j * A0 <= gamma (S (S j)) * A0) by (apply Rmult_le_compat_r; lra).
    assert (G2 : (1 + gamma j) * INR j * eta <= (1 + gamma (S (S j))) * INR j * eta).
    { apply Rmult_le_compat_r; [lra |]. apply Rmult_le_compat_r; [apply pos_INR | lra]. }
    assert (G3 : 0 <= (1 + gamma (S (S j))) * Rabs (r d) * eta).
    { apply Rmult_le_pos; [apply Rmult_le_pos; [lra | apply Rabs_pos] | lra]. }
    eapply Rle_trans; [apply Rabs_triang |].
    rewrite Rmult_plus_distr_l, !Rmult_plus_distr_r, Rmult_plus_distr_l.
    lra.
  - (* below the diagonal: L i j = fl(s / d) *)
    assert (Hlt : (j < i)%nat) by lia.
    assert (HLij : L i j = fdiv (fdot L (A i j) i j j) d) by (apply fchol_lower; exact Hlt).
    assert (Hfij : fin (L i j)) by (apply finite_result with n; [exact HA | exact Hp | lia | lia]).
    assert (Hsf : fin (fdot L (A i j) i j j))
      by (apply (fdiv_finite_inv (div_nan := div_nan) _ d); rewrite <- HLij; exact Hfij).
    destruct (dot_error L (A i j) i j j Hsf Hk0) as [F [HF Hb]]. fold S0 A0 in Hb.
    assert (Hdnz : r d <> 0) by lra.
    destruct (div_error _ _ (ltac:(rewrite <- HLij; exact Hfij)) Hdnz) as [dv [ev [Hdv [Hev Hrv]]]].
    rewrite <- HLij in Hrv.
    assert (Hnz : 1 + dv <> 0) by (pose proof (Rabs_le_inv _ _ Hdv); lra).
    set (s := fdot L (A i j) i j j) in *.
    assert (Hs : r s = (r (L i j) - ev) * r d / (1 + dv)).
    { rewrite Hrv. field. split; assumption. }
    pose proof (factor_div F dv j HF Hdv Hk1) as H1.
    set (G := F / (1 + dv)) in *.
    replace (r (A i j) - (S0 + r (L i j) * r d)) with
      ((r (A i j) - S0 - r s * F) + r (L i j) * r d * (G - 1) - ev * r d * G)
      by (rewrite Hs; unfold G; field; exact Hnz).
    assert (HG1 : Rabs G <= 1 + gamma (S j)).
    { replace G with ((G - 1) + 1) by ring. eapply Rle_trans; [apply Rabs_triang |].
      rewrite Rabs_R1. lra. }
    assert (T2 : Rabs (r (L i j) * r d * (G - 1)) <= Rabs (r (L i j) * r d) * gamma (S j)).
    { rewrite (Rabs_mult (r (L i j) * r d)). apply Rmult_le_compat_l; [apply Rabs_pos | exact H1]. }
    assert (T3 : Rabs (ev * r d * G) <= eta * Rabs (r d) * (1 + gamma (S j))).
    { rewrite !Rabs_mult. apply Rmult_le_compat; [| apply Rabs_pos | | exact HG1].
      - apply Rmult_le_pos; apply Rabs_pos.
      - apply Rmult_le_compat_r; [apply Rabs_pos | exact Hev]. }
    assert (G1 : gamma j * A0 <= gamma (S (S j)) * A0) by (apply Rmult_le_compat_r; lra).
    assert (G2 : (1 + gamma j) * INR j * eta <= (1 + gamma (S (S j))) * INR j * eta).
    { apply Rmult_le_compat_r; [lra |]. apply Rmult_le_compat_r; [apply pos_INR | lra]. }
    assert (G4 : Rabs (r (L i j) * r d) * gamma (S j)
                 <= gamma (S (S j)) * Rabs (r (L i j) * r d)).
    { rewrite Rmult_comm. apply Rmult_le_compat_r; [apply Rabs_pos | lra]. }
    assert (G5 : eta * Rabs (r d) * (1 + gamma (S j))
                 <= (1 + gamma (S (S j))) * Rabs (r d) * eta).
    { replace (eta * Rabs (r d) * (1 + gamma (S j)))
        with ((1 + gamma (S j)) * (Rabs (r d) * eta)) by ring.
      replace ((1 + gamma (S (S j))) * Rabs (r d) * eta)
        with ((1 + gamma (S (S j))) * (Rabs (r d) * eta)) by ring.
      apply Rmult_le_compat_r; [apply Rmult_le_pos; [apply Rabs_pos | lra] | lra]. }
    unfold Rminus at 1.
    eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_Ropp.
    eapply Rle_trans; [apply Rplus_le_compat_r; apply Rabs_triang |].
    rewrite Rmult_plus_distr_l, !Rmult_plus_distr_r, Rmult_plus_distr_l.
    lra.
Qed.

End Model.
