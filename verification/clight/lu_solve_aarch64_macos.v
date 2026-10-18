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
  Definition source_file := "src/lu_solve.c".
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
Definition _b : ident := $"b".
Definition _diana_fp_finite : ident := $"diana_fp_finite".
Definition _diana_lu_solve : ident := $"diana_lu_solve".
Definition _i : ident := $"i".
Definition _k : ident := $"k".
Definition _lu : ident := $"lu".
Definition _main : ident := $"main".
Definition _n : ident := $"n".
Definition _p : ident := $"p".
Definition _piv : ident := $"piv".
Definition _q : ident := $"q".
Definition _r : ident := $"r".
Definition _s : ident := $"s".
Definition _t : ident := $"t".
Definition _x : ident := $"x".
Definition _t'1 : ident := 128%positive.
Definition _t'10 : ident := 137%positive.
Definition _t'11 : ident := 138%positive.
Definition _t'12 : ident := 139%positive.
Definition _t'13 : ident := 140%positive.
Definition _t'14 : ident := 141%positive.
Definition _t'15 : ident := 142%positive.
Definition _t'16 : ident := 143%positive.
Definition _t'17 : ident := 144%positive.
Definition _t'18 : ident := 145%positive.
Definition _t'19 : ident := 146%positive.
Definition _t'2 : ident := 129%positive.
Definition _t'20 : ident := 147%positive.
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

