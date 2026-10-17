import doctest
import io
import os
import re
import shlex
import shutil
import subprocess
import sysconfig
from itertools import pairwise
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[2]
PAGES = sorted((ROOT / "doc" / "api").glob("*.md"))
LIBRARY = sorted((ROOT / "src").glob("*.c"))
CFLAGS = [
    "-std=c11",
    "-pedantic",
    "-Werror",
    "-Wall",
    "-Wextra",
    "-Wconversion",
    "-Wshadow",
    "-Wvla",
    "-Wstrict-prototypes",
    "-Wmissing-prototypes",
    "-Wcast-qual",
    "-Wpointer-arith",
    "-Wundef",
    "-Wdouble-promotion",
    "-ffp-contract=off",
    "-fno-fast-math",
]
FENCE = re.compile(r"```(\w*)")
CLANG_FORMAT = shutil.which("clang-format", path=sysconfig.get_path("scripts"))


def blocks(path):
    """(language, first line counted from 1, text) of each fenced block."""
    found = []
    language = None
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if language is None:
            if match := FENCE.fullmatch(line.rstrip()):
                language, start, body = match[1], number + 1, []
        elif line.rstrip() == "```":
            found.append((language, start, "".join(body)))
            language = None
        else:
            body.append(line + "\n")
    if language is not None:
        raise ValueError(f"{path}:{start - 1}: unclosed code fence")
    return found


def c_blocks():
    """Each C block with its expected output: the next text block, unless a C block comes first."""
    found = []
    for path in PAGES:
        page = [block for block in blocks(path) if block[0] in ("c", "text")]
        for (language, line, text), after in pairwise([*page, None]):
            if language == "c":
                expected = after[2] if after and after[0] == "text" else None
                found.append(pytest.param(path, line, text, expected, id=f"{path.name}:{line}"))
    return found


C_BLOCKS = c_blocks()


def program(path, line, text):
    directive = f'#line {line} "{path.relative_to(ROOT).as_posix()}"\n'
    if re.search(r"\bint\s+main\s*\(", text):
        return directive + text
    return (
        "#include <stdio.h>\n\n#include <diana/diana.h>\n\nint main(void) {\n"
        f"{directive}{text}  return 0;\n}}\n"
    )


def compiler():
    cc = os.environ.get("CC") or shutil.which("cc")
    if not cc:
        pytest.skip("no C compiler: set CC")
    return shlex.split(cc)


@pytest.mark.parametrize(("path", "line", "text", "expected"), C_BLOCKS)
def test_c_example(tmp_path, path, line, text, expected):
    assert expected is not None, f"{path.name}:{line}: no text block with the expected output"
    source = tmp_path / "example.c"
    source.write_text(program(path, line, text), encoding="utf-8")
    exe = tmp_path / "example"
    build = subprocess.run(
        [*compiler(), *CFLAGS, f"-I{ROOT / 'include'}", "-o", exe, source, *LIBRARY],
        capture_output=True,
        text=True,
    )
    assert build.returncode == 0, build.stderr
    run = subprocess.run(
        [exe], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=60
    )
    assert run.returncode >= 0, f"killed by signal {-run.returncode}"
    assert run.stdout == expected


@pytest.mark.parametrize(
    ("path", "line", "text"), [pytest.param(*p.values[:3], id=p.id) for p in C_BLOCKS]
)
def test_c_format(path, line, text):
    if CLANG_FORMAT is None:
        pytest.skip("clang-format is not installed: uv sync --group lint")
    formatted = subprocess.run(
        [CLANG_FORMAT, f"--style=file:{ROOT / '.clang-format'}", "--assume-filename=example.c"],
        input=text,
        capture_output=True,
        text=True,
        check=True,
    ).stdout
    assert formatted == text


@pytest.mark.parametrize(
    "path",
    [path for path in PAGES if any(lang == "python" for lang, _, _ in blocks(path))],
    ids=lambda path: path.name,
)
def test_python_example(path):
    parser = doctest.DocTestParser()
    runner = doctest.DocTestRunner()
    report = io.StringIO()
    globs = {"__name__": path.stem}
    for language, line, text in blocks(path):
        if language != "python":
            continue
        test = parser.get_doctest(text, globs, f"{path.name}:{line}", str(path), line - 1)
        assert test.examples, f"{path.name}:{line}: python block without a >>> example"
        runner.run(test, out=report.write, clear_globs=False)
        globs = test.globs
    assert runner.failures == 0, report.getvalue()


def test_cmake_version():
    project = re.search(
        r"project\(diana\s+VERSION\s+(\d+\.\d+)\.", (ROOT / "CMakeLists.txt").read_text()
    )
    requested = [
        (path.name, line, match[1])
        for path in PAGES
        for language, line, text in blocks(path)
        if language == "cmake"
        for match in re.finditer(r"find_package\(diana\s+([\d.]+)", text)
    ]
    assert requested
    assert all(version == project[1] for _, _, version in requested), requested
