import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]


def load_module(monkeypatch, name="diana_test_ci_change"):
    spec = importlib.util.spec_from_file_location(name, ROOT / "script" / "ci_change.py")
    module = importlib.util.module_from_spec(spec)
    monkeypatch.setitem(sys.modules, spec.name, module)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def cc(monkeypatch):
    return load_module(monkeypatch)


def test_lists_of_the_real_gitlab_file(cc):
    lists = cc.change_lists((ROOT / ".gitlab-ci.yml").read_text())
    assert set(lists) == {
        "c",
        "python",
        "style",
        "style_c",
        "any",
        "frama_c",
        "lean",
        "rocq",
        "provenance",
    }
    assert all(".gitlab-ci.yml" in patterns for patterns in lists.values())
    assert "script/run_frama_c.sh" in lists["frama_c"]


def test_list_ends_at_the_next_key(cc):
    text = ".change_a: &change_a\n  - x\n  - y/**/*\n\nother:\n  - z\n.change_b: &change_b\n  - w\n"
    assert cc.change_lists(text) == {"a": ["x", "y/**/*"], "b": ["w"]}


@pytest.mark.parametrize(
    ("pattern", "path", "match"),
    [
        ("doc/**/*", "doc/a.md", True),
        ("doc/**/*", "doc/api/a.md", True),
        ("doc/**/*", "docs/a.md", False),
        ("doc/**/*", "doc", False),
        ("note/**/*", "note/ci/.hidden", True),
        ("verification/**/*", "verification/rocq/theory/VST/LU.v", True),
        (".gitlab-ci.yml", ".gitlab-ci.yml", True),
        (".gitlab-ci.yml", "x/.gitlab-ci.yml", False),
        ("script/check_spec.py", "script/check_spec.pyc", False),
        ("src/*.c", "src/lu.c", True),
        ("src/*.c", "src/sub/lu.c", False),
        ("cmake/**/*", "cmake/symbol.txt", True),
    ],
)
def test_glob(cc, pattern, path, match):
    assert bool(cc.glob_regex(pattern).match(path)) is match


def test_selected(cc):
    lists = {"c": ["src/**/*"], "doc": ["doc/**/*"]}
    assert cc.selected(lists, ["src/lu.c"]) == {"c": True, "doc": False}
    assert cc.selected(lists, []) == {"c": False, "doc": False}
    assert cc.selected(lists, None) == {"c": True, "doc": True}
    assert cc.selected(lists, [".github/workflows/ci.yml"]) == {"c": True, "doc": True}
    assert cc.selected(lists, ["script/ci_change.py"]) == {"c": True, "doc": True}


@pytest.mark.parametrize(
    ("event", "ref"),
    [("workflow_dispatch", "refs/heads/main"), ("push", "refs/tags/v1.0.0")],
)
def test_everything_runs_without_a_push_range(cc, event, ref):
    assert cc.changed_files(event, ref, "", "HEAD", "main") is None


def init_repo(tmp_path):
    def run(*args):
        return subprocess.run(
            ["git", *args], cwd=tmp_path, check=True, capture_output=True, text=True
        ).stdout.strip()

    run("init", "-q", "-b", "main")
    run("config", "user.email", "t@example.com")
    run("config", "user.name", "t")
    (tmp_path / "a.txt").write_text("a\n")
    run("add", "a.txt")
    run("commit", "-q", "-m", "a")
    first = run("rev-parse", "HEAD")
    (tmp_path / "src").mkdir()
    (tmp_path / "src" / "lu.c").write_text("int x;\n")
    run("add", "src/lu.c")
    run("commit", "-q", "-m", "b")
    return run, first, run("rev-parse", "HEAD")


def test_push_range(cc, tmp_path, monkeypatch):
    run, first, second = init_repo(tmp_path)
    monkeypatch.setattr(cc, "ROOT", tmp_path)
    assert cc.changed_files("push", "refs/heads/main", first, second, "") == ["src/lu.c"]
    # a new branch (before all zeros) compares with the default branch it forked from
    run("update-ref", "refs/remotes/origin/main", first)
    assert cc.changed_files("push", "refs/heads/x", "0" * 40, second, "main") == ["src/lu.c"]
    # an unknown old head (a force push) also falls back to the default branch
    assert cc.changed_files("push", "refs/heads/x", "1" * 40, second, "main") == ["src/lu.c"]
    # with neither, every job runs
    assert cc.changed_files("push", "refs/heads/x", "0" * 40, second, "") is None


def test_main_prints_one_line_per_list(cc, capsys):
    assert cc.main(["--event", "workflow_dispatch"]) == 0
    lines = capsys.readouterr().out.splitlines()
    assert "c=true" in lines and "provenance=true" in lines
    assert all(line.endswith("=true") for line in lines)
