"""Test skeleton.py."""
import pytest

from silver_spork.skeleton import fib, main


def test_fib():
    """Test API."""
    assert fib(1) == 1
    assert fib(2) == 1
    assert fib(7) == 13
    with pytest.raises(ValueError, match="index out of range"):
        fib(-10)


def test_main(capsys):
    """Test CLI."""
    # capsys is a pytest fixture that allows asserts against stdout/stderr
    # https://docs.pytest.org/en/stable/capture.html
    main(["7"])
    captured = capsys.readouterr()
    assert "The 7-th Fibonacci number is 13" in captured.out
