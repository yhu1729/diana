# Frama-C and Flocq boundary

## ACSL arithmetic

ACSL arithmetic on doubles is exact real arithmetic; rounded values are written with casts. The
bound `DBL_MAX/2 = (2^53 - 1) * 2^970` appears twice in `src/bisection.c`: `DIANA_BISECTION_MAX` for
C (an exact power-of-two scaling) and `DIANA_BISECTION_MAX_ACSL` as an exact integer expression,
because WP (Frama-C 33.0) rejects hexadecimal float literals in lemmas and mistranslates them in
predicates.

## Skip list

The midpoint-in-bracket fact is beyond the SMT float model, so the kernel computes the midpoint in
the static helper `bisection_mid`. `script/run_frama_c.sh` passes it to `-wp-skip-fct` (variable
`SKIP`), so WP assumes its contract (each `SKIP` entry is passed only for a source that names it,
because WP rejects an unknown function); Flocq proves it as BISECTION-B1 (`mid_in_bracket` in
`verification/rocq/theory/Float/Bisection.v`), and VST proves the C body against that model
(BISECTION-C1). `SKIP` is the explicit trust boundary between layer C-WP and layer B: every entry
needs a layer-B theorem.

## Bracket predicate

The ACSL predicate `bisection_bracket` is a strict sign change or a bracket collapsed onto an exact
root, the same as `SignChange` in the Lean and Rocq layer-A models. A weak sign change
(`fa * fb <= 0`) is not preserved by the sign test `(fx > 0) == (fa > 0)` when `fa == 0`.

## Goal count

`script/run_frama_c.sh [file...]` runs WP (float model, RTE, Alt-Ergo, 30 s timeout) over the given
kernels (default `src/bisection.c`). WP does not set a non-zero exit status for an unproved goal,
so the report must always be checked: `script/check_frama_c.sh` is the gate.
`verification/frama-c/expectation.txt` stores one `<source> <goal-count>` row per verified C
file, currently `src/bisection.c 162`, `src/euler.c 49`, `src/newton.c 101`, `src/simpson.c 58`
and `src/trapezoidal.c 41`; the source
path is the one WP runs
on and the one an ACSL theorem names in its `acsl` field.
`script/check_frama_c.sh report.txt [source]` fails unless every goal in the report is proved and, when a source is given, the goal count matches its row: a drop
means a contract or RTE guard silently disappeared. `script/verify_frama_c.sh` runs WP and this
check for every row, appending each WP output under a `==> <source> <==` header to the single
`verification/frama-c/report.txt` (CI uploads that one file); `script/dev.sh verify` and the
`verify_frama_c` CI job both call it, so CI and the local workflow check the same files. The count
also moves with the statement structure, not only with the annotations: WP checks an `assigns` clause in one part per write path, so adding
braces to `src/bisection.c` merged 12 `assigns_normal_part` goals (172 to 160) with every other goal
unchanged. Before changing `verification/frama-c/expectation.txt`, compare the goal lists of the old and
new source (`-wp-report-json`) and update the count only when no property kind disappeared.
