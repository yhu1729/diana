# Benchmark

The benchmark suite in `benchmark/` times every kernel of the library, with the callback
wrappers, on in-cache data. It is a local tool: no CI job builds or runs it, and no result is
committed. The documentation quotes no timing; it tells you how to measure one on your machine
and compiler, which is the only figure that means anything for your use.

## Run it

```bash
script/benchmark.sh
```

builds the library and the suite in Release with `cc` in a temporary directory, runs every case
and writes `build/benchmark/result/<date>-<machine>-<compiler>.txt`, printing it as well. Pass
compilers to compare them in one run, each built the same way:

```bash
script/benchmark.sh cc gcc-15
```

`DIANA_BENCHMARK_DIR` chooses the result directory, `DIANA_BENCHMARK_MACHINE` the machine name
in the file name (by default the CPU brand string, `apple-m4`), and
`DIANA_BENCHMARK_CASE="rk4 norm" script/benchmark.sh` runs only the cases whose name starts with
one of the words and prints them without writing a file. An existing file is never overwritten.
After `script/dev.sh build`, `build/benchmark/benchmark --list` names every case and
`build/benchmark/benchmark euler_step` runs one, from the Debug build with sanitizers, which is
for checking the drivers, not for timing.

The file starts with a header naming the date, commit, system, CPU, memory and compiler, so a
result can be compared with another later; to see what a change did, run the script before and
after it on a quiet machine and compare rows at equal `n`.

## Read the table

```text
kernel                          n      ns/call   ns/unit  unit
euler_step                   1024        ...        ...   component
cholesky                      256        ...        ...   flop
```

Each case is one call of a kernel on fixed inputs, repeated: the driver doubles the calls per
trial until a trial lasts 50 ms, takes the best of seven trials, and prints nanoseconds per call
and per unit of work. A row is the throughput of back-to-back independent calls, not the latency
of one; at small `n` the processor overlaps consecutive calls, so compare rows at equal `n` and
read the largest `n` for the kernel alone.

| Case | One call | Unit | `n` |
|---|---|---|---|
| `bisection_step`, `bisection` | a solve of `x² − 2 = 0` on `[0, 2]` to adjacent doubles, by the state machine and by the wrapper | step | — |
| `newton_step`, `newton` | a solve of the same equation from 2 to `tol = 1e-12`, six steps | step | — |
| `trapezoidal`, `simpson` | one rule over `n` samples | sample | 65, 1025, 16385 |
| `euler_step`, `rk4_stage`, `rk4_step`, and `_unchecked` | one kernel call | component | 64, 1024, 16384 |
| `euler_loop`, `rk4_loop`, and `_unchecked` | eight steps of a hand-written loop with the right-hand side `y′ = −y/2` | component of a step | 64, 1024, 16384 |
| `euler`, `rk4` | eight steps of the callback wrapper on the same right-hand side | component of a step | 64, 1024, 16384 |
| `cholesky`, `forward_substitution`, `transpose_substitution` | one factorization or solve with a well-conditioned positive definite matrix | flop (`n³/3`, `n²`) | 16, 64, 256 |
| `lu`, `lu_solve` | one factorization or solve with a random matrix, so rows are interchanged | flop (`2n³/3`, `2n²`) | 16, 64, 256 |
| `norm_1`, `norm_2`, `norm_inf` | one norm | component | 64, 1024, 16384 |

The `_unchecked` rows against their checked ones show what the opt-in
[Euler](../api/euler.md#unchecked-step) and [RK4](../api/rk4.md#unchecked-stage-and-step)
kernels save: one branch-free pass the compiler vectorizes against two passes. The `_loop` rows
put that saving next to a right-hand side; a real one costs more than `y′ = −y/2`.

## Change it

The suite is ordinary C with a shared harness (`benchmark/benchmark.h`, `benchmark/harness.c`,
`benchmark/main.c`) and one file of cases per method; a new kernel gets a case there, listed in
`benchmark/CMakeLists.txt`, `benchmark/benchmark.h` and `benchmark/main.c`. The CMake option
`DIANA_BUILD_BENCHMARK` builds it, which `script/dev.sh config` turns on, so the drivers compile,
run under the sanitizers and pass `clang-format` and `clang-tidy` locally.

## Technical notes

[BENCHMARK-001](../../note/benchmark/BENCHMARK-001.md) what the script builds, runs and writes,
[BENCHMARK-004](../../note/benchmark/BENCHMARK-004.md) the timing method and the table,
[BENCHMARK-005](../../note/benchmark/BENCHMARK-005.md) and
[BENCHMARK-006](../../note/benchmark/BENCHMARK-006.md) the cases and their inputs,
[BENCHMARK-007](../../note/benchmark/BENCHMARK-007.md) the result file,
[BENCHMARK-002](../../note/benchmark/BENCHMARK-002.md) results stay local, no quoted figure,
[BENCHMARK-003](../../note/benchmark/BENCHMARK-003.md) built and linted locally, never run in CI.
