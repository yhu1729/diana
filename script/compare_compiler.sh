#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

driver=test/c/test_compiler.c
strict="-std=c11 -ffp-contract=off -fno-fast-math"
warning="-Wall -Wextra -Wconversion -Wshadow -Wvla -Wpedantic -Wstrict-prototypes
-Wmissing-prototypes -Wcast-qual -Wpointer-arith -Wundef -Wdouble-promotion -Werror"
level="-O0 -O2 -O3"

fail() {
    echo "error: $*" >&2
    exit 1
}

list_candidate() (
    echo clang
    echo gcc
    echo cc
    IFS=:
    for dir in $PATH; do
        for path in "$dir"/gcc-[0-9]* "$dir"/clang-[0-9]*; do
            if [ -x "$path" ]; then
                basename "$path"
            fi
        done
    done
    for path in /opt/homebrew/opt/llvm/bin/clang /usr/local/opt/llvm/bin/clang; do
        if [ -x "$path" ]; then
            echo "$path"
        fi
    done
)

if ! command -v ccomp >/dev/null 2>&1; then
    echo "compiler: ccomp not found; differential test skipped" \
        "(install CompCert in the opam switch, see CONTRIBUTING.md)"
    exit 0
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/diana-compiler.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

ccomp -std=c11 -Wall -Werror -Iinclude -o "$tmp/ccomp" src/*.c "$driver"
"$tmp/ccomp" >"$tmp/ccomp.out" || fail "the ccomp build of $driver failed"
tail -n 1 "$tmp/ccomp.out" | grep -q '^end ' || fail "the ccomp output is truncated"
lines=$(wc -l <"$tmp/ccomp.out" | tr -d ' ')
echo "compiler: reference $(ccomp -version | head -n 1), $(uname -m), $lines lines"

if [ -n "${DIANA_COMPARE_CC:-}" ]; then
    candidate=$DIANA_COMPARE_CC
else
    candidate=$(list_candidate)
fi

seen="$tmp/seen"
: >"$seen"
echo 'int main(void) { return 0; }' >"$tmp/probe.c"
count=0
differ=0
for cc in $candidate; do
    command -v "$cc" >/dev/null 2>&1 || continue
    version=$("$cc" --version 2>/dev/null | head -n 1) || continue
    if grep -qxF "$version" "$seen"; then
        continue
    fi
    echo "$version" >>"$seen"
    if ! "$cc" -o "$tmp/probe" "$tmp/probe.c" >"$tmp/probe.log" 2>&1; then
        echo "compiler: $cc ($version) cannot build a program here; skipped:" \
            "$(head -n 1 "$tmp/probe.log")"
        continue
    fi
    extra=
    macro=$("$cc" -dM -E -x c /dev/null)
    case "$macro" in
    *__clang__*) ;;
    *__GNUC__*) extra=-fexcess-precision=standard ;;
    esac
    for opt in $level; do
        count=$((count + 1))
        binary="$tmp/host$count"
        "$cc" $strict $warning $extra $opt -Iinclude -o "$binary" src/*.c "$driver"
        "$binary" >"$binary.out" || fail "the $cc $opt build of $driver failed"
        if cmp -s "$tmp/ccomp.out" "$binary.out"; then
            echo "compiler: $cc $opt ($version) matches ccomp"
        else
            diff "$tmp/ccomp.out" "$binary.out" | head -n 20 >&2
            echo "error: $cc $opt ($version) differs from ccomp" >&2
            differ=1
        fi
    done
done

[ "$count" -gt 0 ] || fail "no host compiler found (set DIANA_COMPARE_CC)"
if [ "$differ" -ne 0 ]; then
    trap - EXIT
    fail "a host-compiler build differs bitwise from the ccomp build; outputs in $tmp"
fi
