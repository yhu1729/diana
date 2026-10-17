import importlib.util
import sys
from pathlib import Path

import pytest

INDEX_HEAD = """# Note

| Directory | Covers |
|---|---|
| `api/` | public API |

"""


def load_module(monkeypatch, name="diana_test_check_doc"):
    path = Path(__file__).resolve().parents[2] / "script" / "check_doc.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    monkeypatch.setitem(sys.modules, spec.name, module)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def doc(tmp_path, monkeypatch):
    module = load_module(monkeypatch)
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setattr(module, "NOTE_DIR", tmp_path / "note")
    monkeypatch.setattr(module, "INDEX", tmp_path / "note" / "README.md")
    (tmp_path / "note" / "api").mkdir(parents=True)
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "kernel.c").write_text("int kernel(void);\n")
    (tmp_path / "note" / "README.md").write_text(INDEX_HEAD + module.INDEX_MARKER + "\n")
    write_note(tmp_path, "API-001", path=["src/kernel.c"])
    return module


def write_note(root, nid, *, kind="fact", path=(), related=(), body="The kernel adds.\n"):
    topic = nid.split("-")[0].lower()
    lines = ["---", f"id: {nid}", f"title: Note {nid}", f"kind: {kind}"]
    if path:
        lines += ["path:", *(f"  - {p}" for p in path)]
    if related:
        lines.append(f"related: [{', '.join(related)}]")
    (root / "note" / topic / f"{nid}.md").write_text("\n".join([*lines, "---", body]))


def run(doc, monkeypatch, *args):
    monkeypatch.setattr(sys, "argv", ["check_doc.py", *args])
    return doc.main()


def test_write_then_check(doc, monkeypatch, capsys):
    assert run(doc, monkeypatch) == 1
    assert "index is stale" in capsys.readouterr().err
    assert run(doc, monkeypatch, "--write") == 0
    index = doc.INDEX.read_text()
    assert "| [API-001](api/API-001.md) | fact | Note API-001 |" in index
    assert "| `src/kernel.c` | API-001 |" in index
    assert run(doc, monkeypatch) == 0


def test_id_must_match_file_and_topic(doc, monkeypatch, capsys):
    note = doc.NOTE_DIR / "api" / "API-001.md"
    note.write_text(note.read_text().replace("id: API-001", "id: API-002"))
    (doc.NOTE_DIR / "api" / "WP-001.md").write_text(
        "---\nid: WP-001\ntitle: t\nkind: rule\n---\nbody\n"
    )
    assert run(doc, monkeypatch, "--write") == 1
    err = capsys.readouterr().err
    assert "must equal the file stem" in err
    assert "id prefix must be 'API'" in err


@pytest.mark.parametrize(
    ("change", "message"),
    [
        ({"kind": "note"}, "'kind' must be one of"),
        ({"path": ["src/missing.c"]}, "matches no file"),
        ({"path": ["../outside.c"]}, "relative to the repository root"),
        ({"related": ["API-009"]}, "related 'API-009' does not exist"),
        ({"body": ""}, "empty body"),
    ],
)
def test_bad_front_matter(doc, monkeypatch, capsys, change, message):
    write_note(doc.ROOT, "API-002", **change)
    assert run(doc, monkeypatch, "--write") == 1
    assert message in capsys.readouterr().err


def test_unknown_key(doc, monkeypatch, capsys):
    (doc.NOTE_DIR / "api" / "API-002.md").write_text(
        "---\nid: API-002\ntitle: t\nkind: fact\ntag: [x]\n---\nbody\n"
    )
    assert run(doc, monkeypatch, "--write") == 1
    assert "unknown key tag" in capsys.readouterr().err


def test_undescribed_topic(doc, monkeypatch, capsys):
    (doc.NOTE_DIR / "wp").mkdir()
    write_note(doc.ROOT, "WP-001")
    assert run(doc, monkeypatch, "--write") == 1
    assert "topic `wp/` is not described" in capsys.readouterr().err


def test_note_reference(doc, monkeypatch, capsys):
    (doc.ROOT / "doc").mkdir()
    (doc.ROOT / "doc" / "page.md").write_text("See API-001 and API-007.\n")
    assert run(doc, monkeypatch, "--write") == 1
    err = capsys.readouterr().err
    assert "note 'API-007' does not exist" in err
    assert "API-001'" not in err


def test_link(doc, monkeypatch, capsys):
    (doc.ROOT / "doc").mkdir()
    (doc.ROOT / "doc" / "other.md").write_text("# Other page\n\n## Array `y` (C)\n")
    (doc.ROOT / "doc" / "page.md").write_text(
        "# Page\n\n"
        "[ok](other.md#array-y-c) [self](#page) [web](https://example.org/x.md)\n"
        "[file](missing.md) [heading](other.md#nothing)\n"
        "`[code](missing.md)`\n\n"
        "```\n[fenced](missing.md)\n```\n"
    )
    assert run(doc, monkeypatch, "--write") == 1
    err = capsys.readouterr().err
    assert err.count("doc/page.md") == 2
    assert "link 'missing.md' points to a missing file" in err
    assert "link 'other.md#nothing' points to a missing heading" in err


def test_duplicate_heading_anchor(doc):
    page = doc.ROOT / "page.md"
    page.write_text("# A\n\n## Python\n\n## Python\n")
    assert doc.anchor_set(page) == {"a", "python", "python-1"}
