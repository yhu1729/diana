From VST.floyd Require Import proofauto.
From Diana.Clight Require Import bisection_mid_aarch64_macos.
From Diana.VST Require Import Bisection.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition mid_spec :=
  DECLARE _diana_bisection_mid
  WITH a : float, b : float
  PRE [ tdouble, tdouble ]
    PROP () PARAMS (Vfloat a; Vfloat b) SEP ()
  POST [ tdouble ]
    PROP () RETURN (Vfloat (c_mid a b)) SEP ().

Definition Gprog : funspecs := [mid_spec].

Lemma body_diana_bisection_mid : semax_body Vprog Gprog f_diana_bisection_mid mid_spec.
Proof.
  start_function.
  forward.
Qed.
