---
id: COMPILER-002
title: Host compiler discovery, DIANA_COMPARE_CC and duplicate removal
kind: fact
path:
  - script/compare_compiler.sh
  - script/dev.sh
related: [COMPILER-001, COMPILER-003]
---
The comparison uses the compilers in `DIANA_COMPARE_CC` when it is set (a whitespace-separated
list), otherwise every candidate it can find, and compares each distinct compiler once.

- Candidates without `DIANA_COMPARE_CC`: `clang`, `gcc`, `cc`; every executable `gcc-<digit>*`
  and `clang-<digit>*` in each `PATH` directory, by name; and `opt/llvm/bin/clang` and each
  `opt/llvm@<N>/bin/clang` under `/opt/homebrew` and `/usr/local`. A candidate that
  `command -v` cannot find is skipped silently.
- Duplicates: candidates with the same first line of `--version` are one compiler and only the
  first is used. On macOS `gcc` and `cc` are Apple clang, and the `llvm` keg is the newest
  `llvm@N`.
- Description: from that first line, the vendor string in parentheses for GCC
  (`Homebrew GCC 16.2.0`) or `<vendor> clang <version>` with `version` and the trailing
  parenthesis removed (`Apple clang 21.0.0`, `Homebrew clang 23.1.3`).
- Probe: each compiler must compile and link `int main(void) { return 0; }` without flags;
  otherwise it is skipped with `compiler: <cc> (<description>) cannot build a program here;
  skipped:` and the first line of its error.
- If no compiler passes the probe the script fails with
  `no host compiler found (set DIANA_COMPARE_CC)`.
- `script/dev.sh help` documents `DIANA_COMPARE_CC` for `verify`.
