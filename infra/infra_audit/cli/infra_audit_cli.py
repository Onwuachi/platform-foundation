#!/usr/bin/env python3
"""
infra_audit_cli.py

A small Typer-based CLI for checking AWS cost, EBS snapshots, and AMIs
without opening the console. Built to extend infra_audit's existing
terraform_parser.py / log_analyzer.py modules.

Usage:
    python infra_audit_cli.py bill                 # last 30 days cost by service
    python infra_audit_cli.py bill --days 7         # last 7 days
    python infra_audit_cli.py bill --by USAGE_TYPE --filter-service "Amazon Elastic Compute Cloud - Compute" --start 2026-06-01 --end 2026-07-01  # Billing service with date range     
    python infra_audit_cli.py snapshots             # your owned EBS snapshots
    python infra_audit_cli.py snapshots --stale 30  # snapshots older than 30 days
    python infra_audit_cli.py images                # your owned AMIs
    python infra_audit_cli.py images --unused        # AMIs not referenced by any running instance
    python infra_audit_cli.py vpc-audit --vpc-name devopslab-vpc  # VPC audit 
    python infra_audit_cli.py vpc-audit --vpc-name devopslab-vpc --full  # VPC audit full 

Requires: boto3, typer, rich (already in requirements.txt)
Auth: uses your normal AWS credential chain (env vars, ~/.aws/credentials,
SSO profile, etc.) — same as the AWS CLI. Pass --profile to pick a named
profile.
"""

from datetime import datetime, timedelta, timezone

import boto3
import typer
from rich.console import Console
from rich.table import Table
from vpc_audit import find_vpc_id, audit_subnets, audit_security_groups, audit_nat_gateways, audit_igw

app = typer.Typer(help="Quick AWS account checks: cost, snapshots, AMIs.")
console = Console()


def get_session(profile: str | None, region: str) -> boto3.Session:
    if profile:
        return boto3.Session(profile_name=profile, region_name=region)
    return boto3.Session(region_name=region)


@app.command()
def bill(
    days: int = typer.Option(30, help="How many days back to summarize. Ignored if --start is given."),
    start: str = typer.Option(None, help="Start date, YYYY-MM-DD. Overrides --days."),
    end: str = typer.Option(None, help="End date, YYYY-MM-DD (exclusive, per Cost Explorer convention). Defaults to today."),
    daily: bool = typer.Option(False, help="Show DAILY granularity instead of MONTHLY (more buckets, finer detail, same total)."),
    by: str = typer.Option("SERVICE", help="Group by SERVICE, USAGE_TYPE, or INSTANCE_TYPE. Use USAGE_TYPE/INSTANCE_TYPE with --filter-service to drill into one line item."),
    filter_service: str = typer.Option(None, help="Only include this service's cost, e.g. 'Amazon Elastic Compute Cloud - Compute' — pairs with --by USAGE_TYPE to see what's driving it."),
    profile: str = typer.Option(None, help="Named AWS profile to use."),
    region: str = typer.Option("us-east-1", help="Region for the session (Cost Explorer is global, but a session needs one)."),
):
    """Show cost grouped by service (or usage/instance type) for a date range.

    Examples:
        infra_audit_cli.py bill --days 7
        infra_audit_cli.py bill --start 2026-06-01 --end 2026-07-01
        infra_audit_cli.py bill --by USAGE_TYPE --filter-service "Amazon Elastic Compute Cloud - Compute"
    """
    by = by.upper()
    if by not in ("SERVICE", "USAGE_TYPE", "INSTANCE_TYPE"):
        console.print("[red]--by must be SERVICE, USAGE_TYPE, or INSTANCE_TYPE[/red]")
        raise typer.Exit(code=1)

    session = get_session(profile, region)
    ce = session.client("ce")

    if start:
        start_date = datetime.strptime(start, "%Y-%m-%d").date()
    else:
        start_date = datetime.now(timezone.utc).date() - timedelta(days=days)

    if end:
        end_date = datetime.strptime(end, "%Y-%m-%d").date()
    else:
        # Cost Explorer's End is exclusive, so default to tomorrow —
        # otherwise a same-day query (--start today, no --end) reads as
        # an empty [today, today) range and gets rejected below.
        end_date = datetime.now(timezone.utc).date() + timedelta(days=1)

    if start_date >= end_date:
        console.print("[red]--start must be before --end[/red]")
        raise typer.Exit(code=1)

    kwargs = dict(
        TimePeriod={"Start": start_date.isoformat(), "End": end_date.isoformat()},
        Granularity="DAILY" if daily else "MONTHLY",
        Metrics=["UnblendedCost"],
        GroupBy=[{"Type": "DIMENSION", "Key": by}],
    )
    if filter_service:
        kwargs["Filter"] = {"Dimensions": {"Key": "SERVICE", "Values": [filter_service]}}

    resp = ce.get_cost_and_usage(**kwargs)

    # A date range that spans a month boundary returns one ResultsByTime bucket
    # per calendar month (even with MONTHLY granularity picked for the whole
    # range) — so the same key can appear in more than one bucket. Sum across
    # all buckets rather than listing bucket rows directly, otherwise you get
    # duplicate-looking rows like two "EC2 - Other" lines.
    totals: dict[str, float] = {}
    for result in resp["ResultsByTime"]:
        for group in result["Groups"]:
            key = group["Keys"][0]
            amount = float(group["Metrics"]["UnblendedCost"]["Amount"])
            totals[key] = totals.get(key, 0.0) + amount

    rows = [(key, amount) for key, amount in totals.items() if amount != 0]
    rows.sort(key=lambda r: r[1], reverse=True)

    title = f"Cost by {by.lower()}"
    if filter_service:
        title += f" — {filter_service}"
    title += f" — {start_date} to {end_date}"

    table = Table(title=title)
    table.add_column(by.replace("_", " ").title())
    table.add_column("Cost (USD)", justify="right")
    for key, amount in rows:
        table.add_row(key, f"${amount:,.2f}")
    console.print(table)
    console.print(f"[bold]Total: ${sum(a for _, a in rows):,.2f}[/bold]")


