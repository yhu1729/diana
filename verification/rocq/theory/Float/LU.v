From Stdlib Require Import Reals ZArith Lia Lra Psatz.
From Flocq Require Import Core Relative IEEE754.BinarySingleNaN IEEE754.Binary.
From Diana.Float Require Import Sum.
From Diana.Float Require Cholesky Substitution.
From Diana.Real Require Import Cholesky LU.
Open Scope R_scope.

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

(* The C's comparisons x < y, x > y and x == y. *)
Definition fltb (x y : b64) : bool :=
  match Bcompare prec emax x y with Some Lt => true | _ => false end.
Definition fgtb (x y : b64) : bool :=
  match Bcompare prec emax x y with Some Gt => true | _ => false end.
Definition feqb (x y : b64) : bool :=
  match Bcompare prec emax x y with Some Eq => true | _ => false end.

Section Model.

Variable sub_nan mult_nan div_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.
Variable opp_nan : b64 -> {x : b64 | is_nan prec emax x = true}.

Local Abbreviation fsub := (Diana.Float.Cholesky.fsub sub_nan).
Local Abbreviation fmul := (Diana.Float.Sum.fmul mult_nan).
Local Abbreviation fdiv := (Diana.Float.Sum.fdiv div_nan).
Local Abbreviation fzero := Diana.Float.Cholesky.fzero.
Local Abbreviation fin x := (is_finite prec emax x = true).
Local Abbreviation r x := (B2R prec emax x).

(* The C's magnitude: v < 0.0 ? -v : v. *)
Definition fmag (x : b64) : b64 := if fltb x fzero then Bopp prec emax opp_nan x else x.

(* The binary64 operations of the kernel, each rounded to nearest-even. *)
Definition fops : ops b64 :=
  {| osub := fsub; omul := fmul; odiv := fdiv; omag := fmag; ogt := fgtb; ozero := fzero |}.

(* The binary64 model of diana_lu: the working matrix after steps 0, ..., k - 1 in the C's
   operation order, A i j = a[i + j*n]. *)
Definition fstate (n : nat) (A : nat -> nat -> b64) (k : nat) : nat -> nat -> b64 :=
  state fops n A k.

(* The packed factor: L strictly below the diagonal, U on and above it. *)
Definition flu (A : nat -> nat -> b64) (n : nat) : nat -> nat -> b64 := fstate n A n.

(* Row i of P A is row fprow A n i of A. *)
Definition fprow (A : nat -> nat -> b64) (n : nat) : nat -> nat := perm fops n A n.

(* The magnitude of the pivot of step k, which the C compares with 0.0. *)
Definition ftop (A : nat -> nat -> b64) (n k : nat) : b64 := top fops n k (fstate n A k).

(* The C's DIANA_OK conditions: every entry of a finite, and at each step a pivot magnitude
   that is not 0.0 and updates that are all finite. *)
Definition step_ok (A : nat -> nat -> b64) (n k : nat) : Prop :=
  feqb (ftop A n k) fzero = false /\
  forall i j, (k < i)%nat -> (i < n)%nat -> (k < j)%nat -> (j < n)%nat ->
    fin (fstate n A (S k) i j).

Definition fok (A : nat -> nat -> b64) (n : nat) : Prop :=
  (forall i j, (i < n)%nat -> (j < n)%nat -> fin (A i j)) /\
  forall k, (k < n)%nat -> step_ok A n k.

Lemma fmag_finite (x : b64) : fin x -> fin (fmag x) /\ r (fmag x) = Rabs (r x).
Proof.
  intro Hx. unfold fmag, fltb.
  rewrite (Bcompare_correct prec emax x fzero Hx eq_refl). simpl B2R.
  destruct (Rcompare_spec (r x) 0) as [Hlt | Heq | Hgt].
  - split; [rewrite is_finite_Bopp; exact Hx |].
    rewrite B2R_Bopp, Rabs_left by exact Hlt. reflexivity.
  - split; [exact Hx | rewrite Heq, Rabs_R0; reflexivity].
  - split; [exact Hx | rewrite Rabs_right by lra; reflexivity].
Qed.

Lemma fgtb_real (x y : b64) : fin x -> fin y -> fgtb x y = rgt (r x) (r y).
Proof.
  intros Hx Hy. unfold fgtb, rgt. rewrite (Bcompare_correct prec emax x y Hx Hy).
  destruct (Rlt_dec (r y) (r x)) as [H | H].
  - rewrite Rcompare_Gt by exact H. reflexivity.
  - destruct (Rcompare_spec (r x) (r y)); try reflexivity. lra.
Qed.

Lemma feqb_nonzero (x : b64) : fin x -> feqb x fzero = false -> r x <> 0.
Proof.
  intros Hx H E. unfold feqb in H. rewrite (Bcompare_correct prec emax x fzero Hx eq_refl) in H.
  simpl B2R in H. rewrite E, Rcompare_Eq in H by reflexivity. discriminate.
Qed.

(* On finite entries the binary64 pivot search is the real one on their values. *)
Lemma fsearch_real (B : nat -> nat -> b64) (k t : nat) :
  (forall i, (k <= i < k + t)%nat -> fin (B i k)) ->
  fst (search fops B k t) = fst (search rops (fun i j => r (B i j)) k t) /\
  fin (snd (search fops B k t)) /\
  r (snd (search fops B k t)) = snd (search rops (fun i j => r (B i j)) k t).
Proof.
  induction t as [| t IH]; intro H; [split; [| split]; reflexivity |].
  destruct (IH (fun i Hi => H i ltac:(lia))) as [Hp [Hf Hv]].
  cbn [search].
  destruct (fmag_finite (B (k + t)%nat k) (H (k + t)%nat ltac:(lia))) as [Hmf Hmv].
  change (omag fops) with fmag. change (ogt fops) with fgtb.
  change (omag rops) with Rabs. change (ogt rops) with rgt.
  rewrite (fgtb_real _ _ Hmf Hf), Hmv, Hv.
  destruct (rgt _ _); cbn [fst snd]; [split; [reflexivity | split; [exact Hmf | exact Hmv]] |].
  split; [exact Hp | split; [exact Hf | exact Hv]].
Qed.

(* The pivot has the largest magnitude in its column, and the tested magnitude is its own. *)
Lemma ftop_spec (B : nat -> nat -> b64) (n k : nat) :
  (k < n)%nat -> (forall i, (k <= i < n)%nat -> fin (B i k)) ->
  fin (top fops n k B) /\
  r (top fops n k B) = Rabs (r (B (pivot fops n k B) k)) /\
  forall i, (k <= i < n)%nat -> Rabs (r (B i k)) <= r (top fops n k B).
Proof.
  intros Hk H. unfold top, pivot.
  destruct (fsearch_real B k (n - k) (fun i Hi => H i ltac:(lia))) as [Hp [Hf Hv]].
  destruct (rtop_spec (fun i j => r (B i j)) n k Hk) as [Ht Hle].
  unfold top, pivot in Ht, Hle.
  split; [exact Hf |]. rewrite Hv, Hp. split; [exact Ht |].
  intros i Hi. exact (Hle i Hi).
Qed.

(* A quotient of magnitude at most 1 does not overflow and stays at most 1 when rounded. *)
Lemma fdiv_bounded (x d : b64) :
  fin x -> r d <> 0 -> Rabs (r x) <= Rabs (r d) ->
  fin (fdiv x d) /\ Rabs (r (fdiv x d)) <= 1.
Proof.
  intros Hx Hd Hle.
  pose proof (div_le_1 (r x) (r d) Hle) as Hq.
  assert (Hr : Rabs (round radix2 fexp ZnearestE (r x / r d)) <= 1).
  { assert (H1 : round radix2 fexp ZnearestE 1 = 1).
    { apply round_generic; [typeclasses eauto |].
      change 1 with (bpow radix2 0). apply generic_format_bpow. unfold FLT_exp. simpl. lia. }
    assert (Hm1 : round radix2 fexp ZnearestE (Ropp 1) = Ropp 1).
    { rewrite round_NE_opp, H1. reflexivity. }
    apply Rabs_le. apply Rabs_le_inv in Hq. split.
    - rewrite <- Hm1. apply round_le; [typeclasses eauto | typeclasses eauto | lra].
    - rewrite <- H1. apply round_le; [typeclasses eauto | typeclasses eauto | lra]. }
  assert (Hf : fin (fdiv x d)).
  { apply (fdiv_finite_iff x d Hx Hd). eapply Rle_lt_trans; [exact Hr |].
    change 1 with (bpow radix2 0). apply bpow_lt. reflexivity. }
  split; [exact Hf |]. rewrite (fdiv_value x d Hf Hd). exact Hr.
Qed.

(* The trailing block of each working matrix is finite. *)
Lemma trailing_finite (A : nat -> nat -> b64) (n : nat) :
  fok A n -> forall k i j, (k <= i)%nat -> (i < n)%nat -> (k <= j)%nat -> (j < n)%nat ->
  fin (fstate n A k i j).
Proof.
  intros [HA Hs] k i j Hki Hin Hkj Hjn. destruct k as [| k].
  - apply HA; assumption.
  - apply (proj2 (Hs k ltac:(lia))); lia.
Qed.

(* The pivot entry U k k: finite and nonzero. *)
Lemma diag_ok (A : nat -> nat -> b64) (n k : nat) :
  fok A n -> (k < n)%nat ->
  let S0 := fstate n A k in
  fin (S0 (pivot fops n k S0) k) /\ r (S0 (pivot fops n k S0) k) <> 0 /\
  forall i, (k <= i < n)%nat -> Rabs (r (S0 i k)) <= Rabs (r (S0 (pivot fops n k S0) k)).
Proof.
  intros Hok Hk S0.
  assert (Hcol : forall i, (k <= i < n)%nat -> fin (S0 i k))
    by (intros i Hi; apply (trailing_finite A n Hok); lia).
  destruct (ftop_spec S0 n k Hk Hcol) as [Htf [Htv Hle]].
  pose proof (pivot_range fops n k S0 Hk) as Hp.
  split; [apply Hcol; lia |]. split.
  - intro E. apply (feqb_nonzero _ Htf (proj1 (proj2 Hok k Hk))). fold S0. rewrite Htv, E.
    apply Rabs_R0.
  - intros i Hi. rewrite <- Htv. apply Hle. exact Hi.
Qed.

(* Below the diagonal, each column holds finite multipliers of magnitude at most 1, whatever
   rows the later steps interchange. *)
Lemma multiplier_ok (A : nat -> nat -> b64) (n : nat) :
  fok A n -> forall j d r', (S j + d <= n)%nat -> (j < r')%nat -> (r' < n)%nat ->
  fin (fstate n A (S j + d) r' j) /\ Rabs (r (fstate n A (S j + d) r' j)) <= 1.
Proof.
  intros Hok j d. induction d as [| d IH]; intros r' Hd Hr Hrn.
  - rewrite Nat.add_0_r. unfold fstate. cbn [state]. fold (fstate n A j).
    destruct (diag_ok A n j Hok ltac:(lia)) as [Hpf [Hpnz Hle]]. cbv zeta in Hpf, Hpnz, Hle.
    pose proof (pivot_range fops n j (fstate n A j) ltac:(lia)) as Hp.
    set (p := pivot fops n j (fstate n A j)) in *.
    unfold elim. replace (j <? r')%nat with true by (symmetry; apply Nat.ltb_lt; exact Hr).
    rewrite Nat.eqb_refl. change (odiv fops) with fdiv.
    rewrite !swap_tau.
    replace (tau j p j) with p by (unfold tau; rewrite Nat.eqb_refl; reflexivity).
    pose proof (tau_ge j p r' j (le_n j) ltac:(lia) ltac:(lia)).
    pose proof (tau_lt j p r' n ltac:(lia) ltac:(lia) Hrn).
    apply fdiv_bounded; [| exact Hpnz | apply Hle; lia].
    apply (trailing_finite A n Hok); lia.
  - replace (S j + S d)%nat with (S (S j + d)) by lia. unfold fstate. cbn [state].
    fold (fstate n A (S j + d)).
    set (m := (S j + d)%nat) in *. set (Sm := fstate n A m).
    set (p := pivot fops n m Sm).
    assert (Hp : (m <= p < n)%nat) by (apply pivot_range; lia).
    unfold elim.
    replace (j =? m)%nat with false by (symmetry; apply Nat.eqb_neq; lia).
    replace (m <? j)%nat with false by (symmetry; apply Nat.ltb_ge; lia).
    assert (Hs : swap m p Sm r' j = Sm (tau m p r') j) by apply swap_tau.
    assert (Ht : (j < tau m p r')%nat /\ (tau m p r' < n)%nat).
    { split; [unfold tau; destruct (r' =? m)%nat, (r' =? p)%nat; lia | apply tau_lt; lia]. }
    destruct (m <? r')%nat; rewrite Hs; apply IH; lia.
Qed.

(* Row i of the factor is the pivot row of step i, as it stood before the step. *)
Lemma flu_row (A : nat -> nat -> b64) (n i j : nat) :
  (i < n)%nat -> flu A n i j = fstate n A i (pivot fops n i (fstate n A i)) j.
Proof.
  intro Hi. unfold flu, fstate. rewrite (state_row fops n A (S i) n i j) by lia.
  cbn [state]. unfold elim. rewrite Nat.ltb_irrefl. rewrite swap_tau.
  replace (tau i (pivot fops n i (state fops n A i)) i) with (pivot fops n i (state fops n A i))
    by (unfold tau; rewrite Nat.eqb_refl; reflexivity).
  reflexivity.
Qed.

(* Layer B, finiteness: when the C returns DIANA_OK, every entry of the factor is finite. *)
Theorem finite_result (A : nat -> nat -> b64) (n : nat) :
  fok A n -> forall i j, (i < n)%nat -> (j < n)%nat -> fin (flu A n i j).
Proof.
  intros Hok i j Hi Hj. destruct (Nat.le_gt_cases i j) as [Hij | Hji].
  - rewrite flu_row by exact Hi.
    pose proof (pivot_range fops n i (fstate n A i) Hi).
    apply (trailing_finite A n Hok); lia.
  - unfold flu. replace n with (S j + (n - S j))%nat at 2 by lia.
    apply (multiplier_ok A n Hok); lia.
Qed.

(* Layer B, partial pivoting bounds the binary64 multipliers: |L i j| <= 1. *)
Theorem multiplier_bound (A : nat -> nat -> b64) (n : nat) :
  fok A n -> forall i j, (j < i)%nat -> (i < n)%nat -> Rabs (r (flu A n i j)) <= 1.
Proof.
  intros Hok i j Hji Hi. unfold flu. replace n with (S j + (n - S j))%nat at 2 by lia.
  apply (multiplier_ok A n Hok); lia.
Qed.

(* The packed factor is the unpivoted factorization of P A, entry by entry in the C's order. *)
Lemma flu_dot (A : nat -> nat -> b64) (n i j k : nat) :
  (k <= i)%nat -> (k <= j)%nat -> (k <= n)%nat ->
  dot fops (permute (fprow A n) A) i j k =
  Diana.Float.Substitution.fdotv sub_nan mult_nan (fun t => flu A n i t) (fun t => flu A n t j)
    (A (fprow A n i) j) k.
Proof.
  intros Hi Hj Hn. set (B := permute (fprow A n) A).
  assert (E : forall i' j', flu A n i' j' = nstate fops B n i' j') by apply state_nstate.
  induction k as [| k IH]; [reflexivity |].
  cbn [dot Diana.Float.Substitution.fdotv]. rewrite IH by lia.
  rewrite !E. rewrite (nstate_col fops B n i k) by lia. rewrite (nstate_row fops B n k j) by lia.
  reflexivity.
Qed.

Lemma flu_upper (A : nat -> nat -> b64) (n i j : nat) :
  (i <= j)%nat -> (j < n)%nat ->
  flu A n i j =
  Diana.Float.Substitution.fdotv sub_nan mult_nan (fun t => flu A n i t) (fun t => flu A n t j)
    (A (fprow A n i) j) i.
Proof.
  intros Hij Hj. rewrite <- flu_dot by lia.
  unfold flu at 1, fstate, fprow. rewrite state_nstate.
  rewrite (nstate_row fops _ n i j) by lia. apply nstate_dot; lia.
Qed.

Lemma flu_lower (A : nat -> nat -> b64) (n i j : nat) :
  (j < i)%nat -> (i < n)%nat ->
  flu A n i j =
  fdiv (Diana.Float.Substitution.fdotv sub_nan mult_nan (fun t => flu A n i t)
          (fun t => flu A n t j) (A (fprow A n i) j) j)
    (flu A n j j).
Proof.
  intros Hji Hi. rewrite <- flu_dot by lia.
  rewrite (flu_upper A n j j) by lia. rewrite <- flu_dot by lia.
  unfold flu at 1, fstate, fprow. rewrite state_nstate.
  rewrite (nstate_col fops _ n i j) by lia. exact (nstate_mult fops _ i j Hji).
Qed.

Lemma diag_nonzero (A : nat -> nat -> b64) (n j : nat) :
  fok A n -> (j < n)%nat -> r (flu A n j j) <> 0.
Proof.
  intros Hok Hj. rewrite flu_row by exact Hj. exact (proj1 (proj2 (diag_ok A n j Hok Hj))).
Qed.

(* The subtractions of the C, c - g 0 * h 0 - ..., as Cholesky's dot_error. *)
Lemma dotv_error (g h : nat -> b64) (c : b64) (k : nat) :
  fin (Diana.Float.Substitution.fdotv sub_nan mult_nan g h c k) -> INR k * u < 1 ->
  exists F, Rabs (F - 1) <= gamma k /\
    Rabs (r c - sum k (fun m => r (g m) * r (h m))
          - r (Diana.Float.Substitution.fdotv sub_nan mult_nan g h c k) * F)
      <= gamma k * sum k (fun m => Rabs (r (g m) * r (h m))) + (1 + gamma k) * INR k * eta.
Proof.
  intros Hf Hk.
  rewrite Diana.Float.Substitution.fdotv_fdot in Hf.
  destruct (Diana.Float.Cholesky.dot_error sub_nan mult_nan
              (fun i m => if (i =? 0)%nat then g m else h m) c 0 1 k Hf Hk) as [F [HF Hb]].
  exists F. split; [exact HF |].
  rewrite Diana.Float.Substitution.fdotv_fdot. cbn beta iota in Hb. exact Hb.
Qed.

(* Layer B, backward error on and above the diagonal: with B = P A,
   |B i j - sum_{t<i} L i t * U t j - U i j|
     <= gamma i * (sum_{t<i} |L i t * U t j| + |U i j|) + (1 + gamma i) * i * eta. *)
Theorem upper_error (A : nat -> nat -> b64) (n i j : nat) :
  fok A n -> (i <= j)%nat -> (j < n)%nat -> INR i * u < 1 ->
  Rabs (r (A (fprow A n i) j)
        - (sum i (fun t => r (flu A n i t) * r (flu A n t j)) + r (flu A n i j)))
    <= gamma i * (sum i (fun t => Rabs (r (flu A n i t) * r (flu A n t j)))
                  + Rabs (r (flu A n i j)))
       + (1 + gamma i) * INR i * eta.
Proof.
  intros Hok Hij Hj Hk.
  pose proof (finite_result A n Hok i j ltac:(lia) Hj) as Hf.
  rewrite (flu_upper A n i j Hij Hj) in Hf.
  destruct (dotv_error _ _ _ i Hf Hk) as [F [HF Hb]].
  rewrite <- (flu_upper A n i j Hij Hj) in Hb.
  set (S0 := sum i (fun t => r (flu A n i t) * r (flu A n t j))) in *.
  set (A0 := sum i (fun t => Rabs (r (flu A n i t) * r (flu A n t j)))) in *.
  set (c := r (A (fprow A n i) j)) in *.
  set (x := r (flu A n i j)) in *.
  replace (c - (S0 + x)) with ((c - S0 - x * F) + x * (F - 1)) by ring.
  eapply Rle_trans; [apply Rabs_triang |]. rewrite (Rabs_mult x).
  assert (H2 : Rabs x * Rabs (F - 1) <= gamma i * Rabs x).
  { rewrite Rmult_comm. apply Rmult_le_compat_r; [apply Rabs_pos | exact HF]. }
  lra.
Qed.

(* Layer B, backward error below the diagonal: with B = P A,
   |B i j - sum_{t<j} L i t * U t j - U j j * L i j|
     <= gamma (j + 1) * (sum_{t<j} |L i t * U t j| + |U j j * L i j|)
        + (1 + gamma (j + 1)) * (j + |U j j|) * eta. *)
Theorem lower_error (A : nat -> nat -> b64) (n i j : nat) :
  fok A n -> (j < i)%nat -> (i < n)%nat -> INR (S j) * u < 1 ->
  Rabs (r (A (fprow A n i) j)
        - (sum j (fun t => r (flu A n i t) * r (flu A n t j)) + r (flu A n j j) * r (flu A n i j)))
    <= gamma (S j) * (sum j (fun t => Rabs (r (flu A n i t) * r (flu A n t j)))
                      + Rabs (r (flu A n j j) * r (flu A n i j)))
       + (1 + gamma (S j)) * (INR j + Rabs (r (flu A n j j))) * eta.
Proof.
  intros Hok Hji Hi Hk.
  pose proof (finite_result A n Hok i j Hi ltac:(lia)) as Hf.
  pose proof (flu_lower A n i j Hji Hi) as E.
  rewrite E in Hf |- *.
  apply (Diana.Float.Substitution.row_error sub_nan mult_nan div_nan); [exact Hf | | exact Hk].
  apply diag_nonzero; [exact Hok | lia].
Qed.

End Model.
