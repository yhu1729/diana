From VST.floyd Require Import proofauto.
From Diana.Float Require Bisection.
From Stdlib Require Import RIneq Lra.

Definition c_half : float := Float.of_bits (Int64.repr 4602678819172646912).

Lemma c_half_eq : c_half = Diana.Float.Bisection.half.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Definition c_mid (a b : float) : float := Float.mul c_half (Float.add a b).

Lemma c_mid_model (a b : float) :
  c_mid a b = Diana.Float.Bisection.mid Float.binop_nan Float.binop_nan a b.
Proof. unfold c_mid, Diana.Float.Bisection.mid. rewrite c_half_eq. reflexivity. Qed.

Definition c_zero : float := Float.of_bits (Int64.repr 0).

Lemma c_zero_eq : c_zero = Flocq.IEEE754.Binary.B754_zero 53 1024 false.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma cmp_eq_self (x : float) :
  Float.cmp Ceq x x = negb (Binary.is_nan 53 1024 x).
Proof.
  Transparent Float.cmp.
  unfold Float.cmp, Float.compare, cmp_of_comparison.
  Opaque Float.cmp.
  destruct x as [sg | sg | sg pl H | sg m e H]; simpl.
  - reflexivity.
  - destruct sg; reflexivity.
  - reflexivity.
  - unfold Binary.Bcompare; simpl.
    rewrite Z.compare_refl, Pos.compare_cont_refl.
    destruct sg; reflexivity.
Qed.

#[local] Instance prec_gt_0_53' : FLX.Prec_gt_0 53 := eq_refl.
#[local] Instance prec_lt_emax_53' : BinarySingleNaN.Prec_lt_emax 53 1024 := eq_refl.

Lemma sub_self_finite_zero (x : float) :
  Binary.is_finite 53 1024 x = true ->
  Binary.B2R 53 1024 (Float.sub x x) = Rdefinitions.IZR 0 /\
  Binary.is_finite 53 1024 (Float.sub x x) = true.
Proof.
  intro Hf.
  Transparent Float.sub. unfold Float.sub. Opaque Float.sub.
  pose proof (Binary.Bminus_correct 53 1024 _ _ Float.binop_nan
                BinarySingleNaN.mode_NE x x Hf Hf) as H.
  replace (Rdefinitions.Rminus (Binary.B2R 53 1024 x) (Binary.B2R 53 1024 x))
    with (Rdefinitions.IZR 0) in H
    by (unfold Rdefinitions.Rminus; rewrite Raxioms.Rplus_opp_r; reflexivity).
  rewrite Generic_fmt.round_0 in H by typeclasses eauto.
  rewrite Rbasic_fun.Rabs_R0, Raux.Rlt_bool_true in H by apply Raux.bpow_gt_0.
  destruct H as [Hval [Hfin _]].
  split; [exact Hval | exact Hfin].
Qed.

Lemma of_bits_zero : Float.of_bits (Int64.repr 0) = Binary.B754_zero 53 1024 false.
Proof. apply Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma cmp_sub_self_zero (x : float) :
  Binary.is_nan 53 1024 x = false ->
  Float.cmp Ceq (Float.sub x x) (Float.of_bits (Int64.repr 0))
  = Binary.is_finite 53 1024 x.
Proof.
  intro Hnan. rewrite of_bits_zero.
  destruct (Binary.is_finite 53 1024 x) eqn:Hf.
  - destruct (sub_self_finite_zero x Hf) as [Hval Hfin].
    Transparent Float.cmp. unfold Float.cmp, Float.compare, cmp_of_comparison.
    Opaque Float.cmp.
    rewrite (Binary.Bcompare_correct 53 1024 (Float.sub x x)
               (Binary.B754_zero 53 1024 false) Hfin (eq_refl : Binary.is_finite 53 1024 (Binary.B754_zero 53 1024 false) = true)).
    rewrite Hval. simpl.
    rewrite Raux.Rcompare_Eq by reflexivity. reflexivity.
  - destruct x as [sg | sg | sg pl H | sg m e H]; try discriminate.
    Transparent Float.sub Float.cmp.
    unfold Float.sub, Float.cmp, Float.compare, cmp_of_comparison.
    Opaque Float.sub Float.cmp.
    destruct sg; reflexivity.
