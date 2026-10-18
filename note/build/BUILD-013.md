---
id: BUILD-013
title: Configuration refuses a C compiler other than gcc or clang
kind: rule
path:
  - CMakeLists.txt
  - cmake/warning.cmake
related: [BUILD-001, BUILD-002, BUILD-010, FP-004, FP-005, TEST-043]
---
`CMakeLists.txt` stops configuration with a `FATAL_ERROR` when `CMAKE_C_COMPILER_ID` is not
exactly `GNU`, `Clang` or `AppleClang`, the only IDs that `diana_set_strict_flag` gives the strict
floating-point options of FP-004 (BUILD-001). Without those options a build is not the one the
proofs and the compiler comparison cover (FP-005), and the defaults of other compilers contract:

- Intel oneAPI `icx` (`IntelLLVM`) defaults to `-fp-model=fast` with FMA, chosen to match the
  classic `icc` (Intel, "Porting Guide for ICC Users to DPCPP or ICX").
- NVIDIA HPC SDK `nvc` (`NVHPC`) generates fused multiply-add on the CPU and the GPU by default
  from `-O1` (`-Mfma`, HPC Compilers Reference Guide, "Code Generation Controls").

The match is anchored, so clang-based IDs such as `ARMClang`, `CrayClang` or `IBMClang` are
refused too; `cmake/warning.cmake` uses the same anchored match.

`DIANA_ALLOW_UNKNOWN_COMPILER` (OFF) turns the error into a `WARNING`. Such a build gets none of
the strict options, none of the warning flags and no `-Werror` (`DIANA_WERROR` has no effect),
and its strict IEEE binary64 semantics are not established; the flag guard of FP-004 still runs
on `CMAKE_C_FLAGS*`. The option exists for experiments, not for a shipped build.

The ctest test `configure` (TEST-043) checks the refusal and the option with a faked compiler ID;
no Intel or NVIDIA compiler runs locally or in CI.