@app.command()
def snapshots(
    stale: int = typer.Option(None, help="Only show snapshots older than N days."),
    profile: str = typer.Option(None, help="Named AWS profile to use."),
    region: str = typer.Option("us-east-1", help="Region to check."),
):
    """List EBS snapshots owned by this account, optionally filtered to stale ones."""
    session = get_session(profile, region)
    ec2 = session.client("ec2")

    resp = ec2.describe_snapshots(OwnerIds=["self"])
    now = datetime.now(timezone.utc)

    table = Table(title=f"EBS snapshots — {region}")
    table.add_column("Snapshot ID")
    table.add_column("Volume ID")
    table.add_column("Size (GB)", justify="right")
    table.add_column("Age (days)", justify="right")
    table.add_column("Description")

    shown = 0
    for snap in sorted(resp["Snapshots"], key=lambda s: s["StartTime"]):
        age_days = (now - snap["StartTime"]).days
        if stale is not None and age_days < stale:
            continue
        table.add_row(
            snap["SnapshotId"],
            snap.get("VolumeId", "-"),
            str(snap["VolumeSize"]),
            str(age_days),
            snap.get("Description", "")[:40],
        )
        shown += 1

    console.print(table)
    console.print(f"[bold]{shown} snapshot(s) shown[/bold]")


@app.command()
def images(
    unused: bool = typer.Option(False, help="Only show AMIs not currently used by any running instance."),
    profile: str = typer.Option(None, help="Named AWS profile to use."),
    region: str = typer.Option("us-east-1", help="Region to check."),
):
    """List AMIs owned by this account, optionally filtered to ones with no running instance."""
    session = get_session(profile, region)
    ec2 = session.client("ec2")

    owned_images = ec2.describe_images(Owners=["self"])["Images"]

    in_use_ami_ids = set()
    if unused:
        reservations = ec2.describe_instances(
            Filters=[{"Name": "instance-state-name", "Values": ["running", "pending", "stopping", "stopped"]}]
        )["Reservations"]
        for res in reservations:
            for inst in res["Instances"]:
                in_use_ami_ids.add(inst["ImageId"])

    table = Table(title=f"AMIs — {region}" + (" (unused only)" if unused else ""))
    table.add_column("AMI ID")
    table.add_column("Name")
    table.add_column("Created")
    table.add_column("State")

    shown = 0
    for img in sorted(owned_images, key=lambda i: i.get("CreationDate", "")):
        if unused and img["ImageId"] in in_use_ami_ids:
            continue
        table.add_row(
            img["ImageId"],
            img.get("Name", "")[:40],
            img.get("CreationDate", "")[:10],
            img.get("State", ""),
        )
        shown += 1

    console.print(table)
    console.print(f"[bold]{shown} AMI(s) shown[/bold]")