Qed.

Definition c_abs (x : float) : float :=
  if Float.cmp Clt x (Float.of_bits (Int64.repr 0)) then Float.neg x else x.

Lemma c_abs_B2R (x : float) :
  Binary.is_finite 53 1024 x = true ->
  Binary.B2R 53 1024 (c_abs x) = Rbasic_fun.Rabs (Binary.B2R 53 1024 x).
Proof.
  intro Hf. unfold c_abs.
  rewrite of_bits_zero.
  Transparent Float.cmp. unfold Float.cmp, Float.compare, cmp_of_comparison.
  Opaque Float.cmp.
  rewrite (Binary.Bcompare_correct 53 1024 x (Binary.B754_zero 53 1024 false) Hf
             (eq_refl : Binary.is_finite 53 1024 (Binary.B754_zero 53 1024 false) = true)).
  simpl.
  destruct (Raux.Rcompare_spec (Binary.B2R 53 1024 x) (Rdefinitions.IZR 0)) as [Hlt | Heq | Hgt].
  - simpl. Transparent Float.neg. unfold Float.neg. Opaque Float.neg.
    rewrite Binary.B2R_Bopp.
    rewrite Rbasic_fun.Rabs_left by exact Hlt. reflexivity.
  - simpl. rewrite Heq, Rbasic_fun.Rabs_R0. reflexivity.
  - simpl. rewrite Rbasic_fun.Rabs_right by
      (apply RIneq.Rle_ge, RIneq.Rlt_le; exact Hgt). reflexivity.
Qed.

Lemma c_abs_finite (x : float) :
  Binary.is_finite 53 1024 x = true -> Binary.is_finite 53 1024 (c_abs x) = true.
Proof.
  intro Hf. unfold c_abs. destruct (Float.cmp Clt x (Float.of_bits (Int64.repr 0)));
    [| exact Hf].
  Transparent Float.neg. unfold Float.neg. Opaque Float.neg.
  rewrite Binary.is_finite_Bopp. exact Hf.
Qed.

Module FB := Diana.Float.Bisection.

Definition c_max : float :=
  Float.div (Float.of_bits (Int64.repr 9218868437227405311))
            (Float.of_bits (Int64.repr 4611686018427387904)).

Lemma c_max_B2R :
  Binary.B2R 53 1024 c_max = FB.dbl_max_half /\ Binary.is_finite 53 1024 c_max = true.
Proof.
  assert (H : c_max = Binary.B754_finite 53 1024 false 9007199254740991 970 eq_refl)
    by (apply Binary.B2FF_inj; vm_compute; reflexivity).
  rewrite H. split; [| reflexivity].
  unfold FB.dbl_max_half, Binary.B2R, Defs.F2R; simpl Defs.Fnum; simpl Defs.Fexp.
  change 1023%Z with (53 + 970)%Z. rewrite Raux.bpow_plus.
  change (Raux.bpow Zaux.radix2 53) with (IZR 9007199254740992).
  change 9007199254740991%Z with (9007199254740992 - 1)%Z.
  rewrite minus_IZR. simpl. ring.
Qed.

Record cstate : Type := mkcstate { cfl : FB.state; citer : int; cmax : int }.

Definition c_fin (x : float) : bool := Binary.is_finite 53 1024 x.

