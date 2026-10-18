# Test

Three suites cover the code, and every one runs in CI.

| Suite | Location | Runs with |
|---|---|---|
| C | `test/c/`: one program per kernel, plus the status functions, the compiler-comparison driver, and a script that reconfigures the project to check that it refuses other compilers and fast-math flags | `ctest --test-dir build` (configure with `-DDIANA_BUILD_TEST=ON`) |
| Python | `test/python/`: the package, including Hypothesis property tests, plus the spec gate and the doc check scripts | `uv run pytest` |
| Documentation | `test/doc/`: every example in `doc/api/` | `uv run pytest` |

`script/dev.sh test` runs all three, then the format and lint checks.

ctest also installs the build into a temporary prefix and compiles the small consumer project in
`test/install/` against it with `find_package(diana)`, so the exported CMake package is tested as
a user would see it. `uv run script/check_wheel.py` does the same for the Python wheels: it builds
a static and a shared wheel, installs each in a fresh environment, and imports it from outside
the checkout.

## What the tests check

- **Exact cases.** Inputs with few significant bits, for which every operation is exact, so the
  expected value is known exactly.
- **Rounding and order.** Inputs chosen so that a different operation order, or a fused
  multiply-add, would give a different result, which pins the evaluation order the proofs assume.
- **Edges.** Every argument error, NaN and infinite inputs, overflow in each operation, underflow,
  signed zeros, and that a failed call leaves its output untouched.
- **Properties.** Hypothesis draws random inputs and requires bitwise agreement with the same
  operations in Python floats, and the proved rounding bounds are checked against exact rational
  arithmetic.
- **Convergence.** Each method's error shrinks at its proved rate when the step is halved.

The C tests keep every line and branch of the kernels covered. The reasoning behind each expected
value is recorded in the technical notes.

## Documentation examples

Each `c` block in `doc/api/` is compiled with the library sources and the project's warning flags,
run, and its output compared with the `text` block that follows it; it must also be unchanged by
the pinned `clang-format`. The `python` blocks of a page run as one doctest session. Change an
example and its output together.

## Technical notes

[TEST-001](../../note/test/TEST-001.md) suite layout,
[TEST-002](../../note/test/TEST-002.md) installed-consumer tests,
[TEST-003](../../note/test/TEST-003.md) documentation example check,
[TEST-004](../../note/test/TEST-004.md) wheel check,
[TEST-006](../../note/test/TEST-006.md) coverage,
[TEST-043](../../note/test/TEST-043.md) configuration test. Expected values per method are under
[By topic: test](../../note/README.md#test) in the note index.
