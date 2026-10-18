import hashlib
import importlib.util
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

TARGET = "aarch64_macos"
AST = f"kernel_{TARGET}.v"
ROW = "| kernel | KERNEL-C1 | C | – | ok | ok (3/3) | contract |\n"


def load_module(monkeypatch, name="diana_test_check_provenance"):
    path = Path(__file__).resolve().parents[2] / "script" / "check_provenance.py"
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    monkeypatch.setitem(sys.modules, spec.name, module)
    spec.loader.exec_module(module)
    return module


def write(root, path, text):
    file = root / path
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(text)


def ast_text(source):
    return f'Module Info.\n  Definition source_file := "{source}".\nEnd Info.\n'


@pytest.fixture
def prov(tmp_path, monkeypatch):
    module = load_module(monkeypatch)
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setattr(module, "CLIGHT_DIR", tmp_path / "verification" / "clight")
    monkeypatch.setattr(module, "MANIFEST", tmp_path / "verification" / "clight" / "manifest.txt")
    monkeypatch.setattr(module, "REPORT", tmp_path / "doc" / "verification" / "report.md")

    def listed_file(top):
        base = tmp_path / top
        if base.is_file():
            return [top]
        return sorted(p.relative_to(tmp_path).as_posix() for p in base.rglob("*") if p.is_file())

    monkeypatch.setattr(module, "listed_file", listed_file)
    write(tmp_path, "include/diana/kernel.h", '#include "diana/status.h"\n')
    write(tmp_path, "include/diana/status.h", "typedef int diana_status;\n")
    write(tmp_path, "src/fp.h", "#include <float.h>\n")
    write(tmp_path, "src/kernel.c", '#include "diana/kernel.h"\n#include "fp.h"\n')
    write(tmp_path, "spec/kernel.md", "---\nmethod: kernel\n---\n")
    write(tmp_path, "script/axiom_allow.yaml", "rocq: []\n")
    write(tmp_path, "script/run_frama_c.sh", 'SKIP="diana_bisection_mid"\n')
    write(tmp_path, f"verification/clight/{AST}", ast_text("src/kernel.c"))
    return module


def stamp(prov, row=ROW):
    prov.MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    prov.write_manifest(TARGET)
    write(prov.ROOT, "doc/verification/report.md", prov.render_stamp([]) + "\n\n" + row)


def check(prov):
    errors = []
    prov.check_manifest(errors)
    prov.check_report(errors)
    return errors


def test_include_closure_follows_quoted_includes(prov):
    write(prov.ROOT, "src/local.h", "")
    write(prov.ROOT, "src/kernel.c", '#include "local.h"\n#include "diana/kernel.h"\n')
    assert prov.include_closure("src/kernel.c") == [
        "include/diana/kernel.h",
        "include/diana/status.h",
        "src/kernel.c",
        "src/local.h",
    ]


def test_include_closure_takes_project_angle_include(prov):
    write(prov.ROOT, "src/kernel.c", "#include <diana/kernel.h>\n#include <stddef.h>\n")
    assert prov.include_closure("src/kernel.c") == [
        "include/diana/kernel.h",
        "include/diana/status.h",
        "src/kernel.c",
    ]


def test_include_closure_rejects_unknown_header(prov):
    write(prov.ROOT, "src/kernel.c", '#include "missing.h"\n')
    with pytest.raises(ValueError, match='cannot find the included file "missing.h"'):
        prov.include_closure("src/kernel.c")


def test_manifest_lists_ast_source_and_headers(prov):
    stamp(prov)
    lines = [line.split() for line in prov.MANIFEST.read_text().splitlines() if line[0] != "#"]
    assert [(ast, path) for ast, _, path in lines] == [
        (AST, "include/diana/kernel.h"),
        (AST, "include/diana/status.h"),
        (AST, "src/fp.h"),
        (AST, "src/kernel.c"),
        (AST, f"verification/clight/{AST}"),
    ]
    digest = hashlib.sha256((prov.ROOT / "src/fp.h").read_bytes()).hexdigest()
    assert [AST, digest, "src/fp.h"] in lines
    assert check(prov) == []


@pytest.mark.parametrize(
    "path", ["include/diana/status.h", "src/fp.h", f"verification/clight/{AST}"]
)
def test_changed_file_fails_manifest(prov, path):
    stamp(prov)
    (prov.ROOT / path).write_text((prov.ROOT / path).read_text() + "/* change */\n")
    errors = []
    prov.check_manifest(errors)
    assert errors == [f"{AST}: {path} changed since the AST was checked"]


def test_new_include_fails_manifest(prov):
    stamp(prov)
    write(prov.ROOT, "src/extra.h", "")
    write(prov.ROOT, "src/kernel.c", '#include "diana/kernel.h"\n#include "extra.h"\n')
    errors = []
    prov.check_manifest(errors)
    assert f"{AST}: src/extra.h is read but not in the manifest" in errors
    assert f"{AST}: src/fp.h is in the manifest but no longer read" in errors


def test_unrecorded_and_missing_ast_fail(prov):
    stamp(prov)
    write(prov.ROOT, "verification/clight/other_x86_64_linux.v", ast_text("src/kernel.c"))
    (prov.CLIGHT_DIR / AST).rename(prov.CLIGHT_DIR / f"renamed_{TARGET}.v")
    errors = []
    prov.check_manifest(errors)
    assert errors == [
        "verification/clight/other_x86_64_linux.v is not in verification/clight/manifest.txt",
        f"verification/clight/renamed_{TARGET}.v is not in verification/clight/manifest.txt",
        f"verification/clight/manifest.txt lists {AST}, which does not exist",
    ]


