# Frama-C and Flocq boundary

## ACSL arithmetic

ACSL arithmetic on doubles is exact real arithmetic; rounded values are written with casts. The
bound `DBL_MAX/2 = (2^53 - 1) * 2^970` appears twice in the private header `src/bisection_mid.h`:
`DIANA_BISECTION_MAX` for C (an exact power-of-two scaling) and `DIANA_BISECTION_MAX_ACSL` as an
exact integer expression, because WP (Frama-C 32.1, and 33.0 too) rejects hexadecimal float
literals in lemmas and mistranslates them in predicates.

## Skip list

The midpoint-in-bracket fact is beyond the SMT float model, so the kernel computes the midpoint in
the helper `diana_bisection_mid`, alone in `src/bisection_mid.c`, with its contract (including
`terminates \true` and `exits \false`, which Frama-C would otherwise generate with a warning for a
function without a body) on the declaration in `src/bisection_mid.h`. The sources that call it see
only the declaration, so WP assumes its contract at every call, and `src/bisection_mid.c` has no
goal and no expectation row. Flocq proves it as BISECTION-B1 (`mid_in_bracket` in
`verification/rocq/theory/Float/Bisection.v`), and VST proves the C body against that model
(BISECTION-C1).

`SKIP` in `script/run_frama_c.sh` lists the functions whose contracts WP may assume this way, and
the script enforces it: before WP it runs Frama-C's metrics plugin on the same sources and fails if
a called function with a contract but no body ("Specified-only functions") is not in `SKIP`, or
if any called function has neither body nor contract ("Undefined and unspecified functions"),
for which WP would generate and assume a contract; no `SKIP` entry can allow that case. It
also passes a `SKIP` entry to `-wp-skip-fct` for a source that defines it, matched by a line that
starts with the return type in column 0, since WP rejects that option for a function without a
body. `SKIP` is the explicit trust boundary between layer C-WP and layer B: every entry needs a
layer-B theorem, and no other contract can be assumed without failing the run.

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
`src/euler_step.c 49`, `src/euler_step_unchecked.c 19`, `src/newton_init.c 36`, `src/newton_result.c 13`,
`src/newton_step.c 66`, `src/rk4_stage.c 53`, `src/rk4_stage_unchecked.c 21`, `src/rk4_step.c 57`,
`src/rk4_step_unchecked.c 22`, `src/simpson.c 58` and `src/trapezoidal.c 41`; the source path is the
one WP runs on and the one an ACSL theorem names in its `acsl` field. `script/check_frama_c.sh
report.txt [source]` fails unless every goal in the report is proved and, when a source is given,
the goal count matches its row: a drop means a contract or RTE guard silently disappeared.
`script/verify_frama_c.sh` runs WP and this check for every row, writing each WP output under a
`==> <source> <==` header to the single `verification/frama-c/report.txt`, in the order of the
rows (CI uploads that one file); `script/dev.sh verify` and the `verify_frama_c` CI job both call
it, so CI and the local workflow check the same files. It runs `DIANA_JOB` rows at a time
(`script/job_count.sh`: the variable, else the CPU count; `1` is the sequential loop), the rows
with the most goals first, and gives each row `-wp-par ceil(4 / DIANA_JOB)` provers so that about
the default four Alt-Ergo processes of one row are in flight over all the rows; each goal's
verdict is independent of this scheduling, and `why3server` enforces the 30 s limit as CPU time
(`setrlimit`), so sharing a core cannot turn a proved goal into a timeout. The rows finish in any
order, so the `<source>: [wp] Proved goals` lines and the checks come after the last row, every
row is checked even when an earlier one failed, and the exit status is the conjunction.

## Session and cache per row

`script/run_frama_c.sh` names a row after its first source file (`bisection_init` for
`src/bisection_init.c`), creates `verification/frama-c/session/<row>` and
`verification/frama-c/cache/<row>` and passes them as `-wp-session` and `-wp-cache-dir`
(`-wp-cache update`), so rows running at once share no WP directory, and a row's cache stays warm
across runs because the same source always maps to the same directory (both trees are ignored by
git). WP's own creation of a missing cache directory is not safe between processes: when
`verification/frama-c/cache` did not exist and several rows started together, goals in every row
failed with `[Why3 Error] anomaly: Sys_error("No such file or directory")`, and WP 32.1 stores
that `Failed` verdict in the cache like any other, so the next run replayed it as `(Cached)`
failures until the row's cache directory was deleted. The `mkdir -p` in the script makes every
directory before its WP process starts, which is what removed the failure; with it, the
fourteen rows started ten at a time prove every goal from an empty cache. A `Failed` goal whose message is a Why3 anomaly rather than a
prover answer is therefore an environment problem: remove `verification/frama-c/cache/<row>` and
rerun the row alone. The goals of one source are never those of another (the `src/fp.h` helpers
are proved once per file, under each file's own cache), so the per-row caches lose no hits.
