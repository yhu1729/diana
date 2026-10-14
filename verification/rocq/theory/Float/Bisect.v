From Stdlib Require Import Reals ZArith Lia Lra.
From Flocq Require Import Core IEEE754.BinarySingleNaN IEEE754.Binary.
Open Scope R_scope.

Abbreviation prec := 53%Z.
Abbreviation emax := 1024%Z.
Abbreviation emin := (-1074)%Z.
Abbreviation fexp := (FLT_exp emin prec).
Abbreviation b64 := (binary_float prec emax).

#[local] Instance prec_gt_0_53 : Prec_gt_0 prec := eq_refl.
#[local] Instance prec_lt_emax_53 : Prec_lt_emax prec emax := eq_refl.

Definition dbl_max : R := bpow radix2 1024 - bpow radix2 971.
Definition dbl_max_half : R := bpow radix2 1023 - bpow radix2 970.

Lemma pow_diff_format (e : Z) :
  (emin <= e - 53)%Z ->
  generic_format radix2 fexp (bpow radix2 e - bpow radix2 (e - 53)).
Proof.
  intro He.
  apply generic_format_FLT.
  exists (Float radix2 (2 ^ 53 - 1) (e - 53)); simpl.
  - unfold F2R; simpl.
    replace e with (53 + (e - 53))%Z at 1 by ring.
    rewrite bpow_plus, <- (IZR_Zpower radix2 53) by lia.
    change (Zpower radix2 53) with 9007199254740992%Z. ring.
  - lia.
  - exact He.
Qed.

Lemma dbl_max_format : generic_format radix2 fexp dbl_max.
Proof. apply (pow_diff_format 1024); lia. Qed.

Lemma dbl_max_half_format : generic_format radix2 fexp dbl_max_half.
Proof. apply (pow_diff_format 1023); lia. Qed.

Lemma dbl_max_lt : dbl_max < bpow radix2 1024.
Proof. unfold dbl_max. pose proof (bpow_gt_0 radix2 971). lra. Qed.

Lemma dbl_max_half_lt : dbl_max_half < bpow radix2 1024.
Proof.
  unfold dbl_max_half. pose proof (bpow_gt_0 radix2 970).
  pose proof (bpow_lt radix2 1023 1024 ltac:(lia)). lra.
Qed.

Lemma dbl_max_half_twice : 2 * dbl_max_half = dbl_max.
Proof.
  unfold dbl_max, dbl_max_half.
  replace 1024%Z with (1 + 1023)%Z by ring. replace 971%Z with (1 + 970)%Z by ring.
  rewrite !bpow_plus, bpow_1. simpl. ring.
Qed.

Lemma format_double (x : R) :
  generic_format radix2 fexp x -> generic_format radix2 fexp (2 * x).
Proof.
  intro Hx. destruct (FLT_format_generic radix2 emin prec x Hx) as [f Hf Hm He].
  apply generic_format_FLT.
  exists (Float radix2 (Fnum f) (Fexp f + 1)).
  - rewrite Hf. unfold F2R; simpl. rewrite bpow_plus, bpow_1. simpl. ring.
  - exact Hm.
  - simpl; lia.
Qed.

Lemma round_abs_le (m : R) (x : R) :
  generic_format radix2 fexp m -> Rabs x <= m ->
  Rabs (round radix2 fexp ZnearestE x) <= m.
Proof.
  intros Hm Hx. destruct (Rabs_le_inv _ _ Hx) as [Hx1 Hx2]. apply Rabs_le. split.
  - rewrite <- (round_generic radix2 fexp ZnearestE (- m)); [apply round_le; try typeclasses eauto; lra |].
    apply generic_format_opp; try typeclasses eauto; exact Hm.
  - rewrite <- (round_generic radix2 fexp ZnearestE m); [apply round_le; try typeclasses eauto; lra | exact Hm].
Qed.

Section Model.

Variable plus_nan mult_nan minus_nan : b64 -> b64 -> {x : b64 | is_nan prec emax x = true}.

