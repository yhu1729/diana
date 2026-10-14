#!/bin/sh
set -eu
report="$1"
expected="${2:-}"
if ! grep -qE "^\[wp\] Proved goals:" "$report"; then
    echo "no WP summary in $report" >&2
    exit 1
fi
summary=$(grep -E "^\[wp\] Proved goals:" "$report" | tail -1)
proved=$(echo "$summary" | sed -E 's/.*Proved goals: *([0-9]+) *\/ *([0-9]+).*/\1/')
total=$(echo "$summary" | sed -E 's/.*Proved goals: *([0-9]+) *\/ *([0-9]+).*/\2/')
echo "$summary"
if [ "$proved" != "$total" ]; then
    echo "WP: $proved of $total goals proved" >&2
    exit 1
fi
if [ -n "$expected" ]; then
    want=$(sed -E 's/.*Proved goals: *([0-9]+) *\/ *([0-9]+).*/\2/' "$expected")
    if [ "$total" != "$want" ]; then
        echo "WP: $total goals, expected $want (update $expected if intended)" >&2
        exit 1
    fi
fi
