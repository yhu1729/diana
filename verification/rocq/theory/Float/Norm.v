From Stdlib Require Import Reals ZArith Lia Lra Psatz List.
From Flocq Require Import Core Relative IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Float Require Cholesky LU.
From Diana.Real Require Import Norm.
Import ListNotations.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).
Local Abbreviation rnd x := (round radix2 fexp ZnearestE x).

(* DBL_MAX = (2 - 2^-52) 2^1023, the largest finite binary64 value. *)
Definition dbl_max : R := bpow radix2 emax - bpow radix2 (emax - prec).

Definition fone : b64 :=
  B754_finite prec emax false 4503599627370496 (-52) ltac:(vm_compute; reflexivity).

Definition fmaxval : b64 :=
  B754_finite prec emax false 9007199254740991 971 ltac:(vm_compute; reflexivity).

Lemma B2R_fone : r fone = 1.
Proof.
  unfold fone, B2R, F2R; simpl.
  change (Z.pow_pos 2 52) with 4503599627370496%Z. lra.
Qed.

Lemma B2R_fmaxval : r fmaxval = dbl_max.
Proof.
  unfold fmaxval, dbl_max, B2R, F2R; simpl Fnum; simpl Fexp.
  change 9007199254740991%Z with (9007199254740992 - 1)%Z. rewrite minus_IZR.
  change (IZR 9007199254740992) with (bpow radix2 53).
  rewrite Rmult_minus_distr_r, <- bpow_plus, Rmult_1_l. reflexivity.
Qed.

Lemma dbl_max_lt : dbl_max < bpow radix2 emax.
Proof. unfold dbl_max. pose proof (bpow_gt_0 radix2 (emax - prec)). lra. Qed.

Lemma format_one : generic_format radix2 fexp 1.
Proof. rewrite <- B2R_fone. apply generic_format_B2R. Qed.

Lemma round_ge (a z : R) : generic_format radix2 fexp a -> a <= z -> a <= rnd z.
Proof.
  intros Ha Hz. rewrite <- (round_generic radix2 fexp ZnearestE a Ha).
  apply round_le; [typeclasses eauto | typeclasses eauto | exact Hz].
Qed.

Lemma round_le_fmt (a z : R) : generic_format radix2 fexp a -> z <= a -> rnd z <= a.
Proof.
  intros Ha Hz. rewrite <- (round_generic radix2 fexp ZnearestE a Ha).
  apply round_le; [typeclasses eauto | typeclasses eauto | exact Hz].
Qed.

Lemma round_abs_one (z : R) : Rabs z <= 1 -> Rabs (rnd z) <= 1.
Proof.
  intro H. apply Rabs_le. destruct (Rabs_le_inv _ _ H) as [H1 H2]. split.
  - apply round_ge; [apply generic_format_opp, format_one | exact H1].
  - apply round_le_fmt; [apply format_one | exact H2].
Qed.

Lemma one_lt_bpow : 1 < bpow radix2 emax.
Proof. change 1 with (bpow radix2 0). apply bpow_lt. lia. Qed.

Lemma u_small : u <= / 8.
Proof.
  unfold u. replace (/ 8) with (bpow radix2 (-3)) by (simpl; lra). apply bpow_le. lia.
Qed.

Lemma eta_small : eta <= 1.
Proof. unfold eta. change 1 with (bpow radix2 0). apply bpow_le. lia. Qed.

(* The integers below 2^53: k u < 1 leaves a gap of at least u. *)
Lemma gap (k : nat) : INR k * u < 1 -> u <= 1 - INR k * u.
Proof.
  intro H. assert (Hu : u * bpow radix2 53 = 1).
  { unfold u. rewrite <- bpow_plus. reflexivity. }
  assert (Hb : INR k < bpow radix2 53).
  { apply Rmult_lt_reg_r with u; [apply u_pos |]. rewrite Rmult_comm with (r1 := bpow _ _).
    lra. }
  rewrite INR_IZR_INZ in Hb |- *.
  change (bpow radix2 53) with (IZR 9007199254740992) in Hb, Hu.
  apply lt_IZR in Hb. assert (Hle : (Z.of_nat k <= 9007199254740991)%Z) by lia.
  apply IZR_le in Hle. pose proof u_pos.
  replace (IZR 9007199254740991) with (IZR 9007199254740992 - 1) in Hle
    by (rewrite <- minus_IZR; reflexivity).
  nra.
Qed.

Lemma one_gamma_le (k : nat) : INR k * u < 1 -> 1 + gamma k <= / u.
Proof.
  intro H. pose proof (gap k H) as Hg. pose proof u_pos. unfold gamma.
  replace (1 + INR k * u / (1 - INR k * u)) with (/ (1 - INR k * u)) by (field; lra).
  apply Rinv_le_contravar; lra.
Qed.

Lemma inr_lt_inv_u (k : nat) : INR k * u < 1 -> INR k <= / u.
Proof.
  intro H. pose proof u_pos. apply Rmult_le_reg_r with u; [lra |].
  rewrite Rinv_l by lra. lra.
Qed.

Lemma gamma_add (j k : nat) :
  INR (j + k) * u < 1 -> gamma j + gamma k + gamma j * gamma k <= gamma (j + k).
Proof.
  intro H. rewrite plus_INR in H. unfold gamma. rewrite plus_INR.
  pose proof u_pos. pose proof (pos_INR j). pose proof (pos_INR k).
  set (a := INR j * u). set (b := INR k * u).
  assert (Ha : 0 <= a) by (unfold a; nra). assert (Hb : 0 <= b) by (unfold b; nra).
  replace ((INR j + INR k) * u) with (a + b) in * by (unfold a, b; ring).
  assert (E : (a + b) / (1 - (a + b)) - (a / (1 - a) + b / (1 - b) + a / (1 - a) * (b / (1 - b)))
              = a * b / ((1 - a) * (1 - b) * (1 - (a + b)))) by (field; repeat split; lra).
  assert (P : 0 <= a * b / ((1 - a) * (1 - b) * (1 - (a + b)))).
  { apply Rmult_le_pos; [nra |]. left. apply Rinv_0_lt_compat.
    apply Rmult_lt_0_compat; [apply Rmult_lt_0_compat |]; lra. }
  lra.
Qed.

Lemma gamma_add_u (k : nat) : INR (S k) * u < 1 -> gamma k + u <= gamma (S k).
Proof.
  intro H. pose proof (gamma_step k H). pose proof u_pos.
  pose proof (gamma_nonneg k (Diana.Float.Cholesky.gamma_lt k H)). nra.
Qed.

Lemma inr_mono (j k : nat) : (j <= k)%nat -> INR k * u < 1 -> INR j * u < 1.
Proof.
  intros Hjk Hk. eapply Rle_lt_trans; [| exact Hk].
  apply Rmult_le_compat_r; [left; apply u_pos | apply le_INR; exact Hjk].
Qed.

