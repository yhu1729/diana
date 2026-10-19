#!/usr/bin/env python3
"""GitHub Actions job selection from the GitLab path lists in .gitlab-ci.yml.

Prints one ``<list>=true|false`` line per ``.change_<list>`` anchor of ``.gitlab-ci.yml``, for
``$GITHUB_OUTPUT``. Every list is true for a tag push, a manual run, a change to the CI definition
itself, or a push whose base cannot be found; otherwise a list is true when a file changed since
the base matches one of its patterns, with GitLab's ``rules:changes`` glob semantics. The base is
the previous head of a push to the default branch, whose runs are never cancelled, and the merge
base with the default branch for any other branch, so that a run which supersedes a cancelled one
covers the cancelled run's changes too.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GITLAB_CI = ROOT / ".gitlab-ci.yml"
# A change to any of these runs every list, as .gitlab-ci.yml is in every GitLab list.
CI_DEFINITION = (
    ".gitlab-ci.yml",
    ".github/workflows/ci.yml",
    ".github/workflows/c_test.yml",
    "script/ci_change.py",
)
ZERO = re.compile(r"^0*$")


def change_lists(text: str) -> dict[str, list[str]]:
    """The ``.change_<name>`` anchors of a GitLab CI file and their patterns, in file order."""
    lists: dict[str, list[str]] = {}
    current = None
    for line in text.splitlines():
        head = re.match(r"^\.change_([a-z0-9_]+):\s*&change_[a-z0-9_]+\s*$", line)
        if head:
            current = lists.setdefault(head.group(1), [])
            continue
        item = re.match(r"^\s+-\s+(\S+)\s*$", line)
        if current is not None and item:
            current.append(item.group(1))
            continue
        if line.strip():
            current = None
    return lists


def glob_regex(pattern: str) -> re.Pattern[str]:
    """GitLab ``rules:changes`` glob (``File.fnmatch`` with ``FNM_PATHNAME | FNM_DOTMATCH``)."""
    out = []
    i = 0
    while i < len(pattern):
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif pattern.startswith("**", i):
            out.append(".*")
            i += 2
        elif pattern[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pattern[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile("".join(out) + r"\Z")


def selected(lists: dict[str, list[str]], changed: list[str] | None) -> dict[str, bool]:
    """Each list's verdict; ``changed`` None means the change set is unknown, so run everything."""
    if changed is None or any(path in CI_DEFINITION for path in changed):
        return dict.fromkeys(lists, True)
    return {
        name: any(glob_regex(p).match(path) for p in patterns for path in changed)
        for name, patterns in lists.items()
    }


def git(*args: str) -> str | None:
    proc = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    return proc.stdout.strip() if proc.returncode == 0 else None


def changed_files(
    event: str, ref: str, before: str, sha: str, default_branch: str
) -> list[str] | None:
    """The files changed by the push, or None when every job runs."""
    if event != "push" or ref.startswith("refs/tags/"):
        return None
    base = None
    if not default_branch or ref == f"refs/heads/{default_branch}":
        known = before and not ZERO.match(before)
        if known and git("cat-file", "-e", f"{before}^{{commit}}") is not None:
            base = git("merge-base", before, sha)
    else:
        base = git("merge-base", f"origin/{default_branch}", sha)
    if base is None:
        return None
    out = git("diff", "--name-only", "--no-renames", base, sha)
    if out is None:
        return None
    return [line for line in out.splitlines() if line]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--event", default="", help="github.event_name")
    parser.add_argument("--ref", default="", help="github.ref")
    parser.add_argument("--before", default="", help="github.event.before")
    parser.add_argument("--sha", default="HEAD", help="github.sha")
    parser.add_argument("--default-branch", default="", help="the repository's default branch")
    args = parser.parse_args(argv)
    lists = change_lists(GITLAB_CI.read_text())
    if not lists:
        print("error: no .change_* list in .gitlab-ci.yml", file=sys.stderr)
        return 1
    changed = changed_files(args.event, args.ref, args.before, args.sha, args.default_branch)
    for name, value in selected(lists, changed).items():
        print(f"{name}={'true' if value else 'false'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
