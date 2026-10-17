---
id: STYLE-002
title: One function per implementation file, named after the function
kind: rule
path:
  - src/*.c
  - python/ext/*.c
related: [KERNEL-001, VST-005, WP-007]
---
Each implementation file in `src/` and `python/ext/` defines exactly one function and is named
after it without the `diana_` or `diana_py_` prefix: `diana_bisection_init` in
`src/bisection_init.c`, `diana_py_bisection_step` in `python/ext/bisection_step.c`, the callback
wrapper `diana_rk4` in `src/rk4.c`.

- `static inline` helpers do not count: those of `src/fp.h` are compiled into every file that
  includes it, and `python/ext/get_array.c` has its file-local `is_native_double`.
- Static data such as a CPython method table or type object stays with the function that
  registers it (`python/ext/bisection_exec.c` holds `BisectionType`).
- A helper that several files call is a function and file of its own, declared in a private
  header: `diana_bisection_mid` in `src/bisection_mid.c` and `src/bisection_mid.h`,
  `diana_py_get_array` in `python/ext/get_array.c` and `python/ext/module.h`.
- `PyInit__diana` is in `python/ext/module.c`, the one file not named after its function.
- Test sources are exempt.

A verified source file also has its own Frama-C expectation row, Clight AST and VST file
(WP-007, VST-005); a variant such as an `_unchecked` kernel is a separate source file with its own
artifacts. No script enforces the rule.
