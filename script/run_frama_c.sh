#!/bin/sh
SKIP="diana_bisection_mid diana_fp_sqrt"
set -eu
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then
    set -- src/bisection_init.c
fi
files=
for arg in "$@"; do
    if [ -f "$arg" ]; then
        files="$files $arg"
    else
        case "$arg" in
        -*) ;;
        *.c | *.h | *.i)
            echo "error: source file $arg does not exist" >&2
            exit 1
            ;;
        esac
    fi
done
if [ -z "$files" ]; then
    echo "error: no source file among the arguments" >&2
    exit 1
fi
row=${files# }
row=$(basename "${row%% *}" .c)
metrics=$(frama-c -cpp-extra-args="-Iinclude -Isrc" -metrics $files 2>&1) || {
    echo "$metrics" >&2
    echo "error: frama-c -metrics failed" >&2
    exit 1
}
called_in_section() {
    echo "$metrics" | awk -v section="$1" '
        function bad() { failed = 1; exit 1 }
        function count_of(line,    at, rest) {
            at = index(line, section " (")
            if (at == 0 || substr(line, 1, at - 1) !~ /^[ \t]*(\[metrics\][ \t]*)?$/) return -1
            rest = substr(line, at + length(section) + 2)
            if (rest !~ /^[0-9]+\)[ \t]*$/) return -1
            sub(/\).*/, "", rest)
            return rest + 0
        }
        state == 0 { if ((count = count_of($0)) >= 0) state = 1; next }
        state == 1 { if ($0 !~ /^[ \t]*=+[ \t]*$/) bad(); state = 2; next }
        state == 2 && NF == 0 { state = 3; next }
        state == 2 {
            for (i = 1; i <= NF; i += 3) {
                if ($i !~ /^[A-Za-z_][A-Za-z0-9_]*$/ || $(i + 1) !~ /^\([0-9]+$/ ||
                    $(i + 2) !~ /^calls?\);$/) bad()
                listed++
                if ($(i + 1) != "(0") print $i
            }
            next
        }
        state == 3 && count_of($0) >= 0 { bad() }
        END { if (failed || state != 3 || listed != count) exit 1 }'
}
metrics_unreadable() {
    echo "error: cannot read the section \"$1\" of the frama-c -metrics report, so the" \
        "SKIP check cannot run; has its format changed?" >&2
    exit 1
}
undefined=$(called_in_section "Undefined and unspecified functions") ||
    metrics_unreadable "Undefined and unspecified functions"
for name in $undefined; do
    echo "error: $name is called without a body or a contract, so WP would assume a generated" \
        "contract for it" >&2
    exit 1
done
assumed=$(called_in_section "Specified-only functions") ||
    metrics_unreadable "Specified-only functions"
for name in $assumed; do
    case " $SKIP " in
    *" $name "*) ;;
    *)
        echo "error: WP would assume the contract of $name, which is called without a body" \
            "and is not in SKIP" >&2
        exit 1
        ;;
    esac
done
skip=
for name in $SKIP; do
    for arg in "$@"; do
        if [ -f "$arg" ] && grep -Eq "^[A-Za-z_][A-Za-z0-9_ *]*[^A-Za-z0-9_]$name[[:space:]]*\(" "$arg"; then
            skip="${skip:+$skip,}$name"
            break
        fi
    done
done
if [ -n "$skip" ]; then
    set -- -wp-skip-fct "$skip" "$@"
fi
mkdir -p "verification/frama-c/session/$row" "verification/frama-c/cache/$row"
exec frama-c \
    -cpp-extra-args="-Iinclude -Isrc" \
    -warn-special-float none \
    -wp -wp-rte -wp-model "+float" \
    -wp-prover alt-ergo \
    -wp-timeout 30 \
    -wp-session "verification/frama-c/session/$row" -wp-cache update \
    -wp-cache-dir "verification/frama-c/cache/$row" \
    -wp-status \
    "$@"
