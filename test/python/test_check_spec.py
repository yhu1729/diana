import importlib.util
import sys
from pathlib import Path
from unittest.mock import Mock

import pytest


def load_module(monkeypatch, name="diana_test_check_spec"):
    path = Path(__file__).resolve().parents[2] / "script" / "check_spec.py"
    monkeypatch.syspath_prepend(str(path.parent))
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    monkeypatch.setitem(sys.modules, spec.name, module)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def gate(tmp_path, monkeypatch):
    module = load_module(monkeypatch)

    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (tmp_path / "kernel.c").write_text("int kernel(void);\n")
    (tmp_path / "other.c").write_text("int other(void);\n")
    monkeypatch.setattr(module, "ROOT", tmp_path)
    monkeypatch.setattr(module, "SPEC_DIR", spec_dir)
    monkeypatch.setattr(module, "FRAMA_C_EXPECTATION", tmp_path / "expectation.txt")
    monkeypatch.setattr(module, "ALLOW_FILE", tmp_path / "axiom_allow.yaml")
    monkeypatch.setattr(module, "write_check_file", Mock())
    monkeypatch.setattr(module, "write_report", Mock())

    def verify(theorems, allow, provers):
        for theorem in theorems:
            for prover in provers:
                if getattr(theorem, prover):
                    theorem.result[prover] = "ok"

    monkeypatch.setattr(module, "run_prover", Mock(side_effect=verify))
    write_spec(module, "bisection", "BISECTION-C1")
    return module


def write_spec(gate, method, theorem_id, source="kernel.c"):
    (gate.SPEC_DIR / f"{method}.md").write_text(
        f"""---
method: {method}
kernel: {source}
theorem:
  - id: {theorem_id}
    layer: C
    informal: kernel contract
    acsl: {source}:{source.removesuffix(".c")}
---
"""
    )


def run_gate(gate, monkeypatch, *args):
    monkeypatch.setattr(sys, "argv", ["check_spec.py", *args])
    return gate.main()


@pytest.mark.parametrize(
    "expectation", ["kernel.c 1\n", "other.c invalid\nkernel.c 162\n", "kernel.c 162"]
)
def test_strict_accepts_acsl_coverage(gate, monkeypatch, expectation):
    gate.FRAMA_C_EXPECTATION.write_text(expectation)
    assert run_gate(gate, monkeypatch, "--run", "--strict") == 0
    gate.run_prover.assert_called_once()
    gate.write_report.assert_called_once()


@pytest.mark.parametrize("args", [(), ("--prover", "rocq"), ("--run", "--prover", "lean")])
def test_partial_run_keeps_report(gate, monkeypatch, args):
    gate.FRAMA_C_EXPECTATION.write_text("kernel.c 1\n")
    assert run_gate(gate, monkeypatch, *args) == 0
    gate.write_report.assert_not_called()


def test_report_has_stamp_between_marker_and_table(tmp_path, monkeypatch):
    module = load_module(monkeypatch)
    report = tmp_path / "report.md"
    report.write_text(f"# Report\n\n{module.REPORT_MARKER}\n\nold table\n")
    monkeypatch.setattr(module, "REPORT", report)
    monkeypatch.setattr(module.check_provenance, "tool_version", Mock(return_value=[]))
    monkeypatch.setattr(module.check_provenance, "render_stamp", Mock(return_value="STAMP"))
    theorem = module.Theorem(spec="k", id="K-B1", layer="B", informal="x", rocq="Diana.K.b1")
    theorem.result["rocq"] = "ok"
    module.write_report([theorem])
    assert report.read_text() == (
        f"# Report\n\n{module.REPORT_MARKER}\n\nSTAMP\n\n"
        "| Spec | ID | Layer | Lean | Rocq | Frama-C | Statement |\n"
        "|---|---|---|---|---|---|---|\n"
        "| k | K-B1 | B | – | ok | – | x |\n"
    )


def test_shared_constant_gets_every_result(gate, monkeypatch):
    gate.FRAMA_C_EXPECTATION.write_text("kernel.c 1\n")
    (gate.SPEC_DIR / "bisection.md").write_text(
        """---
method: bisection
kernel: kernel.c
theorem:
  - id: BISECTION-A1
    layer: A
    informal: first
    lean: Diana.Real.first
    rocq: Diana.Real.first
  - id: BISECTION-A2
    layer: A
    informal: second, same constant
    lean: Diana.Real.first
    rocq: Diana.Real.first
---
"""
    )
    fresh = load_module(monkeypatch, "diana_test_check_spec_fresh")
    monkeypatch.setattr(fresh, "ROOT", gate.ROOT)
    monkeypatch.setattr(fresh, "SPEC_DIR", gate.SPEC_DIR)
    monkeypatch.setattr(fresh, "LEAN_DIR", gate.ROOT / "lean")
    fresh.LEAN_DIR.mkdir()
    monkeypatch.setattr(fresh.subprocess, "run", Mock(side_effect=FileNotFoundError(2, "no lake")))
    errors = []
    theorems = fresh.load_spec(errors)
    assert not errors
    fresh.run_prover(theorems, {}, ("lean",))
    assert [t.result["lean"] for t in theorems] == ["check failed", "check failed"]


