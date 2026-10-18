---
id: BUILD-010
title: Linux and macOS only
kind: rule
path:
  - CMakeLists.txt
  - script/check_wheel.py
  - script/dev.sh
related: [BUILD-004, BUILD-013, FP-004]
---
Diana supports Linux and macOS with gcc or clang; no file may add a Windows or MSVC branch.

- `CMakeLists.txt` distinguishes only `APPLE` from the rest (Linux) for the wheel RPATH, and
  refuses a compiler ID other than `GNU`, `Clang` and `AppleClang` (BUILD-013), the only ones
  `cmake/warning.cmake` knows.
- `script/check_wheel.py` expects `libdiana.dylib` on `darwin` and `libdiana.so` otherwise;
  `script/dev.sh` reads memory from `sysctl` or `/proc/meminfo`.
- CI runs on Linux images only; macOS is covered by local runs.

Only the compiler half is enforced, at configuration; no check enforces the platform half. Earlier
Windows code was removed: commit `2f6843d` dropped the
Windows cases from the wheel check, `75904e1` the `WIN32` branch of `CMakeLists.txt`.