Definition c_init (a b fa fb tol : float) (m : int) : Z * option cstate :=
  if (negb (c_fin a) || negb (c_fin b) || negb (c_fin fa) || negb (c_fin fb) ||
      negb (c_fin tol))%bool then (-1, None)
  else if (Float.cmp Cgt a b || Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool
  then (-1, None)
  else if (Float.cmp Cgt (c_abs a) c_max || Float.cmp Cgt (c_abs b) c_max)%bool
  then (-1, None)
  else if (Float.cmp Cgt fa c_zero && Float.cmp Cgt fb c_zero ||
           Float.cmp Clt fa c_zero && Float.cmp Clt fb c_zero)%bool then (-2, None)
  else if Float.cmp Ceq fa c_zero then
    (0, Some (mkcstate (FB.mkstate a a fa fa a tol) Int.zero m))
  else if Float.cmp Ceq fb c_zero then
    (0, Some (mkcstate (FB.mkstate b b fb fb b tol) Int.zero m))
  else
    let c := mkcstate (FB.mkstate a b fa fb (c_mid a b) tol) Int.zero m in
    if (Float.cmp Cle (Float.sub b a) tol || Float.cmp Cle (c_mid a b) a ||
        Float.cmp Cge (c_mid a b) b)%bool then (0, Some c) else (1, Some c).

Definition c_keep (s : FB.state) (fx : float) : FB.state :=
  if Bool.eqb (Float.cmp Cgt fx c_zero) (Float.cmp Cgt (FB.sfa s) c_zero)
  then FB.mkstate (FB.sx s) (FB.sb s) fx (FB.sfb s) (FB.sx s) (FB.stol s)
  else FB.mkstate (FB.sa s) (FB.sx s) (FB.sfa s) fx (FB.sx s) (FB.stol s).

Definition c_step (c : cstate) (fx : float) : Z * cstate :=
  if negb (c_fin fx) then (-1, c) else
  let s := cfl c in
  let it := Int.add (citer c) Int.one in
  if Float.cmp Ceq fx c_zero then
    (0, mkcstate (FB.mkstate (FB.sx s) (FB.sx s) fx fx (FB.sx s) (FB.stol s)) it (cmax c))
  else
    let s1 := c_keep s fx in
    if Float.cmp Cle (Float.sub (FB.sb s1) (FB.sa s1)) (FB.stol s1) then
      (0, mkcstate s1 it (cmax c))
    else
      let x := c_mid (FB.sa s1) (FB.sb s1) in
      let s2 := FB.mkstate (FB.sa s1) (FB.sb s1) (FB.sfa s1) (FB.sfb s1) x (FB.stol s1) in
      if (Float.cmp Cle x (FB.sa s1) || Float.cmp Cge x (FB.sb s1))%bool then
        (0, mkcstate s2 it (cmax c))
      else if negb (Int.ltu it (cmax c)) then (-3, mkcstate s2 it (cmax c))
      else (1, mkcstate s2 it (cmax c)).

Lemma cmp_zero_correct (c : comparison) (x : float) :
  Binary.is_finite 53 1024 x = true ->
  Float.cmp c x c_zero =
  cmp_of_comparison c (Some (Raux.Rcompare (Binary.B2R 53 1024 x) 0%R)).
Proof.
  intro Hf. unfold c_zero. rewrite of_bits_zero.
  Transparent Float.cmp. unfold Float.cmp, Float.compare. Opaque Float.cmp.
  rewrite (Binary.Bcompare_correct 53 1024 x (Binary.B754_zero 53 1024 false) Hf
             (eq_refl : Binary.is_finite 53 1024 (Binary.B754_zero 53 1024 false) = true)).
  reflexivity.
Qed.

Lemma cmp_gt_zero_fpos (x : float) :
  Binary.is_finite 53 1024 x = true -> Float.cmp Cgt x c_zero = FB.fpos x.
Proof.
  intro Hf. rewrite cmp_zero_correct by exact Hf. unfold FB.fpos.
  destruct (Raux.Rcompare_spec (Binary.B2R 53 1024 x) 0%R) as [H | H | H];
    destruct (Rlt_dec 0 (Binary.B2R 53 1024 x)); simpl; try reflexivity; lra.
Qed.

Lemma cmp_eq_zero_true (x : float) :
  Binary.is_finite 53 1024 x = true ->
  (Float.cmp Ceq x c_zero = true <-> Binary.B2R 53 1024 x = 0%R).
Proof.
  intro Hf. rewrite cmp_zero_correct by exact Hf.
  destruct (Raux.Rcompare_spec (Binary.B2R 53 1024 x) 0%R) as [H | H | H]; simpl;
    split; intro; try reflexivity; try discriminate; lra.
Qed.

Lemma cmp_le_fle (x y : float) : Float.cmp Cle x y = FB.fle x y.
Proof.
  Transparent Float.cmp. unfold Float.cmp, Float.compare, FB.fle. Opaque Float.cmp.
  destruct (Binary.Bcompare 53 1024 x y) as [[] |]; reflexivity.
Qed.

Lemma sub_fwidth (s : FB.state) :
  Float.sub (FB.sb s) (FB.sa s) = FB.fwidth Float.binop_nan s.
Proof. reflexivity. Qed.

Theorem c_step_fstep (c : cstate) (fx : float) :
  Binary.is_finite 53 1024 fx = true -> Binary.is_finite 53 1024 (FB.sfa (cfl c)) = true ->
  snd (c_step c fx) =
  mkcstate (FB.fstep Float.binop_nan Float.binop_nan Float.binop_nan (cfl c) fx)
           (Int.add (citer c) Int.one) (cmax c).
Proof.
  intros Hfx Hfa. unfold c_step, c_fin. rewrite Hfx. cbv zeta. simpl negb. cbv iota.
  unfold FB.fstep.
  destruct (Req_dec_T (Binary.B2R 53 1024 fx) 0) as [E | E].
  - apply cmp_eq_zero_true in E; [| exact Hfx]. rewrite E. reflexivity.
  - assert (E' : Float.cmp Ceq fx c_zero = false).
    { destruct (Float.cmp Ceq fx c_zero) eqn:Hc; [| reflexivity].
      apply cmp_eq_zero_true in Hc; [contradiction | exact Hfx]. }
    rewrite E'.
    assert (Hk : c_keep (cfl c) fx = FB.fkeep (cfl c) fx).
    { unfold c_keep, FB.fkeep. rewrite !cmp_gt_zero_fpos by assumption. reflexivity. }
    rewrite Hk, sub_fwidth, cmp_le_fle.
    destruct (FB.fle _ _); [reflexivity |].
    rewrite c_mid_model.
    destruct (Float.cmp Cle _ _ || Float.cmp Cge _ _)%bool; [reflexivity |].
    destruct (negb (Int.ltu _ _)); reflexivity.
Qed.

Section Chain.
Local Open Scope R_scope.

Lemma cmp_correct (c : comparison) (x y : float) :
  Binary.is_finite 53 1024 x = true -> Binary.is_finite 53 1024 y = true ->
  Float.cmp c x y =
  cmp_of_comparison c (Some (Raux.Rcompare (Binary.B2R 53 1024 x) (Binary.B2R 53 1024 y))).
Proof.
  intros Hx Hy.
  Transparent Float.cmp. unfold Float.cmp, Float.compare. Opaque Float.cmp.
  rewrite (Binary.Bcompare_correct 53 1024 x y Hx Hy). reflexivity.
Qed.

Lemma cmp_real (c : comparison) (x y : float) :
  Binary.is_finite 53 1024 x = true -> Binary.is_finite 53 1024 y = true ->
  let u := Binary.B2R 53 1024 x in let v := Binary.B2R 53 1024 y in
  (Float.cmp c x y = true -> match c with
                             | Ceq => u = v | Cne => u <> v | Clt => u < v
                             | Cle => u <= v | Cgt => v < u | Cge => v <= u end) /\
  (Float.cmp c x y = false -> match c with
                              | Ceq => u <> v | Cne => u = v | Clt => v <= u
                              | Cle => v < u | Cgt => u <= v | Cge => u < v end).
Proof.
  intros Hx Hy u v. rewrite cmp_correct by assumption. fold u v.
  destruct (Raux.Rcompare_spec u v); destruct c; simpl;
    split; intro E; try discriminate E; lra.
Qed.

Ltac real_of H :=
  match type of H with
  | Float.cmp ?c ?x ?y = true =>
      apply (proj1 (cmp_real c x y ltac:(assumption) ltac:(assumption))) in H; cbv zeta in H
  | Float.cmp ?c ?x ?y = false =>
      apply (proj2 (cmp_real c x y ltac:(assumption) ltac:(assumption))) in H; cbv zeta in H
  end.

Lemma c_zero_B2R : Binary.B2R 53 1024 c_zero = 0 /\ Binary.is_finite 53 1024 c_zero = true.
Proof. unfold c_zero. rewrite of_bits_zero. split; reflexivity. Qed.

Theorem c_init_bracket (a b fa fb tol : float) (m : int) (r : Z) (c : cstate) :
  c_init a b fa fb tol m = (r, Some c) ->
  FB.Bracket (cfl c) /\ (r = 1%Z -> FB.Next (cfl c)) /\ (r = 0%Z \/ r = 1%Z) /\
  citer c = Int.zero /\ cmax c = m /\ Int.eq m Int.zero = false.
Proof.
  destruct c_zero_B2R as [Hz Hzf].
  destruct c_max_B2R as [Hmx Hmxf].
  unfold c_init.
  destruct (negb (c_fin a) || negb (c_fin b) || negb (c_fin fa) || negb (c_fin fb) ||
            negb (c_fin tol))%bool eqn:Hfin; [discriminate |].
  unfold c_fin in Hfin. rewrite !Bool.orb_false_iff, !Bool.negb_false_iff in Hfin.
  destruct Hfin as [[[[Ha Hb] Hfa] Hfb] Htol].
  destruct (Float.cmp Cgt a b || Float.cmp Clt tol c_zero || Int.eq m Int.zero)%bool
    eqn:Hrange; [discriminate |].
  rewrite !Bool.orb_false_iff in Hrange. destruct Hrange as [[Hab Htol0] Hm].
  real_of Hab. real_of Htol0. rewrite Hz in Htol0.
  destruct (Float.cmp Cgt (c_abs a) c_max || Float.cmp Cgt (c_abs b) c_max)%bool
    eqn:Habs; [discriminate |].
  rewrite !Bool.orb_false_iff in Habs. destruct Habs as [Haa Hbb].
  pose proof (c_abs_finite a Ha). pose proof (c_abs_finite b Hb).
  real_of Haa. real_of Hbb. rewrite c_abs_B2R, Hmx in Haa, Hbb by assumption.
  destruct (Float.cmp Cgt fa c_zero && Float.cmp Cgt fb c_zero ||
            Float.cmp Clt fa c_zero && Float.cmp Clt fb c_zero)%bool
    eqn:Hsign; [discriminate |].
  assert (Hsg : (Binary.B2R 53 1024 fa <= 0 \/ Binary.B2R 53 1024 fb <= 0) /\
                (0 <= Binary.B2R 53 1024 fa \/ 0 <= Binary.B2R 53 1024 fb)).
  { rewrite Bool.orb_false_iff, !Bool.andb_false_iff in Hsign.
    destruct Hsign as [[H1 | H1] [H2 | H2]]; real_of H1; real_of H2; rewrite Hz in *;
      split; (left; lra) || (right; lra). }
  destruct (Float.cmp Ceq fa c_zero) eqn:Hfa0.
  { intro E. injection E as <- <-. real_of Hfa0. rewrite Hz in Hfa0.
    unfold FB.Bracket, FB.Next; cbn [cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
    split; [repeat split; try assumption; try lra; right; right; repeat split; assumption |].
    split; [intro; discriminate |]. repeat split; auto. }
  destruct (Float.cmp Ceq fb c_zero) eqn:Hfb0.
  { intro E. injection E as <- <-. real_of Hfb0. rewrite Hz in Hfb0.
    unfold FB.Bracket, FB.Next; cbn [cfl citer cmax FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
    split; [repeat split; try assumption; try lra; right; right; repeat split; assumption |].
    split; [intro; discriminate |]. repeat split; auto. }
  real_of Hfa0. real_of Hfb0. rewrite Hz in Hfa0, Hfb0.
  assert (Hbr : FB.Bracket (FB.mkstate a b fa fb (c_mid a b) tol)).
  { unfold FB.Bracket; cbn [FB.sa FB.sb FB.sfa FB.sfb FB.sx FB.stol].
    repeat split; try assumption; lra. }
  destruct (Float.cmp Cle (Float.sub b a) tol || Float.cmp Cle (c_mid a b) a ||
            Float.cmp Cge (c_mid a b) b)%bool eqn:Hstop.
  - intro E. injection E as <- <-. cbn [cfl citer cmax].
    split; [exact Hbr |]. split; [intro; discriminate |]. repeat split; auto.
  - intro E. injection E as <- <-. cbn [cfl citer cmax].
    split; [exact Hbr |]. split; [| repeat split; auto].
    intros _. rewrite !Bool.orb_false_iff in Hstop. destruct Hstop as [[_ Hxa] Hxb].
    destruct (FB.mid_in_bracket Float.binop_nan Float.binop_nan a b Ha Hb Hab Haa Hbb)
      as [Hxf _].
    rewrite <- c_mid_model in Hxf.
    real_of Hxa. real_of Hxb.
    unfold FB.Next; cbn [FB.sa FB.sb FB.sx]. split; [exact Hxf | split; assumption].
Qed.

Theorem c_step_next (c c' : cstate) (fx : float) :
  FB.Bracket (cfl c) -> FB.Next (cfl c) -> c_step c fx = (1%Z, c') ->
  FB.Bracket (cfl c') /\ FB.Next (cfl c') /\ Int.ltu (citer c') (cmax c') = true.
Proof.
  intros HB HN Hc.
  destruct (c_fin fx) eqn:Hf.
  2: { unfold c_step in Hc. rewrite Hf in Hc. discriminate. }
  assert (Hfa : Binary.is_finite 53 1024 (FB.sfa (cfl c)) = true)
    by (destruct HB as [_ [_ [Hfa _]]]; exact Hfa).
  pose proof (c_step_fstep c fx Hf Hfa) as E. rewrite Hc in E. cbn [snd] in E.
  assert (HB' : FB.Bracket (cfl c')).
  { rewrite E. cbn [cfl].
    exact (proj1 (FB.step_in_bracket Float.binop_nan Float.binop_nan Float.binop_nan
                    (cfl c) fx HB HN Hf)). }
  split; [exact HB' |].
  unfold c_step in Hc. rewrite Hf in Hc. cbv zeta in Hc. cbn [negb] in Hc.
  destruct (Float.cmp Ceq fx c_zero); [discriminate |].
  destruct (Float.cmp Cle _ _); [discriminate |].
  destruct (Float.cmp Cle _ _ || Float.cmp Cge _ _)%bool eqn:Hst; [discriminate |].
  destruct (negb (Int.ltu _ _)) eqn:Hlt; [discriminate |].
  injection Hc as <-. cbn [cfl citer cmax] in *.
  split; [| rewrite Bool.negb_false_iff in Hlt; exact Hlt].
  destruct HB' as [Ha [Hb [_ [_ [_ [Hab [Hba [Hbb _]]]]]]]].
  cbn [FB.sa FB.sb] in Ha, Hb, Hab, Hba, Hbb.
  destruct (FB.mid_in_bracket Float.binop_nan Float.binop_nan _ _ Ha Hb Hab Hba Hbb)
    as [Hxf _].
  rewrite <- c_mid_model in Hxf.
  rewrite !Bool.orb_false_iff in Hst. destruct Hst as [Hxa Hxb].
  real_of Hxa. real_of Hxb.
  unfold FB.Next; cbn [FB.sa FB.sb FB.sx]. split; [exact Hxf | split; assumption].
Qed.

End Chain.