@pytest.mark.parametrize(
    ("expectation", "diagnostic"),
    [
        (None, "missing expectation"),
        ("", "missing expectation"),
        ("other.c 162\n", "missing expectation"),
        ("bisection 162\n", "missing expectation"),
        ("kernel.c\n", "invalid expectation"),
        ("kernel.c invalid\n", "invalid expectation"),
        ("kernel.c 162 extra\n", "invalid expectation"),
        ("kernel.c 162\nkernel.c 162\n", "invalid expectation"),
        ("kernel.c 0\n", "invalid expectation"),
        ("kernel.c -1\n", "invalid expectation"),
    ],
)
def test_strict_rejects_missing_or_invalid_acsl_coverage(
    gate, monkeypatch, capsys, expectation, diagnostic
):
    if expectation is not None:
        gate.FRAMA_C_EXPECTATION.write_text(expectation)
    assert run_gate(gate, monkeypatch, "--run", "--strict", "--no-report") == 1
    assert f"BISECTION-C1 [frama-c]: {diagnostic} for kernel.c" in capsys.readouterr().out
    gate.write_report.assert_not_called()


def test_strict_checks_every_acsl_file(gate, monkeypatch, capsys):
    write_spec(gate, "other", "OTHER-C1", "other.c")
    gate.FRAMA_C_EXPECTATION.write_text("kernel.c 162\n")
    assert run_gate(gate, monkeypatch, "--run", "--strict", "--no-report") == 1
    out = capsys.readouterr().out
    assert "OTHER-C1 [frama-c]: missing expectation for other.c" in out
    assert "BISECTION-C1 [frama-c]" not in out


def test_specs_share_acsl_file_expectation(gate, monkeypatch):
    write_spec(gate, "other", "OTHER-C1")
    gate.FRAMA_C_EXPECTATION.write_text("kernel.c 162\n")
    assert run_gate(gate, monkeypatch, "--run", "--strict", "--no-report") == 0


@pytest.mark.parametrize("expectation", [None, "kernel.c invalid\n"])
def test_non_strict_preserves_acsl_behavior(gate, monkeypatch, expectation):
    if expectation is not None:
        gate.FRAMA_C_EXPECTATION.write_text(expectation)
    assert run_gate(gate, monkeypatch, "--no-report") == 0
    gate.run_prover.assert_not_called()


@pytest.mark.parametrize("provers", [("lean",), ("rocq",), ("lean", "rocq")])
def test_explicit_prover_filters_out_acsl_coverage(gate, monkeypatch, provers):
    path = gate.SPEC_DIR / "bisection.md"
    path.write_text(
        path.read_text().removesuffix("---\n")
        + """  - id: BISECTION-A1
    layer: A
    informal: real theorem
    lean: Diana.Real.Bisection.theorem
    rocq: Diana.Real.Bisection.theorem
---
"""
    )
    args = ["--run", "--strict", "--no-report"]
    for prover in provers:
        args.extend(["--prover", prover])
    assert run_gate(gate, monkeypatch, *args) == 0
    assert gate.run_prover.call_args.args[2] == provers


def test_id_prefix_must_match_method(gate, monkeypatch, capsys):
    write_spec(gate, "other", "BISECTION-C2", "other.c")
    assert run_gate(gate, monkeypatch, "--no-report") == 1
    assert "BISECTION-C2: id prefix must be 'OTHER'" in capsys.readouterr().err


def test_id_prefix_maps_underscore_to_hyphen(gate, monkeypatch, capsys):
    write_spec(gate, "other_unchecked", "OTHER-UNCHECKED-C1", "other.c")
    gate.FRAMA_C_EXPECTATION.write_text("kernel.c 1\nother.c 1\n")
    assert run_gate(gate, monkeypatch, "--run", "--strict", "--no-report") == 0
    write_spec(gate, "other_unchecked", "OTHER_UNCHECKED-C1", "other.c")
    assert run_gate(gate, monkeypatch, "--no-report") == 1
    assert "bad theorem id 'OTHER_UNCHECKED-C1'" in capsys.readouterr().err
    write_spec(gate, "other_unchecked", "OTHER-C1", "other.c")
    assert run_gate(gate, monkeypatch, "--no-report") == 1
    assert "OTHER-C1: id prefix must be 'OTHER-UNCHECKED'" in capsys.readouterr().err


def test_kernel_may_list_files(gate, monkeypatch, capsys):
    path = gate.SPEC_DIR / "bisection.md"
    path.write_text(path.read_text().replace("kernel: kernel.c", "kernel: [kernel.c, other.c]"))
    gate.FRAMA_C_EXPECTATION.write_text("kernel.c 1\n")
    assert run_gate(gate, monkeypatch, "--run", "--strict", "--no-report") == 0
    path.write_text(path.read_text().replace("other.c]", "missing.c]"))
    assert run_gate(gate, monkeypatch, "--no-report") == 1
    assert "kernel 'missing.c' does not exist" in capsys.readouterr().err
