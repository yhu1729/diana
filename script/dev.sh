#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

build_dir=${DIANA_BUILD_DIR:-build}
build_type=${DIANA_BUILD_TYPE:-Debug}
sanitizer=${DIANA_SANITIZER:-ON}

usage() {
    cat <<EOF
usage: script/dev.sh config [cmake option...]
       script/dev.sh build | test | verify

  config  configure CMake in the build directory and sync the uv environment
  build   build the C library and tests, rebuild the Python extension
  test    run ctest and pytest, then the ruff and clang-format checks
  verify  check the Clight ASTs, compare the ccomp build of the kernels with
          gcc/clang builds bitwise, build the Lean and Rocq proofs, run Frama-C
          WP, and run the spec gate in strict mode, which fails on a theorem that
          is listed in spec/ but not proved (rewrites the report in
          doc/verification/report.md)

environment:
  DIANA_BUILD_DIR      CMake build directory (default build)
  DIANA_BUILD_TYPE     CMAKE_BUILD_TYPE for config (default Debug)
  DIANA_SANITIZER      DIANA_SANITIZER for config (default ON)
  DIANA_OPAM_SWITCH    opam switch with Rocq, CompCert, VST, and Frama-C (default: current)
  DIANA_CLIGHT_UPDATE  1: verify overwrites a Clight AST that differs instead of failing
  DIANA_COMPARE_CC     host compilers verify compares with ccomp (default: clang, gcc,
                       cc, gcc-N, clang-N, every Homebrew LLVM keg; duplicates dropped)
  DIANA_CLANG_TIDY     clang-tidy to run in test (default: first one found, else skip)
EOF
}

fail() {
    echo "error: $*" >&2
    exit 1
}

need_build() {
    [ -f "$build_dir/CMakeCache.txt" ] ||
        fail "$build_dir is not configured; run script/dev.sh config"
}

need_venv() {
    [ -d .venv ] || fail "no .venv; run script/dev.sh config"
}

uv_sync() {
    SKBUILD_CMAKE_DEFINE="DIANA_WERROR=ON${SKBUILD_CMAKE_DEFINE:+;$SKBUILD_CMAKE_DEFINE}" \
        uv sync --group test --group lint --group spec "$@"
}

opam_run() {
    if [ -n "${DIANA_OPAM_SWITCH:-}" ]; then
        opam exec --switch="$DIANA_OPAM_SWITCH" -- "$@"
    else
        opam exec -- "$@"
    fi
}

dev_config() {
    if [ -z "${CMAKE_GENERATOR:-}" ] && command -v ninja >/dev/null 2>&1; then
        CMAKE_GENERATOR=Ninja
        export CMAKE_GENERATOR
    fi
    uv_sync
    cmake -S . -B "$build_dir" -DCMAKE_BUILD_TYPE="$build_type" -DDIANA_BUILD_TEST=ON \
        -DDIANA_SANITIZER="$sanitizer" -DDIANA_WERROR=ON \
        -DPython_EXECUTABLE="$PWD/.venv/bin/python" "$@"
}

dev_build() {
    need_build
    cmake --build "$build_dir"
    uv_sync --reinstall-package diana
}

dev_test() {
    need_build
    need_venv
    ctest --test-dir "$build_dir" --output-on-failure
    uv run --no-sync pytest -q -v
    uv run --no-sync ruff check python test/python test/doc script
    uv run --no-sync ruff format --check python test/python test/doc script
    find include src test/c test/install python/ext -name '*.[ch]' -print0 |
        xargs -0 uv run --no-sync clang-format --dry-run --Werror
    run_tidy
}

tidy_bin() {
    if [ -n "${DIANA_CLANG_TIDY:-}" ]; then
        echo "$DIANA_CLANG_TIDY"
    elif command -v clang-tidy >/dev/null 2>&1; then
        echo clang-tidy
    else
        for candidate in /opt/homebrew/opt/llvm/bin/clang-tidy \
            /usr/local/opt/llvm/bin/clang-tidy; do
            if [ -x "$candidate" ]; then
                echo "$candidate"
                return 0
            fi
        done
        return 1
    fi
}

