"""Shared helpers: every command starts from a session and maybe assumes a role per account."""

from collections.abc import Iterator

import boto3

REGION = "eu-central-2"


def session(profile: str | None, region: str = REGION) -> boto3.Session:
    return boto3.Session(profile_name=profile, region_name=region)


def paginate(client, operation: str, key: str, **kwargs) -> Iterator[dict]:
    """Every item of a paginated list call, e.g. paginate(org, "list_accounts", "Accounts")."""
    for page in client.get_paginator(operation).paginate(**kwargs):
        yield from page[key]


def accounts(sess: boto3.Session) -> list[dict]:
    """Active accounts of the organization (needs a management account session)."""
    org = sess.client("organizations")
    return [a for a in paginate(org, "list_accounts", "Accounts") if a["Status"] == "ACTIVE"]


def assume(sess: boto3.Session, account_id: str, role_name: str) -> boto3.Session:
    """A session in another account, through a role that trusts the current one."""
    creds = sess.client("sts").assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{role_name}",
        RoleSessionName="lab-tools",
    )["Credentials"]
    return boto3.Session(
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
        region_name=sess.region_name,
    )


def table(headers: list[str], rows: list[list]) -> str:
    """Plain-text table with aligned columns."""
    cells = [headers] + [[str(c) for c in row] for row in rows]
    widths = [max(len(row[i]) for row in cells) for i in range(len(headers))]
    lines = ["  ".join(c.ljust(w) for c, w in zip(row, widths, strict=True)) for row in cells]
    lines.insert(1, "  ".join("-" * w for w in widths))
    return "\n".join(line.rstrip() for line in lines)