Definition half : b64 :=
  B754_finite prec emax false 4503599627370496 (-53) ltac:(vm_compute; reflexivity).

Lemma B2R_half : B2R prec emax half = / 2.
Proof.
  unfold half, B2R, F2R; simpl.
  change (Z.pow_pos 2 53) with 9007199254740992%Z. lra.
Qed.

Lemma half_finite : is_finite prec emax half = true.
Proof. reflexivity. Qed.

Definition mid (a b : b64) : b64 :=
  Bmult prec emax _ _ mult_nan mode_NE half (Bplus prec emax _ _ plus_nan mode_NE a b).

Theorem mid_in_bracket (a b : b64) :
  is_finite prec emax a = true -> is_finite prec emax b = true ->
  B2R prec emax a <= B2R prec emax b ->
  Rabs (B2R prec emax a) <= dbl_max_half -> Rabs (B2R prec emax b) <= dbl_max_half ->
  is_finite prec emax (mid a b) = true /\
  B2R prec emax a <= B2R prec emax (mid a b) <= B2R prec emax b.
Proof.
  intros Ha Hb Hab Hba Hbb.
  set (ra := B2R prec emax a) in *. set (rb := B2R prec emax b) in *.
  assert (Hfa : generic_format radix2 fexp ra) by apply generic_format_B2R.
  assert (Hfb : generic_format radix2 fexp rb) by apply generic_format_B2R.
  assert (Hsum_bound : Rabs (ra + rb) <= dbl_max).
  { rewrite <- dbl_max_half_twice. pose proof (Rabs_triang ra rb). lra. }
  pose proof (Bplus_correct prec emax _ _ plus_nan mode_NE a b Ha Hb) as Hplus.
  rewrite Rlt_bool_true in Hplus.
  2:{ eapply Rle_lt_trans; [apply round_abs_le; [exact dbl_max_format | exact Hsum_bound] |].
      exact dbl_max_lt. }
  destruct Hplus as [Hplus_val [Hplus_fin _]].
  change (SpecFloat.fexp 53 1024) with fexp in Hplus_val.
  change (round_mode mode_NE) with ZnearestE in Hplus_val.
  fold ra rb in Hplus_val.
  set (s := Bplus prec emax _ _ plus_nan mode_NE a b) in *.
  set (rs := round radix2 fexp ZnearestE (ra + rb)) in *.
  assert (H2a : 2 * ra <= rs).
  { unfold rs. rewrite <- (round_generic radix2 fexp ZnearestE (2 * ra)) at 1;
      [apply round_le; try typeclasses eauto; lra | apply format_double; exact Hfa]. }
  assert (H2b : rs <= 2 * rb).
  { unfold rs. rewrite <- (round_generic radix2 fexp ZnearestE (2 * rb));
      [apply round_le; try typeclasses eauto; lra | apply format_double; exact Hfb]. }
  pose proof (Bmult_correct prec emax _ _ mult_nan mode_NE half s) as Hmult.
  change (SpecFloat.fexp 53 1024) with fexp in Hmult.
  change (round_mode mode_NE) with ZnearestE in Hmult.
  rewrite B2R_half, Hplus_val in Hmult.
  assert (Hhalf_bound : Rabs (/ 2 * rs) <= dbl_max_half).
  { destruct (Rabs_le_inv _ _ Hba) as [Hba1 Hba2]. destruct (Rabs_le_inv _ _ Hbb) as [Hbb1 Hbb2].
    apply Rabs_le. lra. }
  rewrite Rlt_bool_true in Hmult.
  2:{ eapply Rle_lt_trans; [apply round_abs_le; [exact dbl_max_half_format | exact Hhalf_bound] |].
      exact dbl_max_half_lt. }
  destruct Hmult as [Hmult_val [Hmult_fin _]].
  unfold mid. fold s. rewrite Hmult_val, Hmult_fin, half_finite, Hplus_fin.
  split; [reflexivity |]. split.
  - rewrite <- (round_generic radix2 fexp ZnearestE ra) at 1; [apply round_le; try typeclasses eauto; lra | exact Hfa].
  - rewrite <- (round_generic radix2 fexp ZnearestE rb); [apply round_le; try typeclasses eauto; lra | exact Hfb].
