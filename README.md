# Platform Foundation

**[Derrick Onwuachi](https://onwua.com)** · DevOps Engineer · Platform & Infrastructure · Apple Valley, MN

> This is my personally operated infrastructure platform. The production portfolio is at **[onwua.com](https://onwua.com)**.

---

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
| Portfolio Deploy | ![Deploy Portfolio](https://github.com/Onwuachi/platform-foundation/actions/workflows/deploy-portfolio.yml/badge.svg) |

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
| Portfolio Site | Hugo → S3 → CloudFront (onwua.com) |
| CI/CD | GitHub Actions + OIDC |
| Operational Access | AWS SSM Session Manager (no SSH, no bastion) |
| Secrets | AWS SSM Parameter Store (SecureString) |

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

Prometheus scrapes the platform and feeds Grafana dashboards. Runs with
`--network host` so it can reach all loopback-bound services directly —
no Docker bridge networking translation needed.

**Scrape targets — current state:**

| Target | Status | Notes |
|---|---|---|
| Prometheus | ✅ Up | `127.0.0.1:9090` |
| Node Exporter | ✅ Up | `127.0.0.1:9100` — host CPU/mem/disk |
| HAProxy Metrics | ✅ Up | `127.0.0.1:8404/metrics` — native Prometheus exporter |
| Blackbox HTTPS | ✅ Up | probing `onwuachi.com` + `/ready` |
| Blackbox SSL | ✅ Up | TLS expiry for `onwuachi.com` + `www` |
| Platform API | 🔧 In Progress | container running, `/metrics` endpoint not yet instrumented |
| Pushgateway | 🔧 Under review | running but unused — candidate for removal |

**Resolved networking issue:**

Prometheus previously ran in default Docker bridge mode, which meant it could
not reach services bound to the host's `127.0.0.1` (HAProxy stats, node
exporter, blackbox exporter). Fixed by switching the Prometheus container to
`--network host`, removing the now-unnecessary port mapping, and standardizing
every scrape target to `127.0.0.1`.

**HAProxy Prometheus exporter:**

```
frontend stats
    bind 127.0.0.1:8404
    mode http
    http-request use-service prometheus-exporter if { path /metrics }
    no log
```

Bound to loopback only — not reachable from the public internet, so no
additional auth layer needed on top of the path-level Basic Auth already
protecting `/kb`, `/private`, `/family`.

**Grafana provisioning:**

Grafana auto-loads its Prometheus datasource and dashboard definitions from
disk on container start — no manual UI configuration required. This depends
on the container actually mounting those paths:

```
-v /etc/grafana/provisioning:/etc/grafana/provisioning:ro
-v /opt/grafana/dashboards:/opt/grafana/dashboards:ro
```

(In addition to the persistent `/opt/grafana/data` mount for Grafana's own
database.) Without these two mounts, Grafana starts clean every time with no
datasource and no dashboards, silently ignoring the provisioning files that
exist on the host — this was fixed in Phase 4.4.

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

---

## TLS Certificate Lifecycle

Certificates are fully self-managing — zero manual renewal steps required.

```
Packer Build
      │  temp.pem bootstrap cert (self-signed, AMI build only)
      ▼
AMI Boot
      │
      ▼
platform-rehydrate
      │  requests real cert via certbot if missing/invalid
      ▼
certbot.timer (every 12h)
      │
      ▼
certbot renew
      │  if renewal occurs:
      ▼
renewal-hooks/deploy/haproxy-renew.sh
      │  rebuilds /etc/haproxy/certs/<domain>.pem
      │  from fresh fullchain.pem + privkey.pem
      ▼
systemctl reload haproxy
      │
      ▼
New certificate live — zero downtime, zero manual steps
```

**Key design decisions:**

- Fallback/self-signed certs are allowed only during AMI build (`temp.pem`).
  Runtime fallback was deliberately removed — a missing or invalid cert at
  runtime now fails loudly (`platform-rehydrate` exits non-zero) instead of
  silently serving a self-signed cert that masks the real failure.
- The deploy hook uses Certbot's own `$RENEWED_DOMAINS` / `$RENEWED_LINEAGE`
  environment variables rather than a hardcoded domain — any current or future
  domain on this box renews and reloads correctly with zero hook changes.
- HAProxy's `bind *:443 ssl crt /etc/haproxy/certs/` loads every `.pem` file
  in the directory and selects the right one via SNI — this is what makes the
  "any domain renews safely" property work without per-domain HAProxy config.
- The hook content is written inline during AMI build (`install_certbot.sh`)
  rather than referencing a sibling script path, because Packer's shell
  provisioner stages each script independently and doesn't guarantee a shared
  `/tmp/scripts/` directory persists across script executions.

---

## ⑦ Disaster Recovery

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
EC2 destroyed → terraform apply → platform-rehydrate → S3 sync → Platform online
```

Zero manual steps. Validated in practice — Phase 4.4's rebuild replaced the
running instance end-to-end (`terraform apply` destroyed and recreated
`aws_instance.ops` against the new AMI) and the platform came back online
automatically with no manual intervention.

---

## Content Platform (Hugo)

The Hugo site started as a single static dashboard and evolved into an
actual content platform with sections for infrastructure KB, a bourbon
knowledge base, pitmaster recipes, and culture — the homepage needed to
evolve with it.

**Before:** homepage duplicated `/platform/` almost verbatim (hero, metrics,
architecture, services, observability, roadmap — the same partials, twice).

**Now:** homepage is a portal — hero, a **Quick Stats** row (Knowledge
Articles, Runbooks, Bottle Reviews, Platform Services — all computed at
build time from real `WordCount`/section counts, not hardcoded numbers),
cards linking out to each section, a **Platform Snapshot** widget reading
live `data/signals/telemetry.yaml`, and an auto-generated **Latest Updates**
feed. `/platform/` alone now owns the full dashboard.

Other fixes from the same pass:

- Syntax-highlighted code blocks in KB articles were rendering with a fixed
  dark palette baked in as inline styles (Hugo's default Chroma behavior),
  so they ignored the light/dark theme toggle entirely. Fixed by emitting
  CSS classes instead (`noClasses = false`) and mapping them to the site's
  own theme variables.
- Recipe thumbnails moved from a hardcoded slug→filename lookup in the
  template to a front-matter `image:` field — new recipes no longer require
  a template edit.
- Removed a duplicate header/nav partial on `/culture/` and a partial that
  rendered the same anime-links data twice.

**KB authoring tooling** (`tools/hugo/`): `create-kb-article.sh`,
`create-kb-bottle.sh`, `create-kb-domain.sh` scaffold new content with
correct front matter, reducing the KB → new page.

---

## Infra Audit CLI (Python)

A small, deliberately-scoped Python toolkit for reading and inspecting
infrastructure state, developed alongside the platform rather than as a
standalone exercise — each script reads real Terraform/AWS-shaped JSON.

```
infra/infra_audit/
├── cli/
│   ├── log_analyzer.py       reads EC2 JSON, flags Public/Private
│   └── terraform_parser.py   reads terraform show -json, describes resources
│                              per type (aws_instance, aws_eip, aws_vpc, ...)
├── data/                     sample JSON fixtures for local development
├── utils/                    scaffolded, not yet in use
└── tests/                    scaffolded, not yet in use
```

```bash
cd infra/infra_audit/cli
python log_analyzer.py        # Instance i-12345 is Public / Private
python terraform_parser.py    # per-resource description, one block per resource
```

Development pattern: build a small representative sample JSON file first,
write the parser against it, verify output, then point the same script at
real `terraform show -json` output with no logic changes. `utils/` and
`tests/` are scaffolded for the next iteration (richer filtering — public
resources, missing tags, drift detection) but intentionally not built out
ahead of an actual need.

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
- TLS managed by Certbot with automated renewal — deploy hook rebuilds the
  HAProxy PEM and reloads HAProxy automatically after every successful renewal,
  zero manual steps
- Path-level HTTP Basic Auth on private content (`/kb`, `/private`, `/family`)
  enforced at the HAProxy edge — Hugo itself has no auth layer
- Auth credentials stored as SSM Parameter Store SecureString, never committed
  to the repo or baked into the AMI — `platform-rehydrate` injects the real
  password hash at boot; AMIs only ever contain a bootstrap placeholder
- HAProxy validates config before every reload — no unsafe reloads
- GitHub Actions authenticates via OIDC — no long-lived AWS credentials

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
| Phase 5 | EKS module · Kubernetes familiarity layer | 📋 Planned |

---

## Known Constraints

- Single-node architecture (by design — simplicity over scaling)
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
│   ├── security/               Security groups
│   ├── ops/                   EC2, EIP, S3, Route53 — the only always-on compute
│   ├── packer/                AMI build templates + scripts
│   ├── environments/           Per-environment .tfvars (dev/uat/stage/prod)
│   ├── infra_audit/            Python CLI — see "Infra Audit CLI" above
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
└── scripts/                    Setup/bootstrap shell scripts
                                (accumulated duplication here — cleanup
                                candidate, not yet done)
```

**Known pending cleanup** (tracked here rather than pretending it's already
done): `hugo-updated/` at repo root is a stale duplicate of
`apps/hugo/service/` and still needs to be removed; `CHANGELOG.md` still
reflects the very first infrastructure pass and hasn't been updated since —
next real housekeeping pass, not urgent.

---

## Author

**Derrick C. Onwuachi** · Cloud · DevOps · Platform Engineer

[onwua.com](https://onwua.com) · [github.com/Onwuachi](https://github.com/Onwuachi) · [linkedin.com/in/derrick-o-a0777729](https://linkedin.com/in/derrick-o-a0777729)
