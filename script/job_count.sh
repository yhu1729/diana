#!/bin/sh
set -eu
if [ -n "${DIANA_JOBS:-}" ]; then
    case $DIANA_JOBS in
    *[!0-9]* | 0*)
        echo "error: DIANA_JOBS must be a positive integer, not '$DIANA_JOBS'" >&2
        exit 1
        ;;
    esac
    echo "$DIANA_JOBS"
    exit 0
fi
if n=$(nproc 2>/dev/null); then
    :
elif n=$(sysctl -n hw.ncpu 2>/dev/null); then
    :
elif n=$(getconf _NPROCESSORS_ONLN 2>/dev/null); then
    :
else
    n=1
fi
echo "$n"