Qed.

Definition fpos (x : b64) : bool := if Rlt_dec 0 (B2R prec emax x) then true else false.

Lemma fpos_true (x : b64) : fpos x = true <-> 0 < B2R prec emax x.
Proof. unfold fpos; destruct (Rlt_dec 0 (B2R prec emax x)); split; auto; discriminate. Qed.

Lemma fpos_false (x : b64) : fpos x = false <-> B2R prec emax x <= 0.
Proof.
  unfold fpos; destruct (Rlt_dec 0 (B2R prec emax x)); split; intro; try discriminate; lra.
Qed.

Record state : Type := mkstate {
  sa : b64; sb : b64; sfa : b64; sfb : b64; sx : b64; stol : b64
}.

Definition Bracket (s : state) : Prop :=
  is_finite prec emax (sa s) = true /\ is_finite prec emax (sb s) = true /\
  is_finite prec emax (sfa s) = true /\ is_finite prec emax (sfb s) = true /\
  is_finite prec emax (stol s) = true /\
  B2R prec emax (sa s) <= B2R prec emax (sb s) /\
  Rabs (B2R prec emax (sa s)) <= dbl_max_half /\
  Rabs (B2R prec emax (sb s)) <= dbl_max_half /\
  ((B2R prec emax (sfa s) < 0 /\ 0 < B2R prec emax (sfb s)) \/
   (0 < B2R prec emax (sfa s) /\ B2R prec emax (sfb s) < 0) \/
   (B2R prec emax (sa s) = B2R prec emax (sb s) /\
    B2R prec emax (sfa s) = 0 /\ B2R prec emax (sfb s) = 0)) /\
  0 <= B2R prec emax (stol s).

Definition Next (s : state) : Prop :=
  is_finite prec emax (sx s) = true /\
  B2R prec emax (sa s) < B2R prec emax (sx s) < B2R prec emax (sb s).

Definition fle (x y : b64) : bool :=
  match Bcompare prec emax x y with
  | Some Lt | Some Eq => true
  | _ => false
  end.

Lemma fle_spec (x y : b64) :
  is_finite prec emax x = true -> is_finite prec emax y = true ->
  (fle x y = true <-> B2R prec emax x <= B2R prec emax y).
Proof.
  intros Hx Hy. unfold fle. rewrite (Bcompare_correct prec emax x y Hx Hy).
  destruct (Rcompare_spec (B2R prec emax x) (B2R prec emax y)); split; intro; try lra;
    try reflexivity; discriminate.
Qed.

Definition fwidth (s : state) : b64 :=
  Bminus prec emax _ _ minus_nan mode_NE (sb s) (sa s).

Definition fkeep (s : state) (fx : b64) : state :=
  if Bool.eqb (fpos fx) (fpos (sfa s)) then
    mkstate (sx s) (sb s) fx (sfb s) (sx s) (stol s)
  else
    mkstate (sa s) (sx s) (sfa s) fx (sx s) (stol s).

Definition fstep (s : state) (fx : b64) : state :=
  if Req_dec_T (B2R prec emax fx) 0 then
    mkstate (sx s) (sx s) fx fx (sx s) (stol s)
  else
    let s1 := fkeep s fx in
    if fle (fwidth s1) (stol s1) then s1
    else mkstate (sa s1) (sb s1) (sfa s1) (sfb s1) (mid (sa s1) (sb s1)) (stol s1).

