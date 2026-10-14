#!/bin/sh
SKIP=bisect_mid
set -eu
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then
    set -- src/bisect.c
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
    -wp-skip-fct "$SKIP" \
    "$@"
