From Coq Require Import String List ZArith.
From compcert Require Import Coqlib Integers Floats AST Ctypes Cop Clight Clightdefs.
Import Clightdefs.ClightNotations.
Local Open Scope Z_scope.
Local Open Scope string_scope.
Local Open Scope clight_scope.

Module Info.
  Definition version := "3.17".
  Definition build_number := "".
  Definition build_tag := "".
  Definition build_branch := "".
  Definition arch := "aarch64".
  Definition model := "default".
  Definition abi := "apple".
  Definition bitsize := 64.
  Definition big_endian := false.
  Definition source_file := "src/newton.c".
  Definition normalized := true.
End Info.

Definition ___builtin_annot : ident := $"__builtin_annot".
Definition ___builtin_annot_intval : ident := $"__builtin_annot_intval".
Definition ___builtin_bswap : ident := $"__builtin_bswap".
Definition ___builtin_bswap16 : ident := $"__builtin_bswap16".
Definition ___builtin_bswap32 : ident := $"__builtin_bswap32".
Definition ___builtin_bswap64 : ident := $"__builtin_bswap64".
Definition ___builtin_cls : ident := $"__builtin_cls".
Definition ___builtin_clsl : ident := $"__builtin_clsl".
Definition ___builtin_clsll : ident := $"__builtin_clsll".
Definition ___builtin_clz : ident := $"__builtin_clz".
Definition ___builtin_clzl : ident := $"__builtin_clzl".
Definition ___builtin_clzll : ident := $"__builtin_clzll".
Definition ___builtin_ctz : ident := $"__builtin_ctz".
Definition ___builtin_ctzl : ident := $"__builtin_ctzl".
Definition ___builtin_ctzll : ident := $"__builtin_ctzll".
Definition ___builtin_debug : ident := $"__builtin_debug".
Definition ___builtin_expect : ident := $"__builtin_expect".
Definition ___builtin_fabs : ident := $"__builtin_fabs".
Definition ___builtin_fabsf : ident := $"__builtin_fabsf".
Definition ___builtin_fmadd : ident := $"__builtin_fmadd".
Definition ___builtin_fmax : ident := $"__builtin_fmax".
Definition ___builtin_fmin : ident := $"__builtin_fmin".
Definition ___builtin_fmsub : ident := $"__builtin_fmsub".
Definition ___builtin_fnmadd : ident := $"__builtin_fnmadd".
Definition ___builtin_fnmsub : ident := $"__builtin_fnmsub".
Definition ___builtin_fsqrt : ident := $"__builtin_fsqrt".
Definition ___builtin_membar : ident := $"__builtin_membar".
Definition ___builtin_memcpy_aligned : ident := $"__builtin_memcpy_aligned".
Definition ___builtin_sel : ident := $"__builtin_sel".
Definition ___builtin_sqrt : ident := $"__builtin_sqrt".
Definition ___builtin_unreachable : ident := $"__builtin_unreachable".
Definition ___builtin_va_arg : ident := $"__builtin_va_arg".
Definition ___builtin_va_copy : ident := $"__builtin_va_copy".
Definition ___builtin_va_end : ident := $"__builtin_va_end".
Definition ___builtin_va_start : ident := $"__builtin_va_start".
Definition ___compcert_i64_dtos : ident := $"__compcert_i64_dtos".
Definition ___compcert_i64_dtou : ident := $"__compcert_i64_dtou".
Definition ___compcert_i64_sar : ident := $"__compcert_i64_sar".
Definition ___compcert_i64_sdiv : ident := $"__compcert_i64_sdiv".
Definition ___compcert_i64_shl : ident := $"__compcert_i64_shl".
Definition ___compcert_i64_shr : ident := $"__compcert_i64_shr".
Definition ___compcert_i64_smod : ident := $"__compcert_i64_smod".
Definition ___compcert_i64_smulh : ident := $"__compcert_i64_smulh".
Definition ___compcert_i64_stod : ident := $"__compcert_i64_stod".
Definition ___compcert_i64_stof : ident := $"__compcert_i64_stof".
Definition ___compcert_i64_udiv : ident := $"__compcert_i64_udiv".
Definition ___compcert_i64_umod : ident := $"__compcert_i64_umod".
Definition ___compcert_i64_umulh : ident := $"__compcert_i64_umulh".
Definition ___compcert_i64_utod : ident := $"__compcert_i64_utod".
Definition ___compcert_i64_utof : ident := $"__compcert_i64_utof".
Definition ___compcert_va_composite : ident := $"__compcert_va_composite".
Definition ___compcert_va_float64 : ident := $"__compcert_va_float64".
Definition ___compcert_va_int32 : ident := $"__compcert_va_int32".
Definition ___compcert_va_int64 : ident := $"__compcert_va_int64".
Definition _converged : ident := $"converged".
Definition _dfx : ident := $"dfx".
Definition _diana_fp_abs : ident := $"diana_fp_abs".
Definition _diana_fp_finite : ident := $"diana_fp_finite".
Definition _diana_newton_init : ident := $"diana_newton_init".
Definition _diana_newton_result : ident := $"diana_newton_result".
Definition _diana_newton_state : ident := $"diana_newton_state".
Definition _diana_newton_step : ident := $"diana_newton_step".
Definition _dx : ident := $"dx".
Definition _fx : ident := $"fx".
Definition _iter : ident := $"iter".
Definition _main : ident := $"main".
Definition _max_iter : ident := $"max_iter".
Definition _root : ident := $"root".
Definition _s : ident := $"s".
Definition _tol : ident := $"tol".
Definition _x : ident := $"x".
Definition _x0 : ident := $"x0".
Definition _t'1 : ident := 128%positive.
Definition _t'10 : ident := 137%positive.
Definition _t'11 : ident := 138%positive.
Definition _t'12 : ident := 139%positive.
Definition _t'13 : ident := 140%positive.
Definition _t'14 : ident := 141%positive.
Definition _t'15 : ident := 142%positive.
Definition _t'2 : ident := 129%positive.
Definition _t'3 : ident := 130%positive.
Definition _t'4 : ident := 131%positive.
Definition _t'5 : ident := 132%positive.
Definition _t'6 : ident := 133%positive.
Definition _t'7 : ident := 134%positive.
Definition _t'8 : ident := 135%positive.
Definition _t'9 : ident := 136%positive.

