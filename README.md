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



---

### Public Surface Area

Only the following ports are exposed:

- **80** (HTTP → redirected to HTTPS)
- **443** (TLS)

All containers bind to:


127.0.0.1


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

### Principle Reinforced

> Infrastructure and application runtime must remain independent layers.

---

## ✅ Phase 3 – Edge Routing Hardening & Immutable Replacement
**Tag:** `phase-3-edge-observability-stable`

---

### 🔐 HAProxy Routing Hardening

- Removed duplicate `default_backend`
- Deterministic routing model enforced

### ♻ Immutable Replacement Validation

- Full EC2 replacement cycle validated
- No drift, no manual intervention

### ⚙ Runtime Hardening

- systemd restart policies validated
- HAProxy health checks enforced
- TLS renewal automation verified

---

## 🏷 Phase 3.1 – OIDC Namespace Convergence
**Tag:** `phase-3-namespace-converged`

- Corrected IAM trust relationship to canonical repo
- Eliminated legacy lab namespace
- Validated via full immutable rebuild

---

## 📊 Phase 3.2 – Observability Layer Prep

- Prometheus + Grafana baked into AMI
- Node exporter + blackbox exporter enabled
- Local persistent storage under `/opt`

---

## 🚀 Phase 3.3 – Platform Auto-Provisioning
**Tag:** `phase-3-platform-autoprovision`

This phase introduces **self-service deployment capabilities**, transitioning the system from a deployment script to a platform.

---

### 🔥 Capabilities Introduced

- Automatic **ECR repository creation**
- Dynamic **service port allocation**
- Runtime **PORT environment injection**
- Persistent **service registry**
- HAProxy backend generation per service
- systemd-based lifecycle orchestration
- S3-backed platform state recovery

---

### ⚙ Deployment Behavior

```bash
platform deploy <service>


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

### Principle Reinforced

> Infrastructure and application runtime must remain independent layers.

---

## ✅ Phase 3 – Edge Routing Hardening & Immutable Replacement
**Tag:** `phase-3-edge-observability-stable`

---

### 🔐 HAProxy Routing Hardening

- Removed duplicate `default_backend`
- Deterministic routing model enforced

### ♻ Immutable Replacement Validation

- Full EC2 replacement cycle validated
- No drift, no manual intervention

### ⚙ Runtime Hardening

- systemd restart policies validated
- HAProxy health checks enforced
- TLS renewal automation verified

---

## 🏷 Phase 3.1 – OIDC Namespace Convergence
**Tag:** `phase-3-namespace-converged`

- Corrected IAM trust relationship to canonical repo
- Eliminated legacy lab namespace
- Validated via full immutable rebuild

---

## 📊 Phase 3.2 – Observability Layer Prep

- Prometheus + Grafana baked into AMI
- Node exporter + blackbox exporter enabled
- Local persistent storage under `/opt`

---

## 🚀 Phase 3.3 – Platform Auto-Provisioning
**Tag:** `phase-3-platform-autoprovision`

This phase introduces **self-service deployment capabilities**, transitioning the system from a deployment script to a platform.

---

### 🔥 Capabilities Introduced

- Automatic **ECR repository creation**
- Dynamic **service port allocation**
- Runtime **PORT environment injection**
- Persistent **service registry**
- HAProxy backend generation per service
- systemd-based lifecycle orchestration
- S3-backed platform state recovery

---

### ⚙ Deployment Behavior

```bash
platform deploy <service>


Now performs:

Validate service directory
→ Ensure ECR repository exists (auto-create if missing)
→ Build container image
→ Push to ECR
→ Allocate or retrieve service port
→ Create systemd service (if new)
→ Register HAProxy backend dynamically
→ Restart service
→ Validate HAProxy configuration
→ Sync platform state to S3
→ Health check validation


🧠 Architectural Shift

Previously:

Infrastructure had to be pre-provisioned
Services required manual setup

Now:

Platform provisions required infrastructure dynamically
Services are deployable on demand
🧠 Principle Reinforced

Platforms should enable self-service deployment by abstracting infrastructure requirements.

🏗 Immutable AMI Lifecycle

Packer builds hardened image
AMI stored in SSM Parameter Store
Terraform consumes AMI
EC2 replaced on change

🚀 Deployment Model

Infrastructure Pipeline
packer build → SSM → terraform apply → EC2 replacement
Application Pipeline
build → push (ECR) → pull → run → route (HAProxy)

🛠 Repository Structure

platform-foundation
├─ apps
│   ├─ api
│   ├─ analytics
│   ├─ billings
│   ├─ hugo
│   └─ payments
│
├─ infra
│   ├─ packer
│   └─ terraform
│
├─ tools
│   └─ platform

⚠️ Known Constraints

Single-node runtime
No autoscaling
No blue/green deployments
No centralized alerting
Observability not isolated

🔜 Phase 4 – Private Observability Isolation

Private subnet monitoring node
No public exposure
Cost-controlled lifecycle
Full separation from edge runtime


📌 Current Status

Current Phase: 3.3 – Platform Auto-Provisioning
Default Branch: main
Latest Stable Tag: phase-3-platform-autoprovision

---
   Packer:
   installs everything
   enables services
   does NOT run certbot

   Terraform:
   provisions infra
   attaches volumes
   bootstraps instance
   does NOT manage certs

   Instance boot:
   user_data → mount + sync only

   Platform lifecycle:
   systemctl restart platform-rehydrate
      → webroot
      → cert-bootstrap
      → haproxy reload
      → services restart


   🔥 You now have:

   ✅ HAProxy never stops
   ✅ Certs are idempotent
   ✅ Platform is reconstructible
   ✅ Infra is stateless
   ✅ Observability is integrated    

   Infra awareness
   instance down
   disk fill
   cpu/memory
   Platform awareness
   API health
   HAProxy routing
   🔥 Security awareness
   SSL expiration monitoring

dynamic infra (Terraform)
immutable images (Packer)
runtime orchestration (rehydrate)
zero-downtime TLS
proactive alerting

👉 self-healing platform bootstrap system
👉 stateless compute + stateful recovery
👉 cert lifecycle fully automated
👉 zero-downtime TLS rotation
👉 observable from day 1
---

# 3/31/2026
🚧 Current State (Milestone Achieved)
Immutable infrastructure fully operational via Terraform + Packer
Platform node successfully rebuilt and rehydrated
Core services running:
API (healthy)
Hugo frontend
Prometheus + Grafana
HAProxy routing functional (HTTP + HTTPS)
End-to-end deployment pipeline validated (build → push → trigger)
⚠️ Known Gaps
TLS currently using self-signed certificate (LetsEncrypt integration pending)
Service registry mismatch between /etc/platform/services and /opt/platform/services
Dynamic service deployment not yet activating containers post-deploy
Some backends (billings, analytics, payments) not yet running
🎯 Next Steps
Unify service registry path
Implement automated TLS provisioning (Certbot + HAProxy integration)
Finalize service lifecycle management (deploy → run → register)
Add platform CLI command for service creation/registration

---

👤 Author

Derrick C. Onwuachi
Cloud / DevOps Engineer

This repository reflects a production-minded infrastructure evolution emphasizing immutability, operational correctness, and platform engineering principles.
