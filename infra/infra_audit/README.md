# infra_audit

Small collection of AWS account-inspection tools, built to answer quick
operational questions without opening the console: "what am I being
billed for," "which EBS snapshots are stale," "which AMIs aren't in use
anymore."

## What's working

### `cli/infra_audit_cli.py`

A [Typer](https://typer.tiangolo.com/) CLI with three commands:

```bash
# Cost by service for the last 30 days
python cli/infra_audit_cli.py bill

# Cost for the last 7 days
python cli/infra_audit_cli.py bill --days 7

# Drill into what's driving EC2 compute cost, by usage type, for a date range
python cli/infra_audit_cli.py bill --by USAGE_TYPE \
  --filter-service "Amazon Elastic Compute Cloud - Compute" \
  --start 2026-06-01 --end 2026-07-01

# EBS snapshots you own
python cli/infra_audit_cli.py snapshots

# Snapshots older than 30 days
python cli/infra_audit_cli.py snapshots --stale 30

# AMIs you own
python cli/infra_audit_cli.py images

# AMIs not referenced by any instance (running, stopped, or otherwise)
python cli/infra_audit_cli.py images --unused
```

Auth uses your normal AWS credential chain (env vars, `~/.aws/credentials`,
SSO profile) — same as the AWS CLI. Pass `--profile` to pick a named
profile, `--region` to target a specific region (defaults to `us-east-1`).

### Setup

```bash
cd infra/infra_audit
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python cli/infra_audit_cli.py --help
```

## What's scaffolded, not built yet

These files exist but are placeholders — worth knowing before you point
someone at this repo as a portfolio piece:

- `cli/terraform_parser.py` — reads a hardcoded sample state file
  (`data/sample_terraform_state.json`) and prints resource
  addresses. Not yet wired to a live/remote Terraform state.
- `cli/log_analyzer.py` — reads a hardcoded sample EC2 inventory file
  (`data/sample_ec2.json`) and prints public/private status per
  instance. Not yet a real log analyzer.
- `utils/aws_helpers.py`, `utils/file_io.py` — empty.
- `tests/test_cli.py`, `tests/test_terraform.py`, `tests/test_log_parser.py`
  — empty. No test coverage yet.

## Roadmap (not committed to, just the logical next steps)

1. Give `terraform_parser.py` a `--state-file` / remote-state option so it
   reads real state instead of the bundled sample
2. Point `log_analyzer.py` at live `describe-instances` output via
   `aws_helpers.py` instead of the sample file
3. Add real tests for the three `infra_audit_cli.py` commands (mock
   `boto3` responses with `moto` or `botocore.stub.Stubber`)
4. Fold `terraform_parser` and `log_analyzer` into the CLI as subcommands
   once they're doing real work, so there's one entry point
