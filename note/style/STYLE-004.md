---
id: STYLE-004
title: Update CHANGELOG, CLAUDE.md and notes with the change; roadmap one line per idea
kind: rule
path:
  - CHANGELOG.md
  - CLAUDE.md
  - doc/roadmap.md
related: [STYLE-003, GIT-005]
---
A change updates the living documents it affects in the same commit:

- `CHANGELOG.md`: an entry under `## [Unreleased]` for every user-visible change, in Keep a
  Changelog 1.1.0 form (`### Added`, `### Changed`, `### Removed`, `### Fixed`; the unreleased
  `Added` is split into `#### C library`, `#### Python binding`, `#### Verification` and
  `#### Tests and tooling`). A release becomes `## [X.Y.Z] - YYYY-MM-DD`; the release job's
  description points here.
- `CLAUDE.md`, the condensed convention sheet, when the change alters a fact it records
  (convention, toolchain pin, layout, command, status).
- The affected `doc/` page and every note the change makes wrong (`note/README.md`, Maintain).

`doc/roadmap.md` is the only place for future work: one line per idea, under a release section
(`Toward 1.1`, `Toward 1.2`, ..., `Toward 2.0`, ...), each starting with a priority `high`,
`medium` or `low` as defined at its top. An entry is a candidate, not a commitment or a design: a
design is written only when someone picks the item up, so the roadmap holds no plans, sub-bullets
or design text.
Done work is recorded in `CHANGELOG.md`, not in the roadmap.
