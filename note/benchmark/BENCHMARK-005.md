---
id: BENCHMARK-005
title: Only script/benchmark.sh compiles the benchmark driver
kind: fact
path:
  - test/benchmark/unchecked.c
  - script/benchmark.sh
  - script/dev.sh
  - .gitlab-ci.yml
related: [BENCHMARK-001, TEST-001]
---
`test/benchmark/unchecked.c` is built and run only by `script/benchmark.sh`, so a change to the
Euler or RK4 API can break it unnoticed until the next benchmark run.

- It is not in any `CMakeLists.txt`, ctest or CI job.
- The clang-format checks (`script/dev.sh test` and CI `style_c`) scan only `include`, `src`,
  `test/c`, `test/install` and `python/ext`, and clang-tidy only the tracked `.c` files of
  `src`, `test/c`, `test/install` and `python/ext`; neither sees `test/benchmark/`.
- `script/benchmark.sh` compiles it with `-std=c11 -Wall -Wextra -Wconversion -Wshadow -Wvla
  -pedantic -Werror`, so a warning fails the benchmark run.
- It is ordinary C: it uses `malloc`, `clock_gettime` (`_POSIX_C_SOURCE 200809L`) and function
  pointers, none of which a verified kernel may use.
