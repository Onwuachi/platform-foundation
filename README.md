# Platform Foundation

**[Derrick Onwuachi](https://onwua.com)** · DevOps Engineer · Platform & Infrastructure · Apple Valley, MN

> This is my personally operated infrastructure platform. The production portfolio is at **[onwua.com](https://onwua.com)**.

---

### *Stateless Compute · Declarative Runtime State · Deterministic Recovery*

A single-engineer AWS platform implementing immutable infrastructure, declarative runtime state, and a self-rehydrating control plane. The platform rebuilds its entire runtime deterministically from a single source of truth — no manual steps required.

Built and operated end-to-end: from AMI to edge routing, CI/CD to disaster recovery, observability to documentation.

> **Compute is disposable. State is durable. Recovery is deterministic.**

Full operational detail — lifecycle diagrams, DR procedures, TLS internals, tooling — lives in **[docs/OPERATIONS.md](docs/OPERATIONS.md)**.

---

## Status Badges

| Workflow | Status |
|---|---|
| Platform Up | ![Platform Up](https://github.com/Onwuachi/platform-foundation/actions/workflows/platform-up.yml/badge.svg) |
| Platform Down | ![Platform Down](https://github.com/Onwuachi/platform-foundation/actions/workflows/platform-down.yml/badge.svg) |
| Hugo CI | ![Hugo CI](https://github.com/Onwuachi/platform-foundation/actions/workflows/hugo.yml/badge.svg) |
| Portfolio Deploy | ![Deploy Portfolio](https://github.com/Onwuachi/platform-foundation/actions/workflows/deploy-portfolio.yml/badge.svg) |

---

## Platform Architecture

The platform is built around an immutable infrastructure model.

- Packer produces a hardened Ubuntu 24.04 Golden AMI.
- The latest AMI ID is published to AWS Systems Manager Parameter Store.
- Terraform provisions infrastructure using the current Golden AMI.
- Platform services run as Docker containers managed by systemd.
- Configuration is rehydrated at boot from AWS Systems Manager.
- Operational access is provided exclusively through AWS Systems Manager Session Manager (SSH disabled).
- Prometheus, Grafana, Node Exporter, Blackbox Exporter, and Pushgateway provide platform observability.

```
GitHub → GitHub Actions → Packer → Golden AMI → Terraform → EC2 → AWS SSM → Platform Rehydrate
```

![Platform Architecture](apps/hugo/service/static/images/platform-architecture.png)

Step-by-step build and recovery diagrams: see [OPERATIONS.md § Infrastructure Lifecycle](docs/OPERATIONS.md#infrastructure-lifecycle) and [§ Runtime Recovery Lifecycle](docs/OPERATIONS.md#runtime-recovery-lifecycle).

---

## Technology Stack

| Layer | Technology |
|---|---|
| Base Operating System | Ubuntu 24.04 LTS (Noble), Linux 6.17 AWS kernel |
| Image Build | Packer 1.9.4 |
| Golden AMI Registry | AWS SSM Parameter Store |
| Infrastructure as Code | Terraform 1.12.2 + AWS Provider 6.35.1 |
| Cloud Platform | Amazon Web Services (AWS) |
| Compute | Amazon EC2 |
| Identity & Access | AWS IAM |
| Container Runtime | Docker Engine 29.x, containerd 2.2.x |
| Container Registry | Amazon ECR |
| Service Orchestration | systemd |
| Reverse Proxy | HAProxy |
| TLS Automation | Certbot (Let's Encrypt ACME) |
| Runtime Configuration | AWS Systems Manager Parameter Store |
| Remote Administration | AWS SSM Session Manager (SSH disabled) |
| Monitoring | Prometheus 2.51.2, Node Exporter, Blackbox Exporter, Pushgateway |
| Dashboards | Grafana 10.4.2 |
| Logging | systemd journal |
| Documentation Platform | Hugo (containerized) |
| Portfolio Website | Hugo → S3 → CloudFront |
| CI/CD | GitHub Actions + OIDC |
| Source Control | Git + GitHub |
| Configuration Management | Bash + systemd + Packer Provisioners |

The platform migrated from Ubuntu 22.04 → 24.04 via a full immutable rebuild (fresh AMI, fresh EC2, no in-place upgrade) — consistent with the "rebuild over repair" principle below, not an exception to it.

---

## State Ownership Model

The core architectural distinction of the platform: infrastructure and runtime state are owned separately, and destroying one does not destroy the other.

**Terraform owns:** VPC/Subnets, Security Groups, EC2 Instance, Elastic IP, IAM, the S3 bucket resource (not its contents), Route53 Records.

**Terraform does not own:** Docker containers, HAProxy runtime config, service registrations, TLS certificates, S3 runtime objects, the DR bucket and snapshots.

> `terraform destroy` removes compute and networking only. It does not touch runtime state or DR data — that survival is intentional. Full ownership tables and rationale: [OPERATIONS.md § State Ownership Model](docs/OPERATIONS.md#state-ownership-model).

---

## Runtime Services

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

Observability setup, scrape targets, and Grafana provisioning details: [OPERATIONS.md § Observability](docs/OPERATIONS.md#observability).

---

## Security Model

- Public ports: 80 (redirect only) and 443 (TLS termination) only
- All backend services bind exclusively to `127.0.0.1`
- Operational access via AWS SSM Session Manager — no SSH keys, no bastion host
- TLS managed by Certbot with automated renewal — deploy hook rebuilds the HAProxy PEM and reloads HAProxy automatically after every successful renewal, zero manual steps
- Path-level HTTP Basic Auth on private content (`/kb`, `/private`, `/family`) enforced at the HAProxy edge — Hugo itself has no auth layer
- Auth credentials stored as SSM Parameter Store SecureString, never committed to the repo or baked into the AMI — `platform-rehydrate` injects the real password hash at boot; AMIs only ever contain a bootstrap placeholder
- HAProxy validates config before every reload — no unsafe reloads
- GitHub Actions authenticates via OIDC — no long-lived AWS credentials

TLS certificate lifecycle in full: [OPERATIONS.md § TLS Certificate Lifecycle](docs/OPERATIONS.md#tls-certificate-lifecycle).

---

## Platform Evolution

| Phase | Description | Status |
|---|---|---|
| Phase 1 | Immutable Foundation | ✅ Complete |
| Phase 2 | Container Runtime | ✅ Complete |
| Phase 3 | Edge Stability + TLS | ✅ Complete |
| Phase 4 | Declarative Control Plane | ✅ Complete |
| Phase 4.3 | Content Platform · Observability · State Hardening | ✅ Complete |
| Phase 4.4 | Prometheus host networking · HAProxy metrics · Node Exporter · Grafana provisioning mounts | ✅ Complete |
| Phase 4.5 | Path-level content auth (HAProxy + SSM Parameter Store) | ✅ Complete |
| Phase 4.6 | Automated TLS renewal (Certbot deploy hook → HAProxy reload) | ✅ Complete |
| Phase 4.7 | Grafana dashboards · alerting (SNS/email) | 🔧 In Progress |
| Phase 4.8 | Content platform reorg — portal homepage, live Quick Stats + Platform Snapshot (data-driven, not hardcoded), theme-aware syntax highlighting, KB authoring scripts | ✅ Complete |
| Phase 4.9 | OS migration: Ubuntu 22.04 → 24.04 (Noble) via full Packer rebuild, no in-place upgrade | ✅ Complete |
| Phase 5 | EKS module · Kubernetes familiarity layer | 📋 Planned |

---

## Known Constraints

- Single-node architecture (by design — simplicity over scaling)
- Public subnets only — no NAT gateway, no VPC endpoints, no private isolation layer yet
- Platform API metrics endpoint not yet instrumented
- No autoscaling or blue/green deployments
- No multi-node clustering
- No automated alerting (Grafana alerts not yet wired — Phase 4.7)
- Pushgateway running but currently unused — under review for removal

---

## Engineering Principles

- Immutability over mutation
- Declarative state over imperative logic
- Stateless compute, stateful recovery
- Rebuild over repair
- Operational determinism
- Automation by default
- Cost accountability — if it runs, it has a reason to run

---

## Repository Structure

```
platform-foundation/
├── apps/
│   └── hugo/service/          Hugo content platform (KB, recipes, culture, platform dashboard)
├── infra/
│   ├── backend.tf             S3 remote state
│   ├── main.tf                Core infrastructure
│   ├── shared/                VPC, IAM, OIDC
│   ├── security/              Security groups
│   ├── ops/                   EC2, EIP, S3, Route53 — the only always-on compute
│   ├── packer/                AMI build templates + scripts
│   ├── environments/          Per-environment .tfvars (dev/uat/stage/prod)
│   ├── infra_audit/           Python CLI — see OPERATIONS.md
│   └── web/, wordpress/, app/, admin-ui-instance/, cloud-init/
│                               Legacy modules from the pre-consolidation
│                               architecture, gated behind enable_* flags
│                               that default to false — not deployed, kept
│                               for reference rather than deleted outright
├── onwua-portfolio/           onwua.com static portfolio site
│   ├── infra/portfolio/       S3 + CloudFront + ACM Terraform
│   ├── site/                  Hugo source
│   └── .github/workflows/     Deploy pipeline
├── tools/
│   ├── platform                Platform CLI entrypoint
│   ├── hugo/                   KB authoring scripts (create-kb-*.sh)
│   └── control-cli/             Domain-mapping CLI (ctl) + legacy version
├── docs/
│   └── OPERATIONS.md           Full operational runbook
└── scripts/                    Setup/bootstrap shell scripts
                                (accumulated duplication here — cleanup
                                candidate, not yet done)
```

---

## Author

**Derrick C. Onwuachi** · Cloud · DevOps · Platform Engineer
[onwua.com](https://onwua.com) · [github.com/Onwuachi](https://github.com/Onwuachi) · [linkedin.com/in/derrick-o-a0777729](https://linkedin.com/in/derrick-o-a0777729)
