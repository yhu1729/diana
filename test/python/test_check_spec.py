import importlib.util
import sys
from pathlib import Path
from unittest.mock import Mock

import pytest


@pytest.fixture
def gate(tmp_path, monkeypatch):
    path = Path(__file__).resolve().parents[2] / "script" / "check_spec.py"
    spec = importlib.util.spec_from_file_location("diana_test_check_spec", path)
    module = importlib.util.module_from_spec(spec)
    monkeypatch.setitem(sys.modules, spec.name, module)
    spec.loader.exec_module(module)

    spec_dir = tmp_path / "spec"
    spec_dir.mkdir()
    (tmp_path / "kernel.c").write_text("int kernel(void);\n")
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
    write_spec(module, "bisect", "BIS-C1")
    return module


def write_spec(gate, method, theorem_id):
    (gate.SPEC_DIR / f"{method}.md").write_text(
        f"""---
method: {method}
kernel: kernel.c
theorem:
  - id: {theorem_id}
    layer: C
    informal: kernel contract
    acsl: kernel.c:kernel
---
"""
    )


def run_gate(gate, monkeypatch, *args):
    monkeypatch.setattr(sys, "argv", ["check_spec.py", *args])
    return gate.main()


@pytest.mark.parametrize("expectation", ["bisect 1\n", "other invalid\nbisect 162\n"])
def test_strict_accepts_acsl_coverage(gate, monkeypatch, expectation):
    gate.FRAMA_C_EXPECTATION.write_text(expectation)
    assert run_gate(gate, monkeypatch, "--run", "--strict") == 0
    gate.run_prover.assert_called_once()
    gate.write_report.assert_called_once()


@pytest.mark.parametrize(
    ("expectation", "diagnostic"),
    [
        (None, "missing expectation"),
        ("", "missing expectation"),
        ("other 162\n", "missing expectation"),
        ("bisect\n", "invalid expectation"),
        ("bisect invalid\n", "invalid expectation"),
        ("bisect 162 extra\n", "invalid expectation"),
        ("bisect 162\nbisect 162\n", "invalid expectation"),
        ("bisect 0\n", "invalid expectation"),
        ("bisect -1\n", "invalid expectation"),
    ],
)
def test_strict_rejects_missing_or_invalid_acsl_coverage(
    gate, monkeypatch, capsys, expectation, diagnostic
):
    if expectation is not None:
        gate.FRAMA_C_EXPECTATION.write_text(expectation)
    assert run_gate(gate, monkeypatch, "--run", "--strict", "--no-report") == 1
    assert f"BIS-C1 [frama-c]: {diagnostic} for bisect" in capsys.readouterr().out
    gate.write_report.assert_not_called()


def test_strict_checks_every_acsl_spec(gate, monkeypatch, capsys):
    write_spec(gate, "other", "OTH-C1")
    gate.FRAMA_C_EXPECTATION.write_text("bisect 162\n")
    assert run_gate(gate, monkeypatch, "--run", "--strict", "--no-report") == 1
    assert "OTH-C1 [frama-c]: missing expectation for other" in capsys.readouterr().out


@pytest.mark.parametrize("expectation", [None, "bisect invalid\n"])
def test_non_strict_preserves_acsl_behavior(gate, monkeypatch, expectation):
    if expectation is not None:
        gate.FRAMA_C_EXPECTATION.write_text(expectation)
    assert run_gate(gate, monkeypatch, "--no-report") == 0
    gate.run_prover.assert_not_called()


@pytest.mark.parametrize("provers", [("lean",), ("rocq",), ("lean", "rocq")])
def test_explicit_prover_filters_out_acsl_coverage(gate, monkeypatch, provers):
    path = gate.SPEC_DIR / "bisect.md"
    path.write_text(
        path.read_text().removesuffix("---\n")
        + """  - id: BIS-A1
    layer: A
    informal: real theorem
    lean: Diana.Real.Bisect.theorem
    rocq: Diana.Real.Bisect.theorem
---
"""
    )
    args = ["--run", "--strict", "--no-report"]
    for prover in provers:
        args.extend(["--prover", prover])
    assert run_gate(gate, monkeypatch, *args) == 0
    assert gate.run_prover.call_args.args[2] == provers
