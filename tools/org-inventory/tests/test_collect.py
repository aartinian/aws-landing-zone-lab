from org_inventory.collect import _member_status


class _Client:
    def __init__(self, detectors):
        self.detectors = detectors

    def list_detectors(self):
        return {"DetectorIds": self.detectors}

    def get_paginator(self, name):
        return self

    def paginate(self, **kwargs):
        if "DetectorId" in kwargs:
            return [{"Members": [{"AccountId": "1", "RelationshipStatus": "Enabled"}]}]
        return [{"Members": [{"AccountId": "1", "MemberStatus": "Enabled"}]}]


class _Session:
    def __init__(self, detectors):
        self.detectors = detectors

    def client(self, name):
        return _Client(self.detectors)


def test_admin_without_guardduty_detector_reports_no_members():
    gd, sh = _member_status(_Session([]))
    assert gd == {}
    assert sh == {"1": "Enabled"}


def test_admin_with_detector_reads_members():
    gd, _ = _member_status(_Session(["d-1"]))
    assert gd == {"1": "Enabled"}
