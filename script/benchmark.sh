#!/bin/sh
# Build the benchmark suite in Release with each compiler given and run it;
# a full run is recorded in benchmark/result/, a filtered one only printed.
set -eu
cd "$(dirname "$0")/.."

usage() {
    cat <<USAGE
usage: script/benchmark.sh [cc...]

  builds the library and benchmark/ in Release with each compiler (default
  cc), runs the suite and writes benchmark/result/<date>-<machine>-<compiler>.txt

environment:
  DIANA_BENCHMARK_CASE     case names (prefixes) to run; the output is printed,
                           not recorded
  DIANA_BENCHMARK_MACHINE  machine name in the result file name (default: from
                           the CPU brand string)
USAGE
}

case "${1:-}" in
-h | --help)
    usage
    exit 0
    ;;
-*)
    usage >&2
    exit 2
    ;;
esac

if [ "$(uname -s)" = Darwin ] && [ -z "${MACOSX_DEPLOYMENT_TARGET:-}" ]; then
    MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion)
    export MACOSX_DEPLOYMENT_TARGET
fi
if [ "$#" -eq 0 ]; then
    set -- cc
fi
tmp=$(mktemp -d "${TMPDIR:-/tmp}/diana-benchmark.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

slug() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]' |
        sed 's/[^a-z0-9]\{1,\}/-/g; s/^-//; s/-$//'
}

cpu_brand() {
    case "$(uname -s)" in
    Darwin) sysctl -n machdep.cpu.brand_string 2>/dev/null ;;
    Linux) sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo | head -n 1 ;;
    esac
}

cpu_count() {
    case "$(uname -s)" in
    Darwin) sysctl -n hw.ncpu 2>/dev/null ;;
    Linux) nproc 2>/dev/null ;;
    esac
}

memory_gib() {
    case "$(uname -s)" in
    Darwin) sysctl -n hw.memsize 2>/dev/null | awk '{ printf "%d", $1 / 1073741824 }' ;;
    Linux) awk '/^MemTotal:/ { printf "%d", $2 / 1048576 }' /proc/meminfo ;;
    esac
}

os_name() {
    case "$(uname -s)" in
    Darwin) echo "macOS $(sw_vers -productVersion)" ;;
    Linux) sed -n 's/^PRETTY_NAME="\(.*\)"/\1/p' /etc/os-release 2>/dev/null ;;
    esac
}

machine_name() {
    if [ -n "${DIANA_BENCHMARK_MACHINE:-}" ]; then
        echo "$DIANA_BENCHMARK_MACHINE"
    else
        slug "$(cpu_brand | sed 's/([Rr])//g; s/([Tt][Mm])//g; s/ CPU//; s/ @.*//')"
    fi
}

compiler_name() {
    case "$2" in
    "Apple clang version "*)
        echo "apple-clang-$(printf '%s' "$2" | sed 's/.*version \([0-9][0-9]*\).*/\1/')"
        ;;
    *"clang version "*)
        echo "clang-$(printf '%s' "$2" | sed 's/.*version \([0-9][0-9]*\).*/\1/')"
        ;;
    *gcc* | *GCC*)
        version=${2##* }
        echo "gcc-${version%%.*}"
        ;;
    *)
        slug "$(basename "$1")"
        ;;
    esac
}

result_file() {
    base="benchmark/result/$1"
    out="$base.txt"
    n=1
    while [ -e "$out" ]; do
        n=$((n + 1))
        out="$base-$n.txt"
    done
    echo "$out"
}

date=$(date +%Y-%m-%d)
commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
if ! git diff --quiet HEAD 2>/dev/null; then
    commit="$commit, uncommitted changes"
fi
machine=$(machine_name)
[ -n "$machine" ] || machine=unknown

for cc in "$@"; do
    version=$("$cc" --version 2>/dev/null | head -n 1)
    name=$(compiler_name "$cc" "$version")
    build="$tmp/$name"
    CC=$cc cmake -S . -B "$build" -DCMAKE_BUILD_TYPE=Release -DDIANA_BUILD_PYTHON=OFF \
        -DDIANA_BUILD_SHARED_LIB=OFF -DDIANA_BUILD_BENCHMARK=ON -DDIANA_WERROR=ON >/dev/null
    cmake --build "$build" --target benchmark >/dev/null
    if [ -n "${DIANA_BENCHMARK_CASE:-}" ]; then
        # shellcheck disable=SC2086
        "$build/benchmark/benchmark" $DIANA_BENCHMARK_CASE
        continue
    fi
    out=$(result_file "$date-$machine-$name")
    {
        echo "date: $date"
        echo "commit: $commit"
        echo "system: $(uname -srm), $(os_name)"
        echo "cpu: $(cpu_brand), $(cpu_count) cores, $(memory_gib) GiB"
        echo "compiler: $cc, $version"
        echo "build: Release static library, DIANA_BUILD_BENCHMARK=ON, benchmark/ with the strict flags"
        echo
    } >"$out"
    "$build/benchmark/benchmark" >>"$out"
    cat "$out"
    echo "recorded in $out"
done