Lemma fstep_endpoint (s : state) (fx : b64) :
  sa (fstep s fx) = sa (if Req_dec_T (B2R prec emax fx) 0
                        then mkstate (sx s) (sx s) fx fx (sx s) (stol s)
                        else fkeep s fx) /\
  sb (fstep s fx) = sb (if Req_dec_T (B2R prec emax fx) 0
                        then mkstate (sx s) (sx s) fx fx (sx s) (stol s)
                        else fkeep s fx) /\
  sfa (fstep s fx) = sfa (if Req_dec_T (B2R prec emax fx) 0
                          then mkstate (sx s) (sx s) fx fx (sx s) (stol s)
                          else fkeep s fx) /\
  sfb (fstep s fx) = sfb (if Req_dec_T (B2R prec emax fx) 0
                          then mkstate (sx s) (sx s) fx fx (sx s) (stol s)
                          else fkeep s fx) /\
  stol (fstep s fx) = stol s.
Proof.
  unfold fstep. destruct (Req_dec_T (B2R prec emax fx) 0) as [E | E].
  - simpl; repeat split; reflexivity.
  - destruct (fle _ _); unfold fkeep;
      destruct (Bool.eqb (fpos fx) (fpos (sfa s))); simpl; repeat split; reflexivity.
Qed.

Lemma Rabs_le_trans_bound (x y z m : R) :
  x <= y <= z -> Rabs x <= m -> Rabs z <= m -> Rabs y <= m.
Proof.
  intros [H1 H2] Hx Hz.
  destruct (Rabs_le_inv _ _ Hx). destruct (Rabs_le_inv _ _ Hz).
  apply Rabs_le. lra.
Qed.

Theorem step_in_bracket (s : state) (fx : b64) :
  Bracket s -> Next s -> is_finite prec emax fx = true ->
  Bracket (fstep s fx) /\
  B2R prec emax (sa s) <= B2R prec emax (sa (fstep s fx)) /\
  B2R prec emax (sb (fstep s fx)) <= B2R prec emax (sb s).
