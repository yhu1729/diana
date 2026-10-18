# Spec gate

Each method's theorems are listed in `spec/<method>.md`, and `script/check_spec.py` checks that
every one of them is proved. The YAML front matter of a spec names, for each theorem, an ID such
as `BISECTION-A1` (method, layer letter, number), its layer, an informal statement, and the
constant that proves it in Lean or Rocq or the ACSL contract that Frama-C proves. The prose below
the front matter explains the hypotheses and the proofs.

## Run it

| Command | Where | What it does |
|---|---|---|
| `uv run script/check_spec.py --no-report` | CI `style_python` | checks the spec files only |
| `uv run script/check_spec.py --run --strict` | `script/dev.sh verify` | runs both provers, checks axioms, rewrites the [report](report.md) |
| `script/check_spec.py --run --strict --prover lean --no-report` | CI `verify_lean` | the same for the Lean theorems only |

A full run checks that each named constant exists, contains no `sorry` or `Admitted`, and depends
only on the axioms in `script/axiom_allow.yaml`. With `--strict` it also fails when a listed theorem
is not proved and when an ACSL theorem has no Frama-C goal count in
`verification/frama-c/expectation.txt`. It does not run Frama-C itself
(`script/verify_frama_c.sh` does), and it does not check that a theorem's formal statement says
what its informal text says.

The report is rewritten only by a run of both provers, which needs the local opam switch, so it is
regenerated locally and committed; CI never rewrites it. Each rewrite stamps it with a hash of
`include/`, `spec/`, `src/` and `verification/`, of the allowed axioms and of the Frama-C script
with its `SKIP` list, and with the tool versions; CI's `verify_provenance` fails when the
committed stamp no longer matches them.

## Technical notes

[GATE-001](../../note/gate/GATE-001.md) spec front matter,
[GATE-002](../../note/gate/GATE-002.md) theorem IDs,
[GATE-004](../../note/gate/GATE-004.md) axiom parsing,
[GATE-006](../../note/gate/GATE-006.md) report regeneration,
[GATE-009](../../note/gate/GATE-009.md) the report stamp,
[GATE-007](../../note/gate/GATE-007.md) strict mode.