Definition f_diana_lu_solve := {|
  fn_return := tint;
  fn_callconv := cc_default;
  fn_params := ((_lu, (tptr tdouble)) :: (_piv, (tptr tulong)) ::
                (_n, tulong) :: (_b, (tptr tdouble)) ::
                (_x, (tptr tdouble)) :: nil);
  fn_vars := nil;
  fn_temps := ((_s, tdouble) :: (_r, tdouble) :: (_t, tdouble) ::
               (_q, tulong) :: (_p, tulong) :: (_i, tulong) ::
               (_k, tulong) :: (_t'9, tint) :: (_t'8, tint) ::
               (_t'7, tint) :: (_t'6, tint) :: (_t'5, tint) ::
               (_t'4, tint) :: (_t'3, tint) :: (_t'2, tint) ::
               (_t'1, tint) :: (_t'20, tdouble) :: (_t'19, tulong) ::
               (_t'18, tdouble) :: (_t'17, tdouble) :: (_t'16, tdouble) ::
               (_t'15, tdouble) :: (_t'14, tdouble) :: (_t'13, tdouble) ::
               (_t'12, tdouble) :: (_t'11, tdouble) :: (_t'10, tdouble) ::
               nil);
  fn_body :=
(Ssequence
  (Ssequence
    (Ssequence
      (Ssequence
        (Ssequence
          (Ssequence
            (Sifthenelse (Ebinop Oeq (Etempvar _lu (tptr tdouble))
                           (Ecast (Econst_int (Int.repr 0) tint)
                             (tptr tdouble)) tint)
              (Sset _t'1 (Econst_int (Int.repr 1) tint))
              (Sset _t'1
                (Ecast
                  (Ebinop Oeq (Etempvar _piv (tptr tulong))
                    (Ecast (Econst_int (Int.repr 0) tint) (tptr tulong))
                    tint) tbool)))
            (Sifthenelse (Etempvar _t'1 tint)
              (Sset _t'2 (Econst_int (Int.repr 1) tint))
              (Sset _t'2
                (Ecast
                  (Ebinop Oeq (Etempvar _b (tptr tdouble))
                    (Ecast (Econst_int (Int.repr 0) tint) (tptr tdouble))
                    tint) tbool))))
          (Sifthenelse (Etempvar _t'2 tint)
            (Sset _t'3 (Econst_int (Int.repr 1) tint))
            (Sset _t'3
              (Ecast
                (Ebinop Oeq (Etempvar _x (tptr tdouble))
                  (Ecast (Econst_int (Int.repr 0) tint) (tptr tdouble)) tint)
                tbool))))
        (Sifthenelse (Etempvar _t'3 tint)
          (Sset _t'4 (Econst_int (Int.repr 1) tint))
          (Sset _t'4
            (Ecast
              (Ebinop Oeq (Etempvar _n tulong)
                (Econst_int (Int.repr 0) tuint) tint) tbool))))
      (Sifthenelse (Etempvar _t'4 tint)
        (Sset _t'5 (Econst_int (Int.repr 1) tint))
        (Sset _t'5
          (Ecast
            (Ebinop Ogt (Etempvar _n tulong)
              (Ebinop Odiv
                (Ecast (Eunop Oneg (Econst_int (Int.repr 1) tint) tint)
                  tulong) (Etempvar _n tulong) tulong) tint) tbool))))
    (Sifthenelse (Etempvar _t'5 tint)
      (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
      Sskip))
  (Ssequence
    (Ssequence
      (Sset _q (Ecast (Econst_int (Int.repr 0) tuint) tulong))
      (Sloop
        (Ssequence
          (Sifthenelse (Ebinop Olt (Etempvar _q tulong)
                         (Ebinop Omul (Etempvar _n tulong)
                           (Etempvar _n tulong) tulong) tint)
            Sskip
            Sbreak)
          (Ssequence
            (Ssequence
              (Sset _t'20
                (Ederef
                  (Ebinop Oadd (Etempvar _lu (tptr tdouble))
                    (Etempvar _q tulong) (tptr tdouble)) tdouble))
              (Scall (Some _t'6)
                (Evar _diana_fp_finite (Tfunction (tdouble :: nil) tint
                                         cc_default))
                ((Etempvar _t'20 tdouble) :: nil)))
            (Sifthenelse (Eunop Onotbool (Etempvar _t'6 tint) tint)
              (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
              Sskip)))
        (Sset _q
          (Ebinop Oadd (Etempvar _q tulong) (Econst_int (Int.repr 1) tint)
            tulong))))
    (Ssequence
      (Ssequence
        (Sset _k (Ecast (Econst_int (Int.repr 0) tuint) tulong))
        (Sloop
          (Ssequence
            (Sifthenelse (Ebinop Olt (Etempvar _k tulong)
                           (Etempvar _n tulong) tint)
              Sskip
              Sbreak)
            (Ssequence
              (Sset _t'19
                (Ederef
                  (Ebinop Oadd (Etempvar _piv (tptr tulong))
                    (Etempvar _k tulong) (tptr tulong)) tulong))
              (Sifthenelse (Ebinop Oge (Etempvar _t'19 tulong)
                             (Etempvar _n tulong) tint)
                (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
                Sskip)))
          (Sset _k
            (Ebinop Oadd (Etempvar _k tulong) (Econst_int (Int.repr 1) tint)
              tulong))))
      (Ssequence
        (Ssequence
          (Sset _i (Ecast (Econst_int (Int.repr 0) tuint) tulong))
          (Sloop
            (Ssequence
              (Sifthenelse (Ebinop Olt (Etempvar _i tulong)
                             (Etempvar _n tulong) tint)
                Sskip
                Sbreak)
              (Ssequence
                (Ssequence
                  (Sset _t'18
                    (Ederef
                      (Ebinop Oadd (Etempvar _b (tptr tdouble))
                        (Etempvar _i tulong) (tptr tdouble)) tdouble))
                  (Scall (Some _t'7)
                    (Evar _diana_fp_finite (Tfunction (tdouble :: nil) tint
                                             cc_default))
                    ((Etempvar _t'18 tdouble) :: nil)))
                (Sifthenelse (Eunop Onotbool (Etempvar _t'7 tint) tint)
                  (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
                  Sskip)))
            (Sset _i
              (Ebinop Oadd (Etempvar _i tulong)
                (Econst_int (Int.repr 1) tint) tulong))))
        (Ssequence
          (Ssequence
            (Sset _i (Ecast (Econst_int (Int.repr 0) tuint) tulong))
            (Sloop
              (Ssequence
                (Sifthenelse (Ebinop Olt (Etempvar _i tulong)
                               (Etempvar _n tulong) tint)
                  Sskip
                  Sbreak)
                (Ssequence
                  (Sset _t'17
                    (Ederef
                      (Ebinop Oadd (Etempvar _lu (tptr tdouble))
                        (Ebinop Oadd (Etempvar _i tulong)
                          (Ebinop Omul (Etempvar _i tulong)
                            (Etempvar _n tulong) tulong) tulong)
                        (tptr tdouble)) tdouble))
                  (Sifthenelse (Ebinop Oeq (Etempvar _t'17 tdouble)
                                 (Econst_float (Float.of_bits (Int64.repr 0)) tdouble)
                                 tint)
                    (Sreturn (Some (Econst_int (Int.repr (-4)) tint)))
                    Sskip)))
              (Sset _i
                (Ebinop Oadd (Etempvar _i tulong)
                  (Econst_int (Int.repr 1) tint) tulong))))
          (Ssequence
            (Ssequence
              (Sset _i (Ecast (Econst_int (Int.repr 0) tuint) tulong))
              (Sloop
                (Ssequence
                  (Sifthenelse (Ebinop Olt (Etempvar _i tulong)
                                 (Etempvar _n tulong) tint)
                    Sskip
                    Sbreak)
                  (Ssequence
                    (Sset _t'16
                      (Ederef
                        (Ebinop Oadd (Etempvar _b (tptr tdouble))
                          (Etempvar _i tulong) (tptr tdouble)) tdouble))
                    (Sassign
                      (Ederef
                        (Ebinop Oadd (Etempvar _x (tptr tdouble))
                          (Etempvar _i tulong) (tptr tdouble)) tdouble)
                      (Etempvar _t'16 tdouble))))
                (Sset _i
                  (Ebinop Oadd (Etempvar _i tulong)
                    (Econst_int (Int.repr 1) tint) tulong))))
            (Ssequence
              (Ssequence
                (Sset _k (Ecast (Econst_int (Int.repr 0) tuint) tulong))
                (Sloop
                  (Ssequence
                    (Sifthenelse (Ebinop Olt (Etempvar _k tulong)
                                   (Etempvar _n tulong) tint)
                      Sskip
                      Sbreak)
                    (Ssequence
                      (Sset _p
                        (Ederef
                          (Ebinop Oadd (Etempvar _piv (tptr tulong))
                            (Etempvar _k tulong) (tptr tulong)) tulong))
                      (Ssequence
                        (Sset _t
                          (Ederef
                            (Ebinop Oadd (Etempvar _x (tptr tdouble))
                              (Etempvar _k tulong) (tptr tdouble)) tdouble))
                        (Ssequence
                          (Ssequence
                            (Sset _t'15
                              (Ederef
                                (Ebinop Oadd (Etempvar _x (tptr tdouble))
                                  (Etempvar _p tulong) (tptr tdouble))
                                tdouble))
                            (Sassign
                              (Ederef
                                (Ebinop Oadd (Etempvar _x (tptr tdouble))
                                  (Etempvar _k tulong) (tptr tdouble))
                                tdouble) (Etempvar _t'15 tdouble)))
                          (Sassign
                            (Ederef
                              (Ebinop Oadd (Etempvar _x (tptr tdouble))
                                (Etempvar _p tulong) (tptr tdouble)) tdouble)
                            (Etempvar _t tdouble))))))
                  (Sset _k
                    (Ebinop Oadd (Etempvar _k tulong)
                      (Econst_int (Int.repr 1) tint) tulong))))
              (Ssequence
                (Ssequence
                  (Sset _i (Ecast (Econst_int (Int.repr 0) tuint) tulong))
                  (Sloop
                    (Ssequence
                      (Sifthenelse (Ebinop Olt (Etempvar _i tulong)
                                     (Etempvar _n tulong) tint)
                        Sskip
                        Sbreak)
                      (Ssequence
                        (Sset _s
                          (Ederef
                            (Ebinop Oadd (Etempvar _x (tptr tdouble))
                              (Etempvar _i tulong) (tptr tdouble)) tdouble))
                        (Ssequence
                          (Ssequence
                            (Sset _k
                              (Ecast (Econst_int (Int.repr 0) tuint) tulong))
                            (Sloop
                              (Ssequence
                                (Sifthenelse (Ebinop Olt (Etempvar _k tulong)
                                               (Etempvar _i tulong) tint)
                                  Sskip
                                  Sbreak)
                                (Ssequence
                                  (Sset _t'13
                                    (Ederef
                                      (Ebinop Oadd
                                        (Etempvar _lu (tptr tdouble))
                                        (Ebinop Oadd (Etempvar _i tulong)
                                          (Ebinop Omul (Etempvar _k tulong)
                                            (Etempvar _n tulong) tulong)
                                          tulong) (tptr tdouble)) tdouble))
                                  (Ssequence
                                    (Sset _t'14
                                      (Ederef
                                        (Ebinop Oadd
                                          (Etempvar _x (tptr tdouble))
                                          (Etempvar _k tulong)
                                          (tptr tdouble)) tdouble))
                                    (Sset _s
                                      (Ebinop Osub (Etempvar _s tdouble)
                                        (Ebinop Omul (Etempvar _t'13 tdouble)
                                          (Etempvar _t'14 tdouble) tdouble)
                                        tdouble)))))
                              (Sset _k
                                (Ebinop Oadd (Etempvar _k tulong)
                                  (Econst_int (Int.repr 1) tint) tulong))))
                          (Ssequence
                            (Ssequence
                              (Scall (Some _t'8)
                                (Evar _diana_fp_finite (Tfunction
                                                         (tdouble :: nil)
                                                         tint cc_default))
                                ((Etempvar _s tdouble) :: nil))
                              (Sifthenelse (Eunop Onotbool
                                             (Etempvar _t'8 tint) tint)
                                (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
                                Sskip))
                            (Sassign
                              (Ederef
                                (Ebinop Oadd (Etempvar _x (tptr tdouble))
                                  (Etempvar _i tulong) (tptr tdouble))
                                tdouble) (Etempvar _s tdouble))))))
                    (Sset _i
                      (Ebinop Oadd (Etempvar _i tulong)
                        (Econst_int (Int.repr 1) tint) tulong))))
                (Ssequence
                  (Sset _i (Etempvar _n tulong))
                  (Ssequence
                    (Swhile
                      (Ebinop Ogt (Etempvar _i tulong)
                        (Econst_int (Int.repr 0) tuint) tint)
                      (Ssequence
                        (Sset _i
                          (Ebinop Osub (Etempvar _i tulong)
                            (Econst_int (Int.repr 1) tint) tulong))
                        (Ssequence
                          (Sset _s
                            (Ederef
                              (Ebinop Oadd (Etempvar _x (tptr tdouble))
                                (Etempvar _i tulong) (tptr tdouble)) tdouble))
                          (Ssequence
                            (Ssequence
                              (Sset _k
                                (Ebinop Osub (Etempvar _n tulong)
                                  (Econst_int (Int.repr 1) tuint) tulong))
                              (Sloop
                                (Ssequence
                                  (Sifthenelse (Ebinop Ogt
                                                 (Etempvar _k tulong)
                                                 (Etempvar _i tulong) tint)
                                    Sskip
                                    Sbreak)
                                  (Ssequence
                                    (Sset _t'11
                                      (Ederef
                                        (Ebinop Oadd
                                          (Etempvar _lu (tptr tdouble))
                                          (Ebinop Oadd (Etempvar _i tulong)
                                            (Ebinop Omul (Etempvar _k tulong)
                                              (Etempvar _n tulong) tulong)
                                            tulong) (tptr tdouble)) tdouble))
                                    (Ssequence
                                      (Sset _t'12
                                        (Ederef
                                          (Ebinop Oadd
                                            (Etempvar _x (tptr tdouble))
                                            (Etempvar _k tulong)
                                            (tptr tdouble)) tdouble))
                                      (Sset _s
                                        (Ebinop Osub (Etempvar _s tdouble)
                                          (Ebinop Omul
                                            (Etempvar _t'11 tdouble)
                                            (Etempvar _t'12 tdouble) tdouble)
                                          tdouble)))))
                                (Sset _k
                                  (Ebinop Osub (Etempvar _k tulong)
                                    (Econst_int (Int.repr 1) tint) tulong))))
                            (Ssequence
                              (Ssequence
                                (Sset _t'10
                                  (Ederef
                                    (Ebinop Oadd
                                      (Etempvar _lu (tptr tdouble))
                                      (Ebinop Oadd (Etempvar _i tulong)
                                        (Ebinop Omul (Etempvar _i tulong)
                                          (Etempvar _n tulong) tulong)
                                        tulong) (tptr tdouble)) tdouble))
                                (Sset _r
                                  (Ebinop Odiv (Etempvar _s tdouble)
                                    (Etempvar _t'10 tdouble) tdouble)))
                              (Ssequence
                                (Ssequence
                                  (Scall (Some _t'9)
                                    (Evar _diana_fp_finite (Tfunction
                                                             (tdouble :: nil)
                                                             tint cc_default))
                                    ((Etempvar _r tdouble) :: nil))
                                  (Sifthenelse (Eunop Onotbool
                                                 (Etempvar _t'9 tint) tint)
                                    (Sreturn (Some (Econst_int (Int.repr (-1)) tint)))
                                    Sskip))
                                (Sassign
                                  (Ederef
                                    (Ebinop Oadd (Etempvar _x (tptr tdouble))
                                      (Etempvar _i tulong) (tptr tdouble))
                                    tdouble) (Etempvar _r tdouble))))))))
                    (Sreturn (Some (Econst_int (Int.repr 0) tint)))))))))))))
|}.

Definition composites : list composite_definition :=
nil.

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
 (_diana_lu_solve, Gfun(Internal f_diana_lu_solve)) :: nil).

Definition public_idents : list ident :=
(_diana_lu_solve :: ___builtin_debug :: ___builtin_fmin :: ___builtin_fmax ::
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


