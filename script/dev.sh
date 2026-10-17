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
  test    run ctest and pytest, then the ruff, clang-format and clang-tidy checks
  verify  check the Clight ASTs, then at once compare the ccomp build of the
          kernels with gcc/clang builds bitwise, build the Lean and Rocq proofs
          and run Frama-C WP (logs in the build directory under verify/), then
          run the spec gate in strict mode, which fails on a theorem that is
          listed in spec/ but not proved (rewrites the report in
          doc/verification/report.md)

environment:
  DIANA_BUILD_DIR      CMake build directory (default build)
  DIANA_BUILD_TYPE     CMAKE_BUILD_TYPE for config (default Debug)
  DIANA_SANITIZER      DIANA_SANITIZER for config (default ON)
  DIANA_OPAM_SWITCH    opam switch with Rocq, CompCert, VST, and Frama-C (default: current)
  DIANA_JOB            verify: Rocq jobs (capped by memory) and Frama-C rows at a time
                       (default: CPU count); 1 runs the stages one after another
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
    git ls-files 'src/*.c' 'test/c/*.c' 'test/install/*.c' \
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

build_lean() {
    (cd verification/lean && lake exe cache get && lake build)
}

# Memory per VST proof: measured peak RSS of one rocq compile on the heaviest
# theory/VST file, rounded up (doc/verification/local.md); the cap keeps
# DIANA_JOB such proofs resident at once within hw.memsize / MemTotal.
rocq_job_byte=2147483648

rocq_jobs() {
    if mem=$(sysctl -n hw.memsize 2>/dev/null); then
        :
    elif [ -r /proc/meminfo ]; then
        mem=$(awk '/^MemTotal:/ { print $2 * 1024 }' /proc/meminfo)
    else
        echo "$jobs"
        return 0
    fi
    cap=$((mem / rocq_job_byte))
    [ "$cap" -ge 1 ] || cap=1
    if [ "$jobs" -le "$cap" ]; then
        echo "$jobs"
    else
        echo "$cap"
    fi
}

run_stage() {
    name=$1
    shift
    start=$(date +%s)
    status=0
    "$@" >"$verify_dir/$name.log" 2>&1 </dev/null || status=$?
    echo "$status $(($(date +%s) - start))" >"$verify_dir/$name.status"
    if [ "$status" -eq 0 ]; then
        echo "verify: $name passed ($(($(date +%s) - start)) s)"
    else
        echo "verify: $name FAILED with status $status ($(($(date +%s) - start)) s)"
    fi
}

dev_verify() {
    need_venv
    jobs=$(script/job_count.sh)
    DIANA_JOB=$jobs
    export DIANA_JOB
    check_clight
    if [ "$jobs" -eq 1 ]; then
        opam_run script/compare_compiler.sh
        build_lean
        opam_run make -C verification/rocq
        opam_run script/verify_frama_c.sh
    else
        verify_dir="$build_dir/verify"
        mkdir -p "$verify_dir"
        rm -f "$verify_dir"/*.log "$verify_dir"/*.status
        rocq_jobs=$(rocq_jobs)
        echo "verify: compiler, lean, rocq (-j $rocq_jobs) and frama-c run at once" \
            "with DIANA_JOB=$jobs; logs in $verify_dir"
        pids=
        run_stage compiler opam_run script/compare_compiler.sh &
        pids="$pids $!"
        run_stage lean build_lean &
        pids="$pids $!"
        run_stage rocq opam_run make -C verification/rocq -j "$rocq_jobs" &
        pids="$pids $!"
        run_stage frama_c opam_run script/verify_frama_c.sh &
        pids="$pids $!"
        trap 'kill $pids 2>/dev/null; wait; exit 130' INT TERM
        for pid in $pids; do
            wait "$pid" || true
        done
        trap - INT TERM
        failed=
        for name in compiler lean rocq frama_c; do
            status=none
            elapsed=0
            read -r status elapsed <"$verify_dir/$name.status" || status=none
            echo "==> $name: status $status, $elapsed s <=="
            cat "$verify_dir/$name.log"
            echo
            [ "$status" = 0 ] || failed="$failed $name"
        done
        [ -z "$failed" ] || fail "verify stage failed:$failed (logs in $verify_dir)"
    fi
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
