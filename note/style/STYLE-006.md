---
id: STYLE-006
title: EditorConfig sets indentation per file type and no C line limit
kind: fact
path:
  - .editorconfig
related: [STYLE-005, STYLE-009]
---
`.editorconfig` (`root = true`) gives every file UTF-8, LF line ends, a final newline, trimmed
trailing whitespace and space indentation, then per file type:

- 2 spaces: C (`*.{c,h}`), Rocq (`*.v`), Lean (`*.lean`), YAML (`*.{yml,yaml}`), Markdown;
- 4 spaces: Python (with `max_line_length = 100`, as in ruff), shell (`*.sh`), CMake (`*.cmake`,
  `CMakeLists.txt`, `*.cmake.in`), TOML;
- tabs: `Makefile`;
- Markdown keeps trailing whitespace (`trim_trailing_whitespace = false`).

C has no `max_line_length`: clang-format wraps code at 80 columns but leaves ACSL annotations as
written (STYLE-005), and some contract lines in `src/` are longer. Nothing checks EditorConfig,
neither `script/dev.sh` nor CI, although `.change_style_c` and `.change_any` list
`.editorconfig`; it only guides editors.
