---
id: COMPILER-003
title: The comparison sets MACOSX_DEPLOYMENT_TARGET on macOS when it is unset
kind: fact
path:
  - script/compare_compiler.sh
  - script/benchmark.sh
related: [COMPILER-002]
---
On macOS (`uname -s` is `Darwin`), when `MACOSX_DEPLOYMENT_TARGET` is unset or empty,
`script/compare_compiler.sh` sets and exports it to the running version from
`sw_vers -productVersion`, for every build including `ccomp`. A value set by the caller is kept.

- Reason, as recorded with the change (commits `5891b89` and `87ae55e`): without it Homebrew GCC
  13 derives `-mmacosx-version-min=18.0` from Darwin 27, which the assembler and linker it invokes
  reject, so GCC 13 could not link even the probe program and was skipped. With the variable set,
  GCC 13 takes part (COMPILER-011).
- `script/benchmark.sh` sets the variable the same way.
