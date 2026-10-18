From VST.floyd Require Import proofauto.
From Diana.Clight Require Import newton_result_aarch64_macos.
From Diana.VST Require Import Newton.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition t_state := Tstruct _diana_newton_state noattr.

Definition cstate_repr (c : cstate) (st : int) : reptype t_state :=
  (Vfloat (cx c), (Vfloat (cdx c), (Vfloat (ctol c), (Vint (citer c), (Vint (cmax c), Vint st))))).

Definition result_spec :=
  DECLARE _diana_newton_result
  WITH sh : share, s : val, root : val, dx : val, c : cstate, st : int, shr : share,
       shw : share
  PRE [ tptr t_state, tptr tdouble, tptr tdouble ]
    PROP (readable_share sh; writable_share shr; writable_share shw;
          s <> nullval; root <> nullval; dx <> nullval)
    PARAMS (s; root; dx)
    SEP (data_at sh t_state (cstate_repr c st) s;
         data_at_ shr tdouble root; data_at_ shw tdouble dx)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr 0))
    SEP (data_at sh t_state (cstate_repr c st) s;
         data_at shr tdouble (Vfloat (cx c)) root;
         data_at shw tdouble (Vfloat (cdx c)) dx).

Definition Gprog : funspecs :=
  ltac:(with_library prog [result_spec]).

Lemma body_diana_newton_result :
  semax_body Vprog Gprog f_diana_newton_result result_spec.
Proof.
  start_function.
  forward_if.
  - subst s. contradiction.
  - forward_if (PROP ()
      LOCAL (temp _s s; temp _root root; temp _dx dx)
      SEP (data_at sh t_state (cstate_repr c st) s;
           data_at shr tdouble (Vfloat (cx c)) root;
           data_at_ shw tdouble dx)).
    + forward. forward. entailer!.
    + contradiction.
    + forward_if (PROP ()
        LOCAL (temp _s s; temp _root root; temp _dx dx)
        SEP (data_at sh t_state (cstate_repr c st) s;
             data_at shr tdouble (Vfloat (cx c)) root;
             data_at shw tdouble (Vfloat (cdx c)) dx)).
      * forward. forward. entailer!.
      * contradiction.
      * forward.
Qed.
