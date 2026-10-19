#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ "$#" -eq 0 ]; then
    head=${CI_MERGE_REQUEST_SOURCE_BRANCH_SHA:-${CI_COMMIT_SHA:-HEAD}}
    case "${CI_COMMIT_BEFORE_SHA:-0}" in
    *[!0]*) base=$CI_COMMIT_BEFORE_SHA ;;
    *) base=${CI_MERGE_REQUEST_DIFF_BASE_SHA:-} ;;
    esac
    if [ -z "${CI:-}" ] && [ -z "$base" ]; then
        base=$(git rev-parse -q --verify '@{upstream}' 2>/dev/null || true)
    fi
    if [ -n "$base" ] && git cat-file -e "$base^{commit}" 2>/dev/null; then
        set -- "$base..$head"
    else
        set -- "$head"
    fi
fi
echo "checking $*"
log=$(mktemp "${TMPDIR:-/tmp}/diana-commit.XXXXXX")
trap 'rm -f "$log"' EXIT
git log --reverse --format='%x1e%h%x1f%at%x1f%ct%x1f%cn <%ce>%x1f%P%x1f%B' "$@" > "$log"
awk '
    BEGIN { RS = "\036"; FS = "\037"; max_subject = 50 }
    function fail(reason) {
        print hash " " subject ": " reason > "/dev/stderr"
        status = 1
    }
    NF == 0 { next }
    {
        count++
        hash = $1
        n = split($6, line, "\n")
        subject = line[1]
        rest = ""
        for (i = 3; i <= n; i++)
            if (line[i] !~ /^[[:space:]]*$/)
                rest = rest (rest == "" ? "" : "\n") line[i]
        if (split($5, parent, " ") > 1)
            fail("merge commit; rebase instead of merging")
        if (subject !~ /^(feat|fix|perf|refactor|build|style|test|ci|doc|chore)(\([^)]*\))?: [^ ].*$/)
            fail("subject must be <type>[(scope)]: <summary> with a type from feat fix perf refactor build style test ci doc chore")
        if (length(subject) > max_subject)
            fail("subject is " length(subject) " characters, more than " max_subject)
        summary = subject
        sub(/^[^:]*: /, "", summary)
        if (summary ~ /(^| )(a|an|the)( |$)/)
            fail("subject contains an article (a, an, the)")
        if ((n >= 2 && line[2] !~ /^[[:space:]]*$/) || rest != "Signed-off-by: " $4)
            fail("message must be the subject and one \"Signed-off-by: " $4 "\" trailer, with no body or other trailer")
        if ($2 != $3)
            fail("author date differs from commit date (amended or replayed); recreate the commit fresh")
    }
    END {
        print count + 0 " commit(s) checked"
        exit status
    }
' "$log"
