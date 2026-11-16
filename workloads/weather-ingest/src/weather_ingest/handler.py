"""Daily ingest of MeteoSwiss SwissMetNet station data (open data, STAC API) into S3.

For each configured station the Lambda reads the STAC item, downloads the daily
values of the current year (asset ogd-smn_<station>_d_recent.csv), verifies the
SHA-256 checksum published in the STAC metadata and stores the file in S3.
"""

import hashlib
import json
import logging
import os
import re
import urllib.request
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, date, datetime
from typing import Any

STAC_ITEM_URL = (
    "https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-smn/items/{station}"
)
ASSET_NAME = "ogd-smn_{station}_d_recent.csv"
STATION_PATTERN = re.compile(r"^[a-z]{3}$")
TIMEOUT_SECONDS = 20

# multihash prefix: 0x12 = sha2-256, 0x20 = 32-byte digest
SHA256_MULTIHASH_PREFIX = "1220"

logger = logging.getLogger()
logger.setLevel(logging.INFO)

Fetcher = Callable[[str], bytes]


@dataclass(frozen=True)
class Asset:
    name: str
    href: str
    sha256: str | None


def fetch(url: str) -> bytes:
    """Download a URL (only https to data.geo.admin.ch is ever passed in)."""
    with urllib.request.urlopen(url, timeout=TIMEOUT_SECONDS) as response:  # noqa: S310
        return response.read()


def parse_stations(value: str) -> list[str]:
    """Turn "klo, bas" into ["klo", "bas"]; reject anything that is not a station code."""
    stations = [part.strip().lower() for part in value.split(",") if part.strip()]
    invalid = [station for station in stations if not STATION_PATTERN.match(station)]
    if invalid:
        raise ValueError(f"invalid station codes: {invalid}")
    return stations


def find_asset(item: dict[str, Any], station: str) -> Asset:
    name = ASSET_NAME.format(station=station)
    try:
        asset = item["assets"][name]
    except KeyError as error:
        raise ValueError(f"asset {name} not found in STAC item") from error

    checksum = asset.get("file:checksum", "")
    sha256 = (
        checksum.removeprefix(SHA256_MULTIHASH_PREFIX)
        if checksum.startswith(SHA256_MULTIHASH_PREFIX)
        else None
    )
    return Asset(name=name, href=asset["href"], sha256=sha256)


def verify(data: bytes, asset: Asset) -> None:
    if asset.sha256 is None:
        logger.warning("no SHA-256 checksum for %s, skipping verification", asset.name)
        return
    actual = hashlib.sha256(data).hexdigest()
    if actual != asset.sha256:
        raise ValueError(f"checksum mismatch for {asset.name}: {actual} != {asset.sha256}")


def object_key(station: str, day: date) -> str:
    return f"smn/{station}/d_recent/{day.isoformat()}.csv"


def ingest_station(
    station: str,
    bucket: str,
    s3: Any,
    fetcher: Fetcher = fetch,
    today: date | None = None,
) -> str:
    item = json.loads(fetcher(STAC_ITEM_URL.format(station=station)))
    asset = find_asset(item, station)
    data = fetcher(asset.href)
    verify(data, asset)

    key = object_key(station, today or datetime.now(UTC).date())
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=data,
        ContentType="text/csv",
        Metadata={"source": asset.href, "sha256": asset.sha256 or "none"},
    )
    return key


def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    import boto3  # provided by the Lambda runtime, not needed for the tests

    bucket = os.environ["BUCKET"]
    stations = parse_stations(os.environ["STATIONS"])
    s3 = boto3.client("s3")

    stored = [ingest_station(station, bucket, s3) for station in stations]
    logger.info(json.dumps({"bucket": bucket, "stored": stored}))
    return {"stored": stored}
