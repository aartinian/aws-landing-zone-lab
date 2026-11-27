"""Baseline checks: pure functions over collected facts, no AWS calls (easy to test)."""

from dataclasses import dataclass, field

# account-level S3 Block Public Access settings, all must be on
BPA_SETTINGS = ("BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets")
TAG_KEYS = ("owner", "env", "data-classification")


@dataclass
class AccountFacts:
    """What the collector found for one member account. None means: could not be read."""

    name: str
    account_id: str
    status: str
    ou: str | None = None
    tags: dict[str, str] = field(default_factory=dict)
    zurich: str | None = None
    public_access_block: dict[str, bool] | None = None
    budgets: int | None = None
    guardduty: str | None = None
    securityhub: str | None = None
    errors: dict[str, str] = field(default_factory=dict)


@dataclass(frozen=True)
class Finding:
    account: str
    check: str
    ok: bool
    detail: str = ""


def _unreadable(facts: AccountFacts, check: str) -> Finding:
    return Finding(facts.name, check, False, f"not readable: {facts.errors.get(check, 'unknown')}")


def check_account(
    facts: AccountFacts, expected: dict, allowed: dict[str, list[str]]
) -> list[Finding]:
    """Compare one account with its entry in accounts.yaml and the tag standard."""
    name = facts.name
    findings = [Finding(name, "active", facts.status == "ACTIVE", facts.status)]

    findings.append(
        Finding(name, "ou", facts.ou == expected["ou"], f"{facts.ou} (expected {expected['ou']})")
    )

    wrong = [
        f"{key}={facts.tags.get(key)!r}"
        for key in TAG_KEYS
        if facts.tags.get(key) != expected[key] or facts.tags.get(key) not in allowed.get(key, [])
    ]
    findings.append(Finding(name, "tags", not wrong, ", ".join(wrong) or "owner, env, class"))

    if facts.zurich is None:
        findings.append(_unreadable(facts, "zurich"))
    else:
        ok = facts.zurich in ("ENABLED", "ENABLED_BY_DEFAULT")
        findings.append(Finding(name, "zurich", ok, facts.zurich))

    if facts.public_access_block is None:
        findings.append(_unreadable(facts, "s3 block public access"))
    else:
        off = [key for key in BPA_SETTINGS if not facts.public_access_block.get(key)]
        detail = "off: " + ", ".join(off) if off else "all on"
        findings.append(Finding(name, "s3 block public access", not off, detail))

    if facts.budgets is None:
        findings.append(_unreadable(facts, "budget"))
    else:
        findings.append(Finding(name, "budget", facts.budgets > 0, f"{facts.budgets} budget(s)"))

    # the admin account itself is not a member of GuardDuty or Security Hub
    for check, status in (("guardduty", facts.guardduty), ("security hub", facts.securityhub)):
        if facts.errors.get(check):
            findings.append(_unreadable(facts, check))
        elif status != "ADMIN":
            findings.append(Finding(name, check, status == "Enabled", status or "not a member"))

    return findings


def check_organization(
    accounts: list[AccountFacts], expected: dict[str, dict], allowed: dict[str, list[str]]
) -> list[Finding]:
    """All member accounts: vended ones are checked, the others are drift."""
    findings: list[Finding] = []
    found = {facts.name: facts for facts in accounts}

    for name in sorted(expected):
        if name in found:
            findings += check_account(found[name], expected[name], allowed)
        else:
            findings.append(Finding(name, "exists", False, "in accounts.yaml, not in the org"))

    for name in sorted(set(found) - set(expected)):
        findings.append(Finding(name, "vended", False, "in the org, not in accounts.yaml"))

    return findings


def render_markdown(findings: list[Finding]) -> str:
    """Report for a terminal or a GitHub job summary: failures first, then a short summary."""
    failed = [f for f in findings if not f.ok]
    rows = [("Account", "Check", "Result", "Detail")] + [
        (f.account, f.check, "ok" if f.ok else "FAIL", str(f.detail))
        for f in sorted(findings, key=lambda f: (f.ok, f.account, f.check))
    ]
    # padded columns: aligned in a terminal, still a valid Markdown table
    widths = [max(len(row[i]) for row in rows) for i in range(4)]
    lines = [
        "| " + " | ".join(c.ljust(w) for c, w in zip(row, widths, strict=True)) + " |"
        for row in rows
    ]
    lines.insert(1, "|" + "|".join("-" * (w + 2) for w in widths) + "|")
    lines.append("")
    lines.append(f"{len(findings) - len(failed)} ok, {len(failed)} failed")
    return "\n".join(lines) + "\n"
