From VST.floyd Require Import proofauto.
From Diana.Real Require Norm.
From Diana.Float Require Cholesky LU Norm.
From Diana.VST Require Bisection.

Module VB := Diana.VST.Bisection.

(* The binary64 models of the three kernels with CompCert's operations, the constants as
   clightgen writes them. *)

Definition c_zero : float := Float.of_bits (Int64.repr 0).
Definition c_one : float := Float.of_bits (Int64.repr 4607182418800017408).

Lemma c_zero_eq : c_zero = Diana.Float.Cholesky.fzero.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_one_eq : c_one = Diana.Float.Norm.fone.
Proof. apply Flocq.IEEE754.Binary.B2FF_inj. vm_compute. reflexivity. Qed.

Lemma c_abs_eq (x : float) : VB.c_abs x = Diana.Float.LU.fmag Float.neg_nan x.
Proof.
  unfold VB.c_abs, Diana.Float.LU.fmag, Diana.Float.LU.fltb.
  rewrite VB.of_bits_zero.
  Transparent Float.cmp Float.neg. unfold Float.cmp, Float.compare, Float.neg, cmp_of_comparison.
  Opaque Float.cmp Float.neg.
  destruct (Binary.Bcompare 53 1024 x _) as [[] |]; reflexivity.
Qed.

Lemma cmp_gt_eq (a b : float) : Float.cmp Cgt a b = Diana.Float.LU.fgtb a b.
Proof.
  Transparent Float.cmp. unfold Float.cmp, Float.compare, cmp_of_comparison, Diana.Float.LU.fgtb.
  Opaque Float.cmp.
  destruct (Binary.Bcompare 53 1024 a b) as [[] |]; reflexivity.
Qed.

Lemma cmp_eq_eq (a b : float) : Float.cmp Ceq a b = Diana.Float.LU.feqb a b.
Proof.
  Transparent Float.cmp. unfold Float.cmp, Float.compare, cmp_of_comparison, Diana.Float.LU.feqb.
  Opaque Float.cmp.
  destruct (Binary.Bcompare 53 1024 a b) as [[] |]; reflexivity.
Qed.

Lemma fold_left_ext {A B : Type} (f g : A -> B -> A) (l : list B) (a : A) :
  (forall x y, f x y = g x y) -> fold_left f l a = fold_left g l a.
Proof.
  intro H. revert a. induction l as [| y l IH]; intro a; [reflexivity |].
  simpl. rewrite H. apply IH.
Qed.

Definition c_max (m x : float) : float :=
  if Float.cmp Cgt (VB.c_abs x) m then VB.c_abs x else m.

Definition c_norm_inf (xs : list float) : float := fold_left c_max xs c_zero.

Lemma c_norm_inf_model (xs : list float) :
  c_norm_inf xs = Diana.Float.Norm.fnorm_inf Float.neg_nan xs.
Proof.
  unfold c_norm_inf, Diana.Float.Norm.fnorm_inf. rewrite c_zero_eq. apply fold_left_ext.
  intros m x. unfold c_max, Diana.Float.Norm.fmax. rewrite cmp_gt_eq, c_abs_eq. reflexivity.
Qed.

Definition c_norm1 (xs : list float) : float := fold_left Float.add (map VB.c_abs xs) c_zero.

Lemma c_norm1_model (xs : list float) :
  c_norm1 xs = Diana.Float.Norm.fnorm1 Float.binop_nan Float.neg_nan xs.
Proof.
  unfold c_norm1, Diana.Float.Norm.fnorm1. rewrite c_zero_eq.
  rewrite (map_ext _ _ c_abs_eq). reflexivity.
Qed.

Definition c_pick (a : nat * nat * float) (x : float) : nat * nat * float :=
  match a with
  | (i, k, m) => if Float.cmp Cgt (VB.c_abs x) m then (S i, i, VB.c_abs x) else (S i, k, m)
  end.

Definition c_scale (xs : list float) : nat * nat * float := fold_left c_pick xs (O, O, c_zero).

Definition c_sq (m x : float) : float := Float.mul (Float.div x m) (Float.div x m).

Definition c_sumsq (m : float) (ys : list float) : float :=
  fold_left Float.add (map (c_sq m) ys) c_one.

Definition c_norm2 (xs : list float) : float :=
  match c_scale xs with
  | (_, k, m) =>
      if Float.cmp Ceq m c_zero then c_zero
      else Float.mul m (Float.sqrt (c_sumsq m (Diana.Real.Norm.remove k xs)))
  end.