@app.command(name="vpc-audit")
def vpc_audit_cmd(
    vpc_name: str = typer.Option(None, help="VPC Name tag value, e.g. devopslab-vpc. Use this or --vpc-id."),
    vpc_id: str = typer.Option(None, help="VPC ID, e.g. vpc-041057f0cc0747a4e. Use this or --vpc-name."),
    full: bool = typer.Option(False, help="Also audit security groups and NAT gateways."),
    profile: str = typer.Option(None, help="Named AWS profile to use."),
    region: str = typer.Option("us-east-1", help="Region to check."),
):
    """Audit a VPC's subnets, route tables, security groups, and NAT/IGW setup.

    Classifies each subnet as public/private based on its actual route table
    (0.0.0.0/0 to an IGW vs NAT vs nothing), not just MapPublicIpOnLaunch, and
    flags any mismatch between the two. With --full, also lists security
    groups with rules open to 0.0.0.0/0 and any NAT gateways.

    Examples:
        infra_audit_cli.py vpc-audit --vpc-name devopslab-vpc
        infra_audit_cli.py vpc-audit --vpc-name devopslab-vpc --full
    """
    if not vpc_name and not vpc_id:
        console.print("[red]Provide either --vpc-name or --vpc-id[/red]")
        raise typer.Exit(code=1)
    if vpc_name and vpc_id:
        console.print("[red]Provide only one of --vpc-name or --vpc-id[/red]")
        raise typer.Exit(code=1)

    session = get_session(profile, region)
    ec2 = session.client("ec2")

    resolved_vpc_id = find_vpc_id(ec2, vpc_id, vpc_name)
    subnet_rows = audit_subnets(ec2, resolved_vpc_id)
    igw_id, igw_state = audit_igw(ec2, resolved_vpc_id)

    console.print(f"\n[bold]VPC:[/bold] {resolved_vpc_id}")
    console.print(f"[bold]Internet Gateway:[/bold] {igw_id or '-'} ({igw_state})")

    subnet_table = Table(title="Subnets")
    for col in ["Subnet ID", "AZ", "CIDR", "MapPublicIp", "Route Table", "Classification", "Gateway"]:
        subnet_table.add_column(col)
    for r in subnet_rows:
        subnet_table.add_row(
            r["SubnetId"], r["AZ"], r["CIDR"], str(r["MapPublicIp"]),
            r["RouteTableId"], r["Classification"], r["Gateway"],
        )
    console.print(subnet_table)

    mismatches = [
        r for r in subnet_rows
        if (r["MapPublicIp"] and r["Classification"] != "public (IGW)")
        or (not r["MapPublicIp"] and r["Classification"] == "public (IGW)")
    ]
    if mismatches:
        console.print("\n[red bold]MapPublicIp flag disagrees with actual routing for:[/red bold]")
        for r in mismatches:
            console.print(f"  {r['SubnetId']}: MapPublicIp={r['MapPublicIp']} but routing says {r['Classification']}")

    if full:
        sg_rows = audit_security_groups(ec2, resolved_vpc_id)
        sg_table = Table(title="Security Groups")
        for col in ["Group ID", "Group Name", "Open To World"]:
            sg_table.add_column(col)
        for r in sg_rows:
            sg_table.add_row(r["GroupId"], r["GroupName"], r["OpenToWorld"])
        console.print(sg_table)

        open_sgs = [r for r in sg_rows if r["OpenToWorld"] != "-"]
        if open_sgs:
            console.print("\n[yellow bold]Security groups with rules open to 0.0.0.0/0:[/yellow bold]")
            for r in open_sgs:
                console.print(f"  {r['GroupId']} ({r['GroupName']}): {r['OpenToWorld']}")

        nat_rows = audit_nat_gateways(ec2, resolved_vpc_id)
        nat_table = Table(title="NAT Gateways")
        for col in ["NAT Gateway ID", "State", "Subnet ID", "Public IPs"]:
            nat_table.add_column(col)
        for r in nat_rows:
            nat_table.add_row(r["NatGatewayId"], r["State"], r["SubnetId"], r["PublicIps"])
        console.print(nat_table)
        if not nat_rows:
            console.print("[dim]No NAT gateways found.[/dim]")



if __name__ == "__main__":
    app()



