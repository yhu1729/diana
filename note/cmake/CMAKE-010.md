---
id: CMAKE-010
title: Linux and macOS only
kind: rule
path:
  - CMakeLists.txt
  - script/check_wheel.py
  - script/dev.sh
related: [CMAKE-004, FP-004]
---
Diana supports Linux and macOS with gcc or clang; no file may add a Windows or MSVC branch.

- `CMakeLists.txt` distinguishes only `APPLE` from the rest (Linux) for the wheel RPATH, and
  `cmake/warning.cmake` knows only the `GNU`, `Clang` and `AppleClang` compiler IDs.
- `script/check_wheel.py` expects `libdiana.dylib` on `darwin` and `libdiana.so` otherwise;
  `script/dev.sh` reads memory from `sysctl` or `/proc/meminfo`.
- CI runs on Linux images only; macOS is covered by local runs.

No check enforces the rule. Earlier Windows code was removed: commit `2f6843d` dropped the
Windows cases from the wheel check, `75904e1` the `WIN32` branch of `CMakeLists.txt`.
