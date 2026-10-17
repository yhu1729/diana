---
id: STYLE-003
title: Where text goes, doc/ for people, note/ for detail, spec/ for theorems
kind: rule
path:
  - note/README.md
  - doc/README.md
  - script/check_doc.py
related: [STYLE-004, GATE-001, TEST-003, CI-007]
---
Keep in-code comments to a minimum and put each piece of text where its reader looks:

- `doc/`: short prose for human developers (what and why, with examples), indexed by
  `doc/README.md`: `doc/api/` (an overview and one page per method), `doc/development/`,
  `doc/verification/`, `doc/third-party.md` and `doc/roadmap.md` (STYLE-004). Each page ends with
  links to its notes.
- `note/<topic>/<ID>.md`: one technical fact, rule, procedure or rationale per file (evaluation
  and check order, theorem coverage, tool quirks, CI internals, test-value derivations), with the
  front matter that `note/README.md` defines, so an agent finds it by path or ID.
- `spec/<method>.md`: the method's theorem list (IDs, layer, informal statement, prover constant
  names; GATE-001) and its proof notes.
- Code: ACSL `/*@ ... */` annotations are code, not comments; Python docstrings and CPython
  `tp_doc`/`ml_doc` strings are runtime API and stay. The commit log carries no rationale.

`doc/api/` examples are executed: a `c` block is a clang-format-clean program followed by a
`text` block with its output, a `python` block a doctest session (TEST-003).

`script/check_doc.py` checks the note side: front matter keys and values, `id` equal to the file
stem with its directory's prefix, every `path` matching a file, every `related` ID and every note ID
cited in `README.md`, `CONTRIBUTING.md`, `CLAUDE.md`, `doc/`, `note/` or `spec/` existing, the
generated index of `note/README.md` being current (`--write` regenerates it), and every relative
Markdown link and heading anchor resolving. `script/dev.sh test` and CI `style_python` run it
(CI-007).
