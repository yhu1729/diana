---
id: BENCHMARK-003
title: The benchmark is built and linted locally and never run in CI
kind: fact
path:
  - benchmark/CMakeLists.txt
  - benchmark/.clang-tidy
  - script/dev.sh
  - .gitlab-ci.yml
related: [BENCHMARK-001, CI-004, STYLE-007, STYLE-008, BUILD-002]
---
No CI job configures `DIANA_BUILD_BENCHMARK=ON`, so none builds `benchmark/` or runs the suite:
a timing on a shared runner is not a figure of record, and `.change_c` does not list the
directory. The figures of record come from `script/benchmark.sh` on a described machine
(BENCHMARK-007). What does see the sources:

- `script/dev.sh config` passes `-DDIANA_BUILD_BENCHMARK=ON`, so `script/dev.sh build` compiles
  the drivers with the Debug, sanitizer and `-Werror` flags of `build/`, and `script/dev.sh test`
  runs clang-tidy on `benchmark/*.c` from that compile database (STYLE-008) and the clang-format
  check on `benchmark/`, as CI `style_c` does (CI-004, path list `.change_style_c`). A change to
  a kernel's signature therefore fails the local build at once; ctest never runs the executable.
- The sanitized `build/benchmark/benchmark` is a check of the drivers themselves: it runs every
  case under ASan and UBSan in well under a minute.
- The drivers are ordinary C, not verified kernels: `malloc`, `clock_gettime`, function pointers
  and `printf` are allowed, and the one-function-per-file rule does not apply (STYLE-002).
  `benchmark/.clang-tidy` inherits the root configuration and drops `cert-err33-c` (the drivers
  report with `printf` and exit) and `readability-non-const-parameter` (a right-hand side keeps
  the signature of `diana_ode_fn`), STYLE-007.
