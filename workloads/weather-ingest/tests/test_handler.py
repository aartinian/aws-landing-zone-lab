import hashlib
import json
from datetime import date

import pytest

from weather_ingest.handler import (
    STAC_ITEM_URL,
    Asset,
    find_asset,
    ingest_station,
    object_key,
    parse_stations,
    verify,
)

DATA = b"station_abbr;reference_timestamp;tre200d0\nKLO;15.11.2026 00:00;5.3\n"
SHA256 = hashlib.sha256(DATA).hexdigest()
HREF = "https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/klo/ogd-smn_klo_d_recent.csv"


def stac_item(checksum: str | None = "1220" + SHA256) -> dict:
    asset = {"href": HREF, "type": "text/csv"}
    if checksum is not None:
        asset["file:checksum"] = checksum
    return {"id": "klo", "assets": {"ogd-smn_klo_d_recent.csv": asset}}


class FakeS3:
    def __init__(self) -> None:
        self.calls: list[dict] = []

    def put_object(self, **kwargs) -> None:
        self.calls.append(kwargs)


def fake_fetcher(responses: dict[str, bytes]):
    def fetch(url: str) -> bytes:
        return responses[url]

    return fetch


def test_parse_stations_normalizes_and_splits():
    assert parse_stations(" KLO, bas ,") == ["klo", "bas"]


@pytest.mark.parametrize("value", ["kl", "klo,../x", "k1o"])
def test_parse_stations_rejects_invalid_codes(value):
    with pytest.raises(ValueError, match="invalid station codes"):
        parse_stations(value)


def test_find_asset_reads_href_and_checksum():
    assert find_asset(stac_item(), "klo") == Asset(
        name="ogd-smn_klo_d_recent.csv", href=HREF, sha256=SHA256
    )


def test_find_asset_without_checksum():
    assert find_asset(stac_item(checksum=None), "klo").sha256 is None


def test_find_asset_missing_raises():
    with pytest.raises(ValueError, match="not found"):
        find_asset(stac_item(), "bas")


def test_verify_accepts_matching_checksum():
    verify(DATA, Asset("a.csv", HREF, SHA256))


def test_verify_rejects_mismatch():
    with pytest.raises(ValueError, match="checksum mismatch"):
        verify(b"tampered", Asset("a.csv", HREF, SHA256))


def test_object_key_is_partitioned_by_station_and_day():
    assert object_key("klo", date(2026, 11, 16)) == "smn/klo/d_recent/2026-11-16.csv"


def test_ingest_station_stores_verified_file():
    s3 = FakeS3()
    fetcher = fake_fetcher(
        {
            STAC_ITEM_URL.format(station="klo"): json.dumps(stac_item()).encode(),
            HREF: DATA,
        }
    )

    key = ingest_station("klo", "bucket", s3, fetcher=fetcher, today=date(2026, 11, 16))

    assert key == "smn/klo/d_recent/2026-11-16.csv"
    assert s3.calls == [
        {
            "Bucket": "bucket",
            "Key": key,
            "Body": DATA,
            "ContentType": "text/csv",
            "Metadata": {"source": HREF, "sha256": SHA256},
        }
    ]


def test_ingest_station_does_not_store_corrupt_file():
    s3 = FakeS3()
    fetcher = fake_fetcher(
        {
            STAC_ITEM_URL.format(station="klo"): json.dumps(stac_item()).encode(),
            HREF: b"corrupt",
        }
    )

    with pytest.raises(ValueError, match="checksum mismatch"):
        ingest_station("klo", "bucket", s3, fetcher=fetcher)
    assert s3.calls == []
