## Platform Foundation

Production AWS platform · Personal lab · Active development

A single-engineer AWS platform implementing immutable infrastructure, declarative runtime state, and a self-rehydrating control plane. The platform rebuilds its entire runtime deterministically from a single source of truth — no manual steps required.

Built and operated end-to-end: AMI → edge routing → CI/CD → disaster recovery → observability → documentation.

What makes it real: This isn't a tutorial follow-along. It's a working platform that has been destroyed and recovered, scaled and broken, monitored and debugged. Every design decision came from an operational constraint.

Stack: Terraform · Packer · Docker · HAProxy · GitHub Actions (OIDC) · Prometheus · Grafana · Blackbox Exporter · Hugo · AWS SSM · ECR · S3 · Route53 · CloudFront · ACM

Architecture highlights:

    Packer builds immutable AMIs → SSM Parameter Store hands off to Terraform (no hardcoded IDs)
    Clear ownership boundary: Terraform owns infrastructure, S3 owns runtime state, platform-rehydrate owns recovery
    Full node loss recovery: terraform apply + platform-rehydrate → platform online, zero manual steps
    HAProxy with dynamic backend maps (rendered from S3, not static config)
    GitHub Actions authenticates via OIDC — no long-lived AWS credentials anywhere
    This portfolio site (onwua.com) is part of the platform: Hugo → S3 → CloudFront, deployed on every push

View on GitHub →

## Lanner NCA: Onsite UC Appliance Architecture & Deployment System

Production hardware deployment · Architecture & operations design

Designed and documented a standardized deployment and recovery architecture for containerized UC appliances running on Lanner NCA hardware in isolated customer environments. This wasn't a build-and-hand-off task — it was taking a loosely-defined deployment problem and building an architecture, deployment model, operational standard, and recovery process around it.

What was actually built:

    Analyzed the legacy deployment model and identified operational and recovery risks
    Designed artifact distribution flow using GCP Artifact Registry, controlled service accounts, and jumphost-based secure transfers
    Designed access model using reverse SSH tunnel architecture for remote administration in isolated environments
    Standardized Ubuntu 24.04 deployment with Docker-based host-networked UC workloads
    Created deterministic rebuild procedures and operational runbooks

Stack: Docker · Ubuntu 24.04 · GCP Artifact Registry · SSH tunneling · Bash

---

## Production Fleet OS Upgrade at Scale

**Large-scale Linux upgrade · Production incident RCA · Internal engineering initiative**

Planned and executed an in-place Ubuntu 20.04 → 24.04 upgrade across a large production fleet of cloud instances and physical edge appliances, with zero unplanned downtime across the rollout.

**What was actually built:**
- Designed and validated a repeatable multi-hop upgrade path across mixed instance types, including legacy hardware with non-standard boot configurations
- Built a pre-flight and post-upgrade validation checklist covering OS, container runtime, storage, and application-layer health
- Root-caused an upstream container runtime regression that silently lowered a critical resource limit under production load, then shipped a fleet-wide fix and folded detection into the standard validation checklist
- Coordinated zero-downtime execution across dozens of production hosts using a consistent, auditable procedure

**Stack:** Ubuntu · Docker · Terraform · systemd · Bash

---

## TLS & Certificate Lifecycle Operations

**Zero-downtime TLS operations · Root-cause certificate troubleshooting · Internal engineering initiative**

Designed and operated certificate lifecycle processes across a multi-environment production platform — from routine zero-downtime reverse-proxy renewals to a from-scratch root-cause fix of a client VPN TLS handshake failure.

**What was actually built:**
- Documented and operated a zero-downtime certificate renewal and reload process across production, staging, and dev environments
- Diagnosed a client VPN TLS handshake failure to a missing certificate Key Usage/Extended Key Usage extension — a root cause that looked like a networking issue but wasn't
- Reissued a properly-specified certificate chain and rebuilt the client configuration as a validated reference baseline

**Stack:** HAProxy · OpenSSL · AWS ACM · AWS Client VPN · OpenVPN

---

## Live Multi-Tenant Environment Migration (Zero Downtime)

**Production data migration · Single-active-processor architecture · Internal engineering initiative**

Designed and executed a controlled migration of a live customer environment between two production platform instances, under a strict constraint: only one environment could actively process traffic at any moment, with no event deduplication available as a safety net.

**What was actually built:**
- Designed a staged-sync-then-atomic-cutover migration model, since the target system had no built-in mechanism to prevent duplicate processing during a migration
- Built a routing-based rollback path that could safely reverse the cutover without a data rebuild, as long as the source environment hadn't been decommissioned yet
- Defined a validation window and completion criteria before allowing the irreversible final step (decommissioning the source)
- Executed the migration during a live maintenance window with zero data loss and no customer-visible duplication

**Stack:** Routing/DNS cutover · Configuration migration tooling · Production change management

---

## FortiGate HA Firewall Upgrade (Zero-Downtime)

**Network security operations · Production firewall maintenance**

Planned and executed a zero-downtime firmware upgrade on an active-passive FortiGate HA cluster in AWS, using automatic failover to keep traffic flowing throughout.

**What was actually built:**
- Validated HA sync state, backups, and firmware compatibility before initiating the upgrade
- Executed a sequenced upgrade (secondary → failover → primary) with a documented go/no-go checklist for each stage
- Verified HA health, configuration sync, and session continuity as hard completion criteria before closing the maintenance window

**Stack:** FortiGate HA · AWS · Firmware lifecycle management

---

## Cloud DNS Access Governance Redesign

**IAM redesign · Audit-ready access model · Internal engineering initiative**

Replaced a shared-credential DNS administration model with per-user cloud IAM identity, group-based access policy, and fully audit-logged record changes — for a platform where DNS changes directly affect live customer traffic.

**What was actually built:**
- Designed a group-based IAM policy model (console + CLI) to eliminate shared admin credentials
- Documented a mandatory pre-check-before-write safety pattern, since the underlying API performs full record-set replacement rather than incremental patches — a subtle but high-risk behavior worth designing around explicitly
- Established a fully traceable audit trail (user identity, timestamp, source IP, and payload) for every DNS change going forward

**Stack:** Oracle Cloud Infrastructure (OCI) · IAM · DNS · CLI tooling


---

## Coming next

EKS module — adding a minimal, billing-safe EKS cluster to Platform Foundation using Terraform. Fargate-based so it costs $0 when idle. Will integrate with existing GitHub Actions OIDC, Prometheus observability, and the platform CLI.

Prometheus/Grafana completion — standardizing all scrape targets to 127.0.0.1, wiring Grafana alerts, completing the observability stack that's currently ~70% there.
