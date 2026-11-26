"""lab: small read-only tools for the landing zone. Add a command: one file with run(), one line
in COMMANDS, its options below."""

import argparse

from lab_tools import accounts, findings, subnets, untagged
from lab_tools.aws import session

COMMANDS = {
    "accounts": accounts,
    "subnets": subnets,
    "untagged": untagged,
    "findings": findings,
}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="lab", description=__doc__)
    parser.add_argument("--profile", help="AWS profile (default: environment)")
    parser.add_argument("--region", default="eu-central-2")
    sub = parser.add_subparsers(dest="command", required=True)
    for name, module in COMMANDS.items():
        sub.add_parser(name, help=module.__doc__.split(":", 1)[1].strip())

    sub.choices["subnets"].add_argument("--threshold", type=float, default=80, help="warn at %%")
    sub.choices["untagged"].add_argument(
        "--all-accounts", action="store_true", help="every account (management profile)"
    )
    sub.choices["untagged"].add_argument("--role-name", default="OrganizationAccountAccessRole")

    args = parser.parse_args(argv)
    return COMMANDS[args.command].run(session(args.profile, args.region), args)
