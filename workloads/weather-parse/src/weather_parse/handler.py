"""Daily summary of an ingested SwissMetNet file.

S3 (smn/<station>/d_recent/<date>.csv) → event → SQS → this Lambda, inside the shared VPC.
For each new file: read it, compute the summary of the daily mean temperature (tre200d0),
write summary/<station>.json. A message that fails is reported back alone, so SQS retries only
that one; after 3 tries it goes to the dead-letter queue.
"""

import csv
import io
import json
import logging
from urllib.parse import unquote_plus

import boto3

TEMPERATURE = "tre200d0"  # daily mean air temperature 2 m above ground, °C

logger = logging.getLogger()
logger.setLevel(logging.INFO)
s3 = boto3.client("s3")


def summarize(text: str) -> dict:
    """Days, first and last day, and min / max / latest temperature of one CSV file."""
    rows = list(csv.DictReader(io.StringIO(text), delimiter=";"))
    temps = []
    for row in rows:
        try:
            temps.append(float(row[TEMPERATURE]))
        except (KeyError, TypeError, ValueError):
            continue  # missing column or no measurement that day
    return {
        "days": len(rows),
        "first": rows[0]["reference_timestamp"] if rows else None,
        "last": rows[-1]["reference_timestamp"] if rows else None,
        "temp_min": min(temps, default=None),
        "temp_max": max(temps, default=None),
        "temp_latest": temps[-1] if temps else None,
    }


def process(bucket: str, key: str) -> str:
    station = key.split("/")[1]
    text = s3.get_object(Bucket=bucket, Key=key)["Body"].read().decode("utf-8")
    summary = {"station": station, "source": key, **summarize(text)}
    out = f"summary/{station}.json"
    s3.put_object(Bucket=bucket, Key=out, Body=json.dumps(summary), ContentType="application/json")
    return out


def handler(event, context):
    failures = []
    for message in event["Records"]:
        try:
            # S3 sends one test event when the notification is created: no Records, nothing to do
            for record in json.loads(message["body"]).get("Records", []):
                bucket = record["s3"]["bucket"]["name"]
                key = unquote_plus(record["s3"]["object"]["key"])
                logger.info("summarized %s into %s", key, process(bucket, key))
        except Exception:
            logger.exception("failed message %s", message["messageId"])
            failures.append({"itemIdentifier": message["messageId"]})
    # partial batch response: only the failed messages go back to the queue
    return {"batchItemFailures": failures}
