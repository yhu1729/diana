---
id: BUILD-012
title: A shared libdiana exports only the functions listed in cmake/symbol.txt
kind: rule
path:
  - cmake/symbol.txt
  - cmake/check_symbol.cmake
  - CMakeLists.txt
related: [BUILD-002, BUILD-004, BUILD-005, KERNEL-005, KERNEL-006]
---
`cmake/symbol.txt` lists every function declared in `include/diana/*.h`, one name per line,
sorted. With `DIANA_BUILD_SHARED_LIB=ON` it is the library's whole export set:

- macOS: `diana.exp` in the build directory, each name with a leading `_`, passed to the linker
  as `-exported_symbols_list`; the link fails on a listed name the library does not define.
- Linux: `diana.map`, an anonymous version script (`global:` the list, `local: *`), passed as
  `--version-script`; it adds no symbol version.
- Both are written by `file(CONFIGURE)`, so `cmake/symbol.txt` is a configure dependency and the
  generated file a `LINK_DEPENDS` of `diana`.

Every other external function, the private helpers `diana_bisection_mid` and `diana_fp_sqrt`
(KERNEL-005) among them, is hidden: no consumer of the shared library can link against it, so
it is not ABI. A static library is unaffected, its objects keep every external symbol.

The ctest `symbol` (`cmake -P cmake/check_symbol.cmake`) fails when the list differs from the
`diana_<name>(` declarations of the public headers and, in a shared build, when the `diana_`
symbols the library defines and exports (`nm -g` on macOS, `nm -D --defined-only` on Linux)
differ from the list. A new public function goes into `cmake/symbol.txt` in the commit that
declares it (KERNEL-006). CI checks the Linux export set in `test_install`.
