#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
expectation=verification/frama-c/expectation.txt
report=verification/frama-c/report.txt
jobs=$(script/job_count.sh)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/diana-frama-c.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
: >"$report"
count=0
while read -r source _ || [ -n "$source" ]; do
    [ -n "$source" ] || continue
    count=$((count + 1))
    echo "$source"
done <"$expectation" >"$tmp/row"
if [ "$count" -eq 0 ]; then
    echo "no entry in $expectation" >&2
    exit 1
fi
# WP runs 4 provers per row by default; keep about that many in flight over all
# the rows, so a row gets 4 provers alone and 1 when 4 or more rows run at once.
par=$(((4 + jobs - 1) / jobs))
echo "WP: $count rows, $jobs at a time, -wp-par $par"
# Longest rows first (goal count as the estimate), so the tail is short.
if [ "$jobs" -eq 1 ]; then
    cat "$tmp/row"
else
    sort -k2,2nr "$expectation" | cut -d' ' -f1 | grep .
fi |
    xargs -P "$jobs" -n 1 sh -c '
        out=$1/$(basename "$3" .c)
        script/run_frama_c.sh -wp-par "$2" "$3" >"$out.out" 2>&1 </dev/null
        echo $? >"$out.status"' sh "$tmp" "$par" || true
failed=0
while read -r source; do
    out="$tmp/$(basename "$source" .c)"
    {
        echo "==> $source <=="
        cat "$out.out" 2>/dev/null || echo "(no output)"
        echo
    } >>"$report"
done <"$tmp/row"
while read -r source; do
    out="$tmp/$(basename "$source" .c)"
    status=$(cat "$out.status" 2>/dev/null) || status=none
    if [ "$status" != 0 ]; then
        tail -n 20 "$out.out" 2>/dev/null >&2
        echo "Frama-C WP failed on $source (status $status); full output in $report" >&2
        failed=1
        continue
    fi
    printf '%s: ' "$source"
    if ! script/check_frama_c.sh "$out.out" "$source"; then
        echo "WP check failed on $source; full output in $report" >&2
        failed=1
    fi
done <"$tmp/row"
[ "$failed" -eq 0 ]