Proof.
  intros HB HN Hfx.
  destruct HB as [Ha [Hb [Hfa [Hfb [Htol [Hab [Hba [Hbb [Hsign Htol0]]]]]]]]].
  destruct HN as [Hx [Hxa Hxb]].
  assert (Hxabs : Rabs (B2R prec emax (sx s)) <= dbl_max_half)
    by (apply (Rabs_le_trans_bound (B2R prec emax (sa s)) _ (B2R prec emax (sb s)));
        [lra | exact Hba | exact Hbb]).
  assert (Hmid : forall u v : b64,
             is_finite prec emax u = true -> is_finite prec emax v = true ->
             B2R prec emax u <= B2R prec emax v ->
             Rabs (B2R prec emax u) <= dbl_max_half ->
             Rabs (B2R prec emax v) <= dbl_max_half ->
             is_finite prec emax (mid u v) = true /\
             B2R prec emax u <= B2R prec emax (mid u v) <= B2R prec emax v)
    by (intros; apply mid_in_bracket; assumption).
  unfold fstep. destruct (Req_dec_T (B2R prec emax fx) 0) as [E0 | E0].
  { simpl. split; [| lra]. unfold Bracket; simpl.
    split; [exact Hx |]. split; [exact Hx |]. split; [exact Hfx |]. split; [exact Hfx |].
    split; [exact Htol |]. split; [lra |]. split; [exact Hxabs |]. split; [exact Hxabs |].
    split; [| exact Htol0]. right; right. split; [reflexivity | split; exact E0]. }
  unfold fkeep. destruct (Bool.eqb (fpos fx) (fpos (sfa s))) eqn:Esign.
  - apply Bool.eqb_prop in Esign.
    assert (Hfxfb : (B2R prec emax fx < 0 /\ 0 < B2R prec emax (sfb s)) \/
                    (0 < B2R prec emax fx /\ B2R prec emax (sfb s) < 0)).
    { destruct (fpos fx) eqn:Ex; symmetry in Esign.
      + apply fpos_true in Ex. apply fpos_true in Esign.
        destruct Hsign as [[H1 H2] | [[H1 H2] | [H1 [H2 H3]]]];
          [right; split; lra | lra | lra].
      + apply fpos_false in Ex. apply fpos_false in Esign.
        destruct Hsign as [[H1 H2] | [[H1 H2] | [H1 [H2 H3]]]];
          [left; split; lra | lra | lra]. }
    destruct (fle _ _) eqn:Efle; simpl.
    + split; [| lra]. unfold Bracket; simpl.
      split; [exact Hx |]. split; [exact Hb |]. split; [exact Hfx |]. split; [exact Hfb |].
      split; [exact Htol |]. split; [lra |]. split; [exact Hxabs |]. split; [exact Hbb |].
      split; [| exact Htol0].
      destruct Hfxfb as [[H1 H2] | [H1 H2]]; [left; split; lra | right; left; split; lra].
    + destruct (Hmid (sx s) (sb s) Hx Hb ltac:(lra) Hxabs Hbb) as [Hmf [Hm1 Hm2]].
      split; [| simpl; lra]. unfold Bracket; simpl.
      split; [exact Hx |]. split; [exact Hb |]. split; [exact Hfx |]. split; [exact Hfb |].
      split; [exact Htol |]. split; [lra |]. split; [exact Hxabs |]. split; [exact Hbb |].
      split; [| exact Htol0].
      destruct Hfxfb as [[H1 H2] | [H1 H2]]; [left; split; lra | right; left; split; lra].
  - apply Bool.eqb_false_iff in Esign.
    assert (Hfafx : (B2R prec emax (sfa s) < 0 /\ 0 < B2R prec emax fx) \/
                    (0 < B2R prec emax (sfa s) /\ B2R prec emax fx < 0)).
    { destruct (fpos fx) eqn:Ex; destruct (fpos (sfa s)) eqn:Ea; try congruence.
      + apply fpos_true in Ex. apply fpos_false in Ea.
        destruct Hsign as [[H1 H2] | [[H1 H2] | [H1 [H2 H3]]]];
          [left; split; lra | lra | lra].
      + apply fpos_false in Ex. apply fpos_true in Ea. right; split; lra. }
    destruct (fle _ _) eqn:Efle; simpl.
    + split; [| lra]. unfold Bracket; simpl.
      split; [exact Ha |]. split; [exact Hx |]. split; [exact Hfa |]. split; [exact Hfx |].
      split; [exact Htol |]. split; [lra |]. split; [exact Hba |]. split; [exact Hxabs |].
      split; [| exact Htol0].
      destruct Hfafx as [[H1 H2] | [H1 H2]]; [left; split; lra | right; left; split; lra].
    + destruct (Hmid (sa s) (sx s) Ha Hx ltac:(lra) Hba Hxabs) as [Hmf [Hm1 Hm2]].
      split; [| simpl; lra]. unfold Bracket; simpl.
      split; [exact Ha |]. split; [exact Hx |]. split; [exact Hfa |]. split; [exact Hfx |].
      split; [exact Htol |]. split; [lra |]. split; [exact Hba |]. split; [exact Hxabs |].
      split; [| exact Htol0].
      destruct Hfafx as [[H1 H2] | [H1 H2]]; [left; split; lra | right; left; split; lra].
Qed.

Theorem mid_adjacent (a b : b64) :
  is_finite prec emax a = true -> is_finite prec emax b = true ->
  B2R prec emax a < B2R prec emax b ->
  Rabs (B2R prec emax a) <= dbl_max_half -> Rabs (B2R prec emax b) <= dbl_max_half ->
  succ radix2 fexp (B2R prec emax a) = B2R prec emax b ->
  B2R prec emax (mid a b) = B2R prec emax a \/
  B2R prec emax (mid a b) = B2R prec emax b.
Proof.
  intros Ha Hb Hab Hba Hbb Hsucc.
  destruct (mid_in_bracket a b Ha Hb ltac:(lra) Hba Hbb) as [_ [Hm1 Hm2]].
  assert (Hfm : generic_format radix2 fexp (B2R prec emax (mid a b)))
    by apply generic_format_B2R.
  assert (Hfa : generic_format radix2 fexp (B2R prec emax a)) by apply generic_format_B2R.
  destruct (Rle_lt_dec (B2R prec emax (mid a b)) (B2R prec emax a)) as [Hle | Hlt].
  - left; lra.
  - right.
    assert (Hs : succ radix2 fexp (B2R prec emax a) <= B2R prec emax (mid a b))
      by (apply succ_le_lt; try typeclasses eauto; assumption).
    rewrite Hsucc in Hs. lra.
