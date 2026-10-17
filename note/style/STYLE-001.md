---
id: STYLE-001
title: Single-form nouns and base-form verbs in every name; Diana in prose
kind: rule
related: [CI-006, GIT-001]
---
Every name uses the singular noun and the base-form verb: directories (`test/`, `doc/`,
`script/`, `spec/`, `note/`), C identifiers (`diana_bisection_init`, `diana_fp_finite`), files and
scripts (`check_spec.py`, `run_frama_c.sh`), CI jobs (`build_gcc_debug`, `test_python`,
`verify_lean`), environment variables (`DIANA_JOB`, not `DIANA_JOBS`) and the Python API
(`diana.bisection`, `diana.rk4_step`). No plural and no `-ing` or `-s` verb form; the commit type
is `doc`, not `docs` (GIT-001).

The project is `Diana` in prose: headings, documentation sentences and user-facing strings
(`script/check_wheel.py` prints `Diana <version>: ...`). Lowercase `diana` appears only where it is
an identifier: the Python package, the CMake target and `diana::` namespace, the library file
`libdiana`, URLs, and the `diana_`/`DIANA_` prefixes.

Enforcement is partial. `style_name` rejects only six common plural directory names at depth two
or less (CI-006), and nothing checks identifiers or file names; the tracked `.git-hooks/` is a
plural directory no check catches.
