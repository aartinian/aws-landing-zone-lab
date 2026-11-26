"""untagged: resources that miss a required tag, in one account or in every account."""

from lab_tools.aws import accounts, assume, paginate, table

REQUIRED = ["project", "env", "owner", "data-classification", "managed-by"]


def missing(resource: dict) -> list[str]:
    keys = {t["Key"] for t in resource.get("Tags", [])}
    return [k for k in REQUIRED if k not in keys]


def check(sess, account: str) -> list[list]:
    # shortcut: the Tagging API only lists resources that have or had a tag; resources created
    # without any tag are invisible here (AWS Config rule required-tags would catch them)
    tagging = sess.client("resourcegroupstaggingapi")
    rows = []
    for resource in paginate(tagging, "get_resources", "ResourceTagMappingList"):
        if gaps := missing(resource):
            rows.append([account, resource["ResourceARN"], ", ".join(gaps)])
    return rows


def run(sess, args) -> int:
    if args.all_accounts:
        # the management account has no OrganizationAccountAccessRole: use the own session there
        me = sess.client("sts").get_caller_identity()["Account"]
        targets = [
            (a["Name"], sess if a["Id"] == me else assume(sess, a["Id"], args.role_name))
            for a in accounts(sess)
        ]
    else:
        targets = [("current", sess)]
    rows = [row for name, target in targets for row in check(target, name)]
    print(table(["account", "resource", "missing tags"], rows) if rows else "all resources tagged")
    return 1 if rows else 0
