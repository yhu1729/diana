#!/bin/sh
set -eu
if [ -n "${DIANA_JOB:-}" ]; then
    case $DIANA_JOB in
    *[!0-9]* | 0*)
        echo "error: DIANA_JOB must be a positive integer, not '$DIANA_JOB'" >&2
        exit 1
        ;;
    esac
    echo "$DIANA_JOB"
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
