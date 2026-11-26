"""subnets: IP usage per subnet, warning above a threshold (owner sees all, participants theirs)."""

from lab_tools.aws import paginate, table

RESERVED = 5  # AWS keeps 5 addresses in every subnet (network, router, DNS, future, broadcast)


def usage(subnet: dict) -> tuple[int, int, float]:
    """(usable, used, percent used) of one subnet from describe_subnets."""
    usable = 2 ** (32 - int(subnet["CidrBlock"].split("/")[1])) - RESERVED
    used = usable - subnet["AvailableIpAddressCount"]
    return usable, used, round(100 * used / usable, 1)


def run(sess, args) -> int:
    rows, warn = [], False
    for subnet in paginate(sess.client("ec2"), "describe_subnets", "Subnets"):
        usable, used, pct = usage(subnet)
        flag = "WARN" if pct >= args.threshold else ""
        warn = warn or bool(flag)
        rows.append(
            [
                subnet["SubnetId"],
                subnet["CidrBlock"],
                subnet["AvailabilityZoneId"],
                usable,
                used,
                f"{pct}%",
                flag,
            ]
        )
    print(table(["subnet", "cidr", "az", "usable", "used", "used %", ""], sorted(rows)))
    return 1 if warn else 0
