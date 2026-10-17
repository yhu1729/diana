# Frama-C and Flocq boundary

## ACSL arithmetic

ACSL arithmetic on doubles is exact real arithmetic; rounded values are written with casts. The
bound `DBL_MAX/2 = (2^53 - 1) * 2^970` appears twice in the private header `src/bisection_mid.h`:
`DIANA_BISECTION_MAX` for C (an exact power-of-two scaling) and `DIANA_BISECTION_MAX_ACSL` as an
exact integer expression, because WP (Frama-C 33.0) rejects hexadecimal float literals in lemmas and
mistranslates them in predicates.

## Skip list

The midpoint-in-bracket fact is beyond the SMT float model, so the kernel computes the midpoint in
the helper `diana_bisection_mid`, alone in `src/bisection_mid.c`, with its contract (including
`terminates \true` and `exits \false`, which Frama-C would otherwise generate with a warning for a
function without a body) on the declaration in `src/bisection_mid.h`. `script/run_frama_c.sh` passes
it to `-wp-skip-fct` (variable `SKIP`) for the source that defines it, matched by a line that starts
with the return type in column 0, because WP rejects a function without a body there; the sources
that call it see only the declaration, so WP assumes its contract at every call, and
`src/bisection_mid.c` has no goal and no expectation row. Flocq proves it as BISECTION-B1
(`mid_in_bracket` in `verification/rocq/theory/Float/Bisection.v`), and VST proves the C body
against that model (BISECTION-C1). `SKIP` is the explicit trust boundary between layer C-WP and
layer B: every entry needs a layer-B theorem.

## Bracket predicate

The ACSL predicate `bisection_bracket` is a strict sign change or a bracket collapsed onto an exact
root, the same as `SignChange` in the Lean and Rocq layer-A models. A weak sign change
(`fa * fb <= 0`) is not preserved by the sign test `(fx > 0) == (fa > 0)` when `fa == 0`.

## Goal count

`script/run_frama_c.sh [file...]` runs WP (float model, RTE, Alt-Ergo, 30 s timeout) over the given
kernels (default `src/bisection_init.c`). WP does not set a non-zero exit status for an unproved
goal, so the report must always be checked: `script/check_frama_c.sh` is the gate.
`verification/frama-c/expectation.txt` stores one `<source> <goal-count>` row per verified C file,
currently `src/bisection_init.c 84`, `src/bisection_result.c 19`, `src/bisection_step.c 71`,
`src/euler.c 49`, `src/euler_step_unchecked.c 19`, `src/newton_init.c 36`, `src/newton_result.c 13`,
`src/newton_step.c 66`, `src/rk4_stage.c 53`, `src/rk4_stage_unchecked.c 21`, `src/rk4_step.c 57`,
`src/rk4_step_unchecked.c 22`, `src/simpson.c 58` and `src/trapezoidal.c 41`; the source path is the
one WP runs on and the one an ACSL theorem names in its `acsl` field. `script/check_frama_c.sh
report.txt [source]` fails unless every goal in the report is proved and, when a source is given,
the goal count matches its row: a drop means a contract or RTE guard silently disappeared.
`script/verify_frama_c.sh` runs WP and this check for every row, appending each WP output under a
`==> <source> <==` header to the single `verification/frama-c/report.txt` (CI uploads that one
file); `script/dev.sh verify` and the `verify_frama_c` CI job both call it, so CI and the local
workflow check the same files. The count also moves with the statement structure, not only with the
annotations: WP checks an `assigns` clause in one part per write path, so adding braces to the then
single `src/bisection.c` merged 12 `assigns_normal_part` goals (172 to 160) with every other goal
unchanged. Splitting `src/bisection.c`, `src/newton.c` and `src/rk4.c` into one file per function
raised their totals from 162, 103 and 98 to 174, 115 and 110 with no property kind lost: WP proves
the `static inline` helpers of `src/fp.h` in every source that includes them, so their goals now
appear once per file. Before changing `verification/frama-c/expectation.txt`, compare the goal lists
of the old and new source (`-wp-report-json`) and update the count only when no property kind
disappeared.