Lemma sqrt_one_error (z : R) : 0 <= z -> Rabs (sqrt z - 1) <= Rabs (z - 1).
Proof.
  intro Hz. pose proof (sqrt_sqrt z Hz) as Hs. pose proof (sqrt_pos z) as Hp.
  set (s := sqrt z) in *. rewrite <- Hs.
  replace (s * s - 1) with ((s - 1) * (s + 1)) by ring.
  rewrite Rabs_mult, (Rabs_pos_eq (s + 1)) by lra.
  pose proof (Rabs_pos (s - 1)). nra.
Qed.

Lemma rsum_nonneg (ts : list b64) : Forall (fun t => 0 <= r t) ts -> 0 <= rsum ts.
Proof.
  induction ts as [| t ts IH]; intro H; simpl; [lra |].
  inversion H as [| ? ? Ht Hts]. subst. cbv beta in *. specialize (IH Hts). lra.
Qed.

Lemma remove_map {A B : Type} (f : A -> B) (k : nat) (x : list A) :
  remove k (map f x) = map f (remove k x).
Proof. unfold remove. rewrite map_app, firstn_map, skipn_map. reflexivity. Qed.

Lemma length_remove {A : Type} (k : nat) (x : list A) :
  (k < length x)%nat -> length (remove k x) = (length x - 1)%nat.
Proof.
  intro H. unfold remove. rewrite length_app, length_firstn, length_skipn. lia.
Qed.

Lemma in_remove {A : Type} (k : nat) (x : list A) (a : A) : In a (remove k x) -> In a x.
Proof.
  revert k. induction x as [| b x IH]; intros k H; [destruct k; destruct H |].
  destruct k as [| k]; [right; exact H |].
  change (remove (S k) (b :: x)) with (b :: remove k x) in H.
  destruct H as [H | H]; [left; exact H | right; exact (IH k H)].
Qed.

Lemma absorb (L : nat) : INR L * u < 1 -> (1 + gamma L) * (5 * INR L * eta) <= u.
Proof.
  intro H. pose proof u_pos as Hu. pose proof eta_pos as He.
  pose proof (one_gamma_le L H) as H1. pose proof (inr_lt_inv_u L H) as H2.
  pose proof (pos_INR L) as H3. pose proof (gamma_nonneg L H) as H4.
  assert (Hiu : 0 < / u) by (apply Rinv_0_lt_compat; exact Hu).
  assert (H5 : 5 * eta <= u * u * u).
  { unfold eta, u. rewrite <- !bpow_plus.
    apply Rle_trans with (bpow radix2 3 * bpow radix2 (-1075)).
    - apply Rmult_le_compat_r; [apply bpow_ge_0 | simpl; lra].
    - rewrite <- bpow_plus. apply bpow_le. lia. }
  apply Rle_trans with (/ u * (5 * / u * eta)).
  - apply Rmult_le_compat; [lra | | exact H1 |].
    + apply Rmult_le_pos; [lra | exact (Rlt_le _ _ He)].
    + apply Rmult_le_compat_r; [lra | lra].
  - replace (/ u * (5 * / u * eta)) with (5 * eta / (u * u)) by (field; lra).
    apply Rmult_le_reg_r with (u * u); [nra |].
    unfold Rdiv. rewrite Rmult_assoc, Rinv_l by nra. nra.
Qed.

Lemma inv_u_sq_lt : / u * / u < bpow radix2 emax.
Proof.
  unfold u. rewrite <- !bpow_opp, <- bpow_plus. apply bpow_lt. lia.
Qed.

Section Model.

