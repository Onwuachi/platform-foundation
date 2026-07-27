# Cheatsheet: `platform register` / `.domain` Files & Why Manual S3 Edits Are Sometimes Needed

## The command

```bash
echo -n "onwuachi.com,www.onwuachi.com" | aws s3 cp - s3://platform-api-services/platform/services/hugo.domain
```

## Why this exists — the chain

```text
S3: platform/services/<service>.domain   (source of truth)
        ↓ (aws s3 sync --delete, every rehydrate)
Instance: /opt/platform/services/<service>.domain
        ↓ (read by platform-render-haproxy.sh)
/etc/haproxy/domain.map                  (regenerated every rehydrate — never edit directly)
```

`domain.map` on the live instance is **fully disposable**. It gets rebuilt from scratch on every `platform-rehydrate.sh` run:

* Every boot
* Every AMI swap
* Every manual `platform rehydrate`

Editing `domain.map` directly with `tee`, `vim`, or another editor works only until the next rehydrate. The change is not durable.

The durable fix is upstream, in the `.domain` file stored in S3.

---

## Why `hugo.domain` was wrong in the first place

`platform register <service> <port> <domain>` writes whatever domain string is passed, verbatim, once.

There is no separate command that updates an existing service's domain in place. The available operations are effectively:

* `register` — writes or overwrites the service registration
* `deregister` — removes the service registration

`platform-render-haproxy.sh` supports comma-separated multi-domain values through `IFS=','`.

That support was added after `hugo` was originally registered with only:

```text
onwuachi.com
```

Nothing automatically retroactively modified the existing S3 source-of-truth file.

The correct durable value is:

```text
onwuachi.com,www.onwuachi.com
```

---

## When you may need to update a `.domain` file again

Use the source-of-truth S3 object when:

* Adding a new subdomain or alias to an existing service
* Correcting a `.domain` file
* Correcting a `.port` file
* Correcting another per-service configuration value that is synchronized from S3
* Fixing a configuration problem that would otherwise be reintroduced during rehydrate

For a normal registration update, re-registering the service with the complete domain list is preferred when supported by the platform CLI.

---

# Backup and Restore Gotcha

The daily snapshot workflow:

```text
GitHub Actions
    ↓
platform-state-backup.yml
    ↓
aws s3 sync
    ↓
s3://platform-api-services
```

The backup workflow runs daily at approximately:

```text
07:00 UTC
```

The entire `platform-api-services` bucket is synchronized into the backup snapshot.

Any snapshot created **before a known configuration fix** may still contain the broken configuration.

For example, snapshots dated:

```text
≤ 2026-07-24
```

may contain the previous incorrect `hugo.domain` value.

The restore operation performs a full synchronization back into the primary state:

```text
platform restore-from-backup <date>
        ↓
full aws s3 sync --delete
        ↓
primary platform-api-services bucket
```

The restore process does not know that a specific file was subsequently fixed. If an older snapshot contains a stale file, restoring that snapshot can intentionally reintroduce the older configuration.

### Rule of thumb

> After restoring from a snapshot created before a known configuration fix, re-check the affected `.domain`, `.port`, or configuration file.

---

# Phase 4 Network Architecture

The platform now contains a two-tier VPC network architecture.

```text
VPC
10.50.0.0/16
│
├── Public Tier
│   │
│   ├── us-east-1a
│   │   └── 10.50.1.0/24
│   │
│   ├── us-east-1b
│   │   └── 10.50.2.0/24
│   │
│   └── Public Route Table
│       ├── 10.50.0.0/16 → local
│       └── 0.0.0.0/0 → Internet Gateway
│
└── Private Tier
    │
    ├── us-east-1a
    │   └── 10.50.3.0/24
    │
    ├── us-east-1b
    │   └── 10.50.4.0/24
    │
    └── Private Route Table
        └── 10.50.0.0/16 → local
```

## Current subnet allocation

| Tier    | Availability Zone | CIDR           | Public IP on Launch |
| ------- | ----------------- | -------------- | ------------------- |
| Public  | us-east-1a        | `10.50.1.0/24` | Yes                 |
| Public  | us-east-1b        | `10.50.2.0/24` | Yes                 |
| Private | us-east-1a        | `10.50.3.0/24` | No                  |
| Private | us-east-1b        | `10.50.4.0/24` | No                  |

## Private tier design

The private subnets intentionally have:

* No route to the Internet Gateway
* No NAT Gateway
* No VPC Interface Endpoints
* No VPC Gateway Endpoints
* No public IP assignment on launch

The private route table currently contains only the implicit VPC-local route:

```text
10.50.0.0/16 → local
```

This means the private tier currently has **no internet egress path**.

The subnets are not completely isolated from the VPC. The VPC-local route allows communication between resources according to normal AWS routing and security controls.

The private tier currently exists as an architectural boundary for future workloads.

---

## Cost posture

The Phase 4 private subnet architecture intentionally introduces no recurring networking services beyond the standard VPC/subnet resources.

No additional cost-generating components were introduced:

* No NAT Gateway
* No VPC Interface Endpoint
* No VPC Gateway Endpoint
* No additional EC2 workloads

This provides the architectural representation of a private application/data tier while preserving the platform's current cost-control objective.

> The private subnet tier is intentionally infrastructure-ready but workload-empty.

Future private workloads will require an explicit connectivity decision before deployment.

Possible future options include:

* NAT Gateway for controlled internet egress
* VPC Interface Endpoints for private AWS service access
* VPC Gateway Endpoints where applicable
* Transit Gateway
* VPN
* PrivateLink
* Other private connectivity patterns

Any of these additions should be evaluated for both operational need and recurring AWS cost before implementation.

---

# Recovery Validation Notes

The platform has validated both default and explicit-date restore workflows.

Validated restore paths include:

```text
platform restore-from-backup
```

and:

```text
platform restore-from-backup 2026-07-19
```

The explicit-date restore was intentionally tested against a historical snapshot rather than relying only on the latest snapshot path.

After restore validation, the platform health checks confirmed:

* EC2 instance healthy
* HAProxy healthy
* Docker healthy
* All four platform containers healthy
* HTTPS responding
* Recovery signal file generated successfully

Example recovery signal:

```text
content/signals/restored-from-backup-223454.md
```

The restore test also confirmed that the recovery workflow records the restoration event as expected.

---

# Important Restore State Consideration

An explicit-date restore can leave the platform operating from the selected historical snapshot.

For example:

```text
platform restore-from-backup 2026-07-19
```

does not automatically mean the platform is returned to the latest available state afterward.

After testing an older restore point, deliberately decide whether to:

```bash
platform restore-from-backup
```

to return to the latest snapshot, or leave the platform on the historical snapshot if that state is intentional.

Before considering recovery testing complete, verify:

```text
Current platform state
Current snapshot date
Expected service registrations
Expected domain mappings
Expected application configuration
Expected platform health
```

---

# Operational Principle

The platform follows this general model:

```text
S3
Source of Truth
    ↓
Backup Snapshot
    ↓
Restore
    ↓
S3 Primary State
    ↓
Platform Rehydrate
    ↓
Live Instance
    ↓
Generated Runtime Configuration
```

Changes made only to generated runtime configuration are temporary.

Changes made to the source-of-truth S3 configuration are durable and become part of future rehydration and backup cycles.

Changes to infrastructure architecture should be represented in Terraform and validated with:

```bash
terraform plan
```

followed by AWS-side validation where appropriate.

This separation between **source of truth**, **backup state**, **infrastructure definition**, and **generated runtime configuration** is a core operational design principle of the platform.

