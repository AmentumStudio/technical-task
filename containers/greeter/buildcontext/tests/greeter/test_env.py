import os
from unittest.mock import patch


def test_does_mock_work():
    assert "default" == os.getenv("THIS_PROBABLY_DOESNT_EXIST", "default")

    with patch.dict(os.environ, {"THIS_PROBABLY_DOESNT_EXIST": "mocked"}):
        assert "mocked" == os.getenv("THIS_PROBABLY_DOESNT_EXIST", "default")


def test_int_from_env():
    from greeter.env import int_from_env

    # missing env var
    assert 0 == int_from_env("BAR", 0)

    def with_mock(value: str, expected: int):
        with patch.dict(os.environ, {"FOO": value}):
            assert expected == int_from_env("FOO", 0)

    # empty env var
    with_mock("", 0)
    # invalid value
    with_mock("abc", 0)
    # valid values
    with_mock("1", 1)
    with_mock("123", 123)
