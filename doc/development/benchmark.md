# Benchmark

`script/benchmark.sh [cc...]` measures what the opt-in `_unchecked` kernels save over the checked
ones. For each compiler given (default `cc`) it builds the static library in Release, links the
driver `test/benchmark/unchecked.c` against it, and prints nanoseconds per component for the
Euler step, the RK4 stage and step, and whole Euler and RK4 steps with a trivial right-hand side,
at dimensions 64, 1024 and 16384.

The figures quoted in the [Euler](../api/euler.md) and [RK4](../api/rk4.md) pages and in
`CHANGELOG.md` come from one run, `script/benchmark.sh cc gcc-15` on an Apple M4 Mac on
2026-10-17, with Apple clang 21 and GCC 15.3:

| Kernel | Checked (ns) | Unchecked (ns) | Speed-up |
|---|---|---|---|
| Euler step | 0.44–0.52 | 0.10–0.19 | 2.8–4.8× |
| RK4 stage | 0.44–0.56 | 0.10–0.17 | 2.9–4.8× |
| RK4 step | 0.86–1.26 | 0.25–0.37 | 2.6–4.5× |
| whole RK4 step, with right-hand side | 2.8–3.7 | 0.8–2.0 | 1.7–3.5× |

The unchecked kernels gain because they make one pass with no branch, which the compilers
vectorize; the checked ones make two passes. The numbers depend on the machine and the compiler,
so treat them as orders of magnitude elsewhere. When a kernel or the driver changes, rerun the
script and update every quoted figure together.

## Technical notes

[BENCHMARK-001](../../note/benchmark/BENCHMARK-001.md) what is measured and how,
[BENCHMARK-002](../../note/benchmark/BENCHMARK-002.md) and
[BENCHMARK-003](../../note/benchmark/BENCHMARK-003.md) the full recorded output per compiler,
[BENCHMARK-004](../../note/benchmark/BENCHMARK-004.md) keeping quoted figures in sync,
[BENCHMARK-005](../../note/benchmark/BENCHMARK-005.md) the driver is built only by the script.
