"""accounts: every active account with its OU (run with the management profile)."""

from lab_tools.aws import accounts, table


def ou_name(org, account_id: str) -> str:
    parent = org.list_parents(ChildId=account_id)["Parents"][0]
    if parent["Type"] != "ORGANIZATIONAL_UNIT":
        return "Root"
    return org.describe_organizational_unit(OrganizationalUnitId=parent["Id"])[
        "OrganizationalUnit"
    ]["Name"]


def run(sess, args) -> int:
    org = sess.client("organizations")
    rows = [[a["Name"], a["Id"], ou_name(org, a["Id"])] for a in accounts(sess)]
    print(table(["account", "id", "ou"], sorted(rows)))
    return 0
