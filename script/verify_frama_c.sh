#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
expectation=verification/frama-c/expectation.txt
count=0
while read -r source _ || [ -n "$source" ]; do
    [ -n "$source" ] || continue
    count=$((count + 1))
    report=verification/frama-c/report-$(basename "$source" .c).txt
    if ! script/run_frama_c.sh "$source" >"$report" 2>&1 </dev/null; then
        tail -n 20 "$report" >&2
        echo "Frama-C WP failed on $source; full output in $report" >&2
        exit 1
    fi
    script/check_frama_c.sh "$report" "$source"
done <"$expectation"
if [ "$count" -eq 0 ]; then
    echo "no entry in $expectation" >&2
    exit 1
fi
