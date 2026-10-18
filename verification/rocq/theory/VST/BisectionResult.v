From VST.floyd Require Import proofauto.
From Diana.Clight Require Import bisection_result_aarch64_macos.
From Diana.VST Require Import Bisection.
From Diana.VST Require BisectionMid.

#[export] Instance CompSpecs : compspecs. make_compspecs prog. Defined.
Definition Vprog : varspecs. mk_varspecs prog. Defined.

Definition t_state := Tstruct _diana_bisection_state noattr.

Definition state_repr (a b fa fb x tol : float) (iter max_iter status : Z) : reptype t_state :=
  (Vfloat a, (Vfloat b, (Vfloat fa, (Vfloat fb,
   (Vfloat x, (Vfloat tol, (Vint (Int.repr iter), (Vint (Int.repr max_iter),
    Vint (Int.repr status))))))))).

Definition cstate_repr (c : cstate) (st : int) : reptype t_state :=
  (Vfloat (FB.sa (cfl c)), (Vfloat (FB.sb (cfl c)), (Vfloat (FB.sfa (cfl c)),
   (Vfloat (FB.sfb (cfl c)), (Vfloat (FB.sx (cfl c)), (Vfloat (FB.stol (cfl c)),
   (Vint (citer c), (Vint (cmax c), Vint st)))))))).

Lemma cstate_repr_state_repr (c : cstate) (st : int) :
  cstate_repr c st = state_repr (FB.sa (cfl c)) (FB.sb (cfl c)) (FB.sfa (cfl c)) (FB.sfb (cfl c))
                       (FB.sx (cfl c)) (FB.stol (cfl c))
                       (Int.unsigned (citer c)) (Int.unsigned (cmax c)) (Int.unsigned st).
Proof. unfold cstate_repr, state_repr. rewrite !Int.repr_unsigned. reflexivity. Qed.

Definition result_spec :=
  DECLARE _diana_bisection_result
  WITH sh : share, s : val, root : val, width : val,
       a : float, b : float, fa : float, fb : float, x : float, tol : float,
       iter : Z, max_iter : Z, status : Z, shr : share, shw : share
  PRE [ tptr t_state, tptr tdouble, tptr tdouble ]
    PROP (readable_share sh; writable_share shr; writable_share shw;
          s <> nullval; root <> nullval; width <> nullval)
    PARAMS (s; root; width)
    SEP (data_at sh t_state (state_repr a b fa fb x tol iter max_iter status) s;
         data_at_ shr tdouble root; data_at_ shw tdouble width)
  POST [ tint ]
    PROP () RETURN (Vint (Int.repr 0))
    SEP (data_at sh t_state (state_repr a b fa fb x tol iter max_iter status) s;
         data_at shr tdouble (Vfloat (c_mid a b)) root;
         data_at shw tdouble (Vfloat (Float.sub b a)) width).

Definition Gprog : funspecs :=
  ltac:(with_library prog [Diana.VST.BisectionMid.mid_spec; result_spec]).

Lemma body_diana_bisection_result :
  semax_body Vprog Gprog f_diana_bisection_result result_spec.
Proof.
  start_function.
  forward_if.
  - subst s. contradiction.
  - forward_if (PROP ()
      LOCAL (temp _s s; temp _root root; temp _width width)
      SEP (data_at sh t_state (state_repr a b fa fb x tol iter max_iter status) s;
           data_at shr tdouble (Vfloat (c_mid a b)) root;
           data_at_ shw tdouble width)).
    + forward. forward. forward_call (a, b). forward. entailer!.
    + contradiction.
    + forward_if (PROP ()
        LOCAL (temp _s s; temp _root root; temp _width width)
        SEP (data_at sh t_state (state_repr a b fa fb x tol iter max_iter status) s;
             data_at shr tdouble (Vfloat (c_mid a b)) root;
             data_at shw tdouble (Vfloat (Float.sub b a)) width)).
      * forward. forward. forward. entailer!.
      * contradiction.
      * forward.
Qed.
