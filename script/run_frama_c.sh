#!/bin/sh
SKIP=bisection_mid
set -eu
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then
    set -- src/bisection.c
fi
skip=
for name in $SKIP; do
    for arg in "$@"; do
        if [ -f "$arg" ] && grep -Eq "(^|[^A-Za-z0-9_])$name[[:space:]]*\(" "$arg"; then
            skip="${skip:+$skip,}$name"
            break
        fi
    done
done
if [ -n "$skip" ]; then
    set -- -wp-skip-fct "$skip" "$@"
fi
exec frama-c \
    -cpp-extra-args="-Iinclude -Isrc" \
    -warn-special-float none \
    -wp -wp-rte -wp-model "+float" \
    -wp-prover alt-ergo \
    -wp-timeout 30 \
    -wp-session verification/frama-c/session -wp-cache update \
    -wp-cache-dir verification/frama-c/cache \
    -wp-status \
    "$@"
