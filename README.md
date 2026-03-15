# Platform Foundation – Immutable Edge + Container Runtime

A production-style infrastructure platform built using immutable infrastructure principles and disciplined cloud engineering patterns.
---

### Platform Architecture Diagram (Pending completion)  

Internet
   ↓
Route53
   ↓
HAProxy
   ↓
Docker services
   ↓
Prometheus metrics
   ↓
Grafana dashboards

---

## 🔧 Stack

- **Packer** – Hardened AMI baking  
- **Terraform** – Infrastructure as Code  
- **HAProxy** – Edge reverse proxy + TLS termination  
- **Docker** – Application runtime  
- **Let’s Encrypt** – Automated TLS lifecycle  
- **AWS SSM Parameter Store** – AMI version tracking  
- **Amazon ECR** – Container registry  

---

## 🎯 Platform Objectives

- Build hardened, repeatable AMIs
- Separate build-time from run-time logic
- Terminate TLS strictly at the edge
- Run containerized workloads behind HAProxy
- Eliminate manual server mutation
- Enforce deterministic infrastructure replacement
- Maintain cost-aware cloud discipline
- Evolve architecture in controlled, documented phases

---

# 🧱 Current Architecture (Phase 3 – Stable)

```
                Internet
                    │
                    ▼
              Route53 (DNS)
                    │
               Elastic IP
                    │
              EC2 (Ops Node)
                    │
                HAProxy
             (TLS Termination)
                    │
          ┌────────────────────┐
          │ 127.0.0.1:3000     │ → Platform API (Docker)
          │ 127.0.0.1:8080     │ → Hugo (nginx container)
          └────────────────────┘

---
Phase 3.2 

                    GitHub
                      │
                      │ push
                      ▼
               GitHub Actions
                (CI Pipeline)
                      │
                      │ docker build
                      ▼
                     ECR
        (Elastic Container Registry)
                      │
                      │ docker pull
                      ▼
                 EC2 Host
           ┌─────────────────┐
           │    systemd      │
           │ (orchestrator)  │
           └────────┬────────┘
                    │
                    ▼
                 Docker
        ┌──────────┼──────────┐
        │          │          │
        ▼          ▼          ▼
    platform-api  hugo    grafana
                               │
                               ▼
                           prometheus


In front of everything:

Internet
   │
   ▼
HAProxy
   │
   ├── /api      → platform-api container
   ├── /metrics  → prometheus
   └── /         → hugo


---
User Browser
     │
     ▼
https://onwuachi.com/api
     │
     ▼
DNS
     │
     ▼
EC2 Public IP
     │
     ▼
HAProxy
     │
     ▼
platform-api container
     │
     ▼
Node API server
     │
     ▼
JSON response

---

Edge Layer
   HAProxy
        │
Service Layer
   Docker containers
        │
Application Layer
   Node API / Hugo / Grafana
        │
Host Layer
   systemd
        │
Infrastructure
   EC2 / Terraform / Packer

---
CLI
 │
 │ platform deploy api
 ▼
platform script
 │
 ├─ docker build
 ├─ docker push
 ├─ ssh
 │
 ▼
EC2 server
 │
 ├─ systemd restart
 │
 ▼
docker container
 │
 ▼
node express api
 │
 ▼
haproxy
 │
 ▼
internet
---

platform-foundation
├─ apps
│   └─ billing
│   └─ api
│
├─ infra
│   ├─ packer
│   └─ terraform
│
├─ tools
│   └─ platform


```

### Public Surface Area

Only the following ports are exposed:

- **80** (HTTP → redirected to HTTPS)
- **443** (TLS)

All containers bind to:

```
127.0.0.1
```

No backend services are publicly reachable.

---

# 📦 Phase Evolution

---

## ✅ Phase 1 – Infrastructure Foundation  
**Tag:** `phase-1-infra-stable`

Established immutable infrastructure baseline.

### Delivered

