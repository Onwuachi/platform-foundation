---
title: "Adding a vpc-audit command to infra_audit_cli.py"
date: 2026-08-07
description: "Built a VPC subnet/route-table/security-group/NAT auditor and wired it into the existing Typer CLI"
tags: ["aws", "vpc", "networking", "cli", "typer", "security-groups"]
categories: ["infrastructure"]
summary: "Added a vpc-audit subcommand to infra_audit_cli.py that classifies subnets as public/private from actual route tables (not just MapPublicIpOnLaunch), flags security groups open to 0.0.0.0/0, and lists NAT gateways — replacing manual describe-subnets/describe-route-tables/describe-security-groups console checks."
---

## Problem

Checking whether a VPC's subnets were actually public or private meant manually running `describe-vpcs`, `describe-subnets`, and cross-referencing `describe-route-tables` by hand to find the `0.0.0.0/0` route target for each subnet. `MapPublicIpOnLaunch` alone isn't reliable — a subnet can have it set `False` but still route to an IGW, or vice versa. Security group audits (checking for rules open to the world) and NAT gateway inventory were separate manual `describe-security-groups` calls on top of that. No single command answered "is this VPC actually locked down the way I think it is."

## Approach

Built `vpc_audit.py` as a standalone script first, then folded it into the existing `infra_audit_cli.py` Typer CLI once validated against the real `devopslab-vpc`.

- **Subnet classification**: for each subnet, resolve its actual route table (explicit association, or fall back to the VPC's main/default table — same resolution AWS itself uses) and inspect it for a `0.0.0.0/0` route. Target `igw-*` → `public (IGW)`; a NAT Gateway ID → `private (NAT)`; no default route → `private (no default route)`.
- **Mismatch detection**: flag any subnet where `MapPublicIpOnLaunch` disagrees with the routing-derived classification, since that's the actual gap between assumption and reality.
- **Security groups**: list every SG in the VPC and flag any ingress rule with a CIDR of `0.0.0.0/0`, reporting the protocol/port (e.g. `tcp/22`) rather than just a yes/no.
- **NAT gateways**: list any NAT gateways with state, subnet, and associated EIPs.
- **IGW attachment**: confirm the Internet Gateway is actually attached to the VPC, not just referenced by a route.

Kept the AWS-calling functions (`find_vpc_id`, `audit_subnets`, `audit_security_groups`, `audit_nat_gateways`, `audit_igw`) separate from the presentation layer so `vpc_audit.py` still works standalone with plain-text tables, while `infra_audit_cli.py` imports the same functions and renders through Rich to match the styling of the existing `bill`/`snapshots`/`images` commands.

One integration mistake during the port: the new `@app.command(name="vpc-audit")` function got pasted after `if __name__ == "__main__(): app()` in the file, making it dead code Typer never registered (`No such command 'vpc-audit'`). Fixed by moving the command definition above the `if __name__` guard.

## Result

```
python infra_audit_cli.py vpc-audit --vpc-name devopslab-vpc
python infra_audit_cli.py vpc-audit --vpc-name devopslab-vpc --full
```

Validated live against `devopslab-vpc` (`vpc-041057f0cc0747a4e`):

- Both public subnets correctly classified `public (IGW)`, both private subnets `private (no default route)` — matches the known state (public subnets only, no NAT/VPC endpoints yet).
- Zero MapPublicIp/routing mismatches.
- `--full` correctly flagged `ops-sg`, `web-sg`, `wordpress-sg` (expected, public web tier on 80/443) and confirmed `dop-lab-sg` only exposes `tcp/80` to the world — its port 22 rule (scoped to a single `/32`) was correctly *not* flagged.
- `default` SG showed no open rules, as expected for an unmodified default.
- NAT gateway check correctly returned empty, matching the current no-NAT VPC design.

`vpc_audit.py` lives alongside `infra_audit_cli.py` in `cli/` and is imported directly (no duplicated AWS logic between the standalone script and the CLI command).
