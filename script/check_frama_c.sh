#!/bin/sh
set -eu
report="$1"
kernel="${2:-}"
expectation="$(dirname "$0")/../verification/frama-c/expectation.txt"
summary=$(grep -E '^\[wp\] Proved goals:' "$report" | tail -1)
if ! echo "$summary" | grep -qE '^\[wp\] Proved goals: *[0-9]+ */ *[0-9]+ *$'; then
    echo "no WP summary in $report" >&2
    exit 1
fi
proved=$(echo "$summary" | sed -E 's/.*Proved goals: *([0-9]+) *\/ *([0-9]+).*/\1/')
total=$(echo "$summary" | sed -E 's/.*Proved goals: *([0-9]+) *\/ *([0-9]+).*/\2/')
echo "$summary"
if [ "$proved" != "$total" ]; then
    echo "WP: $proved of $total goals proved" >&2
    exit 1
fi
if [ -n "$kernel" ]; then
    if ! want=$(awk -v kernel="$kernel" '
        $1 == kernel {
            count++
            if (NF != 2 || $2 !~ /^[1-9][0-9]*$/) invalid = 1
            goals = $2
        }
        END {
            if (count != 1 || invalid) exit 1
            print goals
        }
    ' "$expectation"); then
        echo "WP: missing, duplicate, or invalid entry for $kernel in $expectation" >&2
        exit 1
    fi
    if [ "$total" != "$want" ]; then
        echo "WP: $total goals, expected $want (update $expectation if intended)" >&2
        exit 1
    fi
fi
