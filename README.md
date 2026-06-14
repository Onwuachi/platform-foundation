# Platform Foundation

### *Stateless Compute · Declarative Runtime State · Deterministic Recovery*

A single-engineer AWS platform implementing immutable infrastructure, declarative runtime state, and a self-rehydrating control plane. The platform rebuilds its entire runtime deterministically from a single source of truth — no manual steps required.

Built and operated end-to-end: from AMI to edge routing, CI/CD to disaster recovery, observability to documentation.

> **Compute is disposable. State is durable. Recovery is deterministic.**

---

## Status Badges

| Workflow | Status |
|---|---|
| Platform Up | ![Platform Up](https://github.com/Onwuachi/platform-foundation/actions/workflows/platform-up.yml/badge.svg) |
| Platform Down | ![Platform Down](https://github.com/Onwuachi/platform-foundation/actions/workflows/platform-down.yml/badge.svg) |
| Hugo CI | ![Hugo CI](https://github.com/Onwuachi/platform-foundation/actions/workflows/hugo.yml/badge.svg) |

---

## Architecture

![Platform Architecture](apps/hugo/service/static/images/platform-architecture.png)

---

## Technology Stack

| Layer | Technology |
|---|---|
| AMI Build | Packer (Ubuntu 22.04) |
| AMI Registry | AWS SSM Parameter Store |
| Infrastructure | Terraform v1.12.2 · AWS Provider v6.35.1 |
| Edge Routing | HAProxy (TLS termination, dynamic backends) |
| Container Runtime | Docker + ECR |
| Service Orchestration | systemd |
| Runtime State | Amazon S3 (primary + backup) |
| TLS Management | Certbot (ACME) |
| Metrics | Prometheus + Node Exporter + Blackbox Exporter |
| Dashboards | Grafana |
| Documentation | Hugo (self-hosted, containerized) |
| CI/CD | GitHub Actions + OIDC |
| Operational Access | AWS SSM Session Manager (no SSH, no bastion) |

---

## ① Infrastructure Lifecycle

Terraform provisions infrastructure. SSM Parameter Store is the handoff between Packer and Terraform — the AMI ID never gets hardcoded.

```
Packer Build
      │  Ubuntu 22.04 + Docker + HAProxy + SSM agent + base packages
      ▼
AMI Created
      │
      ▼
SSM Parameter Store
      │  /devopslab/ami/ops/latest
      ▼
Terraform Apply
      │  VPC · Subnets · EC2 · EIP · IAM · S3 · Route53
      ▼
EC2 Launch
```

---

## ② Runtime Recovery Lifecycle

Once EC2 is up, Terraform's job is done. The runtime reconstructs itself independently — no Terraform involvement.

```
EC2 Launch
      │
      ▼
systemd Startup
      │  platform-rehydrate.service
      ▼
S3 State Sync
      │  platform/services/* → local
      ▼
Certificate Recovery
      │  TLS certs from S3 / certbot validation
      ▼
HAProxy Render
      │  dynamic backend map generation
      ▼
Docker Pull + Start
      │  ECR → hugo · api · grafana · prometheus
      ▼
Platform Online ✅
```

---

## ③ State Ownership Model

This is the core architectural distinction of the platform.

### Terraform Owns (infrastructure layer)

- VPC + Subnets
- Security Groups
- EC2 Instance
- Elastic IP
- IAM Roles + Policies
- S3 Bucket (the bucket resource, not its contents)
- Route53 Records

### Terraform Does NOT Own (runtime layer)

- Docker containers and running workloads
- HAProxy runtime configuration
- Service definitions and registrations
- TLS certificates
- S3 runtime objects (service state, certs, metadata)
- Disaster Recovery bucket and snapshots

> The DR S3 bucket and Route53 hosted zone were provisioned outside of Terraform and predate it.
> A `terraform destroy` removes compute and networking. It does not touch runtime state or DR data.
> This is intentional — recovery data must survive infrastructure destruction.

---

## ④ Runtime Services

All services bind to `127.0.0.1`. HAProxy handles all public ingress on ports 80 and 443.

| Service | Role | Internal Port |
|---|---|---|
| HAProxy | Edge routing + TLS termination | 80, 443 |
| Hugo | Documentation platform | 127.0.0.1:8081 |
| Node API | Platform API | 127.0.0.1:3000 |
| Grafana | Dashboards | 127.0.0.1:4000 |
| Prometheus | Metrics collection | 127.0.0.1:9090 |
| Blackbox Exporter | HTTPS + TLS expiry probes | 127.0.0.1:9115 |
| Node Exporter | Host metrics | 127.0.0.1:9100 |
| Pushgateway | Batch metrics | 127.0.0.1:9091 |

---

## ⑤ Observability

Prometheus scrapes the platform and feeds Grafana dashboards.

**Scrape targets — current state:**

| Target | Status | Notes |
|---|---|---|
| Prometheus | ✅ Up | `127.0.0.1:9090` |
| Blackbox HTTPS | ✅ Up | probing `onwuachi.com` + `/ready` |
| Blackbox SSL | ✅ Up | TLS expiry for `onwuachi.com` + `www` |
| Node Exporter | 🔧 In Progress | bind mismatch — EC2 SD vs `127.0.0.1` |
| HAProxy Metrics | 🔧 In Progress | stats listener not yet configured |
| Platform API | 🔧 In Progress | Prometheus targeting docker bridge IP, service on loopback |
| Pushgateway | 🔧 In Progress | same bridge IP issue as API |

**Known issue — networking consistency:**

Prometheus config currently mixes three addressing models:
- `127.0.0.1` (loopback — correct for this single-node setup)
- `172.17.0.1` (Docker bridge — incorrect for host-published services)
- `10.50.2.72` (EC2 private IP — used by EC2 service discovery)

Resolution: standardize all static scrape targets to `127.0.0.1`. EC2 SD either removed or scoped to node_exporter only.

**Useful diagnostic command:**
```bash
curl -s localhost:9090/api/v1/targets \
  | jq '.data.activeTargets[] | select(.health != "up") | {job, health, lastError}'
```

---

## ⑥ Terraform State

```hcl
terraform {
  backend "s3" {
    bucket       = "devops-lab-tfstate-bucket"
    key          = "platform-foundation/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
```

| Setting | Value |
|---|---|
| Backend | AWS S3 |
| Encryption | Enabled |
| State Locking | Native S3 lock (`use_lockfile = true`) |
| DynamoDB | Not required — Terraform ≥ 1.10 |
| Versioning | S3 versioning enabled on state bucket |

**Important distinction learned:**
- `.terraform.lock.hcl` — provider dependency lock file. Committed to git. Does NOT contain state.
- `terraform.tfstate` — infrastructure state. Stored in S3. Never committed to git.

---

## ⑦ Disaster Recovery

Runtime state is fully independent of any EC2 instance.

```
Primary S3:  platform-api-services/
             ├── platform/services/*     service registry
             ├── certs/                  TLS certificates
             ├── haproxy/                runtime maps
             └── metadata/

Backup S3:   platform-api-services-backup/
             └── snapshots/YYYY-MM-DD/   nightly via GitHub Actions
```

**Full node loss recovery:**

```
EC2 destroyed
      │
      ▼
terraform apply  (new instance, same AMI)
      │
      ▼
platform-rehydrate
      │
      ▼
S3 sync restores runtime state
      │
      ▼
HAProxy, services, TLS reconstructed automatically
      │
      ▼
Platform online — zero manual steps
```

---

## Platform CLI

```bash
platform up                          # bring platform online
platform down                        # graceful shutdown
platform deploy <service>            # deploy a service
platform register <service> <port> <domain>  # register new service
platform rehydrate                   # full runtime restore from S3
platform health                      # validate service health
platform shell                       # SSM interactive session
```

---

## Security Model

- Public ports: 80 (redirect only) and 443 (TLS termination) only
- All backend services bind exclusively to `127.0.0.1`
- Operational access via AWS SSM Session Manager — no SSH keys, no bastion host
- TLS managed by Certbot with automated renewal
- HAProxy validates config before every reload — no unsafe reloads
- GitHub Actions authenticates via OIDC — no long-lived AWS credentials

---

## Phase 4.3 — What Was Built

### Infrastructure + State
- Packer AMI pipeline with full package baseline and OS hardening
- SSM Parameter Store as AMI handoff between Packer and Terraform
- Terraform remote state in S3 with native locking — no DynamoDB required
- Clarified ownership boundary: Terraform owns infrastructure, not runtime
- S3 versioning enabled for state rollback protection

### Runtime Platform
- Docker-based application runtime with ECR image management
- Dynamic service registration via S3
- HAProxy edge routing with rendered backend maps (not static config)
- Automated TLS lifecycle via Certbot
- Automated platform rehydration on boot and on-demand

### Observability Foundation
- Prometheus metrics collection (scraping platform + infrastructure)
- Node Exporter for host-level metrics
- Blackbox Exporter for HTTPS uptime and TLS expiry probes
- Grafana dashboard integration
- `jq` added to base AMI for structured operational diagnostics

### Documentation Platform (Hugo)
- Self-hosted Hugo platform running in Docker via ECR
- Custom layouts, reusable partials, section-based content architecture
- Data-driven rendering from YAML
- Image support in markdown content
- Content streams: Platform · Engineering · Culture · Recipes · Signals · KB

### Pitmaster Runbooks
- Overnight Traeger Brisket
- Smoked Beef Tallow
- 3-Rib Fest Pitmaster Guide
- Baby Back Rib Compression Method
- Salmon + Brined Chicken Dual Smoke
- Standard Salmon Runbook

---

## Terraform Resource Inventory

```
data.aws_route53_zone.onwuachi
aws_route53_record.ops
module.ops.aws_eip.ops / aws_eip_association.ops
module.ops.aws_instance.ops
module.ops.aws_route53_record.root / www
module.ops.aws_s3_bucket.platform_state
module.ops.aws_s3_bucket_lifecycle_configuration.platform_state
module.ops.aws_s3_bucket_public_access_block.platform_state
module.ops.aws_s3_bucket_versioning.platform_state
module.security.aws_security_group.ops_sg / web_sg / wordpress_sg
module.shared.aws_iam_instance_profile.ec2_profile
module.shared.aws_iam_openid_connect_provider.github
module.shared.aws_iam_policy.packer_policy
module.shared.aws_iam_role.ec2_ssm_role / github_oidc_role
module.shared.aws_iam_role_policy.ops_s3
module.shared.aws_iam_role_policy_attachment.*
module.shared.aws_internet_gateway.gw
module.shared.aws_route_table.public + associations
module.shared.aws_secretsmanager_secret.mongodb
module.shared.aws_subnet.public_a / public_b
module.shared.aws_vpc.main
```

---

## Platform Evolution

| Phase | Description | Status |
|---|---|---|
| Phase 1 | Immutable Foundation | ✅ Complete |
| Phase 2 | Container Runtime | ✅ Complete |
| Phase 3 | Edge Stability + TLS | ✅ Complete |
| Phase 4 | Declarative Control Plane | ✅ Complete |
| Phase 4.3 | Content Platform · Observability · State Hardening | ✅ Current |
| Phase 4.4 | Observability completion · Prometheus target alignment | 🔧 In Progress |

---

## Known Constraints

- Single-node architecture (by design — simplicity over scaling)
- Prometheus scrape targets partially down (networking alignment in progress)
- No autoscaling or blue/green deployments
- No multi-node clustering
- No automated alerting (Grafana alerts not yet wired)
- No automatic failed-node replacement

---

## Engineering Principles

- Immutability over mutation
- Declarative state over imperative logic
- Stateless compute, stateful recovery
- Rebuild over repair
- Operational determinism
- Automation by default
- Silent failures are worse than loud ones — no fallback masking

---

## Repository Structure

```
platform-foundation/
├── apps/
│   └── hugo/service/          Hugo documentation platform
├── infra/
│   ├── backend.tf             S3 remote state
│   ├── main.tf                Core infrastructure
│   ├── shared/                VPC, IAM, OIDC
│   ├── ops/                   EC2, EIP, S3, Route53
│   ├── security/              Security groups
│   └── packer/                AMI build templates + scripts
├── scripts/                   Platform CLI + automation
└── docs/                      Architecture documentation
```

---

## Commit + Tag Reference

```bash
git commit -m "feat(platform): phase 4.3 content platform, observability, and terraform state hardening"

git tag -a v4.3.0 \
  -m "Phase 4.3 - Content Platform, Observability, and State Management"

git push origin main
git push origin v4.3.0
```

---

## Author

**Derrick C. Onwuachi**
Cloud · DevOps · Platform Engineer

---

