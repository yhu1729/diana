From VST.floyd Require Import proofauto.

(* Lemmas the VST proofs of the column-major matrix kernels share; no Clight AST. *)

(* Every entry on or below the diagonal of the n x n matrix al, a[i + j*n], is finite. *)
Definition lower_finite (al : list float) (n : Z) : Prop :=
  forall i j, 0 <= j <= i -> i < n -> Binary.is_finite 53 1024 (Znth (i + j * n) al) = true.

(* The output buffer while the kernel writes it in increasing linear index: the model up to p,
   the caller's contents after it. *)
Definition lpre (L : list float) (ol : list val) (N p : Z) : list val :=
  map Vfloat (sublist 0 p L) ++ sublist p N ol.

Lemma Zlength_lpre (L : list float) (ol : list val) (N p : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= p <= N -> Zlength (lpre L ol N p) = N.
Proof. intros. unfold lpre. list_solve. Qed.

Lemma lpre_step (L : list float) (ol : list val) (N p : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= p < N ->
  upd_Znth p (lpre L ol N p) (Vfloat (Znth p L)) = lpre L ol N (p + 1).
Proof. intros. unfold lpre. list_solve. Qed.

Lemma Znth_inhabitant {A : Type} (d1 d2 : Inhabitant A) (q : Z) (xs : list A) :
  0 <= q < Zlength xs -> @Znth A d1 q xs = @Znth A d2 q xs.
Proof.
  intro H. unfold Znth. destruct (Z_lt_dec q 0); [lia |]. apply nth_indep.
  rewrite <- ZtoNat_Zlength. lia.
Qed.

Lemma lpre_get {d : Inhabitant val} (L : list float) (ol : list val) (N p q : Z) :
  Zlength L = N -> Zlength ol = N -> 0 <= q < p -> p <= N ->
  @Znth val d q (lpre L ol N p) = Vfloat (Znth q L).
Proof.
  intros. rewrite (Znth_inhabitant d Inhabitant_val) by (rewrite Zlength_lpre; lia).
  unfold lpre. list_solve.
Qed.

Lemma lpre_full (L : list float) (ol : list val) (N : Z) :
  Zlength L = N -> Zlength ol = N -> lpre L ol N N = map Vfloat L.
Proof. intros. unfold lpre. list_solve. Qed.

Lemma lpre_zero (L : list float) (ol : list val) (N : Z) :
  Zlength ol = N -> lpre L ol N 0 = ol.
Proof. intros. unfold lpre. list_solve. Qed.

Lemma ltu_lt (x y : Z) :
  0 <= x <= Int64.max_unsigned -> 0 <= y <= Int64.max_unsigned ->
  Int64.ltu (Int64.repr x) (Int64.repr y) = true -> x < y.
Proof.
  intros Hx Hy H. unfold Int64.ltu in H. rewrite !Int64.unsigned_repr in H by lia.
  destruct (zlt x y); [lia | discriminate].
Qed.

Lemma ltu_ge (x y : Z) :
  0 <= x <= Int64.max_unsigned -> 0 <= y <= Int64.max_unsigned ->
  Int64.ltu (Int64.repr x) (Int64.repr y) = false -> y <= x.
Proof.
  intros Hx Hy H. unfold Int64.ltu in H. rewrite !Int64.unsigned_repr in H by lia.
  destruct (zlt x y); [discriminate | lia].
Qed.

Ltac lt_of_ltu :=
  repeat match goal with
  | H : Int64.ltu (Int64.repr _) (Int64.repr _) = true |- _ =>
      apply ltu_lt in H; [| lia | lia]
  | H : Int64.ltu (Int64.repr _) (Int64.repr _) = false |- _ =>
      apply ltu_ge in H; [| lia | lia]
  end.

Lemma no_overflow (n : Z) :
  1 <= n -> n * n <= Int64.max_unsigned ->
  Int64.cmpu Cgt (Int64.repr n)
    (Int64.divu (Int64.repr (Int.signed (Int.neg (Int.repr 1)))) (Int64.repr n)) = false.
Proof.
  intros H1 H2. change (Int.signed (Int.neg (Int.repr 1))) with (-1).
  unfold Int64.cmpu, Int64.ltu, Int64.divu.
  change (Int64.unsigned (Int64.repr (-1))) with Int64.max_unsigned.
  assert (Hn : Int64.unsigned (Int64.repr n) = n) by (apply Int64.unsigned_repr; nia).
  rewrite Hn.
  assert (Hq : n <= Int64.max_unsigned / n) by (apply Z.div_le_lower_bound; lia).
  rewrite Int64.unsigned_repr.
  - destruct (zlt (Int64.max_unsigned / n) n); [lia | reflexivity].
  - split; [apply Z.div_pos; rep_lia |].
    apply Z.div_le_upper_bound; [lia |]. rep_lia.
Qed.
