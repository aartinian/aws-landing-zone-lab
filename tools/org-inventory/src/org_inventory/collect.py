"""Read-only AWS calls: one AccountFacts per member account."""

from collections.abc import Callable

import boto3
from botocore.exceptions import BotoCoreError, ClientError

from org_inventory.checks import AccountFacts

ADMIN_ACCOUNT = "security-tooling"


def _try(facts: AccountFacts, check: str, read: Callable[[], object]) -> object | None:
    """Run one read; a failure is recorded on the account instead of stopping the run."""
    try:
        return read()
    except (ClientError, BotoCoreError) as error:
        code = getattr(error, "response", {}).get("Error", {}).get("Code", type(error).__name__)
        facts.errors[check] = code
        return None


def assume(session: boto3.Session, account_id: str, role_name: str, region: str) -> boto3.Session:
    creds = session.client("sts").assume_role(
        RoleArn=f"arn:aws:iam::{account_id}:role/{role_name}",
        RoleSessionName="org-inventory",
    )["Credentials"]
    return boto3.Session(
        aws_access_key_id=creds["AccessKeyId"],
        aws_secret_access_key=creds["SecretAccessKey"],
        aws_session_token=creds["SessionToken"],
        region_name=region,
    )


def _ou_name(org, account_id: str) -> str:
    parent = org.list_parents(ChildId=account_id)["Parents"][0]
    if parent["Type"] != "ORGANIZATIONAL_UNIT":
        return "Root"
    return org.describe_organizational_unit(OrganizationalUnitId=parent["Id"])[
        "OrganizationalUnit"
    ]["Name"]


def _member_status(admin: boto3.Session) -> tuple[dict[str, str], dict[str, str]]:
    """GuardDuty and Security Hub membership as seen by the delegated admin."""
    guardduty = admin.client("guardduty")
    detector = guardduty.list_detectors()["DetectorIds"][0]
    gd: dict[str, str] = {}
    for page in guardduty.get_paginator("list_members").paginate(
        DetectorId=detector, OnlyAssociated="false"
    ):
        gd |= {m["AccountId"]: m["RelationshipStatus"] for m in page["Members"]}

    sh: dict[str, str] = {}
    for page in (
        admin.client("securityhub").get_paginator("list_members").paginate(OnlyAssociated=False)
    ):
        sh |= {m["AccountId"]: m["MemberStatus"] for m in page["Members"]}
    return gd, sh


def collect(session: boto3.Session, role_name: str, region: str) -> list[AccountFacts]:
    org = session.client("organizations")
    management_id = org.describe_organization()["Organization"]["MasterAccountId"]
    accounts = [
        account
        for page in org.get_paginator("list_accounts").paginate()
        for account in page["Accounts"]
        if account["Id"] != management_id
    ]

    admin_id = next((a["Id"] for a in accounts if a["Name"] == ADMIN_ACCOUNT), None)
    gd: dict[str, str] = {}
    sh: dict[str, str] = {}
    member_error: str | None = None
    if admin_id:
        try:
            gd, sh = _member_status(assume(session, admin_id, role_name, region))
        except (ClientError, BotoCoreError) as error:
            member_error = type(error).__name__

    result = []
    for account in accounts:
        facts = AccountFacts(account["Name"], account["Id"], account["Status"])
        result.append(facts)
        if account["Status"] != "ACTIVE":
            continue

        if account["Id"] == admin_id:
            facts.guardduty = facts.securityhub = "ADMIN"
        elif member_error:
            facts.errors["guardduty"] = facts.errors["security hub"] = member_error
        else:
            facts.guardduty = gd.get(account["Id"])
            facts.securityhub = sh.get(account["Id"])

        _collect_account(session, org, facts, role_name, region)

    return result


def _collect_account(
    session: boto3.Session, org, facts: AccountFacts, role_name: str, region: str
) -> None:
    """Organization data from the management account, the rest from inside the account."""
    account_id = facts.account_id
    facts.ou = _try(facts, "ou", lambda: _ou_name(org, account_id))
    tags = _try(facts, "tags", lambda: org.list_tags_for_resource(ResourceId=account_id))
    facts.tags = {t["Key"]: t["Value"] for t in (tags or {}).get("Tags", [])}
    facts.zurich = _try(
        facts,
        "zurich",
        lambda: session.client("account").get_region_opt_status(
            AccountId=account_id, RegionName=region
        )["RegionOptStatus"],
    )

    member = _try(
        facts, "s3 block public access", lambda: assume(session, account_id, role_name, region)
    )
    if member is None:
        facts.errors["budget"] = facts.errors["s3 block public access"]
        return
    facts.public_access_block = _try(
        facts,
        "s3 block public access",
        lambda: member.client("s3control").get_public_access_block(AccountId=account_id)[
            "PublicAccessBlockConfiguration"
        ],
    )
    budgets = _try(
        facts, "budget", lambda: member.client("budgets").describe_budgets(AccountId=account_id)
    )
    facts.budgets = None if budgets is None else len(budgets.get("Budgets", []))
