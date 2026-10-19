---
id: BENCHMARK-007
title: The result file a benchmark run writes
kind: fact
path:
  - script/benchmark.sh
related: [BENCHMARK-001, BENCHMARK-002, BENCHMARK-004]
---
A full run of `script/benchmark.sh` writes one file per compiler,
`<DIANA_BENCHMARK_DIR>/<date>-<commit>-<machine>-<compiler>.txt`
(`2026-10-19-1eeb5cf-apple-m4-apple-clang-21.txt`), by default under `build/benchmark/result/`,
which `.gitignore` covers with `build/`; a result is local and is not committed (BENCHMARK-002).
A second run of the same commit on the same day gets the suffix `-2`, `-3`, ...

- Header: `date`; `commit` (the short hash of the file name, `-dirty` appended when the tree
  differed from `HEAD`); `system` (`uname -srm` and the OS version, `sw_vers` on macOS,
  `PRETTY_NAME` of `/etc/os-release` on Linux); `cpu` (brand string, core count, memory in
  GiB); `compiler` (command and first line of `--version`); `build`; a blank line.
- Body: the driver output (BENCHMARK-004): `compiler: __VERSION__`, the method line, and the
  table `kernel  n  ns/call  ns/unit  unit`, one row per case and size.
- To compare two states of the code, run the script on each (the file name and the header
  carry the commit; a `-dirty` run is not reproducible from the hash) and compare rows at equal
  `n`; to compare compilers, pass them in one invocation
  (`script/benchmark.sh cc gcc-15`), which builds each in its own temporary directory on the same
  machine state. Quiet the machine first; the best-of-7 minimum discards most interference but
  not a sustained load.
