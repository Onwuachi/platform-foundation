#!/usr/bin/env python3
"""
vpc_audit.py
Crawls a VPC's subnets, route tables, security groups, NAT gateways, and
IGW attachment to give a full picture of network exposure - not just the
MapPublicIpOnLaunch flag.

Usage:
    python vpc_audit.py --profile platform-foundation --vpc-name devopslab-vpc
    python vpc_audit.py --profile platform-foundation --vpc-id vpc-041057f0cc0747a4e
    python vpc_audit.py --profile platform-foundation --vpc-name devopslab-vpc --full
"""
import argparse
import boto3
from botocore.exceptions import ClientError


def get_session(profile):
    return boto3.Session(profile_name=profile)


def find_vpc_id(ec2, vpc_id, vpc_name):
    if vpc_id:
        return vpc_id
    resp = ec2.describe_vpcs(Filters=[{"Name": "tag:Name", "Values": [vpc_name]}])
    vpcs = resp.get("Vpcs", [])
    if not vpcs:
        raise SystemExit(f"No VPC found with tag:Name={vpc_name}")
    if len(vpcs) > 1:
        raise SystemExit(f"Multiple VPCs found with tag:Name={vpc_name}, pass --vpc-id explicitly")
    return vpcs[0]["VpcId"]


def classify_route_table(rt):
    """
    Inspect a route table's routes for a 0.0.0.0/0 target.
    Returns one of: 'public (IGW)', 'private (NAT)', 'private (no default route)'
    """
    for route in rt.get("Routes", []):
        if route.get("DestinationCidrBlock") == "0.0.0.0/0":
            gw = route.get("GatewayId", "")
            nat = route.get("NatGatewayId", "")
            if gw.startswith("igw-"):
                return "public (IGW)", gw
            if nat:
                return "private (NAT)", nat
    return "private (no default route)", "-"


def audit_subnets(ec2, vpc_id):
    subnets = ec2.describe_subnets(
        Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
    )["Subnets"]

    route_tables = ec2.describe_route_tables(
        Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
    )["RouteTables"]

    main_rt = None
    subnet_to_rt = {}
    for rt in route_tables:
        for assoc in rt.get("Associations", []):
            if assoc.get("Main"):
                main_rt = rt
            sid = assoc.get("SubnetId")
            if sid:
                subnet_to_rt[sid] = rt

    rows = []
    for subnet in subnets:
        sid = subnet["SubnetId"]
        rt = subnet_to_rt.get(sid, main_rt)
        if rt is None:
            classification, gw_target = "unknown (no route table)", "-"
        else:
            classification, gw_target = classify_route_table(rt)

        rows.append({
            "SubnetId": sid,
            "AZ": subnet["AvailabilityZone"],
            "CIDR": subnet["CidrBlock"],
            "MapPublicIp": subnet["MapPublicIpOnLaunch"],
            "RouteTableId": rt["RouteTableId"] if rt else "-",
            "Classification": classification,
            "Gateway": gw_target,
        })

    return rows


def audit_security_groups(ec2, vpc_id):
    sgs = ec2.describe_security_groups(
        Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
    )["SecurityGroups"]

    rows = []
    for sg in sgs:
        open_rules = []
        for perm in sg.get("IpPermissions", []):
            for ip_range in perm.get("IpRanges", []):
                if ip_range.get("CidrIp") == "0.0.0.0/0":
                    proto = perm.get("IpProtocol", "-1")
                    from_port = perm.get("FromPort", "all")
                    to_port = perm.get("ToPort", "all")
                    if proto == "-1":
                        open_rules.append("ALL traffic")
                    elif from_port == to_port:
                        open_rules.append(f"{proto}/{from_port}")
                    else:
                        open_rules.append(f"{proto}/{from_port}-{to_port}")

        rows.append({
            "GroupId": sg["GroupId"],
            "GroupName": sg["GroupName"],
            "OpenToWorld": ", ".join(open_rules) if open_rules else "-",
        })

    return rows


def audit_nat_gateways(ec2, vpc_id):
    nats = ec2.describe_nat_gateways(
        Filters=[{"Name": "vpc-id", "Values": [vpc_id]}]
    )["NatGateways"]

    rows = []
    for nat in nats:
        eips = [addr.get("PublicIp", "-") for addr in nat.get("NatGatewayAddresses", [])]
        rows.append({
            "NatGatewayId": nat["NatGatewayId"],
            "State": nat["State"],
            "SubnetId": nat.get("SubnetId", "-"),
            "PublicIps": ", ".join(eips) if eips else "-",
        })

    return rows


