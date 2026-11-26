"""findings: open Security Hub findings per account and severity (run in security-tooling)."""

from collections import Counter

from lab_tools.aws import paginate, table

SEVERITIES = ["CRITICAL", "HIGH", "MEDIUM", "LOW", "INFORMATIONAL"]
OPEN = {
    "RecordState": [{"Value": "ACTIVE", "Comparison": "EQUALS"}],
    "WorkflowStatus": [{"Value": "NEW", "Comparison": "EQUALS"}],
}


def count(findings) -> dict[str, Counter]:
    """account -> Counter(severity -> number of findings)."""
    result: dict[str, Counter] = {}
    for f in findings:
        result.setdefault(f["AwsAccountId"], Counter())[f["Severity"]["Label"]] += 1
    return result


def run(sess, args) -> int:
    # the admin sees the findings of every member; GuardDuty findings arrive here too
    hub = sess.client("securityhub")
    counts = count(paginate(hub, "get_findings", "Findings", Filters=OPEN))
    rows = [[acct] + [c[s] for s in SEVERITIES] for acct, c in sorted(counts.items())]
    print(table(["account"] + SEVERITIES, rows) if rows else "no open findings")
    return 1 if any(c["CRITICAL"] or c["HIGH"] for c in counts.values()) else 0