Definition f_diana_fp_finite := {|
  fn_return := tint;
  fn_callconv := cc_default;
  fn_params := ((_x, tdouble) :: nil);
  fn_vars := nil;
  fn_temps := ((_t'1, tint) :: nil);
  fn_body :=
(Ssequence
  (Sifthenelse (Ebinop Oeq (Etempvar _x tdouble) (Etempvar _x tdouble) tint)
    (Sset _t'1
      (Ecast
        (Ebinop Oeq
          (Ebinop Osub (Etempvar _x tdouble) (Etempvar _x tdouble) tdouble)
          (Econst_float (Float.of_bits (Int64.repr 0)) tdouble) tint) tbool))
    (Sset _t'1 (Econst_int (Int.repr 0) tint)))
  (Sreturn (Some (Etempvar _t'1 tint))))
|}.

Definition f_diana_fp_abs := {|
  fn_return := tdouble;
  fn_callconv := cc_default;
  fn_params := ((_x, tdouble) :: nil);
  fn_vars := nil;
  fn_temps := ((_t'1, tdouble) :: nil);
  fn_body :=
(Ssequence
  (Sifthenelse (Ebinop Olt (Etempvar _x tdouble)
                 (Econst_float (Float.of_bits (Int64.repr 0)) tdouble) tint)
    (Sset _t'1 (Ecast (Eunop Oneg (Etempvar _x tdouble) tdouble) tdouble))
    (Sset _t'1 (Ecast (Etempvar _x tdouble) tdouble)))
  (Sreturn (Some (Etempvar _t'1 tdouble))))
|}.

Definition f_diana_newton_init := {|
  fn_return := tint;
  fn_callconv := cc_default;
  fn_params := ((_s, (tptr (Tstruct _diana_newton_state noattr))) ::
                (_x0, tdouble) :: (_tol, tdouble) :: (_max_iter, tuint) ::
                nil);
  fn_vars := nil;
  fn_temps := ((_t'4, tint) :: (_t'3, tint) :: (_t'2, tint) ::
               (_t'1, tint) :: nil);
  fn_body :=
(Ssequence
  (Sifthenelse (Ebinop Oeq
                 (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                 (Ecast (Econst_int (Int.repr 0) tint)
                   (tptr (Tstruct _diana_newton_state noattr))) tint)
    (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
    Sskip)
  (Ssequence
    (Ssequence
      (Ssequence
        (Scall (Some _t'1)
          (Evar _diana_fp_finite (Tfunction (tdouble :: nil) tint cc_default))
          ((Etempvar _x0 tdouble) :: nil))
        (Sifthenelse (Eunop Onotbool (Etempvar _t'1 tint) tint)
          (Sset _t'2 (Econst_int (Int.repr 1) tint))
          (Ssequence
            (Scall (Some _t'3)
              (Evar _diana_fp_finite (Tfunction (tdouble :: nil) tint
                                       cc_default))
              ((Etempvar _tol tdouble) :: nil))
            (Sset _t'2
              (Ecast (Eunop Onotbool (Etempvar _t'3 tint) tint) tbool)))))
      (Sifthenelse (Etempvar _t'2 tint)
        (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
        Sskip))
    (Ssequence
      (Ssequence
        (Sifthenelse (Ebinop Olt (Etempvar _tol tdouble)
                       (Econst_float (Float.of_bits (Int64.repr 0)) tdouble)
                       tint)
          (Sset _t'4 (Econst_int (Int.repr 1) tint))
          (Sset _t'4
            (Ecast
              (Ebinop Oeq (Etempvar _max_iter tuint)
                (Econst_int (Int.repr 0) tuint) tint) tbool)))
        (Sifthenelse (Etempvar _t'4 tint)
          (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
          Sskip))
      (Ssequence
        (Sassign
          (Efield
            (Ederef (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
              (Tstruct _diana_newton_state noattr)) _x tdouble)
          (Etempvar _x0 tdouble))
        (Ssequence
          (Sassign
            (Efield
              (Ederef
                (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                (Tstruct _diana_newton_state noattr)) _dx tdouble)
            (Econst_float (Float.of_bits (Int64.repr 0)) tdouble))
          (Ssequence
            (Sassign
              (Efield
                (Ederef
                  (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                  (Tstruct _diana_newton_state noattr)) _tol tdouble)
              (Etempvar _tol tdouble))
            (Ssequence
              (Sassign
                (Efield
                  (Ederef
                    (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                    (Tstruct _diana_newton_state noattr)) _iter tuint)
                (Econst_int (Int.repr 0) tuint))
              (Ssequence
                (Sassign
                  (Efield
                    (Ederef
                      (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                      (Tstruct _diana_newton_state noattr)) _max_iter tuint)
                  (Etempvar _max_iter tuint))
                (Sreturn (Some (Econst_int (Int.repr 1) tint)))))))))))
|}.

Definition f_diana_newton_step := {|
  fn_return := tint;
  fn_callconv := cc_default;
  fn_params := ((_s, (tptr (Tstruct _diana_newton_state noattr))) ::
                (_fx, tdouble) :: (_dfx, tdouble) :: nil);
  fn_vars := nil;
  fn_temps := ((_dx, tdouble) :: (_x, tdouble) :: (_converged, tint) ::
               (_t'8, tdouble) :: (_t'7, tint) :: (_t'6, tint) ::
               (_t'5, tint) :: (_t'4, tint) :: (_t'3, tint) ::
               (_t'2, tint) :: (_t'1, tint) :: (_t'15, tuint) ::
               (_t'14, tdouble) :: (_t'13, tdouble) :: (_t'12, tdouble) ::
               (_t'11, tuint) :: (_t'10, tuint) :: (_t'9, tuint) :: nil);
  fn_body :=
(Ssequence
  (Ssequence
    (Ssequence
      (Sifthenelse (Ebinop Oeq
                     (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                     (Ecast (Econst_int (Int.repr 0) tint)
                       (tptr (Tstruct _diana_newton_state noattr))) tint)
        (Sset _t'1 (Econst_int (Int.repr 1) tint))
        (Ssequence
          (Scall (Some _t'2)
            (Evar _diana_fp_finite (Tfunction (tdouble :: nil) tint
                                     cc_default))
            ((Etempvar _fx tdouble) :: nil))
          (Sset _t'1
            (Ecast (Eunop Onotbool (Etempvar _t'2 tint) tint) tbool))))
      (Sifthenelse (Etempvar _t'1 tint)
        (Sset _t'3 (Econst_int (Int.repr 1) tint))
        (Ssequence
          (Scall (Some _t'4)
            (Evar _diana_fp_finite (Tfunction (tdouble :: nil) tint
                                     cc_default))
            ((Etempvar _dfx tdouble) :: nil))
          (Sset _t'3
            (Ecast (Eunop Onotbool (Etempvar _t'4 tint) tint) tbool)))))
    (Sifthenelse (Etempvar _t'3 tint)
      (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
      Sskip))
  (Ssequence
    (Sifthenelse (Ebinop Oeq (Etempvar _fx tdouble)
                   (Econst_float (Float.of_bits (Int64.repr 0)) tdouble)
                   tint)
      (Ssequence
        (Sassign
          (Efield
            (Ederef (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
              (Tstruct _diana_newton_state noattr)) _dx tdouble)
          (Econst_float (Float.of_bits (Int64.repr 0)) tdouble))
        (Ssequence
          (Ssequence
            (Sset _t'15
              (Efield
                (Ederef
                  (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                  (Tstruct _diana_newton_state noattr)) _iter tuint))
            (Sassign
              (Efield
                (Ederef
                  (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                  (Tstruct _diana_newton_state noattr)) _iter tuint)
              (Ebinop Oadd (Etempvar _t'15 tuint)
                (Econst_int (Int.repr 1) tuint) tuint)))
          (Sreturn (Some (Econst_int (Int.repr 0) tint)))))
      Sskip)
    (Ssequence
      (Sset _dx
        (Ebinop Odiv (Etempvar _fx tdouble) (Etempvar _dfx tdouble) tdouble))
      (Ssequence
        (Ssequence
          (Scall (Some _t'5)
            (Evar _diana_fp_finite (Tfunction (tdouble :: nil) tint
                                     cc_default))
            ((Etempvar _dx tdouble) :: nil))
          (Sifthenelse (Eunop Onotbool (Etempvar _t'5 tint) tint)
            (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
            Sskip))
        (Ssequence
          (Ssequence
            (Sset _t'14
              (Efield
                (Ederef
                  (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                  (Tstruct _diana_newton_state noattr)) _x tdouble))
            (Sset _x
              (Ebinop Osub (Etempvar _t'14 tdouble) (Etempvar _dx tdouble)
                tdouble)))
          (Ssequence
            (Ssequence
              (Scall (Some _t'6)
                (Evar _diana_fp_finite (Tfunction (tdouble :: nil) tint
                                         cc_default))
                ((Etempvar _x tdouble) :: nil))
              (Sifthenelse (Eunop Onotbool (Etempvar _t'6 tint) tint)
                (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
                Sskip))
            (Ssequence
              (Ssequence
                (Ssequence
                  (Sset _t'12
                    (Efield
                      (Ederef
                        (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                        (Tstruct _diana_newton_state noattr)) _x tdouble))
                  (Sifthenelse (Ebinop Oeq (Etempvar _x tdouble)
                                 (Etempvar _t'12 tdouble) tint)
                    (Sset _t'7 (Econst_int (Int.repr 1) tint))
                    (Ssequence
                      (Scall (Some _t'8)
                        (Evar _diana_fp_abs (Tfunction (tdouble :: nil)
                                              tdouble cc_default))
                        ((Etempvar _dx tdouble) :: nil))
                      (Ssequence
                        (Sset _t'13
                          (Efield
                            (Ederef
                              (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                              (Tstruct _diana_newton_state noattr)) _tol
                            tdouble))
                        (Sset _t'7
                          (Ecast
                            (Ebinop Ole (Etempvar _t'8 tdouble)
                              (Etempvar _t'13 tdouble) tint) tbool))))))
                (Sset _converged (Etempvar _t'7 tint)))
              (Ssequence
                (Ssequence
                  (Sset _t'11
                    (Efield
                      (Ederef
                        (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                        (Tstruct _diana_newton_state noattr)) _iter tuint))
                  (Sassign
                    (Efield
                      (Ederef
                        (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                        (Tstruct _diana_newton_state noattr)) _iter tuint)
                    (Ebinop Oadd (Etempvar _t'11 tuint)
                      (Econst_int (Int.repr 1) tuint) tuint)))
                (Ssequence
                  (Sassign
                    (Efield
                      (Ederef
                        (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                        (Tstruct _diana_newton_state noattr)) _dx tdouble)
                    (Etempvar _dx tdouble))
                  (Ssequence
                    (Sassign
                      (Efield
                        (Ederef
                          (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                          (Tstruct _diana_newton_state noattr)) _x tdouble)
                      (Etempvar _x tdouble))
                    (Ssequence
                      (Sifthenelse (Etempvar _converged tint)
                        (Sreturn (Some (Econst_int (Int.repr 0) tint)))
                        Sskip)
                      (Ssequence
                        (Ssequence
                          (Sset _t'9
                            (Efield
                              (Ederef
                                (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                                (Tstruct _diana_newton_state noattr)) _iter
                              tuint))
                          (Ssequence
                            (Sset _t'10
                              (Efield
                                (Ederef
                                  (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                                  (Tstruct _diana_newton_state noattr))
                                _max_iter tuint))
                            (Sifthenelse (Ebinop Oge (Etempvar _t'9 tuint)
                                           (Etempvar _t'10 tuint) tint)
                              (Sreturn (Some (Econst_int (Int.repr (-3)) tint)))
                              Sskip)))
                        (Sreturn (Some (Econst_int (Int.repr 1) tint)))))))))))))))
|}.

Definition f_diana_newton_result := {|
  fn_return := tint;
  fn_callconv := cc_default;
  fn_params := ((_s, (tptr (Tstruct _diana_newton_state noattr))) ::
                (_root, (tptr tdouble)) :: (_dx, (tptr tdouble)) :: nil);
  fn_vars := nil;
  fn_temps := ((_t'2, tdouble) :: (_t'1, tdouble) :: nil);
  fn_body :=
(Ssequence
  (Sifthenelse (Ebinop Oeq
                 (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                 (Ecast (Econst_int (Int.repr 0) tint)
                   (tptr (Tstruct _diana_newton_state noattr))) tint)
    (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
    Sskip)
  (Ssequence
    (Sifthenelse (Ebinop One (Etempvar _root (tptr tdouble))
                   (Ecast (Econst_int (Int.repr 0) tint) (tptr tdouble))
                   tint)
      (Ssequence
        (Sset _t'2
          (Efield
            (Ederef (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
              (Tstruct _diana_newton_state noattr)) _x tdouble))
        (Sassign (Ederef (Etempvar _root (tptr tdouble)) tdouble)
          (Etempvar _t'2 tdouble)))
      Sskip)
    (Ssequence
      (Sifthenelse (Ebinop One (Etempvar _dx (tptr tdouble))
                     (Ecast (Econst_int (Int.repr 0) tint) (tptr tdouble))
                     tint)
        (Ssequence
          (Sset _t'1
            (Efield
              (Ederef
                (Etempvar _s (tptr (Tstruct _diana_newton_state noattr)))
                (Tstruct _diana_newton_state noattr)) _dx tdouble))
          (Sassign (Ederef (Etempvar _dx (tptr tdouble)) tdouble)
            (Etempvar _t'1 tdouble)))
        Sskip)
      (Sreturn (Some (Econst_int (Int.repr 0) tint))))))
|}.

Definition composites : list composite_definition :=
(Composite _diana_newton_state Struct
   (Member_plain _x tdouble :: Member_plain _dx tdouble ::
    Member_plain _tol tdouble :: Member_plain _iter tuint ::
    Member_plain _max_iter tuint :: nil)
   noattr :: nil).

Definition global_definitions : list (ident * globdef fundef type) :=
((___compcert_va_int32,
   Gfun(External (EF_runtime "__compcert_va_int32"
                   (mksignature (AST.Xptr :: nil) AST.Xint cc_default))
     ((tptr tvoid) :: nil) tuint cc_default)) ::
 (___compcert_va_int64,
   Gfun(External (EF_runtime "__compcert_va_int64"
                   (mksignature (AST.Xptr :: nil) AST.Xlong cc_default))
     ((tptr tvoid) :: nil) tulong cc_default)) ::
 (___compcert_va_float64,
   Gfun(External (EF_runtime "__compcert_va_float64"
                   (mksignature (AST.Xptr :: nil) AST.Xfloat cc_default))
     ((tptr tvoid) :: nil) tdouble cc_default)) ::
 (___compcert_va_composite,
   Gfun(External (EF_runtime "__compcert_va_composite"
                   (mksignature (AST.Xptr :: AST.Xlong :: nil) AST.Xptr
                     cc_default)) ((tptr tvoid) :: tulong :: nil)
     (tptr tvoid) cc_default)) ::
 (___compcert_i64_dtos,
   Gfun(External (EF_runtime "__compcert_i64_dtos"
                   (mksignature (AST.Xfloat :: nil) AST.Xlong cc_default))
     (tdouble :: nil) tlong cc_default)) ::
 (___compcert_i64_dtou,
   Gfun(External (EF_runtime "__compcert_i64_dtou"
                   (mksignature (AST.Xfloat :: nil) AST.Xlong cc_default))
     (tdouble :: nil) tulong cc_default)) ::
 (___compcert_i64_stod,
   Gfun(External (EF_runtime "__compcert_i64_stod"
                   (mksignature (AST.Xlong :: nil) AST.Xfloat cc_default))
     (tlong :: nil) tdouble cc_default)) ::
 (___compcert_i64_utod,
   Gfun(External (EF_runtime "__compcert_i64_utod"
                   (mksignature (AST.Xlong :: nil) AST.Xfloat cc_default))
     (tulong :: nil) tdouble cc_default)) ::
 (___compcert_i64_stof,
   Gfun(External (EF_runtime "__compcert_i64_stof"
                   (mksignature (AST.Xlong :: nil) AST.Xsingle cc_default))
     (tlong :: nil) tfloat cc_default)) ::
 (___compcert_i64_utof,
   Gfun(External (EF_runtime "__compcert_i64_utof"
                   (mksignature (AST.Xlong :: nil) AST.Xsingle cc_default))
     (tulong :: nil) tfloat cc_default)) ::
 (___compcert_i64_sdiv,
   Gfun(External (EF_runtime "__compcert_i64_sdiv"
                   (mksignature (AST.Xlong :: AST.Xlong :: nil) AST.Xlong
                     cc_default)) (tlong :: tlong :: nil) tlong cc_default)) ::
 (___compcert_i64_udiv,
   Gfun(External (EF_runtime "__compcert_i64_udiv"
                   (mksignature (AST.Xlong :: AST.Xlong :: nil) AST.Xlong
                     cc_default)) (tulong :: tulong :: nil) tulong
     cc_default)) ::
 (___compcert_i64_smod,
   Gfun(External (EF_runtime "__compcert_i64_smod"
                   (mksignature (AST.Xlong :: AST.Xlong :: nil) AST.Xlong
                     cc_default)) (tlong :: tlong :: nil) tlong cc_default)) ::
 (___compcert_i64_umod,
   Gfun(External (EF_runtime "__compcert_i64_umod"
                   (mksignature (AST.Xlong :: AST.Xlong :: nil) AST.Xlong
                     cc_default)) (tulong :: tulong :: nil) tulong
     cc_default)) ::
 (___compcert_i64_shl,
   Gfun(External (EF_runtime "__compcert_i64_shl"
                   (mksignature (AST.Xlong :: AST.Xint :: nil) AST.Xlong
                     cc_default)) (tlong :: tint :: nil) tlong cc_default)) ::
 (___compcert_i64_shr,
   Gfun(External (EF_runtime "__compcert_i64_shr"
                   (mksignature (AST.Xlong :: AST.Xint :: nil) AST.Xlong
                     cc_default)) (tulong :: tint :: nil) tulong cc_default)) ::
 (___compcert_i64_sar,
   Gfun(External (EF_runtime "__compcert_i64_sar"
                   (mksignature (AST.Xlong :: AST.Xint :: nil) AST.Xlong
                     cc_default)) (tlong :: tint :: nil) tlong cc_default)) ::
 (___compcert_i64_smulh,
   Gfun(External (EF_runtime "__compcert_i64_smulh"
                   (mksignature (AST.Xlong :: AST.Xlong :: nil) AST.Xlong
                     cc_default)) (tlong :: tlong :: nil) tlong cc_default)) ::
 (___compcert_i64_umulh,
   Gfun(External (EF_runtime "__compcert_i64_umulh"
                   (mksignature (AST.Xlong :: AST.Xlong :: nil) AST.Xlong
                     cc_default)) (tulong :: tulong :: nil) tulong
     cc_default)) ::
 (___builtin_bswap64,
   Gfun(External (EF_builtin "__builtin_bswap64"
                   (mksignature (AST.Xlong :: nil) AST.Xlong cc_default))
     (tulong :: nil) tulong cc_default)) ::
 (___builtin_bswap,
   Gfun(External (EF_builtin "__builtin_bswap"
                   (mksignature (AST.Xint :: nil) AST.Xint cc_default))
     (tuint :: nil) tuint cc_default)) ::
 (___builtin_bswap32,
   Gfun(External (EF_builtin "__builtin_bswap32"
                   (mksignature (AST.Xint :: nil) AST.Xint cc_default))
     (tuint :: nil) tuint cc_default)) ::
 (___builtin_bswap16,
   Gfun(External (EF_builtin "__builtin_bswap16"
                   (mksignature (AST.Xint16unsigned :: nil)
                     AST.Xint16unsigned cc_default)) (tushort :: nil) tushort
     cc_default)) ::
 (___builtin_clz,
   Gfun(External (EF_builtin "__builtin_clz"
                   (mksignature (AST.Xint :: nil) AST.Xint cc_default))
     (tuint :: nil) tint cc_default)) ::
 (___builtin_clzl,
   Gfun(External (EF_builtin "__builtin_clzl"
                   (mksignature (AST.Xlong :: nil) AST.Xint cc_default))
     (tulong :: nil) tint cc_default)) ::
 (___builtin_clzll,
   Gfun(External (EF_builtin "__builtin_clzll"
                   (mksignature (AST.Xlong :: nil) AST.Xint cc_default))
     (tulong :: nil) tint cc_default)) ::
 (___builtin_ctz,
   Gfun(External (EF_builtin "__builtin_ctz"
                   (mksignature (AST.Xint :: nil) AST.Xint cc_default))
     (tuint :: nil) tint cc_default)) ::
 (___builtin_ctzl,
   Gfun(External (EF_builtin "__builtin_ctzl"
                   (mksignature (AST.Xlong :: nil) AST.Xint cc_default))
     (tulong :: nil) tint cc_default)) ::
 (___builtin_ctzll,
   Gfun(External (EF_builtin "__builtin_ctzll"
                   (mksignature (AST.Xlong :: nil) AST.Xint cc_default))
     (tulong :: nil) tint cc_default)) ::
 (___builtin_fabs,
   Gfun(External (EF_builtin "__builtin_fabs"
                   (mksignature (AST.Xfloat :: nil) AST.Xfloat cc_default))
     (tdouble :: nil) tdouble cc_default)) ::
 (___builtin_fabsf,
   Gfun(External (EF_builtin "__builtin_fabsf"
                   (mksignature (AST.Xsingle :: nil) AST.Xsingle cc_default))
     (tfloat :: nil) tfloat cc_default)) ::
 (___builtin_fsqrt,
   Gfun(External (EF_builtin "__builtin_fsqrt"
                   (mksignature (AST.Xfloat :: nil) AST.Xfloat cc_default))
     (tdouble :: nil) tdouble cc_default)) ::
 (___builtin_sqrt,
   Gfun(External (EF_builtin "__builtin_sqrt"
                   (mksignature (AST.Xfloat :: nil) AST.Xfloat cc_default))
     (tdouble :: nil) tdouble cc_default)) ::
 (___builtin_memcpy_aligned,
   Gfun(External (EF_builtin "__builtin_memcpy_aligned"
                   (mksignature
                     (AST.Xptr :: AST.Xptr :: AST.Xlong :: AST.Xlong :: nil)
                     AST.Xvoid cc_default))
     ((tptr tvoid) :: (tptr tvoid) :: tulong :: tulong :: nil) tvoid
     cc_default)) ::
 (___builtin_sel,
   Gfun(External (EF_builtin "__builtin_sel"
                   (mksignature (AST.Xbool :: nil) AST.Xvoid
                     {|cc_vararg:=(Some 1); cc_unproto:=false; cc_structret:=false|}))
     (tbool :: nil) tvoid
     {|cc_vararg:=(Some 1); cc_unproto:=false; cc_structret:=false|})) ::
 (___builtin_annot,
   Gfun(External (EF_builtin "__builtin_annot"
                   (mksignature (AST.Xptr :: nil) AST.Xvoid
                     {|cc_vararg:=(Some 1); cc_unproto:=false; cc_structret:=false|}))
     ((tptr tschar) :: nil) tvoid
     {|cc_vararg:=(Some 1); cc_unproto:=false; cc_structret:=false|})) ::
 (___builtin_annot_intval,
   Gfun(External (EF_builtin "__builtin_annot_intval"
                   (mksignature (AST.Xptr :: AST.Xint :: nil) AST.Xint
                     cc_default)) ((tptr tschar) :: tint :: nil) tint
     cc_default)) ::
 (___builtin_membar,
   Gfun(External (EF_builtin "__builtin_membar"
                   (mksignature nil AST.Xvoid cc_default)) nil tvoid
     cc_default)) ::
 (___builtin_va_start,
   Gfun(External (EF_builtin "__builtin_va_start"
                   (mksignature (AST.Xptr :: nil) AST.Xvoid cc_default))
     ((tptr tvoid) :: nil) tvoid cc_default)) ::
 (___builtin_va_arg,
   Gfun(External (EF_builtin "__builtin_va_arg"
                   (mksignature (AST.Xptr :: AST.Xint :: nil) AST.Xvoid
                     cc_default)) ((tptr tvoid) :: tuint :: nil) tvoid
     cc_default)) ::
 (___builtin_va_copy,
   Gfun(External (EF_builtin "__builtin_va_copy"
                   (mksignature (AST.Xptr :: AST.Xptr :: nil) AST.Xvoid
                     cc_default)) ((tptr tvoid) :: (tptr tvoid) :: nil) tvoid
     cc_default)) ::
 (___builtin_va_end,
   Gfun(External (EF_builtin "__builtin_va_end"
                   (mksignature (AST.Xptr :: nil) AST.Xvoid cc_default))
     ((tptr tvoid) :: nil) tvoid cc_default)) ::
 (___builtin_unreachable,
   Gfun(External (EF_builtin "__builtin_unreachable"
                   (mksignature nil AST.Xvoid cc_default)) nil tvoid
     cc_default)) ::
 (___builtin_expect,
   Gfun(External (EF_builtin "__builtin_expect"
                   (mksignature (AST.Xlong :: AST.Xlong :: nil) AST.Xlong
                     cc_default)) (tlong :: tlong :: nil) tlong cc_default)) ::
 (___builtin_cls,
   Gfun(External (EF_builtin "__builtin_cls"
                   (mksignature (AST.Xint :: nil) AST.Xint cc_default))
     (tint :: nil) tint cc_default)) ::
 (___builtin_clsl,
   Gfun(External (EF_builtin "__builtin_clsl"
                   (mksignature (AST.Xlong :: nil) AST.Xint cc_default))
     (tlong :: nil) tint cc_default)) ::
 (___builtin_clsll,
   Gfun(External (EF_builtin "__builtin_clsll"
                   (mksignature (AST.Xlong :: nil) AST.Xint cc_default))
     (tlong :: nil) tint cc_default)) ::
 (___builtin_fmadd,
   Gfun(External (EF_builtin "__builtin_fmadd"
                   (mksignature
                     (AST.Xfloat :: AST.Xfloat :: AST.Xfloat :: nil)
                     AST.Xfloat cc_default))
     (tdouble :: tdouble :: tdouble :: nil) tdouble cc_default)) ::
 (___builtin_fmsub,
   Gfun(External (EF_builtin "__builtin_fmsub"
                   (mksignature
                     (AST.Xfloat :: AST.Xfloat :: AST.Xfloat :: nil)
                     AST.Xfloat cc_default))
     (tdouble :: tdouble :: tdouble :: nil) tdouble cc_default)) ::
 (___builtin_fnmadd,
   Gfun(External (EF_builtin "__builtin_fnmadd"
                   (mksignature
                     (AST.Xfloat :: AST.Xfloat :: AST.Xfloat :: nil)
                     AST.Xfloat cc_default))
     (tdouble :: tdouble :: tdouble :: nil) tdouble cc_default)) ::
 (___builtin_fnmsub,
   Gfun(External (EF_builtin "__builtin_fnmsub"
                   (mksignature
                     (AST.Xfloat :: AST.Xfloat :: AST.Xfloat :: nil)
                     AST.Xfloat cc_default))
     (tdouble :: tdouble :: tdouble :: nil) tdouble cc_default)) ::
 (___builtin_fmax,
   Gfun(External (EF_builtin "__builtin_fmax"
                   (mksignature (AST.Xfloat :: AST.Xfloat :: nil) AST.Xfloat
                     cc_default)) (tdouble :: tdouble :: nil) tdouble
     cc_default)) ::
 (___builtin_fmin,
   Gfun(External (EF_builtin "__builtin_fmin"
                   (mksignature (AST.Xfloat :: AST.Xfloat :: nil) AST.Xfloat
                     cc_default)) (tdouble :: tdouble :: nil) tdouble
     cc_default)) ::
 (___builtin_debug,
   Gfun(External (EF_external "__builtin_debug"
                   (mksignature (AST.Xint :: nil) AST.Xvoid
                     {|cc_vararg:=(Some 1); cc_unproto:=false; cc_structret:=false|}))
     (tint :: nil) tvoid
     {|cc_vararg:=(Some 1); cc_unproto:=false; cc_structret:=false|})) ::
 (_diana_fp_finite, Gfun(Internal f_diana_fp_finite)) ::
 (_diana_fp_abs, Gfun(Internal f_diana_fp_abs)) ::
 (_diana_newton_init, Gfun(Internal f_diana_newton_init)) ::
 (_diana_newton_step, Gfun(Internal f_diana_newton_step)) ::
 (_diana_newton_result, Gfun(Internal f_diana_newton_result)) :: nil).

Definition public_idents : list ident :=
(_diana_newton_result :: _diana_newton_step :: _diana_newton_init ::
 ___builtin_debug :: ___builtin_fmin :: ___builtin_fmax ::
 ___builtin_fnmsub :: ___builtin_fnmadd :: ___builtin_fmsub ::
 ___builtin_fmadd :: ___builtin_clsll :: ___builtin_clsl :: ___builtin_cls ::
 ___builtin_expect :: ___builtin_unreachable :: ___builtin_va_end ::
 ___builtin_va_copy :: ___builtin_va_arg :: ___builtin_va_start ::
 ___builtin_membar :: ___builtin_annot_intval :: ___builtin_annot ::
 ___builtin_sel :: ___builtin_memcpy_aligned :: ___builtin_sqrt ::
 ___builtin_fsqrt :: ___builtin_fabsf :: ___builtin_fabs ::
 ___builtin_ctzll :: ___builtin_ctzl :: ___builtin_ctz :: ___builtin_clzll ::
 ___builtin_clzl :: ___builtin_clz :: ___builtin_bswap16 ::
 ___builtin_bswap32 :: ___builtin_bswap :: ___builtin_bswap64 ::
 ___compcert_i64_umulh :: ___compcert_i64_smulh :: ___compcert_i64_sar ::
 ___compcert_i64_shr :: ___compcert_i64_shl :: ___compcert_i64_umod ::
 ___compcert_i64_smod :: ___compcert_i64_udiv :: ___compcert_i64_sdiv ::
 ___compcert_i64_utof :: ___compcert_i64_stof :: ___compcert_i64_utod ::
 ___compcert_i64_stod :: ___compcert_i64_dtou :: ___compcert_i64_dtos ::
 ___compcert_va_composite :: ___compcert_va_float64 ::
 ___compcert_va_int64 :: ___compcert_va_int32 :: nil).

Definition prog : Clight.program := 
  mkprogram composites global_definitions public_idents _main Logic.I.


