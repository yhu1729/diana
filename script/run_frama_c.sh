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
    fi
done
row=${files# }
row=$(basename "${row%% *}" .c)
metrics=$(frama-c -cpp-extra-args="-Iinclude -Isrc" -metrics $files 2>&1)
called_in_section() {
    echo "$metrics" |
        awk -v section="$1" 'index($0, section) { on = 1; next }
             on && /functions \(|global variables \(/ { on = 0 }
             on { for (i = 1; i < NF; i++) if ($(i + 1) ~ /^\(/ && $(i + 1) != "(0") print $i }'
}
for name in $(called_in_section "Undefined and unspecified functions"); do
    echo "error: $name is called without a body or a contract, so WP would assume a generated" \
        "contract for it" >&2
    exit 1
done
assumed=$(called_in_section "Specified-only functions")
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
# Make the row's directories before WP does: its own mkdir of a missing parent
# races with the rows started at the same time and fails the goal instead.
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
