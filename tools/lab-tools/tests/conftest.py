import boto3
import pytest
from moto import mock_aws


@pytest.fixture
def sess(monkeypatch):
    # fake credentials: moto intercepts every call, nothing reaches AWS
    for key in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"):
        monkeypatch.setenv(key, "testing")
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    with mock_aws():
        yield boto3.Session(region_name="eu-central-2")