- Ubuntu 22.04 hardened AMI built with Packer
- HAProxy installed and validated at image build time
- Dummy certificate baked to validate configuration
- Let’s Encrypt certificate issued at first boot
- Certbot renewal timer enabled
- Renewal deploy hook reloads HAProxy safely
- Deterministic 503 baseline response

### Principle Reinforced

> Validate infrastructure during image build — not at runtime.

---

## ✅ Phase 2 – Containerized Runtime  
**Tag:** `phase-2-app-backends`

Introduced application lifecycle management using containers.

### Delivered

- Docker installed in AMI
- systemd-managed container services
- Platform API container (Node.js)
- Hugo static site served via nginx container
- Health endpoint (`/ready`)
- HAProxy backend routing
- ECR authentication via IAM role
- AMI ID stored in SSM Parameter Store

### Runtime Flow

```
systemd
 → docker pull
 → docker run
 → health check
 → HAProxy reverse proxy
```

Application artifacts are **never baked into the AMI**.

### Principle Reinforced

> Infrastructure and application runtime must remain independent layers.

---

## ✅ Phase 3 – Edge Routing Hardening & Immutable Replacement  
**Tag:** `phase-3-edge-observability-stable`  
**Closed:** March 2026  

Phase 3 strengthened edge routing correctness and validated full immutable replacement discipline.

---

### 🔐 HAProxy Routing Hardening

Corrected structural configuration issues:

- Removed duplicate `default_backend`
- Enforced deterministic routing model:

```
/api     → platform_api
/ready   → platform_api
/        → hugo_backend
```

All HAProxy configuration resides inside the AMI.

No runtime rewriting.  
No user_data mutation.

### Principle Reinforced

> Edge configuration belongs in the image layer.

---

### ♻ Immutable Replacement Validation

Executed full rebuild cycle:

```
Packer build
 → AMI stored in SSM
 → Terraform apply
 → EC2 destroyed
 → EC2 recreated
 → Elastic IP reattached
```

Terraform output confirmed:

```
2 destroyed
2 added
```

No SSH fixes.  
No hot patches.  
No configuration drift.

### Principle Reinforced

> Fix images, not servers.

---

### ⚙ Runtime Hardening

- `Restart=always` validated in systemd
- ECR login pipe wrapped correctly with `/bin/sh -c`
- Health checks enforced at HAProxy layer
- Clean service grouping via `ops.target`
- TLS renewal hook verified

---

# 🏗 Immutable AMI Lifecycle

1. Packer builds hardened image
2. AMI ID stored in:

```
/devopslab/ami/ops/latest
```

3. Terraform reads SSM parameter
4. `terraform apply` replaces EC2 when AMI changes

Servers are disposable.

---

# 🚀 Deployment Model

## Infrastructure Pipeline

```
packer build
   ↓
AMI ID → SSM
   ↓
terraform apply
   ↓
EC2 replacement (if required)
```

## Application Pipeline

```
CI builds container
   ↓
Push to Amazon ECR
   ↓
Instance pulls image at service start
   ↓
systemd manages lifecycle
```

---

# 🔐 TLS Strategy

| Stage       | Certificate Type        | Purpose |
|------------|------------------------|----------|
| AMI Build  | Dummy self-signed cert | Validate HAProxy config |
| First Boot | Let’s Encrypt cert     | Production TLS |
| Renewal    | systemd timer + hook   | Rebuild PEM + reload HAProxy |

Certbot runs twice daily via:

```
certbot.timer
```

Renewal hook:

```
/etc/letsencrypt/renewal-hooks/deploy/haproxy
```

Ensures:

- PEM bundle rebuilt
- Correct permissions applied
- HAProxy reload
- Zero downtime

---

# 🛠 Repository Structure

```
infra/
├── packer/
│   └── ops/
│       ├── template.pkr.hcl
│       └── scripts/
│
├── terraform/
│   └── ops/
│
opt/
└── scripts/
    └── hugo.sh
```

