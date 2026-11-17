from org_inventory.checks import (
    AccountFacts,
    Finding,
    check_account,
    check_organization,
    render_markdown,
)

ALLOWED = {
    "data-classification": ["public", "internal", "confidential"],
    "env": ["dev", "prod", "management"],
    "owner": ["platform", "weather-data"],
}
EXPECTED = {
    "ou": "Workloads",
    "owner": "weather-data",
    "env": "dev",
    "data-classification": "public",
}
BPA_ON = {
    "BlockPublicAcls": True,
    "IgnorePublicAcls": True,
    "BlockPublicPolicy": True,
    "RestrictPublicBuckets": True,
}


def healthy(**changes) -> AccountFacts:
    facts = AccountFacts(
        name="workload-dev",
        account_id="000000000000",
        status="ACTIVE",
        ou="Workloads",
        tags={"owner": "weather-data", "env": "dev", "data-classification": "public"},
        zurich="ENABLED",
        public_access_block=dict(BPA_ON),
        budgets=1,
        guardduty="Enabled",
        securityhub="Enabled",
    )
    for key, value in changes.items():
        setattr(facts, key, value)
    return facts


def failed(findings: list[Finding]) -> dict[str, str]:
    return {f.check: f.detail for f in findings if not f.ok}


def test_healthy_account_passes_every_check():
    findings = check_account(healthy(), EXPECTED, ALLOWED)
    assert failed(findings) == {}
    assert {f.check for f in findings} == {
        "active",
        "ou",
        "tags",
        "zurich",
        "s3 block public access",
        "budget",
        "guardduty",
        "security hub",
    }


def test_wrong_ou_fails():
    assert "ou" in failed(check_account(healthy(ou="Sandbox"), EXPECTED, ALLOWED))


def test_tag_differs_from_vending_file():
    tags = {"owner": "platform", "env": "dev", "data-classification": "public"}
    assert failed(check_account(healthy(tags=tags), EXPECTED, ALLOWED)) == {
        "tags": "owner='platform'"
    }


def test_tag_value_not_in_standard_fails_even_if_vending_file_agrees():
    tags = {"owner": "weather-data", "env": "dev", "data-classification": "secret"}
    expected = EXPECTED | {"data-classification": "secret"}
    assert "tags" in failed(check_account(healthy(tags=tags), expected, ALLOWED))


def test_missing_tag_fails():
    tags = {"owner": "weather-data", "env": "dev"}
    assert "tags" in failed(check_account(healthy(tags=tags), EXPECTED, ALLOWED))


def test_zurich_not_enabled_fails():
    assert "zurich" in failed(check_account(healthy(zurich="DISABLED"), EXPECTED, ALLOWED))


def test_one_block_public_access_setting_off_fails():
    bpa = BPA_ON | {"RestrictPublicBuckets": False}
    result = failed(check_account(healthy(public_access_block=bpa), EXPECTED, ALLOWED))
    assert result == {"s3 block public access": "off: RestrictPublicBuckets"}


def test_no_budget_fails():
    assert "budget" in failed(check_account(healthy(budgets=0), EXPECTED, ALLOWED))


def test_guardduty_auto_enable_gap_is_found():
    # the real case: auto-enable ALL, but existing accounts were never added as members
    result = failed(check_account(healthy(guardduty=None), EXPECTED, ALLOWED))
    assert result == {"guardduty": "not a member"}


def test_admin_account_is_not_checked_for_membership():
    facts = healthy(guardduty="ADMIN", securityhub="ADMIN")
    checks = {f.check for f in check_account(facts, EXPECTED, ALLOWED)}
    assert "guardduty" not in checks
    assert "security hub" not in checks


def test_unreadable_value_fails_with_the_error():
    facts = healthy(public_access_block=None, errors={"s3 block public access": "AccessDenied"})
    result = failed(check_account(facts, EXPECTED, ALLOWED))
    assert result == {"s3 block public access": "not readable: AccessDenied"}


def test_organization_finds_missing_and_unvended_accounts():
    rogue = healthy(name="shadow-it")
    findings = check_organization([rogue], {"workload-dev": EXPECTED}, ALLOWED)
    assert ("workload-dev", "exists") in {(f.account, f.check) for f in findings if not f.ok}
    assert ("shadow-it", "vended") in {(f.account, f.check) for f in findings if not f.ok}


def test_report_lists_failures_first_with_summary():
    findings = [Finding("a", "ou", True, "Workloads"), Finding("b", "budget", False, "0")]
    report = render_markdown(findings)
    rows = report.splitlines()
    assert rows[2] == "| b | budget | FAIL | 0 |"
    assert rows[-1] == "1 ok, 1 failed"
