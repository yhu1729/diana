From VST.floyd Require Import proofauto.
From Diana.Clight Require Import fp_sqrt_aarch64_macos.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

(* The semantics CompCert gives the builtin (Builtins0: __builtin_sqrt is BI_fsqrt, that is
   Float.sqrt). VST has no rule for a builtin call, so this funspec is assumed; it is the one
   VST funspec in Diana that no semax_body discharges (doc/verification/trust.md). *)
Definition builtin_sqrt_spec :=
  DECLARE ___builtin_sqrt
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tdouble ]
    PROP () RETURN (Vfloat (Float.sqrt x)) SEP ().

Definition sqrt_spec :=
  DECLARE _diana_fp_sqrt
  WITH x : float
  PRE [ tdouble ]
    PROP () PARAMS (Vfloat x) SEP ()
  POST [ tdouble ]
    PROP () RETURN (Vfloat (Float.sqrt x)) SEP ().

Definition Gprog : funspecs := [builtin_sqrt_spec; sqrt_spec].

Lemma body_diana_fp_sqrt : semax_body Vprog Gprog f_diana_fp_sqrt sqrt_spec.
Proof.
  start_function.
  forward_call x.
  forward.
Qed.