---

# 🧪 Validation

```
curl -Iv https://onwuachi.com
```

Expected:

- Valid Let's Encrypt certificate
- HTTP 200 response
- No exposed container ports

---

# 🧠 Engineering Principles

- Infrastructure before applications
- Immutable > mutable
- Containers are disposable
- Edge terminates TLS
- Health checks everywhere
- Minimal public attack surface
- Deterministic rebuild discipline
- Cost awareness without architectural shortcuts

---

# ⚠️ Known Constraints (Intentional)

- Single-node runtime
- No autoscaling
- No blue/green deployment
- No centralized metrics pipeline
- No alerting system
- Observability not yet isolated

These are addressed in Phase 4.

---

# 🔜 Phase 4 – Private Observability Isolation (Planned)

Next evolution:

- Dedicated private EC2 instance
- Private subnet only
- No public IP
- No Elastic IP
- Prometheus + Grafana isolated
- Node exporter integration
- HAProxy metrics endpoint
- Scheduled stop/start workflows
- Cost-aware lifecycle automation

Goal:

> Separate monitoring from edge runtime while preserving cost discipline.

---

# 📌 Current Status

**Current Phase:** 3 – Edge Routing Hardened  
**Default Branch:** `main`  
**Latest Stable Tag:** `phase-3-namespace-converged`

---

🏷 Phase 3.1 – GitHub OIDC Namespace Convergence

Tag: phase-3-namespace-converged
Closed: March 2026

Aligned IAM trust relationship with repository canonical namespace.

What Changed

Updated OIDC condition:

repo:trainbus/devops-lab-week1

→

repo:Onwuachi/platform-foundation

Terraform plan confirmed in-place IAM role update:

~ assume_role_policy modified

Followed by full immutable instance replacement to validate no drift.

Why This Matters

Eliminates legacy lab namespace

Ensures CI/CD trust is tied to canonical repository

Prevents OIDC token mismatch failures

Removes hidden technical debt from early lab scaffolding

Validation Performed
terraform apply
→ IAM role updated
→ EC2 destroyed
→ EC2 recreated
→ EIP reattached

Outputs confirmed successful convergence:

Apply complete! Resources: 2 added, 1 changed, 2 destroyed.
Principle Reinforced

Identity boundaries must reflect production ownership — not training artifacts.

---

Observability Layer Prep (Phase 3.2)

The platform includes a lightweight observability stack baked into the immutable AMI.

Prometheus runs in a containerized deployment model with persistent
host-backed storage mounted at /opt/prometheus/data.


Components:

Component	Purpose
Node Exporter	Host metrics
Prometheus	Metrics collection
Blackbox Exporter	TLS + endpoint probing
Grafana	Visualization

Metrics are stored locally:

/opt/prometheus/data

Grafana dashboards persist in:

/opt/grafana/data

Prometheus configuration:

/opt/prometheus/prometheus.yml

Blackbox probes validate:

TLS certificate expiry

HTTP readiness endpoints

edge availability

Prometheus storage optimizations:

--storage.tsdb.wal-compression
--storage.tsdb.retention.time=15d

These reduce disk IO and control EBS growth.

Important folders: 
infra/
 ├ packer/
 │   └ ops/
 │       ├ template.pkr.hcl
 │       ├ scripts/
 │       ├ files/
 │       │   ├ prometheus.yml
 │       │   ├ blackbox.yml
 │       │   └ rules/
 │       │        └ instance_down.yml
 │       └ systemd/
 │           ├ prometheus.service
 │           ├ grafana.service
 │           ├ node_exporter.service
 │           └ blackbox-exporter.service


---

# 👤 Author

Derrick C. Onwuachi  
Cloud / DevOps Engineer  

This repository reflects a production-minded infrastructure evolution emphasizing immutability, operational correctness, and responsible cloud architecture.
