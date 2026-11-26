from types import SimpleNamespace

from lab_tools import accounts, findings, subnets, untagged
from lab_tools.aws import table


def test_accounts_lists_ou_of_each_account(sess, capsys):
    org = sess.client("organizations")
    org.create_organization(FeatureSet="ALL")
    root = org.list_roots()["Roots"][0]["Id"]
    ou = org.create_organizational_unit(ParentId=root, Name="Workloads")["OrganizationalUnit"]
    acct = org.create_account(AccountName="workload-dev", Email="dev@example.com")
    acct_id = acct["CreateAccountStatus"]["AccountId"]
    org.move_account(AccountId=acct_id, SourceParentId=root, DestinationParentId=ou["Id"])

    assert accounts.run(sess, SimpleNamespace()) == 0
    out = capsys.readouterr().out
    assert "workload-dev" in out and "Workloads" in out


def test_subnet_usage_keeps_5_reserved_addresses():
    usable, used, pct = subnets.usage({"CidrBlock": "10.0.0.0/24", "AvailableIpAddressCount": 241})
    assert (usable, used, pct) == (251, 10, 4.0)


def test_subnets_warns_above_threshold(sess, capsys):
    ec2 = sess.client("ec2")
    vpc = ec2.create_vpc(CidrBlock="10.0.0.0/16")["Vpc"]["VpcId"]
    ec2.create_subnet(VpcId=vpc, CidrBlock="10.0.0.0/28")  # 11 usable, all free
    assert subnets.run(sess, SimpleNamespace(threshold=80)) == 0
    assert subnets.run(sess, SimpleNamespace(threshold=0)) == 1  # 0 % >= 0 %: warns
    assert "WARN" in capsys.readouterr().out


def test_missing_reports_required_tags_not_set():
    resource = {"Tags": [{"Key": "project", "Value": "x"}, {"Key": "env", "Value": "dev"}]}
    assert untagged.missing(resource) == ["owner", "data-classification", "managed-by"]


def test_untagged_finds_bucket_without_required_tags(sess, capsys):
    s3 = sess.client("s3")
    s3.create_bucket(
        Bucket="half-tagged", CreateBucketConfiguration={"LocationConstraint": "eu-central-2"}
    )
    s3.put_bucket_tagging(Bucket="half-tagged", Tagging={"TagSet": [{"Key": "env", "Value": "x"}]})
    assert untagged.run(sess, SimpleNamespace(all_accounts=False)) == 1
    assert "half-tagged" in capsys.readouterr().out


def test_findings_counted_per_account_and_severity():
    raw = [
        {"AwsAccountId": "1", "Severity": {"Label": "HIGH"}},
        {"AwsAccountId": "1", "Severity": {"Label": "HIGH"}},
        {"AwsAccountId": "2", "Severity": {"Label": "LOW"}},
    ]
    counts = findings.count(raw)
    assert counts["1"]["HIGH"] == 2 and counts["2"]["LOW"] == 1 and counts["2"]["HIGH"] == 0


def test_table_aligns_columns():
    assert table(["a", "bb"], [["xxx", 1]]).splitlines() == ["a    bb", "---  --", "xxx  1"]


def test_untagged_all_accounts_uses_own_session_for_management(sess, monkeypatch, capsys):
    org = sess.client("organizations")
    org.create_organization(FeatureSet="ALL")
    org.create_account(AccountName="workload-dev", Email="dev@example.com")
    assumed = []
    monkeypatch.setattr(
        untagged, "assume", lambda s, account_id, role: assumed.append(account_id) or s
    )

    assert untagged.run(sess, SimpleNamespace(all_accounts=True, role_name="r")) == 0
    me = sess.client("sts").get_caller_identity()["Account"]
    assert me not in assumed and len(assumed) == 1
