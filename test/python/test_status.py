import pytest

import diana


def test_version():
    assert isinstance(diana.version(), str)


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