Variable plus_nan mult_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.
Variable sqrt_nan opp_nan : b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fadd := (Diana.Float.Sum.fadd plus_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fdiv := (Diana.Float.Sum.fdiv div_nan).
Local Abbreviation fsqrt := (Diana.Float.Cholesky.fsqrt sqrt_nan).
Local Abbreviation fabs := (Diana.Float.LU.fmag opp_nan).
Local Abbreviation fzero := Diana.Float.Cholesky.fzero.
Local Abbreviation fgtb := Diana.Float.LU.fgtb.
Local Abbreviation feqb := Diana.Float.LU.feqb.

(* diana_norm_inf: m = 0.0, then for each x[i], a = |x[i]| and m = a if a > m. *)
Definition fmax (m x : b64) : b64 := if fgtb (fabs x) m then fabs x else m.
Definition fnorm_inf (xs : list b64) : b64 := fold_left fmax xs fzero.

(* diana_norm_1: s = 0.0, then s = s + |x[i]| in index order. *)
Definition fnorm1 (xs : list b64) : b64 := fold_left fadd (map fabs xs) fzero.

(* diana_norm_2, first pass: the count i, the index k of the first largest |x[i]| and that
   magnitude m. *)
Definition fpick (a : nat * nat * b64) (x : b64) : nat * nat * b64 :=
  match a with (i, k, m) => if fgtb (fabs x) m then (S i, i, fabs x) else (S i, k, m) end.
Definition fscale (xs : list b64) : nat * nat * b64 := fold_left fpick xs (O, O, fzero).

(* Second pass: s = 1.0, then s = s + q * q, q = x[i] / m, for i <> k in index order. *)
Definition fsq (m x : b64) : b64 := let q := fdiv x m in fmul q q.
Definition fsumsq (m : b64) (ys : list b64) : b64 := fold_left fadd (map (fsq m) ys) fone.

(* The result: +0 when m == 0.0, else m * sqrt(s). *)
Definition fnorm2 (xs : list b64) : b64 :=
  match fscale xs with
  | (_, k, m) => if feqb m fzero then fzero else fmul m (fsqrt (fsumsq m (remove k xs)))
  end.

Lemma fzero_spec : fin fzero /\ r fzero = 0.
Proof. split; reflexivity. Qed.

Lemma fabs_spec (x : b64) : fin x -> fin (fabs x) /\ r (fabs x) = Rabs (r x).
Proof. exact (Diana.Float.LU.fmag_finite opp_nan x). Qed.

Lemma fmax_spec (m x : b64) :
  fin m -> fin x -> fin (fmax m x) /\ r (fmax m x) = Rmax (r m) (Rabs (r x)).
Proof.
  intros Hm Hx. destruct (fabs_spec x Hx) as [Ha Hv]. unfold fmax.
  rewrite (Diana.Float.LU.fgtb_real _ _ Ha Hm). unfold Diana.Real.LU.rgt.
  destruct (Rlt_dec (r m) (r (fabs x))) as [H | H]; rewrite Hv in *.
  - split; [exact Ha |]. rewrite Rmax_right; lra.
  - split; [exact Hm |]. rewrite Rmax_left; lra.
Qed.

Lemma fold_fmax (xs : list b64) (m : b64) :
  fin m -> 0 <= r m -> Forall (fun x => fin x) xs ->
  fin (fold_left fmax xs m) /\ r (fold_left fmax xs m) = Rmax (r m) (norm_inf (map (B2R prec emax) xs)).
Proof.
  revert m. induction xs as [| x xs IH]; intros m Hm Hm0 Hxs; cbn [fold_left map norm_inf].
  - split; [exact Hm |]. rewrite Rmax_left; [reflexivity | exact Hm0].
  - inversion Hxs as [| ? ? Hx Hxs']. subst. cbv beta in *.
    destruct (fmax_spec m x Hm Hx) as [Hf Hv].
    assert (H0 : 0 <= r (fmax m x))
      by (rewrite Hv; eapply Rle_trans; [exact Hm0 | apply Rmax_l]).
    destruct (IH _ Hf H0 Hxs') as [Hf' Hv']. split; [exact Hf' |].
    rewrite Hv', Hv. symmetry. apply Rmax_assoc.
Qed.

(* Layer B, the maximum norm is exact: with every entry finite, the binary64 model returns a
   finite value equal to max |x[i]|. *)
Theorem norm_inf_exact (xs : list b64) :
  Forall (fun x => fin x) xs -> fin (fnorm_inf xs) /\ r (fnorm_inf xs) = norm_inf (map (B2R prec emax) xs).
Proof.
  intro H. unfold fnorm_inf.
  destruct (fold_fmax xs fzero eq_refl (ltac:(simpl; lra)) H) as [Hf Hv].
  split; [exact Hf |]. rewrite Hv. simpl B2R. apply Rmax_right, norm_inf_nonneg.
Qed.

Lemma nonneg_step (s t : b64) (X : R) (j : nat) :
  0 <= r t -> 0 <= X -> Rabs (r s - X) <= gamma j * X -> INR (S j) * u < 1 ->
  Rabs (rnd (r s + r t) - (X + r t)) <= gamma (S j) * (X + r t).
Proof.
  intros Ht HX Hs Hk.
  destruct (add_error (r s) (r t) (generic_format_B2R prec emax s)
              (generic_format_B2R prec emax t)) as [d [Hd Hr]].
  rewrite Hr.
  pose proof (gamma_step j Hk) as Hg.
  pose proof (gamma_nonneg j (Diana.Float.Cholesky.gamma_lt j Hk)) as Hg0.
  pose proof u_pos as Hu.
  replace ((r s + r t) * (1 + d) - (X + r t)) with ((r s - X) + d * (r s + r t)) by ring.
  assert (Hst : Rabs (r s + r t) <= (1 + gamma j) * X + r t).
  { replace (r s + r t) with ((r s - X) + (X + r t)) by ring.
    eapply Rle_trans; [apply Rabs_triang |]. rewrite (Rabs_pos_eq (X + r t)) by lra. lra. }
  eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult.
  assert (Hdm : Rabs d * Rabs (r s + r t) <= u * ((1 + gamma j) * X + r t))
    by (apply Rmult_le_compat; [apply Rabs_pos | apply Rabs_pos | exact Hd | exact Hst]).
  assert (Hu1 : u <= gamma (S j)) by nra.
  assert (H1 : (gamma j * (1 + u) + u) * X <= gamma (S j) * X)
    by (apply Rmult_le_compat_r; lra).
  assert (H2 : u * r t <= gamma (S j) * r t) by (apply Rmult_le_compat_r; lra).
  nra.
Qed.

Lemma fold_nonneg (ts : list b64) :
  forall (s : b64) (X : R) (j : nat),
  fin (fold_left fadd ts s) -> Forall (fun t => 0 <= r t) ts -> 0 <= X ->
  Rabs (r s - X) <= gamma j * X -> INR (j + length ts) * u < 1 ->
  Rabs (r (fold_left fadd ts s) - (X + rsum ts)) <= gamma (j + length ts) * (X + rsum ts).
Proof.
  induction ts as [| t ts IH]; intros s X j Hf Hts HX Hs Hk; cbn [fold_left rsum length] in *.
  - rewrite Nat.add_0_r, Rplus_0_r. exact Hs.
  - inversion Hts as [| ? ? Ht Hts']. subst. cbv beta in *.
    assert (Hst : fin (fadd s t)) by exact (proj1 (fold_finite_inv _ _ Hf)).
    replace (j + S (length ts))%nat with (S j + length ts)%nat in * by lia.
    replace (X + (r t + rsum ts)) with (X + r t + rsum ts) by ring.
    apply IH; [exact Hf | exact Hts' | lra | | exact Hk].
    rewrite (fadd_value _ _ Hst). apply nonneg_step; [exact Ht | exact HX | exact Hs |].
    apply (inr_mono (S j) (S j + length ts)); [lia | exact Hk].
Qed.

Lemma fold_nonneg_finite (ts : list b64) :
  forall (s : b64) (X : R) (j : nat),
  fin s -> Forall (fun t => fin t) ts -> Forall (fun t => 0 <= r t) ts -> 0 <= X ->
  Rabs (r s - X) <= gamma j * X -> INR (j + length ts) * u < 1 ->
  (1 + gamma (j + length ts)) * (X + rsum ts) < bpow radix2 emax ->
  fin (fold_left fadd ts s).
Proof.
  induction ts as [| t ts IH]; intros s X j Hs Hf Hts HX Herr Hk Hb;
    cbn [fold_left rsum length] in *; [exact Hs |].
  inversion Hf as [| ? ? Ft Hf']. cbv beta in *. inversion Hts as [| ? ? Ht Hts']. subst. cbv beta in *.
  replace (j + S (length ts))%nat with (S j + length ts)%nat in * by lia.
  assert (Hk1 : INR (S j) * u < 1) by (apply (inr_mono (S j) (S j + length ts)); [lia | exact Hk]).
  pose proof (nonneg_step s t X j Ht HX Herr Hk1) as Hstep.
  assert (Hsum0 : 0 <= rsum ts) by (apply rsum_nonneg; exact Hts').
  assert (Hmono : gamma (S j) <= gamma (S j + length ts)) by (apply gamma_mono; [lia | exact Hk]).
  assert (Hg0 : 0 <= gamma (S j)) by (apply gamma_nonneg; exact Hk1).
  assert (Hfin : fin (fadd s t)).
  { apply (proj2 (fadd_finite_iff s t Hs Ft)).
    assert (Hr : Rabs (rnd (r s + r t)) <= (1 + gamma (S j)) * (X + r t)).
    { replace (rnd (r s + r t)) with ((rnd (r s + r t) - (X + r t)) + (X + r t)) by ring.
      eapply Rle_trans; [apply Rabs_triang |]. rewrite (Rabs_pos_eq (X + r t)) by lra. lra. }
    eapply Rle_lt_trans; [exact Hr |]. eapply Rle_lt_trans; [| exact Hb].
    apply Rmult_le_compat; lra. }
  apply (IH (fadd s t) (X + r t) (S j)); [exact Hfin | exact Hf' | exact Hts' | lra | | exact Hk |].
  - rewrite (fadd_value _ _ Hfin). exact Hstep.
  - replace (X + r t + rsum ts) with (X + (r t + rsum ts)) by ring. exact Hb.
Qed.

Lemma fadd_zero_l (a : b64) : fin a -> fin (fadd fzero a) /\ r (fadd fzero a) = r a.
Proof.
  intro Ha.
  assert (Hv : rnd (r fzero + r a) = r a).
  { simpl (r fzero). rewrite Rplus_0_l.
    apply round_generic; [typeclasses eauto | apply generic_format_B2R]. }
  assert (Hf : fin (fadd fzero a)).
  { apply (proj2 (fadd_finite_iff fzero a eq_refl Ha)). rewrite Hv. apply abs_B2R_lt_emax. }
  split; [exact Hf | rewrite (fadd_value _ _ Hf); exact Hv].
Qed.

Lemma fabs_all (xs : list b64) :
  Forall (fun x => fin x) xs ->
  Forall (fun t => fin t) (map fabs xs) /\ Forall (fun t => 0 <= r t) (map fabs xs) /\
  rsum (map fabs xs) = norm1 (map (B2R prec emax) xs).
Proof.
  induction xs as [| x xs IH]; intro H; [repeat split; constructor || reflexivity |].
  inversion H as [| ? ? Hx Hxs]. subst. cbv beta in *. destruct (IH Hxs) as [F [N S]].
  destruct (fabs_spec x Hx) as [Fa Va]. cbn [map rsum norm1].
  split; [constructor; assumption | split; [constructor; [rewrite Va; apply Rabs_pos | exact N] |]].
  rewrite Va, S. reflexivity.
Qed.

(* Layer B, forward error of the 1-norm: with every entry finite and a finite result,
   |r - |x|_1| <= gamma (n - 1) |x|_1. The first addition, 0 + |x[0]|, is exact. *)
Theorem norm1_error (xs : list b64) :
  Forall (fun x => fin x) xs -> fin (fnorm1 xs) -> INR (length xs - 1) * u < 1 ->
  Rabs (r (fnorm1 xs) - norm1 (map (B2R prec emax) xs)) <= gamma (length xs - 1) * norm1 (map (B2R prec emax) xs).
Proof.
  intros Hxs Hf Hk. destruct xs as [| a t].
  - simpl. rewrite Rminus_0_r, Rabs_R0, gamma_0. lra.
  - inversion Hxs as [| ? ? Ha Ht]. subst. cbv beta in *.
    unfold fnorm1 in *. cbn [map fold_left] in *.
    destruct (fabs_spec a Ha) as [Faa Vaa].
    destruct (fadd_zero_l (fabs a) Faa) as [F0 V0].
    destruct (fabs_all t Ht) as [_ [Nt St]].
    replace (length (a :: t) - 1)%nat with (0 + length (map fabs t))%nat in *
      by (rewrite length_map; simpl; lia).
    cbn [norm1]. rewrite <- St.
    apply fold_nonneg; [exact Hf | exact Nt | apply Rabs_pos | | exact Hk].
    rewrite V0, Vaa, Rminus_diag, Rabs_R0, gamma_0. lra.
Qed.

(* Layer B, no spurious overflow in the 1-norm: with every entry finite, the result is finite
   whenever (1 + gamma (n - 1)) |x|_1 <= DBL_MAX. *)
Theorem norm1_finite (xs : list b64) :
  Forall (fun x => fin x) xs -> INR (length xs - 1) * u < 1 ->
  (1 + gamma (length xs - 1)) * norm1 (map (B2R prec emax) xs) <= dbl_max -> fin (fnorm1 xs).
Proof.
  intros Hxs Hk Hb. destruct xs as [| a t]; [reflexivity |].
  inversion Hxs as [| ? ? Ha Ht]. subst. cbv beta in *.
  unfold fnorm1. cbn [map fold_left].
  destruct (fabs_spec a Ha) as [Faa Vaa].
  destruct (fadd_zero_l (fabs a) Faa) as [F0 V0].
  destruct (fabs_all t Ht) as [Ft [Nt St]].
  replace (length (a :: t) - 1)%nat with (0 + length (map fabs t))%nat in *
    by (rewrite length_map; simpl; lia).
  apply (fold_nonneg_finite _ _ (Rabs (r a)) 0); [exact F0 | exact Ft | exact Nt |
    apply Rabs_pos | | exact Hk |].
  - rewrite V0, Vaa, Rminus_diag, Rabs_R0, gamma_0. lra.
  - eapply Rle_lt_trans; [| apply dbl_max_lt]. rewrite St. exact Hb.
Qed.

Lemma fscale_snd (xs : list b64) (i k : nat) (m : b64) :
  snd (fold_left fpick xs (i, k, m)) = fold_left fmax xs m.
Proof.
  revert i k m. induction xs as [| x xs IH]; intros i k m; [reflexivity |].
  cbn [fold_left]. unfold fpick at 2, fmax at 2.
  destruct (fgtb (fabs x) m); apply IH.
Qed.

Lemma fscale_index (xs : list b64) :
  forall (p : list b64) (k : nat) (m : b64),
  Forall (fun x => fin x) xs ->
  (r m = 0 \/ ((k < length p)%nat /\ Rabs (r (nth k p fzero)) = r m)) ->
  let a := fold_left fpick xs (length p, k, m) in
  r (snd a) = 0 \/
  ((snd (fst a) < length (p ++ xs))%nat /\ Rabs (r (nth (snd (fst a)) (p ++ xs) fzero)) = r (snd a)).
Proof.
  induction xs as [| x xs IH]; intros p k m Hxs Hinv a.
  - unfold a. cbn [fold_left fst snd]. rewrite app_nil_r. exact Hinv.
  - inversion Hxs as [| ? ? Hx Hxs']. subst. cbv beta in *.
    unfold a. clear a.
    replace (p ++ x :: xs) with ((p ++ [x]) ++ xs) by (rewrite <- app_assoc; reflexivity).
    cbn [fold_left].
    replace (fpick (length p, k, m) x) with
      (if fgtb (fabs x) m then (S (length p), length p, fabs x) else (S (length p), k, m))
      by reflexivity.
    destruct (fabs_spec x Hx) as [Fa Va].
    replace (S (length p)) with (length (p ++ [x])) by (rewrite length_app; simpl; lia).
    destruct (fgtb (fabs x) m).
    + apply IH; [exact Hxs' |]. right. split.
      * rewrite length_app. simpl. lia.
      * rewrite app_nth2 by lia. rewrite Nat.sub_diag. simpl nth. rewrite Va. reflexivity.
    + apply IH; [exact Hxs' |]. destruct Hinv as [H0 | [Hk Hv]]; [left; exact H0 | right].
      split; [rewrite length_app; simpl; lia | rewrite app_nth1 by lia; exact Hv].
Qed.

Lemma fscale_spec (xs : list b64) (i k : nat) (m : b64) :
  Forall (fun x => fin x) xs -> fscale xs = (i, k, m) ->
  fin m /\ r m = norm_inf (map (B2R prec emax) xs) /\
  (r m = 0 \/ ((k < length xs)%nat /\ Rabs (r (nth k xs fzero)) = r m)).
Proof.
  intros Hxs Hsc.
  assert (Hm : m = fnorm_inf xs).
  { change m with (snd (i, k, m)). rewrite <- Hsc. apply fscale_snd. }
  destruct (norm_inf_exact xs Hxs) as [Fm Vm]. rewrite <- Hm in Fm, Vm.
  split; [exact Fm | split; [exact Vm |]].
  pose proof (fscale_index xs [] 0 fzero Hxs (or_introl eq_refl)) as H.
  cbv zeta in H. simpl length in H. change (fold_left fpick xs (0%nat, 0%nat, fzero)) with (fscale xs) in H.
  rewrite Hsc in H. exact H.
Qed.

Lemma fsqrt_finite_inv (x : b64) : fin (fsqrt x) -> fin x.
Proof.
  unfold Diana.Float.Cholesky.fsqrt, Bsqrt. rewrite is_finite_BSN2B.
  destruct x as [s|s|s pl Hpl|s m e He]; intro H; try reflexivity; simpl in H;
    try discriminate; destruct s; discriminate.
Qed.

Lemma fsq_nonneg (m y : b64) : fin (fsq m y) -> 0 <= r (fsq m y).
Proof.
  intro H. unfold fsq in *. destruct (fmul_value _ _ H) as [_ [_ V]]. rewrite V.
  apply round_ge; [apply generic_format_0 | apply Rle_0_sqr].
Qed.

Lemma sq_spec (m y : b64) :
  fin m -> fin y -> 0 < r m -> Rabs (r y) <= r m -> INR 3 * u < 1 ->
  fin (fsq m y) /\ 0 <= r (fsq m y) <= 1 /\
  Rabs (r (fsq m y) - (r y / r m) ^ 2) <= gamma 3 * (r y / r m) ^ 2 + 5 * eta.
Proof.
  intros Hm Hy Hpos Hle H3.
  set (t := r y / r m).
  assert (Ht : Rabs t <= 1).
  { unfold t, Rdiv. rewrite Rabs_mult, Rabs_inv, (Rabs_pos_eq (r m)) by lra.
    apply Rmult_le_reg_r with (r m); [exact Hpos |].
    rewrite Rmult_assoc, Rinv_l, Rmult_1_r by lra. lra. }
  assert (Hm0 : r m <> 0) by lra.
  assert (Fq : fin (fdiv y m)).
  { apply (proj2 (fdiv_finite_iff y m Hy Hm0)).
    eapply Rle_lt_trans; [apply round_abs_one; exact Ht | apply one_lt_bpow]. }
  pose proof (fdiv_value y m Fq Hm0) as Vq. fold t in Vq.
  set (q := fdiv y m) in *.
  assert (Hq1 : Rabs (r q) <= 1) by (rewrite Vq; apply round_abs_one; exact Ht).
  assert (Hqq : Rabs (r q * r q) <= 1)
    by (rewrite Rabs_mult; pose proof (Rabs_pos (r q)); nra).
  assert (Fp : fin (fmul q q)).
  { apply (proj2 (fmul_finite_iff q q Fq Fq)).
    eapply Rle_lt_trans; [apply round_abs_one; exact Hqq | apply one_lt_bpow]. }
  destruct (fmul_value q q Fp) as [_ [_ Vp]].
  change (fsq m y) with (fmul q q).
  split; [exact Fp | split].
  - rewrite Vp. split.
    + apply round_ge; [apply generic_format_0 | nra].
    + apply round_le_fmt; [apply format_one |]. destruct (Rabs_le_inv _ _ Hqq). lra.
  - destruct (round_error t) as [d1 [e1 [Hd1 [He1 Hr1]]]].
    destruct (round_error (r q * r q)) as [d2 [e2 [Hd2 [He2 Hr2]]]].
    rewrite Vp, Hr2, Vq, Hr1.
    pose proof u_pos. pose proof eta_pos. pose proof u_small. pose proof eta_small.
    assert (G1 : Rabs (1 * (1 + d1) - 1) <= gamma 1)
      by (apply Diana.Float.Cholesky.factor_mul; [rewrite gamma_0; replace (1 - 1) with 0 by ring;
          rewrite Rabs_R0; lra | exact Hd1 | apply (inr_mono 1 3 ltac:(lia) H3)]).
    assert (G2 : Rabs (1 * (1 + d1) * (1 + d1) - 1) <= gamma 2)
      by (apply Diana.Float.Cholesky.factor_mul; [exact G1 | exact Hd1 |
          apply (inr_mono 2 3 ltac:(lia) H3)]).
    assert (G3 : Rabs (1 * (1 + d1) * (1 + d1) * (1 + d2) - 1) <= gamma 3)
      by (apply Diana.Float.Cholesky.factor_mul; [exact G2 | exact Hd2 | exact H3]).
    set (F := 1 * (1 + d1) * (1 + d1) * (1 + d2)) in *.
    replace ((t * (1 + d1) + e1) * (t * (1 + d1) + e1) * (1 + d2) + e2 - t ^ 2)
      with (t ^ 2 * (F - 1) + ((2 * t * (1 + d1) * e1 + e1 * e1) * (1 + d2) + e2))
      by (unfold F; ring).
    eapply Rle_trans; [apply Rabs_triang |].
    rewrite Rabs_mult, (Rabs_pos_eq (t ^ 2)) by apply pow2_ge_0.
    assert (T1 : t ^ 2 * Rabs (F - 1) <= gamma 3 * t ^ 2).
    { rewrite Rmult_comm. apply Rmult_le_compat_r; [apply pow2_ge_0 | exact G3]. }
    assert (A1 : Rabs (2 * t * (1 + d1) * e1) <= 2 * (1 + u) * eta).
    { rewrite !Rabs_mult, (Rabs_pos_eq 2) by lra.
      assert (Rabs (1 + d1) <= 1 + u).
      { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_R1. lra. }
      assert (B1 : Rabs t * Rabs (1 + d1) <= 1 * (1 + u))
        by (apply Rmult_le_compat; try apply Rabs_pos; assumption).
      assert (B2 : Rabs t * Rabs (1 + d1) * Rabs e1 <= 1 * (1 + u) * eta)
        by (apply Rmult_le_compat; [apply Rmult_le_pos; apply Rabs_pos | apply Rabs_pos |
            exact B1 | exact He1]).
      lra. }
    assert (A2 : Rabs (e1 * e1) <= eta).
    { rewrite Rabs_mult. pose proof (Rabs_pos e1). nra. }
    assert (A3 : Rabs (1 + d2) <= 1 + u).
    { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_R1. lra. }
    assert (A4 : Rabs ((2 * t * (1 + d1) * e1 + e1 * e1) * (1 + d2) + e2)
                 <= (2 * (1 + u) * eta + eta) * (1 + u) + eta).
    { eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult.
      assert (Rabs (2 * t * (1 + d1) * e1 + e1 * e1) <= 2 * (1 + u) * eta + eta)
        by (eapply Rle_trans; [apply Rabs_triang | lra]).
      pose proof (Rabs_pos (2 * t * (1 + d1) * e1 + e1 * e1)). pose proof (Rabs_pos (1 + d2)).
      nra. }
    assert (C : (2 * (1 + u) * eta + eta) * (1 + u) + eta <= 5 * eta).
    { replace ((2 * (1 + u) * eta + eta) * (1 + u) + eta) with (eta * (4 + 5 * u + 2 * (u * u)))
        by ring.
      apply Rle_trans with (eta * 5); [apply Rmult_le_compat_l; [lra | nra] | lra]. }
    lra.
Qed.

Lemma sumsq_spec (m : b64) (ys : list b64) :
  fin m -> 0 < r m -> Forall (fun y => fin y /\ Rabs (r y) <= r m) ys -> INR 3 * u < 1 ->
  Forall (fun p => fin p) (map (fsq m) ys) /\ Forall (fun p => 0 <= r p) (map (fsq m) ys) /\
  rsum (map (fsq m) ys) <= INR (length ys) /\
  Rabs (rsum (map (fsq m) ys) - sumsq (map (fun a => a / r m) (map (B2R prec emax) ys)))
    <= gamma 3 * sumsq (map (fun a => a / r m) (map (B2R prec emax) ys)) + 5 * INR (length ys) * eta.
Proof.
  intros Hm Hpos Hys H3. induction ys as [| y ys IH].
  - simpl. rewrite Rminus_0_r, Rabs_R0. repeat split; try constructor; lra.
  - inversion Hys as [| ? ? [Fy Ly] Hys']. subst. cbv beta in *. destruct (IH Hys') as [F [N [B E]]].
    destruct (sq_spec m y Hm Fy Hpos Ly H3) as [Fp [[P0 P1] Ep]].
    cbn [map rsum sumsq length]. rewrite S_INR.
    split; [constructor; assumption | split; [constructor; assumption | split; [lra |]]].
    set (a := r (fsq m y)) in *. set (b := (r y / r m) ^ 2) in *.
    set (A := rsum (map (fsq m) ys)) in *.
    set (T := sumsq (map (fun a0 => a0 / r m) (map (B2R prec emax) ys))) in *.
    replace (a + A - (b + T)) with ((a - b) + (A - T)) by ring.
    eapply Rle_trans; [apply Rabs_triang | lra].
Qed.

Lemma fold_ge (ts : list b64) (s : b64) :
  fin (fold_left fadd ts s) -> Forall (fun t => 0 <= r t) ts -> r s <= r (fold_left fadd ts s).
Proof.
  revert s. induction ts as [| t ts IH]; intros s Hf Hts; cbn [fold_left] in *; [lra |].
  inversion Hts as [| ? ? Ht Hts']. subst. cbv beta in *.
  assert (Hst : fin (fadd s t)) by exact (proj1 (fold_finite_inv _ _ Hf)).
  eapply Rle_trans; [| apply IH; [exact Hf | exact Hts']].
  rewrite (fadd_value _ _ Hst). apply round_ge; [apply generic_format_B2R | lra].
Qed.

Lemma sumsq_ge_one (m : b64) (ys : list b64) :
  fin (fsumsq m ys) -> 1 <= r (fsumsq m ys).
Proof.
  intro Hf. unfold fsumsq in *. rewrite <- B2R_fone. apply fold_ge; [exact Hf |].
  destruct (fold_finite_inv _ _ Hf) as [_ HF].
  apply Forall_forall. intros p Hp. rewrite Forall_forall in HF.
  apply in_map_iff in Hp. destruct Hp as [y [<- Hy]].
  apply fsq_nonneg. apply HF. apply in_map. exact Hy.
Qed.

Lemma sqrt_ge_one (s : b64) :
  fin s -> 1 <= r s -> fin (fsqrt s) /\ 1 <= r (fsqrt s).
Proof.
  intros Hf H1.
  assert (Hp : Diana.Float.Cholesky.positive s)
    by (apply Diana.Float.Cholesky.finite_positive; [exact Hf | lra]).
  destruct (proj1 (Diana.Float.Cholesky.sqrt_contract sqrt_nan s Hp) Hf) as [F [_ V]].
  split; [exact F |]. rewrite V. apply round_ge; [apply format_one |].
  rewrite <- sqrt_1. apply sqrt_le_1_alt. exact H1.
Qed.


Lemma feqb_zero (x : b64) : fin x -> feqb x fzero = true -> r x = 0.
Proof.
  intros Hx H. unfold Diana.Float.LU.feqb in H.
  rewrite (Bcompare_correct prec emax x fzero Hx eq_refl) in H. simpl (B2R _ _ fzero) in H.
  destruct (Rcompare_spec (r x) 0) as [E | E | E]; [discriminate | exact E | discriminate].
Qed.

Lemma remove_bound (xs : list b64) (k : nat) (m : b64) :
  Forall (fun x => fin x) xs -> r m = norm_inf (map (B2R prec emax) xs) ->
  Forall (fun y => fin y /\ Rabs (r y) <= r m) (remove k xs).
Proof.
  intros Hxs Vm. apply Forall_forall. intros y Hy. apply in_remove in Hy.
  rewrite Forall_forall in Hxs. split; [exact (Hxs y Hy) |].
  rewrite Vm. apply norm_inf_ge. apply in_map. exact Hy.
Qed.

(* The computed sum of squares s against the exact 1 + sum over i <> k of (x[i] / m)^2. *)
Lemma sum_error (xs : list b64) (k : nat) (m : b64) :
  Forall (fun x => fin x) xs -> fin m -> r m = norm_inf (map (B2R prec emax) xs) -> 0 < r m ->
  (k < length xs)%nat -> INR (length xs + 3) * u < 1 -> fin (fsumsq m (remove k xs)) ->
  let Q := 1 + sumsq (map (fun a => a / r m) (map (B2R prec emax) (remove k xs))) in
  Rabs (r (fsumsq m (remove k xs)) - Q) <= gamma (length xs + 3) * Q.
Proof.
  intros Hxs Fm Vm Hpos Hkn Hk Fs Q.
  pose proof u_pos as Hu. pose proof eta_pos as He.
  set (ys := remove k xs) in *.
  assert (HL : length ys = (length xs - 1)%nat) by (apply length_remove; exact Hkn).
  set (L := length ys) in *.
  assert (H3 : INR 3 * u < 1) by (apply (inr_mono 3 (length xs + 3)); [lia | exact Hk]).
  destruct (sumsq_spec m ys Fm Hpos (remove_bound xs k m Hxs Vm) H3) as [F [N [_ E]]].
  set (A := rsum (map (fsq m) ys)) in *.
  set (T := sumsq (map (fun a => a / r m) (map (B2R prec emax) ys))) in *.
  fold L in E.
  assert (HT : 0 <= T) by apply sumsq_nonneg.
  assert (HkL : INR (0 + length (map (fsq m) ys)) * u < 1)
    by (rewrite length_map; apply (inr_mono L (length xs + 3)); [lia | exact Hk]).
  pose proof (fold_nonneg (map (fsq m) ys) fone 1 0 Fs N ltac:(lra)
                (ltac:(rewrite B2R_fone, Rminus_diag, Rabs_R0, gamma_0; lra)) HkL) as Hsum.
  rewrite length_map in Hsum. cbn [Nat.add] in Hsum. fold L A in Hsum.
  change (fold_left fadd (map (fsq m) ys) fone) with (fsumsq m ys) in Hsum.
  assert (HL3 : INR (L + 3) * u < 1) by (apply (inr_mono (L + 3) (length xs + 3)); [lia | exact Hk]).
  assert (HL0 : INR L * u < 1) by (apply (inr_mono L (L + 3)); [lia | exact HL3]).
  pose proof (gamma_add L 3 HL3) as Gadd.
  pose proof (absorb L HL0) as Hab.
  pose proof (gamma_nonneg L HL0) as GL. pose proof (gamma_nonneg 3 H3) as G3.
  assert (HL4 : INR (S (L + 3)) * u < 1)
    by (apply (inr_mono (S (L + 3)) (length xs + 3)); [lia | exact Hk]).
  pose proof (gamma_add_u (L + 3) HL4) as Gu.
  assert (Gm : gamma (S (L + 3)) <= gamma (length xs + 3)) by (apply gamma_mono; [lia | exact Hk]).
  pose proof (pos_INR L) as HLp.
  assert (HA : 1 + A <= (1 + gamma 3) * Q + 5 * INR L * eta).
  { unfold Q. fold ys T. destruct (Rabs_le_inv _ _ E). nra. }
  assert (H1 : Rabs (r (fsumsq m ys) - Q)
               <= gamma L * (1 + A) + (gamma 3 * T + 5 * INR L * eta)).
  { replace (r (fsumsq m ys) - Q) with ((r (fsumsq m ys) - (1 + A)) + (A - T))
      by (unfold Q; fold ys T; ring).
    eapply Rle_trans; [apply Rabs_triang | lra]. }
  assert (H2 : gamma L * (1 + A) <= gamma L * ((1 + gamma 3) * Q + 5 * INR L * eta))
    by (apply Rmult_le_compat_l; lra).
  assert (H4 : gamma 3 * T <= gamma 3 * Q) by (apply Rmult_le_compat_l; unfold Q; fold ys T; lra).
  assert (HS1 : 1 <= Q) by (unfold Q; fold ys T; lra).
  assert (H5 : u <= u * Q) by nra.
  assert (H6 : (gamma L + gamma 3 + gamma L * gamma 3) * Q <= gamma (L + 3) * Q)
    by (apply Rmult_le_compat_r; lra).
  assert (H7 : (gamma (L + 3) + u) * Q <= gamma (length xs + 3) * Q)
    by (apply Rmult_le_compat_r; lra).
  nra.
Qed.

Lemma root_error (xs : list b64) (k : nat) (m : b64) :
  Forall (fun x => fin x) xs -> fin m -> r m = norm_inf (map (B2R prec emax) xs) -> 0 < r m ->
  (k < length xs)%nat -> Rabs (r (nth k xs fzero)) = r m ->
  INR (length xs + 4) * u < 1 -> fin (fsumsq m (remove k xs)) ->
  fin (fsqrt (fsumsq m (remove k xs))) /\ 1 <= r (fsqrt (fsumsq m (remove k xs))) /\
  exists F, Rabs (F - 1) <= gamma (length xs + 4) /\
    r m * r (fsqrt (fsumsq m (remove k xs))) = norm2 (map (B2R prec emax) xs) * F.
Proof.
  intros Hxs Fm Vm Hpos Hkn Hv Hk Fs.
  assert (Hk3 : INR (length xs + 3) * u < 1)
    by (apply (inr_mono (length xs + 3) (length xs + 4)); [lia | exact Hk]).
  pose proof (sum_error xs k m Hxs Fm Vm Hpos Hkn Hk3 Fs) as Hs. cbv zeta in Hs.
  set (s := fsumsq m (remove k xs)) in *.
  set (T := sumsq (map (fun a => a / r m) (map (B2R prec emax) (remove k xs)))) in *.
  assert (HT : 0 <= T) by apply sumsq_nonneg.
  set (Q := 1 + T) in *.
  pose proof (sumsq_ge_one m (remove k xs) Fs) as Hs1. fold s in Hs1.
  destruct (sqrt_ge_one s Fs Hs1) as [Ft Ht1].
  split; [exact Ft | split; [exact Ht1 |]].
  destruct (Diana.Float.Cholesky.sqrt_error sqrt_nan s Fs ltac:(lra)) as [d [Hd Hr]].
  set (z := r s / Q).
  assert (HSp : 0 < Q) by (unfold Q; lra).
  assert (Hz : 0 <= z) by (unfold z; apply Rmult_le_pos; [lra | left; apply Rinv_0_lt_compat; lra]).
  assert (Hz1 : Rabs (z - 1) <= gamma (length xs + 3)).
  { unfold z. replace (r s / Q - 1) with ((r s - Q) / Q) by (field; lra).
    unfold Rdiv. rewrite Rabs_mult, Rabs_inv, (Rabs_pos_eq Q) by lra.
    apply Rmult_le_reg_r with Q; [exact HSp |].
    rewrite Rmult_assoc, Rinv_l, Rmult_1_r by lra. exact Hs. }
  assert (Hsq : sqrt (r s) = sqrt Q * sqrt z).
  { rewrite <- sqrt_mult by lra. f_equal. unfold z. field. lra. }
  pose proof (Rle_trans _ _ _ (sqrt_one_error z Hz) Hz1) as HF1.
  pose proof (Diana.Float.Cholesky.factor_mul (sqrt z) d (length xs + 3) HF1 Hd
                (inr_mono (S (length xs + 3)) (length xs + 4) ltac:(lia) Hk)) as HF.
  replace (S (length xs + 3)) with (length xs + 4)%nat in HF by lia.
  exists (sqrt z * (1 + d)). split; [exact HF |].
  assert (Hn : nth k (map (B2R prec emax) xs) 0 = r (nth k xs fzero))
    by exact (map_nth (B2R prec emax) xs fzero k).
  assert (Hnz : nth k (map (B2R prec emax) xs) 0 <> 0)
    by (rewrite Hn; intro E; rewrite E, Rabs_R0 in Hv; lra).
  pose proof (scale (map (B2R prec emax) xs) k ltac:(rewrite length_map; exact Hkn) Hnz) as Hsc.
  rewrite Hn, Hv, remove_map in Hsc. fold T Q in Hsc.
  rewrite Hr, Hsq, <- Hsc. ring.
Qed.

Lemma fnorm2_zero (xs : list b64) (i k : nat) (m : b64) :
  Forall (fun x => fin x) xs -> fscale xs = (i, k, m) -> feqb m fzero = true ->
  norm2 (map (B2R prec emax) xs) = 0.
Proof.
  intros Hxs Hsc Heq. destruct (fscale_spec xs i k m Hxs Hsc) as [Fm [Vm _]].
  rewrite (feqb_zero m Fm Heq) in Vm.
  destruct (equiv (map (B2R prec emax) xs)) as [_ [H1 H2]].
  pose proof (norm2_nonneg (map (B2R prec emax) xs)). rewrite <- Vm in H2. lra.
Qed.

(* Layer B, forward error of the 2-norm: with every entry finite and a finite result,
   |r - |x|_2| <= gamma (n + 5) |x|_2 + eta. *)
Theorem norm2_error (xs : list b64) :
  Forall (fun x => fin x) xs -> fin (fnorm2 xs) -> INR (length xs + 5) * u < 1 ->
  Rabs (r (fnorm2 xs) - norm2 (map (B2R prec emax) xs))
    <= gamma (length xs + 5) * norm2 (map (B2R prec emax) xs) + eta.
Proof.
  intros Hxs Hf Hk. pose proof u_pos. pose proof eta_pos.
  pose proof (gamma_nonneg _ Hk) as Hg. pose proof (norm2_nonneg (map (B2R prec emax) xs)) as HN.
  unfold fnorm2 in *. destruct (fscale xs) as [[i k] m] eqn:Hsc.
  destruct (feqb m fzero) eqn:Heq.
  - rewrite (fnorm2_zero xs i k m Hxs Hsc Heq). simpl (B2R _ _ fzero).
    rewrite Rminus_0_r, Rabs_R0. lra.
  - destruct (fscale_spec xs i k m Hxs Hsc) as [Fm [Vm Hidx]].
    pose proof (Diana.Float.LU.feqb_nonzero m Fm Heq) as Hm0.
    assert (Hpos : 0 < r m) by (pose proof (norm_inf_nonneg (map (B2R prec emax) xs)); lra).
    destruct Hidx as [Hz0 | [Hkn Hv]]; [lra |].
    destruct (fmul_value _ _ Hf) as [_ [Ft Vr]].
    pose proof (fsqrt_finite_inv _ Ft) as Fs.
    destruct (root_error xs k m Hxs Fm Vm Hpos Hkn Hv
                (inr_mono (length xs + 4) (length xs + 5) ltac:(lia) Hk) Fs) as [_ [_ [F [HF HmF]]]].
    rewrite Vr, HmF.
    set (N := norm2 (map (B2R prec emax) xs)) in *.
    destruct (round_error (N * F)) as [d [e [Hd [He Hr]]]]. rewrite Hr.
    pose proof (Diana.Float.Cholesky.factor_mul F d (length xs + 4) HF Hd
                  (inr_mono (S (length xs + 4)) (length xs + 5) ltac:(lia) Hk)) as HF2.
    replace (S (length xs + 4)) with (length xs + 5)%nat in HF2 by lia.
    replace (N * F * (1 + d) + e - N) with (N * (F * (1 + d) - 1) + e) by ring.
    eapply Rle_trans; [apply Rabs_triang |]. rewrite Rabs_mult, (Rabs_pos_eq N) by exact HN.
    apply Rplus_le_compat; [| exact He].
    rewrite (Rmult_comm (gamma _)). apply Rmult_le_compat_l; [exact HN | exact HF2].
Qed.

(* Layer B, no spurious overflow in the 2-norm: with every entry finite, the result is finite
   whenever (1 + gamma (n + 4)) |x|_2 <= DBL_MAX; no square, quotient or partial sum can
   overflow. *)
Theorem norm2_finite (xs : list b64) :
  Forall (fun x => fin x) xs -> INR (length xs + 4) * u < 1 ->
  (1 + gamma (length xs + 4)) * norm2 (map (B2R prec emax) xs) <= dbl_max -> fin (fnorm2 xs).
Proof.
  intros Hxs Hk Hb. pose proof u_pos. pose proof eta_pos.
  unfold fnorm2. destruct (fscale xs) as [[i k] m] eqn:Hsc.
  destruct (feqb m fzero) eqn:Heq; [reflexivity |].
  destruct (fscale_spec xs i k m Hxs Hsc) as [Fm [Vm Hidx]].
  pose proof (Diana.Float.LU.feqb_nonzero m Fm Heq) as Hm0.
  assert (Hpos : 0 < r m) by (pose proof (norm_inf_nonneg (map (B2R prec emax) xs)); lra).
  destruct Hidx as [Hz0 | [Hkn Hv]]; [lra |].
  assert (H3 : INR 3 * u < 1) by (apply (inr_mono 3 (length xs + 4)); [lia | exact Hk]).
  set (ys := remove k xs).
  assert (HL : length ys = (length xs - 1)%nat) by (apply length_remove; exact Hkn).
  destruct (sumsq_spec m ys Fm Hpos (remove_bound xs k m Hxs Vm) H3) as [F [N [B _]]].
  assert (HkL : INR (0 + length (map (fsq m) ys)) * u < 1)
    by (rewrite length_map; apply (inr_mono (length ys) (length xs + 4)); [lia | exact Hk]).
  assert (Fs : fin (fsumsq m ys)).
  { unfold fsumsq. apply (fold_nonneg_finite _ fone 1 0); [reflexivity | exact F | exact N | lra |
      rewrite B2R_fone, Rminus_diag, Rabs_R0, gamma_0; lra | exact HkL |].
    rewrite length_map in *. simpl (0 + length ys)%nat in *.
    assert (HL0 : INR (length ys) * u < 1) by (simpl in HkL; exact HkL).
    pose proof (one_gamma_le _ HL0) as G1.
    assert (Hn : INR (S (length ys)) <= / u).
    { apply (inr_lt_inv_u (S (length ys))).
      apply (inr_mono (S (length ys)) (length xs + 4)); [lia | exact Hk]. }
    rewrite S_INR in Hn.
    pose proof (gamma_nonneg _ HL0). pose proof (rsum_nonneg _ N).
    eapply Rle_lt_trans; [| apply inv_u_sq_lt].
    apply Rmult_le_compat; [lra | lra | exact G1 | lra]. }
  destruct (root_error xs k m Hxs Fm Vm Hpos Hkn Hv Hk Fs) as [Ft [Ht1 [F2 [HF HmF]]]].
  apply (proj2 (fmul_finite_iff m _ Fm Ft)).
  fold ys in Ht1, HmF, Ft.
  assert (Hprod : 0 <= r m * r (fsqrt (fsumsq m ys))) by nra.
  assert (Hle : r m * r (fsqrt (fsumsq m ys)) <= dbl_max).
  { rewrite HmF. pose proof (norm2_nonneg (map (B2R prec emax) xs)).
    destruct (Rabs_le_inv _ _ HF). eapply Rle_trans; [| exact Hb].
    rewrite (Rmult_comm (1 + _)). apply Rmult_le_compat_l; lra. }
  rewrite Rabs_pos_eq by (apply round_ge; [apply generic_format_0 | exact Hprod]).
  eapply Rle_lt_trans; [| apply dbl_max_lt].
  apply round_le_fmt; [rewrite <- B2R_fmaxval; apply generic_format_B2R | exact Hle].
Qed.

(* Layer B, the 2-norm is at least the largest magnitude, so a nonzero vector has a positive
   2-norm: no underflow to zero. *)
Theorem norm2_lower (xs : list b64) :
  Forall (fun x => fin x) xs -> fin (fnorm2 xs) -> norm_inf (map (B2R prec emax) xs) <= r (fnorm2 xs).
Proof.
  intros Hxs Hf. unfold fnorm2 in *. destruct (fscale xs) as [[i k] m] eqn:Hsc.
  destruct (fscale_spec xs i k m Hxs Hsc) as [Fm [Vm _]].
  destruct (feqb m fzero) eqn:Heq.
  - rewrite <- Vm, (feqb_zero m Fm Heq). simpl (B2R _ _ fzero). lra.
  - destruct (fmul_value _ _ Hf) as [_ [Ft Vr]]. pose proof (fsqrt_finite_inv _ Ft) as Fs.
    pose proof (sumsq_ge_one m (remove k xs) Fs) as H1.
    destruct (sqrt_ge_one _ Fs H1) as [_ Ht1].
    pose proof (norm_inf_nonneg (map (B2R prec emax) xs)) as H0.
    rewrite Vr, <- Vm in *. apply round_ge; [apply generic_format_B2R | nra].
Qed.

End Model.