Lemma c_scale_model (xs : list float) : c_scale xs = Diana.Float.Norm.fscale Float.neg_nan xs.
Proof.
  unfold c_scale, Diana.Float.Norm.fscale. rewrite c_zero_eq. apply fold_left_ext.
  intros [[i k] m] x. unfold c_pick, Diana.Float.Norm.fpick. rewrite cmp_gt_eq, c_abs_eq.
  reflexivity.
Qed.

Lemma c_norm2_model (xs : list float) :
  c_norm2 xs =
  Diana.Float.Norm.fnorm2 Float.binop_nan Float.binop_nan Float.binop_nan Float.unop_nan
    Float.neg_nan xs.
Proof.
  unfold c_norm2, Diana.Float.Norm.fnorm2. rewrite c_scale_model.
  destruct (Diana.Float.Norm.fscale Float.neg_nan xs) as [[i k] m].
  rewrite cmp_eq_eq, c_zero_eq. destruct (Diana.Float.LU.feqb m _); [reflexivity |].
  unfold c_sumsq, Diana.Float.Norm.fsumsq. rewrite c_one_eq. reflexivity.
Qed.

(* The status each kernel returns: -1 for a non-finite entry, else 0 or, for the 1- and
   2-norms, -5 when the result is not finite. *)
Definition inf_status (xs : list float) : Z :=
  if forallb (Binary.is_finite 53 1024) xs then 0 else -1.

Definition norm1_status (xs : list float) : Z :=
  if forallb (Binary.is_finite 53 1024) xs then
    if Binary.is_finite 53 1024 (c_norm1 xs) then 0 else -5
  else -1.

Definition norm2_status (xs : list float) : Z :=
  if forallb (Binary.is_finite 53 1024) xs then
    if Binary.is_finite 53 1024 (c_norm2 xs) then 0 else -5
  else -1.

(* Prefix lemmas for the loops. *)

Lemma sublist_succ (xs : list float) (i : Z) :
  0 <= i < Zlength xs -> sublist 0 (i + 1) xs = sublist 0 i xs ++ [Znth i xs].
Proof. intro H. rewrite (sublist_split 0 i (i + 1)) by lia. rewrite sublist_len_1 by lia. reflexivity. Qed.

Lemma c_norm_inf_succ (xs : list float) (i : Z) :
  0 <= i < Zlength xs ->
  c_norm_inf (sublist 0 (i + 1) xs) = c_max (c_norm_inf (sublist 0 i xs)) (Znth i xs).
Proof. intro H. unfold c_norm_inf. rewrite sublist_succ, fold_left_app by exact H. reflexivity. Qed.

Lemma c_norm1_succ (xs : list float) (i : Z) :
  0 <= i < Zlength xs ->
  c_norm1 (sublist 0 (i + 1) xs) = Float.add (c_norm1 (sublist 0 i xs)) (VB.c_abs (Znth i xs)).
Proof.
  intro H. unfold c_norm1. rewrite sublist_succ, map_app, fold_left_app by exact H. reflexivity.
Qed.

Lemma c_scale_succ (xs : list float) (i : Z) :
  0 <= i < Zlength xs -> c_scale (sublist 0 (i + 1) xs) = c_pick (c_scale (sublist 0 i xs)) (Znth i xs).
Proof. intro H. unfold c_scale. rewrite sublist_succ, fold_left_app by exact H. reflexivity. Qed.

Lemma c_pick_fold (l : list float) (i k : nat) (m : float) :
  fst (fst (fold_left c_pick l (i, k, m))) = (i + length l)%nat /\
  (snd (fst (fold_left c_pick l (i, k, m))) <= Nat.max k (i + length l - 1))%nat.
Proof.
  revert i k m. induction l as [| x l IH]; intros i k m; simpl; [lia |].
  destruct (Float.cmp Cgt (VB.c_abs x) m);
    match goal with |- context [fold_left c_pick l (?a, ?b, ?c)] =>
      destruct (IH a b c) as [H1 H2] end; split; lia.
Qed.

Lemma c_scale_count (l : list float) : fst (fst (c_scale l)) = length l.
Proof. exact (proj1 (c_pick_fold l 0 0 c_zero)). Qed.