def audit_igw(ec2, vpc_id):
    igws = ec2.describe_internet_gateways(
        Filters=[{"Name": "attachment.vpc-id", "Values": [vpc_id]}]
    )["InternetGateways"]

    if not igws:
        return None, "not attached"

    igw = igws[0]
    state = "unknown"
    for attach in igw.get("Attachments", []):
        if attach.get("VpcId") == vpc_id:
            state = attach.get("State", "unknown")
    return igw["InternetGatewayId"], state


def audit(profile, vpc_id, vpc_name):
    session = get_session(profile)
    ec2 = session.client("ec2")

    resolved_vpc_id = find_vpc_id(ec2, vpc_id, vpc_name)

    subnet_rows = audit_subnets(ec2, resolved_vpc_id)
    sg_rows = audit_security_groups(ec2, resolved_vpc_id)
    nat_rows = audit_nat_gateways(ec2, resolved_vpc_id)
    igw_id, igw_state = audit_igw(ec2, resolved_vpc_id)

    return resolved_vpc_id, subnet_rows, sg_rows, nat_rows, igw_id, igw_state


def print_generic_table(rows, headers, title):
    print(f"\n{title}\n")
    if not rows:
        print("  (none)")
        return
    widths = {h: max(len(h), max((len(str(r[h])) for r in rows), default=0)) for h in headers}

    def fmt_row(vals):
        return " | ".join(str(vals[h]).ljust(widths[h]) for h in headers)

    sep = "-+-".join("-" * widths[h] for h in headers)
    print(fmt_row({h: h for h in headers}))
    print(sep)
    for r in rows:
        print(fmt_row(r))


def print_report(vpc_id, subnet_rows, sg_rows, nat_rows, igw_id, igw_state, full):
    print(f"\nVPC: {vpc_id}")
    print(f"Internet Gateway: {igw_id or '-'} ({igw_state})")

    print_generic_table(
        subnet_rows,
        ["SubnetId", "AZ", "CIDR", "MapPublicIp", "RouteTableId", "Classification", "Gateway"],
        "Subnets",
    )

    mismatches = [
        r for r in subnet_rows
        if (r["MapPublicIp"] and r["Classification"] != "public (IGW)")
        or (not r["MapPublicIp"] and r["Classification"] == "public (IGW)")
    ]
    if mismatches:
        print("\n[!] MapPublicIp flag disagrees with actual routing for:")
        for r in mismatches:
            print(f"  {r['SubnetId']}: MapPublicIp={r['MapPublicIp']} but routing says {r['Classification']}")

    if full:
        print_generic_table(
            sg_rows,
            ["GroupId", "GroupName", "OpenToWorld"],
            "Security Groups",
        )
        open_sgs = [r for r in sg_rows if r["OpenToWorld"] != "-"]
        if open_sgs:
            print("\n[!] Security groups with rules open to 0.0.0.0/0:")
            for r in open_sgs:
                print(f"  {r['GroupId']} ({r['GroupName']}): {r['OpenToWorld']}")

        print_generic_table(
            nat_rows,
            ["NatGatewayId", "State", "SubnetId", "PublicIps"],
            "NAT Gateways",
        )


def main():
    parser = argparse.ArgumentParser(description="Audit a VPC's subnets, route tables, security groups, and NAT/IGW setup")
    parser.add_argument("--profile", required=True, help="AWS CLI profile name")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--vpc-id", help="VPC ID, e.g. vpc-041057f0cc0747a4e")
    group.add_argument("--vpc-name", help="VPC Name tag value, e.g. devopslab-vpc")
    parser.add_argument("--full", action="store_true", help="Also audit security groups and NAT gateways")
    args = parser.parse_args()

    try:
        vpc_id, subnet_rows, sg_rows, nat_rows, igw_id, igw_state = audit(
            args.profile, args.vpc_id, args.vpc_name
        )
    except ClientError as e:
        raise SystemExit(f"AWS error: {e}")

    print_report(vpc_id, subnet_rows, sg_rows, nat_rows, igw_id, igw_state, args.full)


if __name__ == "__main__":
    main()
