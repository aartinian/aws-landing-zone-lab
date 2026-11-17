"""org-inventory: check every member account against the landing zone baseline."""

import argparse
import sys
from pathlib import Path

import boto3
import yaml

from org_inventory.checks import check_organization, render_markdown
from org_inventory.collect import collect

# tools/org-inventory/src/org_inventory/cli.py -> repository root
VENDING_DIR = Path(__file__).resolve().parents[4] / "live" / "organization"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", help="AWS profile of the management account")
    parser.add_argument("--region", default="eu-central-2")
    parser.add_argument(
        "--role-name",
        default="OrganizationAccountAccessRole",
        help="role assumed in member accounts (read-only calls only)",
    )
    parser.add_argument("--vending-dir", type=Path, default=VENDING_DIR)
    parser.add_argument("--output", type=Path, help="write the Markdown report to this file")
    args = parser.parse_args(argv)

    expected = yaml.safe_load((args.vending_dir / "accounts.yaml").read_text())
    allowed = yaml.safe_load((args.vending_dir / "tagging.yaml").read_text())["tags"]

    session = boto3.Session(profile_name=args.profile, region_name=args.region)
    findings = check_organization(collect(session, args.role_name, args.region), expected, allowed)

    report = render_markdown(findings)
    if args.output:
        args.output.write_text(report)
    sys.stdout.write(report)
    return 1 if any(not f.ok for f in findings) else 0


if __name__ == "__main__":
    sys.exit(main())