Lemma c_scale_index (l : list float) : (snd (fst (c_scale l)) <= length l)%nat.
Proof. unfold c_scale. pose proof (proj2 (c_pick_fold l 0 0 c_zero)) as H. lia. Qed.

Lemma remove_snoc {A : Type} (k : nat) (l : list A) (a : A) :
  Diana.Real.Norm.remove k (l ++ [a]) =
  if Nat.eqb k (length l) then Diana.Real.Norm.remove k l
  else Diana.Real.Norm.remove k l ++ [a].
Proof.
  unfold Diana.Real.Norm.remove. rewrite List.firstn_app, List.skipn_app.
  destruct (Nat.eqb_spec k (length l)) as [-> | Hne].
  - rewrite Nat.sub_diag, List.firstn_all, (List.skipn_all2 l) by lia.
    replace (S (length l) - length l)%nat with 1%nat by lia. simpl.
    rewrite !app_nil_r. reflexivity.
  - destruct (Nat.lt_ge_cases k (length l)) as [Hlt | Hge].
    + replace (k - length l)%nat with 0%nat by lia.
      replace (S k - length l)%nat with 0%nat by lia. simpl.
      rewrite app_nil_r, app_assoc. reflexivity.
    + rewrite (List.firstn_all2 l) by lia. rewrite (List.skipn_all2 l) by lia.
      replace (k - length l)%nat with (S (k - length l - 1))%nat by lia.
      replace (S k - length l)%nat with (S (S (k - length l - 1)))%nat by lia. simpl.
      rewrite List.firstn_nil, ?List.skipn_nil, !app_nil_r. reflexivity.
Qed.

Lemma c_sumsq_succ (m : float) (kk : nat) (xs : list float) (i : Z) :
  0 <= i < Zlength xs ->
  c_sumsq m (Diana.Real.Norm.remove kk (sublist 0 (i + 1) xs)) =
  if Nat.eqb kk (Z.to_nat i) then c_sumsq m (Diana.Real.Norm.remove kk (sublist 0 i xs))
  else Float.add (c_sumsq m (Diana.Real.Norm.remove kk (sublist 0 i xs))) (c_sq m (Znth i xs)).
Proof.
  intro H. rewrite sublist_succ by exact H. rewrite remove_snoc.
  replace (length (sublist 0 i xs)) with (Z.to_nat i)
    by (rewrite <- ZtoNat_Zlength, Zlength_sublist by lia; f_equal; lia).
  destruct (Nat.eqb kk (Z.to_nat i)); [reflexivity |].
  unfold c_sumsq. rewrite map_app, fold_left_app. reflexivity.
Qed.

Lemma c_scale_take (xs : list float) (i : Z) :
  0 <= i < Zlength xs ->
  Float.cmp Cgt (VB.c_abs (Znth i xs)) (snd (c_scale (sublist 0 i xs))) = true ->
  snd (c_scale (sublist 0 (i + 1) xs)) = VB.c_abs (Znth i xs) /\
  snd (fst (c_scale (sublist 0 (i + 1) xs))) = Z.to_nat i.
Proof.
  intros H Hc. rewrite c_scale_succ by exact H.
  pose proof (c_scale_count (sublist 0 i xs)) as Hn.
  destruct (c_scale (sublist 0 i xs)) as [[cnt k] m]. simpl in Hc, Hn |- *. rewrite Hc.
  split; [reflexivity |]. rewrite Hn, <- ZtoNat_Zlength, Zlength_sublist by lia.
  simpl. f_equal. lia.
Qed.

Lemma c_scale_keep (xs : list float) (i : Z) :
  0 <= i < Zlength xs ->
  Float.cmp Cgt (VB.c_abs (Znth i xs)) (snd (c_scale (sublist 0 i xs))) = false ->
  snd (c_scale (sublist 0 (i + 1) xs)) = snd (c_scale (sublist 0 i xs)) /\
  snd (fst (c_scale (sublist 0 (i + 1) xs))) = snd (fst (c_scale (sublist 0 i xs))).
Proof.
  intros H Hc. rewrite c_scale_succ by exact H.
  destruct (c_scale (sublist 0 i xs)) as [[cnt k] m]. simpl in Hc |- *. rewrite Hc.
  split; reflexivity.
Qed.

Lemma c_scale_index_lt (xs : list float) :
  Z.of_nat (snd (fst (c_scale xs))) <= Zlength xs.
Proof. rewrite Zlength_correct. apply Nat2Z.inj_le, c_scale_index. Qed.