Qed.

Theorem mid_strict_between (a b : b64) :
  is_finite prec emax a = true -> is_finite prec emax b = true ->
  Rabs (B2R prec emax a) <= dbl_max_half -> Rabs (B2R prec emax b) <= dbl_max_half ->
  B2R prec emax a < B2R prec emax (mid a b) < B2R prec emax b ->
  succ radix2 fexp (B2R prec emax a) <= B2R prec emax (mid a b) /\
  B2R prec emax (mid a b) <= pred radix2 fexp (B2R prec emax b).
Proof.
  intros Ha Hb Hba Hbb [H1 H2].
  assert (Hfa : generic_format radix2 fexp (B2R prec emax a)) by apply generic_format_B2R.
  assert (Hfb : generic_format radix2 fexp (B2R prec emax b)) by apply generic_format_B2R.
  assert (Hfm : generic_format radix2 fexp (B2R prec emax (mid a b)))
    by apply generic_format_B2R.
  split.
  - apply succ_le_lt; try typeclasses eauto; assumption.
  - apply pred_ge_gt; try typeclasses eauto; assumption.
Qed.

Definition rwidth (s : state) : R := B2R prec emax (sb s) - B2R prec emax (sa s).

Theorem step_width_le (s : state) (fx : b64) :
  Bracket s -> Next s -> is_finite prec emax fx = true ->
  rwidth (fstep s fx) <= rwidth s.
Proof.
  intros HB HN Hfx.
  destruct (step_in_bracket s fx HB HN Hfx) as [_ [Hla Hub]].
  unfold rwidth. lra.
Qed.

Theorem step_mag_le (s : state) (fx : b64) :
  Bracket s -> Next s -> is_finite prec emax fx = true ->
  rwidth (fstep s fx) <> 0 ->
  (mag radix2 (rwidth (fstep s fx)) <= mag radix2 (rwidth s))%Z.
Proof.
  intros HB HN Hfx Hnz.
  pose proof (step_width_le s fx HB HN Hfx) as Hle.
  destruct (step_in_bracket s fx HB HN Hfx) as [HB' _].
  destruct HB' as [_ [_ [_ [_ [_ [Hab' _]]]]]].
  apply mag_le_abs; [exact Hnz |].
  unfold rwidth in *.
  rewrite !Rabs_pos_eq; [exact Hle | | lra].
  lra.
Qed.

Lemma format_multiple_emin (x : R) :
  generic_format radix2 fexp x -> exists n : Z, x = IZR n * bpow radix2 emin.
Proof.
  intro Hx. destruct (FLT_format_generic radix2 emin prec x Hx) as [f Hf Hm He].
  exists (Fnum f * radix2 ^ (Fexp f - emin))%Z.
  rewrite Hf. unfold F2R.
  replace (Fexp f) with ((Fexp f - emin) + emin)%Z at 1 by ring.
  rewrite bpow_plus, mult_IZR, (IZR_Zpower radix2 (Fexp f - emin)) by lia.
  ring.
Qed.

Definition lattice (s : state) : Z :=
  Ztrunc (rwidth s * bpow radix2 (- emin)).

Lemma lattice_spec (s : state) :
  Bracket s -> rwidth s = IZR (lattice s) * bpow radix2 emin.
