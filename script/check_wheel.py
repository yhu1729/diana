#!/usr/bin/env python3
"""Build and check self-contained static and shared Diana wheels with uv."""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
from pathlib import Path
from tempfile import TemporaryDirectory
from zipfile import ZipFile

ROOT = Path(__file__).resolve().parent.parent
SMOKE = """
import math
import sys
from pathlib import Path

import diana

assert Path(diana.__file__).resolve().is_relative_to(Path(sys.prefix).resolve())
root = diana.bisect(lambda x: x*x - 2.0, 0.0, 2.0, tol=1e-12)
assert math.isfinite(root) and abs(root - math.sqrt(2.0)) <= 1e-12
print(f"Diana {diana.version()}: installed wheel import and bisection passed")
"""


def check_wheel(work: Path, shared: bool) -> None:
    build = work / "build"
    wheel_dir = work / "wheel"
    subprocess.run(
        [
            "uv",
            "build",
            "--wheel",
            "--python",
            sys.executable,
            "--out-dir",
            str(wheel_dir),
            "-C",
            f"build-dir={build}",
            "-C",
            f"cmake.define.BUILD_SHARED_LIBS={'ON' if shared else 'OFF'}",
            "-C",
            "cmake.define.DIANA_WERROR=ON",
            "-C",
            "cmake.define.DIANA_SANITIZER=OFF",
        ],
        cwd=ROOT,
        check=True,
    )
    wheels = list(wheel_dir.glob("*.whl"))
    if len(wheels) != 1:
        raise RuntimeError(f"expected one wheel in {wheel_dir}, found {len(wheels)}")
    wheel = wheels[0]
    if sys.platform == "win32":
        runtime = "diana.dll"
    elif sys.platform == "darwin":
        runtime = "libdiana.dylib"
    else:
        runtime = "libdiana.so"
    with ZipFile(wheel) as archive:
        names = archive.namelist()
    libraries = {name for name in names if Path(name).name.startswith(("libdiana.", "diana.dll"))}
    expected = {f"diana/{runtime}"} if shared else set()
    if libraries != expected:
        raise RuntimeError(f"unexpected runtime libraries in {wheel.name}: {libraries}")
    if any(name.endswith((".h", ".a", ".lib", ".cmake")) for name in names):
        raise RuntimeError(f"development artifacts packaged in {wheel.name}")
    shutil.rmtree(build)

    venv = work / "venv"
    subprocess.run(["uv", "venv", "--python", sys.executable, str(venv)], check=True)
    python = venv / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")
    subprocess.run(
        ["uv", "pip", "install", "--python", str(python), "--no-deps", "--no-index", str(wheel)],
        check=True,
    )
    env = os.environ.copy()
    for key in (
        "PYTHONPATH",
        "PYTHONHOME",
        "LD_LIBRARY_PATH",
        "LD_PRELOAD",
        "DYLD_LIBRARY_PATH",
        "DYLD_FALLBACK_LIBRARY_PATH",
        "DYLD_FRAMEWORK_PATH",
        "DYLD_FALLBACK_FRAMEWORK_PATH",
        "DYLD_INSERT_LIBRARIES",
    ):
        env.pop(key, None)
    if sys.platform == "win32":
        env["PATH"] = str(python.parent)
    subprocess.run([str(python), "-I", "-c", SMOKE], cwd=work, env=env, check=True)
    print(f"{'Shared' if shared else 'Static'} wheel passed", flush=True)


def main() -> None:
    with TemporaryDirectory(prefix="diana-wheel-") as tmp:
        for shared in (False, True):
            work = Path(tmp) / ("shared" if shared else "static")
            work.mkdir()
            check_wheel(work, shared)


if __name__ == "__main__":
    main()