run_tidy() {
    tidy=$(tidy_bin) || {
        echo "clang-tidy: not found; check skipped" \
            "(set DIANA_CLANG_TIDY or install LLVM, see doc/development/style.md)"
        return 0
    }
    [ -f "$build_dir/compile_commands.json" ] ||
        fail "$build_dir/compile_commands.json is missing; run script/dev.sh config"
    grep -q 'python/ext/' "$build_dir/compile_commands.json" ||
        fail "$build_dir/compile_commands.json has no entry for python/ext;" \
            "reconfigure with DIANA_BUILD_PYTHON=ON (script/dev.sh config)"
    "$tidy" --version | head -n 1
    git ls-files 'src/*.c' 'src/wrapper/*.c' 'test/c/*.c' 'test/install/*.c' \
        'python/ext/*.c' |
        xargs "$tidy" --quiet -p "$build_dir" --warnings-as-errors='*'
}

clight_platform() {
    lib=$(opam_run opam var lib)
    for config in "$lib/coq/user-contrib/compcert/compcert.config" \
        "$lib/rocq/user-contrib/compcert/compcert.config"; do
        if [ -f "$config" ]; then
            arch=$(sed -n 's/^COMPCERT_ARCH=//p' "$config")
            model=$(sed -n 's/^COMPCERT_MODEL=//p' "$config")
            system=$(sed -n 's/^COMPCERT_SYSTEM=//p' "$config")
            if [ "$model" = default ]; then
                echo "${arch}_$system"
            else
                echo "${arch}_${model}_$system"
            fi
            return 0
        fi
    done
    fail "compcert.config not found under $lib; is CompCert installed in the opam switch?"
}

check_clight() {
    platform=$(clight_platform)
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/diana-clight.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT
    stale=0
    found=0
    for ast in verification/clight/*_"$platform".v; do
        [ -e "$ast" ] || continue
        found=1
        name=$(basename "$ast" "_$platform.v")
        opam_run clightgen -normalize -Iinclude -Isrc -o "$tmp/$name.v" "src/$name.c"
        if cmp -s "$tmp/$name.v" "$ast"; then
            echo "clight: $ast is current"
        elif [ "${DIANA_CLIGHT_UPDATE:-0}" = 1 ]; then
            cp "$tmp/$name.v" "$ast"
            echo "clight: updated $ast"
        else
            diff -u "$ast" "$tmp/$name.v" | head -n 40 >&2
            echo "error: $ast does not match clightgen output for src/$name.c" >&2
            stale=1
        fi
    done
    if [ "$found" -eq 0 ]; then
        echo "clight: no committed AST for CompCert target $platform; check skipped" \
            "(the VST proofs are about the ASTs of the platform in their file name)"
    fi
    [ "$stale" -eq 0 ] || fail "after a source change, rerun with DIANA_CLIGHT_UPDATE=1"
}

dev_verify() {
    need_venv
    check_clight
    opam_run script/compare_compiler.sh
    (cd verification/lean && lake exe cache get && lake build)
    opam_run make -C verification/rocq
    opam_run script/verify_frama_c.sh
    opam_run uv run --no-sync script/check_spec.py --run --strict
}

command=${1:-}
if [ "$#" -gt 0 ]; then
    shift
fi
case "$command" in
config)
    dev_config "$@"
    ;;
build | test | verify)
    if [ "$#" -ne 0 ]; then
        usage >&2
        exit 2
    fi
    case "$command" in
    build) dev_build ;;
    test) dev_test ;;
    verify) dev_verify ;;
    esac
    ;;
help | -h | --help)
    usage
    ;;
*)
    usage >&2
    exit 2
    ;;
esac
