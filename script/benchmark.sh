#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

if [ "$(uname -s)" = Darwin ] && [ -z "${MACOSX_DEPLOYMENT_TARGET:-}" ]; then
    MACOSX_DEPLOYMENT_TARGET=$(sw_vers -productVersion)
    export MACOSX_DEPLOYMENT_TARGET
fi
if [ "$#" -eq 0 ]; then
    set -- cc
fi
tmp=$(mktemp -d "${TMPDIR:-/tmp}/diana-benchmark.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

uname -sm
for cc in "$@"; do
    build="$tmp/$(basename "$cc")"
    CC=$cc cmake -S . -B "$build" -DCMAKE_BUILD_TYPE=Release -DDIANA_BUILD_PYTHON=OFF \
        -DDIANA_BUILD_SHARED_LIB=OFF >/dev/null
    cmake --build "$build" >/dev/null
    "$cc" -std=c11 -O2 -ffp-contract=off -Wall -Wextra -Wconversion -Wshadow -Wvla -pedantic \
        -Werror -Iinclude -o "$build/unchecked" test/benchmark/unchecked.c "$build/libdiana.a"
    "$build/unchecked"
done
