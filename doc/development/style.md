# Format and lint

| Tool | Applies to | Configuration | Checked by |
|---|---|---|---|
| `clang-format` (version pinned in the uv `lint` group) | C | `.clang-format`: LLVM style with braces always inserted | `script/dev.sh test`, CI `style_c` |
| `ruff` | Python | `[tool.ruff]` in `pyproject.toml`: 100 columns | `script/dev.sh test`, CI `style_python` |
| `clang-tidy` (optional, any recent LLVM) | C | `.clang-tidy`, with narrower files in `python/ext/` and `test/` | `script/dev.sh test` only |
| EditorConfig | every file | `.editorconfig`: indent per file type | your editor |

Format C before committing:

```bash
uv sync --group lint
git ls-files '*.c' '*.h' | xargs uv run clang-format -i
```

`clang-format` leaves ACSL annotations (`/*@ ... */`) alone, so those may exceed 80 columns. Every
`clang-tidy` suppression is a deliberate project convention, so a new finding is a real one; fix
it rather than suppress it. `script/dev.sh test` needs `build/compile_commands.json` from
`script/dev.sh config` for `clang-tidy`, including the entries of the Python extension.

The naming, file layout, comment and commit conventions are in `CONTRIBUTING.md`.

## Technical notes

[STYLE-005](../../note/style/STYLE-005.md) `clang-format` settings,
[STYLE-006](../../note/style/STYLE-006.md) EditorConfig,
[STYLE-007](../../note/style/STYLE-007.md) `clang-tidy` checks and suppressions,
[STYLE-008](../../note/style/STYLE-008.md) `clang-tidy` in `script/dev.sh`,
[STYLE-009](../../note/style/STYLE-009.md) `ruff`.
