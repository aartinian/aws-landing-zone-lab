# lab-tools

Small read-only boto3 tools, one file per command in `src/lab_tools/`, shared helpers in
`aws.py` (session, paginator, list accounts, assume a role, print a table). Exit code 1 when
something needs attention, so a command can gate a job.

| Command | Run with | Shows |
|---|---|---|
| `accounts` | management | every active account with its OU |
| `subnets [--threshold 80]` | network (all subnets) or a workload account (its shared subnets) | usable and used IPs per subnet, `WARN` above the threshold |
| `untagged [--all-accounts]` | any account; `--all-accounts` from management | resources missing a required tag |
| `findings` | security-tooling | open Security Hub findings per account and severity (GuardDuty included) |

```bash
cd tools/lab-tools
uv run lab --profile lab-management accounts
uv run lab --profile lab-network subnets
uv run lab --profile lab-management untagged --all-accounts
uv run lab --profile lab-security-tooling findings
uv run pytest            # moto: no AWS calls
```

New command: a file `src/lab_tools/<name>.py` with a docstring `"<name>: what it shows"` and
`run(sess, args) -> int`, one line in `COMMANDS` in `cli.py`, a test in `tests/`.
