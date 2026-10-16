import re
import tomllib
from pathlib import Path

import pytest

import diana


def test_version():
    assert isinstance(diana.version(), str)
    assert diana.__version__ == diana.version()


def test_version_consistent():
    root = Path(__file__).resolve().parents[2]
    cmake = re.search(r"project\(diana\s+VERSION\s+([\d.]+)", (root / "CMakeLists.txt").read_text())
    header = re.search(
        r'#define DIANA_VERSION_STRING "([\d.]+)"', (root / "include/diana/diana.h").read_text()
    )
    with (root / "pyproject.toml").open("rb") as f:
        project = tomllib.load(f)["project"]["version"]
    assert cmake is not None and header is not None
    assert cmake[1] == header[1] == project == diana.version()


def test_status_str():
    assert diana.status_str(diana.OK) == "ok"
    assert diana.status_str(diana.CONTINUE) == "continue"
    assert diana.status_str(12345) == "unknown status"
    with pytest.raises(OverflowError):
        diana.status_str(2**32)


def test_status_value():
    assert (diana.OK, diana.CONTINUE) == (0, 1)
    assert (diana.ERR_ARG, diana.ERR_BRACKET, diana.ERR_MAXITER) == (-1, -2, -3)


def test_exception_hierarchy():
    assert issubclass(diana.BracketError, ValueError)
    assert issubclass(diana.MaxIterError, RuntimeError)