def test_missing_manifest_fails(prov):
    errors = []
    prov.check_manifest(errors)
    assert errors == ["verification/clight/manifest.txt does not exist"]


def test_malformed_manifest_raises(prov):
    stamp(prov)
    prov.MANIFEST.write_text(prov.MANIFEST.read_text() + f"{AST} abc src/kernel.c\n")
    with pytest.raises(ValueError, match="malformed line"):
        prov.check_manifest([])


def test_write_manifest_keeps_other_target(prov):
    other = "kernel_x86_64_linux.v"
    write(prov.ROOT, f"verification/clight/{other}", ast_text("src/kernel.c"))
    prov.MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    prov.write_manifest("x86_64_linux")
    write(prov.ROOT, "src/fp.h", "/* changed */\n")
    stamp(prov)
    errors = []
    prov.check_manifest(errors)
    assert errors == [f"{other}: src/fp.h changed since the AST was checked"]


def test_write_manifest_rejects_misnamed_ast(prov):
    write(prov.ROOT, f"verification/clight/{AST}", ast_text("src/fp.h"))
    prov.MANIFEST.parent.mkdir(parents=True, exist_ok=True)
    with pytest.raises(ValueError, match="not named after the AST"):
        prov.write_manifest(TARGET)


@pytest.mark.parametrize(
    ("path", "top"),
    [
        ("include/diana/status.h", "include/"),
        ("script/axiom_allow.yaml", "script/axiom_allow.yaml"),
        ("script/run_frama_c.sh", "script/run_frama_c.sh"),
        ("spec/kernel.md", "spec/"),
        ("src/kernel.c", "src/"),
    ],
)
def test_changed_input_fails_stamp(prov, path, top):
    stamp(prov)
    (prov.ROOT / path).write_text("changed\n")
    errors = []
    prov.check_report(errors)
    assert errors == [f"{top} changed since doc/verification/report.md was generated"]


def test_new_file_fails_stamp(prov):
    stamp(prov)
    write(prov.ROOT, "verification/rocq/theory/New.v", "")
    errors = []
    prov.check_report(errors)
    assert errors == ["verification/ changed since doc/verification/report.md was generated"]


def test_other_script_does_not_change_stamp(prov):
    stamp(prov)
    write(prov.ROOT, "script/check_doc.py", "")
    errors = []
    prov.check_report(errors)
    assert errors == []


def test_missing_stamp_fails(prov):
    stamp(prov)
    write(prov.ROOT, "doc/verification/report.md", ROW)
    errors = []
    prov.check_report(errors)
    assert errors == [
        "doc/verification/report.md: no stamp with exactly the inputs include/, "
        "script/axiom_allow.yaml, script/run_frama_c.sh, spec/, src/, verification/"
    ]


@pytest.mark.parametrize(
    ("row", "error"),
    [
        ("| k | K-B1 | B | – | missing | – | x |\n", "K-B1 [Rocq] is 'missing'"),
        ("| k | K-A1 | A | check failed | ok | – | x |\n", "K-A1 [Lean] is 'check failed'"),
        ("| k | K-C1 | C | – | – | planned | x |\n", "K-C1 [Frama-C] is 'planned'"),
        ("| k | K-C1 | C | – | – | ok (2/3) | x |\n", "K-C1 [Frama-C] is 'ok (2/3)'"),
    ],
)
def test_unverified_row_fails(prov, row, error):
    stamp(prov, row)
    errors = []
    prov.check_report(errors)
    assert errors == [f"doc/verification/report.md: {error}"]


def test_report_without_row_fails(prov):
    stamp(prov, "")
    errors = []
    prov.check_report(errors)
    assert errors == ["doc/verification/report.md: no theorem row"]


@pytest.mark.parametrize(
    ("top", "files"),
    [
        ("include/", ("include/diana/kernel.h", "include/diana/status.h")),
        ("script/axiom_allow.yaml", ("script/axiom_allow.yaml",)),
    ],
)
def test_input_digest_is_sha256_of_listing(prov, top, files):
    listing = "".join(
        f"{hashlib.sha256((prov.ROOT / p).read_bytes()).hexdigest()}  {p}\n" for p in files
    )
    assert prov.input_digest()[top] == hashlib.sha256(listing.encode()).hexdigest()


def test_render_stamp_escapes_tool_version(prov):
    text = prov.render_stamp([("lean", "a|b")])
    assert "| lean | a\\|b |" in text
    assert [top for top, _ in prov.STAMP_RE.findall(text)] == list(prov.INPUT)


@pytest.mark.skipif(shutil.which("git") is None, reason="git is not installed")
def test_listed_file_skips_ignored_and_keeps_untracked(tmp_path, monkeypatch):
    module = load_module(monkeypatch)
    monkeypatch.setattr(module, "ROOT", tmp_path)
    subprocess.run(["git", "init", "-q"], cwd=tmp_path, check=True)
    write(tmp_path, ".gitignore", "*.vo\n")
    write(tmp_path, "verification/A.v", "")
    write(tmp_path, "verification/A.vo", "")
    write(tmp_path, "verification/B.v", "")
    subprocess.run(["git", "add", "verification/A.v"], cwd=tmp_path, check=True)
    assert module.listed_file("verification") == ["verification/A.v", "verification/B.v"]
