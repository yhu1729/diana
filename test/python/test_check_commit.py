import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "script" / "check_commit.sh"

pytestmark = pytest.mark.skipif(
    shutil.which("git") is None or shutil.which("sh") is None, reason="git or sh is not installed"
)


@pytest.fixture
def repo(tmp_path):
    """A repository holding a copy of the script, so its `cd` lands in the test repository."""
    (tmp_path / "script").mkdir()
    shutil.copy(SCRIPT, tmp_path / "script" / "check_commit.sh")
    env = {
        **os.environ,
        "GIT_AUTHOR_DATE": "2026-01-01T00:00:00+0000",
        "GIT_COMMITTER_DATE": "2026-01-01T00:00:00+0000",
    }
    env.pop("CI", None)

    def git(*args):
        return subprocess.run(
            ["git", *args], cwd=tmp_path, env=env, check=True, capture_output=True, text=True
        ).stdout.strip()

    git("init", "-q", "-b", "main")
    git("config", "user.email", "t@example.com")
    git("config", "user.name", "t")
    (tmp_path / "a.txt").write_text("a\n")
    git("add", "a.txt")
    git("commit", "-q", "-s", "-m", "feat: add file")

    def check(*args):
        return subprocess.run(
            ["sh", "script/check_commit.sh", *args],
            cwd=tmp_path,
            env=env,
            capture_output=True,
            text=True,
        )

    return git, check


def test_good_commit_passes(repo):
    _, check = repo
    proc = check("HEAD")
    assert proc.returncode == 0, proc.stderr
    assert proc.stdout.splitlines() == ["checking HEAD", "1 commit(s) checked"]


def test_bad_commit_fails(repo, tmp_path):
    git, check = repo
    (tmp_path / "b.txt").write_text("b\n")
    git("add", "b.txt")
    git("commit", "-q", "-m", "add the file")
    proc = check("HEAD")
    assert proc.returncode == 1
    reasons = [line.split(": ", 1)[1] for line in proc.stderr.splitlines()]
    assert len(reasons) == 3
    assert reasons[0].startswith("subject must be <type>[(scope)]: <summary>")
    assert reasons[1] == "subject contains an article (a, an, the)"
    assert reasons[2].startswith("message must be the subject and one")
    assert "2 commit(s) checked" in proc.stdout


def test_git_failure_fails(repo):
    _, check = repo
    proc = check("nonexistent..HEAD")
    assert proc.returncode != 0
    assert "commit(s) checked" not in proc.stdout
    assert "nonexistent" in proc.stderr