Proof.
  intro HB.
  destruct HB as [_ [_ [_ [_ [_ [Hab _]]]]]].
  assert (Hfa : generic_format radix2 fexp (B2R prec emax (sa s)))
    by apply generic_format_B2R.
  assert (Hfb : generic_format radix2 fexp (B2R prec emax (sb s)))
    by apply generic_format_B2R.
  destruct (format_multiple_emin _ Hfa) as [na Hna].
  destruct (format_multiple_emin _ Hfb) as [nb Hnb].
  assert (Hw : rwidth s = IZR (nb - na) * bpow radix2 emin).
  { unfold rwidth. rewrite Hna, Hnb, minus_IZR. ring. }
  unfold lattice.
  replace (rwidth s * bpow radix2 (- emin)) with (IZR (nb - na)) by
    (rewrite Hw, Rmult_assoc, <- bpow_plus;
     replace (emin + - emin)%Z with 0%Z by ring;
     simpl; ring).
  rewrite Ztrunc_IZR. exact Hw.
Qed.

Lemma lattice_nonneg (s : state) : Bracket s -> (0 <= lattice s)%Z.
Proof.
  intro HB. pose proof (lattice_spec s HB) as Hs.
  destruct HB as [_ [_ [_ [_ [_ [Hab _]]]]]].
  assert (Hw : 0 <= rwidth s) by (unfold rwidth; lra).
  apply le_IZR. apply Rmult_le_reg_r with (r := bpow radix2 emin).
  - apply bpow_gt_0.
  - rewrite <- Hs. simpl. lra.
Qed.

Lemma lattice_lt (s t : state) :
  Bracket s -> Bracket t -> rwidth t < rwidth s -> (lattice t < lattice s)%Z.
Proof.
  intros HBs HBt Hlt.
  pose proof (lattice_spec s HBs) as Hs. pose proof (lattice_spec t HBt) as Ht.
  apply lt_IZR. apply Rmult_lt_reg_r with (r := bpow radix2 emin).
  - apply bpow_gt_0.
  - rewrite <- Hs, <- Ht. exact Hlt.
Qed.

Theorem step_lattice_lt (s : state) (fx : b64) :
  Bracket s -> Next s -> is_finite prec emax fx = true ->
  (lattice (fstep s fx) < lattice s)%Z.
Proof.
  intros HB HN Hfx.
  destruct (step_in_bracket s fx HB HN Hfx) as [HB' _].
  apply (lattice_lt s (fstep s fx) HB HB').
  destruct HN as [_ [Hxa Hxb]].
  pose proof (fstep_endpoint s fx) as [Ea [Eb _]].
  unfold rwidth. rewrite Ea, Eb.
  destruct (Req_dec_T (B2R prec emax fx) 0) as [E0 | E0]; simpl; [lra |].
  unfold fkeep. destruct (Bool.eqb (fpos fx) (fpos (sfa s))); simpl; lra.
Qed.

Fixpoint run (f : state -> b64) (s : state) (n : nat) : state :=
  match n with
  | O => s
  | S k => run f (fstep s (f s)) k
  end.

Theorem step_count_bound (f : state -> b64) (s : state) (n : nat) :
  (forall t, is_finite prec emax (f t) = true) ->
  Bracket s ->
  (forall k : nat, (k < n)%nat -> Next (run f s k)) ->
  (Z.of_nat n <= lattice s)%Z.
Proof.
  intros Hf HB Hnext.
  assert (Hmain : forall n s,
             Bracket s ->
             (forall k : nat, (k < n)%nat -> Next (run f s k)) ->
             (Z.of_nat n <= lattice s)%Z).
  { induction n0 as [| m IH]; intros t HBt Hall.
    - simpl. apply lattice_nonneg; exact HBt.
    - assert (HNt : Next (run f t 0)) by (apply Hall; lia).
      simpl in HNt.
      pose proof (step_lattice_lt t (f t) HBt HNt (Hf t)) as Hlt.
      destruct (step_in_bracket t (f t) HBt HNt (Hf t)) as [HBs _].
      assert (Hrest : forall k : nat, (k < m)%nat -> Next (run f (fstep t (f t)) k)).
      { intros k Hk. specialize (Hall (S k) ltac:(lia)). simpl in Hall. exact Hall. }
      specialize (IH (fstep t (f t)) HBs Hrest).
      rewrite Nat2Z.inj_succ. lia. }
  apply Hmain; assumption.
Qed.

End Model.
