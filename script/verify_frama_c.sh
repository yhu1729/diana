#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
expectation=verification/frama-c/expectation.txt
report=verification/frama-c/report.txt
part=$(mktemp)
trap 'rm -f "$part"' EXIT
: >"$report"
count=0
while read -r source _ || [ -n "$source" ]; do
    [ -n "$source" ] || continue
    count=$((count + 1))
    status=0
    script/run_frama_c.sh "$source" >"$part" 2>&1 </dev/null || status=$?
    {
        echo "==> $source <=="
        cat "$part"
        echo
    } >>"$report"
    if [ "$status" -ne 0 ]; then
        tail -n 20 "$part" >&2
        echo "Frama-C WP failed on $source; full output in $report" >&2
        exit 1
    fi
    printf '%s: ' "$source"
    if ! script/check_frama_c.sh "$part" "$source"; then
        echo "WP check failed on $source; full output in $report" >&2
        exit 1
    fi
done <"$expectation"
if [ "$count" -eq 0 ]; then
    echo "no entry in $expectation" >&2
    exit 1
fi
