import json

import boto3
import pytest
from moto import mock_aws

CSV = (
    "station_abbr;reference_timestamp;tre200d0\n"
    "KLO;24.11.2026 00:00;4.0\n"
    "KLO;25.11.2026 00:00;-\n"
    "KLO;26.11.2026 00:00;1.5\n"
)
KEY = "smn/klo/d_recent/2026-11-26.csv"


@pytest.fixture
def env(monkeypatch):
    for key in ("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"):
        monkeypatch.setenv(key, "testing")
    monkeypatch.setenv("AWS_DEFAULT_REGION", "eu-central-2")
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    with mock_aws():
        from weather_parse import handler

        handler.s3 = boto3.client("s3")  # the module client was created outside the mock
        handler.s3.create_bucket(
            Bucket="data", CreateBucketConfiguration={"LocationConstraint": "eu-central-2"}
        )
        handler.s3.put_object(Bucket="data", Key=KEY, Body=CSV.encode())
        yield handler


def sqs_event(*bodies):
    return {"Records": [{"messageId": str(i), "body": b} for i, b in enumerate(bodies)]}


def s3_body(key):
    return json.dumps({"Records": [{"s3": {"bucket": {"name": "data"}, "object": {"key": key}}}]})


def test_summarize_skips_days_without_measurement():
    from weather_parse.handler import summarize

    assert summarize(CSV) == {
        "days": 3,
        "first": "24.11.2026 00:00",
        "last": "26.11.2026 00:00",
        "temp_min": 1.5,
        "temp_max": 4.0,
        "temp_latest": 1.5,
    }


def test_summarize_empty_file():
    from weather_parse.handler import summarize

    assert summarize("station_abbr;reference_timestamp;tre200d0\n")["temp_max"] is None


def test_handler_writes_summary_per_station(env):
    assert env.handler(sqs_event(s3_body(KEY)), None) == {"batchItemFailures": []}
    summary = json.loads(env.s3.get_object(Bucket="data", Key="summary/klo.json")["Body"].read())
    assert summary["station"] == "klo" and summary["temp_max"] == 4.0


def test_only_the_failed_message_goes_back(env):
    event = sqs_event(s3_body("smn/bas/d_recent/missing.csv"), s3_body(KEY))
    assert env.handler(event, None) == {"batchItemFailures": [{"itemIdentifier": "0"}]}


def test_s3_test_event_is_ignored(env):
    assert env.handler(sqs_event(json.dumps({"Event": "s3:TestEvent"})), None) == {
        "batchItemFailures": []
    }
