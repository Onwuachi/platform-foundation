# Platform Foundation — Operations Runbook

Full operational detail behind [README.md](../README.md): lifecycle diagrams, state ownership, TLS internals, observability, disaster recovery, and tooling. Read the README first for the high-level picture — this doc is the "how it actually works" reference.

---

## Infrastructure Lifecycle

Terraform provisions infrastructure. SSM Parameter Store is the handoff between Packer and Terraform — the AMI ID never gets hardcoded.

```
Packer Build
      │  Ubuntu 24.04 + Docker + HAProxy + SSM agent + base packages
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

## Runtime Recovery Lifecycle

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

## State Ownership Model

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

## Network Architecture

The VPC (`devopslab-vpc`, 10.50.0.0/16) currently consists of two public subnets only. There is no NAT gateway and no VPC endpoints — all instance traffic, including SSM Session Manager, reaches AWS APIs over the public internet via the Internet Gateway. "No NAT" here is a byproduct of the current flat topology, not evidence of private isolation.

A future phase may introduce a private subnet with SSM interface endpoints (`ssm`, `ssmmessages`, `ec2messages`) to remove public internet dependency for operational access. Cost check at time of writing: 3 interface endpoints in a single AZ run roughly $22/month, which exceeds the cost of a single NAT gateway (~$33-40/month with data processing) only in the sense that NAT would additionally cover ECR/S3/CloudWatch access that interface endpoints would otherwise require paying for individually. Whether to pursue this is an open decision, not yet a commitment.

---

## Observability

Prometheus scrapes the platform and feeds Grafana dashboards. Runs with `--network host` so it can reach all loopback-bound services directly — no Docker bridge networking translation needed.

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

Prometheus previously ran in default Docker bridge mode, which meant it could not reach services bound to the host's `127.0.0.1` (HAProxy stats, node exporter, blackbox exporter). Fixed by switching the Prometheus container to `--network host`, removing the now-unnecessary port mapping, and standardizing every scrape target to `127.0.0.1`.

**HAProxy Prometheus exporter:**

```
frontend stats
    bind 127.0.0.1:8404
    mode http
    http-request use-service prometheus-exporter if { path /metrics }
    no log
```

Bound to loopback only — not reachable from the public internet, so no additional auth layer needed on top of the path-level Basic Auth already protecting `/kb`, `/private`, `/family`.

**Grafana provisioning:**

Grafana auto-loads its Prometheus datasource and dashboard definitions from disk on container start — no manual UI configuration required. This depends on the container actually mounting those paths:

```
-v /etc/grafana/provisioning:/etc/grafana/provisioning:ro
-v /opt/grafana/dashboards:/opt/grafana/dashboards:ro
```

(In addition to the persistent `/opt/grafana/data` mount for Grafana's own database.) Without these two mounts, Grafana starts clean every time with no datasource and no dashboards, silently ignoring the provisioning files that exist on the host — this was fixed in Phase 4.4.

**Useful diagnostic command:**
```bash
curl -s localhost:9090/api/v1/targets \
  | jq '.data.activeTargets[] | select(.health != "up") | {job, health, lastError}'
```

---

## Terraform State

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

- Fallback/self-signed certs are allowed only during AMI build (`temp.pem`). Runtime fallback was deliberately removed — a missing or invalid cert at runtime now fails loudly (`platform-rehydrate` exits non-zero) instead of silently serving a self-signed cert that masks the real failure.
- The deploy hook uses Certbot's own `$RENEWED_DOMAINS` / `$RENEWED_LINEAGE` environment variables rather than a hardcoded domain — any current or future domain on this box renews and reloads correctly with zero hook changes.
- HAProxy's `bind *:443 ssl crt /etc/haproxy/certs/` loads every `.pem` file in the directory and selects the right one via SNI — this is what makes the "any domain renews safely" property work without per-domain HAProxy config.
- The hook content is written inline during AMI build (`install_certbot.sh`) rather than referencing a sibling script path, because Packer's shell provisioner stages each script independently and doesn't guarantee a shared `/tmp/scripts/` directory persists across script executions.

---

## Disaster Recovery

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

Zero manual steps. Validated in practice — Phase 4.4's rebuild replaced the running instance end-to-end (`terraform apply` destroyed and recreated `aws_instance.ops` against the new AMI) and the platform came back online automatically with no manual intervention.

---

## Docker Runtime Hardening

Docker daemon defaults were updated to ensure all containers receive appropriate file descriptor limits.

Docker daemon configuration now defines:

- Soft Limit: 524288
- Hard Limit: 524288

Critical platform services also explicitly define systemd `LimitNOFILE` values where appropriate.

Validation includes:

- Docker daemon limits
- systemd service limits
- Kernel limits
- Running container limits

---

## Content Platform (Hugo)

The Hugo site started as a single static dashboard and evolved into an actual content platform with sections for infrastructure KB, a bourbon knowledge base, pitmaster recipes, and culture — the homepage needed to evolve with it.

**Before:** homepage duplicated `/platform/` almost verbatim (hero, metrics, architecture, services, observability, roadmap — the same partials, twice).

**Now:** homepage is a portal — hero, a **Quick Stats** row (Knowledge Articles, Runbooks, Bottle Reviews, Platform Services — all computed at build time from real `WordCount`/section counts, not hardcoded numbers), cards linking out to each section, a **Platform Snapshot** widget reading live `data/signals/telemetry.yaml`, and an auto-generated **Latest Updates** feed. `/platform/` alone now owns the full dashboard.

Other fixes from the same pass:

- Syntax-highlighted code blocks in KB articles were rendering with a fixed dark palette baked in as inline styles (Hugo's default Chroma behavior), so they ignored the light/dark theme toggle entirely. Fixed by emitting CSS classes instead (`noClasses = false`) and mapping them to the site's own theme variables.
- Recipe thumbnails moved from a hardcoded slug→filename lookup in the template to a front-matter `image:` field — new recipes no longer require a template edit.
- Removed a duplicate header/nav partial on `/culture/` and a partial that rendered the same anime-links data twice.

**KB authoring tooling** (`tools/hugo/`): `create-kb-article.sh`, `create-kb-bottle.sh`, `create-kb-domain.sh` scaffold new content with correct front matter, reducing the KB → new page.

---

## Infra Audit CLI (Python)

A small, deliberately-scoped Python toolkit for reading and inspecting infrastructure state, developed alongside the platform rather than as a standalone exercise — each script reads real Terraform/AWS-shaped JSON.

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

Development pattern: build a small representative sample JSON file first, write the parser against it, verify output, then point the same script at real `terraform show -json` output with no logic changes. `utils/` and `tests/` are scaffolded for the next iteration (richer filtering — public resources, missing tags, drift detection) but intentionally not built out ahead of an actual need.

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
