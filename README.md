# Platform Foundation

### Stateless Infrastructure + Self-Rehydrating Control Plane

A production-style platform engineering project combining:

* Immutable Infrastructure
* Declarative Runtime State
* Automated Recovery
* Edge Routing
* Observability
* Internal Documentation Services

The platform is designed around a simple principle:

> Compute is disposable. State is durable. Recovery is deterministic.

---

# 🚀 Current Platform Phase

## Phase 4.3 — Content Platform & Observability

Current capabilities include:

* Immutable AMI deployments
* Terraform-managed infrastructure
* Self-rehydrating control plane
* HAProxy edge routing
* Dockerized application runtime
* Automated TLS lifecycle
* Prometheus observability
* Node Exporter metrics
* Hugo-powered documentation platform
* Knowledge Base publishing
* Signals and content streams
* Disaster recovery snapshots

---
Phase 4.3 Highlights
--------------------

✓ Self-hosted Hugo documentation platform

✓ New content streams
  - Platform
  - Engineering
  - Culture
  - Recipes
  - Signals

✓ Dynamic Hugo layouts
  - section templates
  - reusable partials
  - module architecture

✓ Image support for markdown content

✓ Containerized Hugo publishing pipeline

✓ ECR-based deployment workflow

✓ platform rehydrate integration

✓ Prometheus observability stack

✓ Node Exporter metrics collection

✓ Grafana dashboard support

✓ Immutable infrastructure workflow
  Packer → Terraform → Rehydrate

---

# 🧠 Architecture Overview

```text
                     Route53
                         │
                         ▼
                ┌─────────────────┐
                │     HAProxy     │
                │ TLS + Routing   │
                └────────┬────────┘
                         │
         ┌───────────────┼───────────────┐
         │                               │
         ▼                               ▼

     Hugo Site                     Platform Services
 Documentation                     Docker Runtime

                         │
                         ▼

                 Control Plane (S3)

                         │
                         ▼

               platform-rehydrate

                         │
                         ▼

             Deterministic Recovery
```

---

# 🔧 Technology Stack

Infrastructure

* AWS EC2
* AWS EBS
* AWS S3
* AWS ECR
* Route53

Provisioning

* Terraform
* Packer

Runtime

* Docker
* systemd
* HAProxy
* Certbot

Observability

* Prometheus
* Node Exporter
* Grafana

Content Platform

* Hugo
* Nginx
* Markdown

---

# 🎯 Platform Capabilities

## Infrastructure

* Immutable AMIs
* Terraform provisioning
* Automated rebuild workflows
* Persistent state volumes

## Runtime

* Dockerized services
* Service registration
* Dynamic routing
* Automated TLS management

## Recovery

* Runtime rehydration
* S3 state restoration
* Automated service recreation
* HAProxy regeneration

## Observability

* Node metrics
* Platform metrics
* Health validation
* Runtime inspection

## Documentation

* Internal platform documentation
* Knowledge Base publishing
* Operational runbooks
* Engineering content streams

---

# 🔁 Platform Lifecycle

```text
packer build
      │
      ▼

terraform apply
      │
      ▼

EC2 Launch
      │
      ▼

systemd Startup
      │
      ▼

platform-rehydrate
      │
      ▼

S3 State Sync
      │
      ▼

Service Recovery
      │
      ▼

HAProxy Validation
      │
      ▼

Platform Online
```

---

# 🏗 Rehydration Workflow

```text
Sync runtime state from S3

Generate:

- service definitions
- routing maps
- HAProxy configs

Restore:

- TLS certificates
- platform metadata

Pull containers

Start services

Validate HAProxy

Reload edge

Platform operational
```

---

# ⚙️ Platform CLI

Start Platform

```bash
platform up
```

Stop Platform

```bash
platform down
```

Rehydrate Runtime

```bash
platform rehydrate
```

Deploy Service

```bash
platform deploy <service>
```

Register Service

```bash
platform register <service> <port> <domain>
```

Validate Health

```bash
platform health
```

---

# 📊 Observability

## Node Exporter

Validate metrics:

```bash
curl http://127.0.0.1:9115/metrics
```

Example metrics:

```text
node_cpu_seconds_total
node_memory_MemAvailable_bytes
node_filesystem_size_bytes
```

## Prometheus

Collects:

* Node metrics
* Platform metrics
* Runtime health data

---

# 🌐 Hugo Documentation Platform

The platform includes a self-hosted Hugo service published behind HAProxy.

Current site modules:

```text
Home
Platform
Engineering
Culture
Recipes
Signals
KB
```

---

# 📚 Content Architecture

```text
content/

├── platform/
├── engineering/
├── culture/
├── recipes/
├── signals/
└── kb/
```

```text
layouts/

├── _default/
├── platform/
├── culture/
├── recipes/
├── kb/
└── partials/
```

---

# 🍖 Recipes Module

Personal BBQ and smoking knowledge base.

Examples:

* Overnight Traeger Brisket
* Pitmaster Smoked Beef Tallow
* 3-Rib Fest Guide
* Baby Back Rib Runbooks
* Salmon + Drumstick Dual Smoke

---

# 🔐 Security Model

Public Exposure

* 80/tcp
* 443/tcp

Private Services

* 127.0.0.1 bindings only

Protection

* TLS automation
* HAProxy validation
* Zero-downtime reloads
* No direct container exposure

---

# 💾 Backup Strategy

Primary State

```text
platform-api-services
```

Backup State

```text
platform-api-services-backup
```

Includes:

* Service registry
* Routing definitions
* TLS assets
* Platform metadata

---

# 🔥 Disaster Recovery

```text
Node Loss

Terraform
   ↓

New EC2
   ↓

AMI Boot
   ↓

platform-rehydrate
   ↓

S3 Restore
   ↓

Runtime Recovery
   ↓

Platform Online
```

---

# 📦 Repository Structure

```text
platform-foundation

├── apps/
│   └── hugo/
│       └── service/
│
├── infra/
│   ├── terraform/
│   └── packer/
│
├── scripts/
├── docs/
└── tools/
```

---

# 🧪 Deployment Workflow

Build Hugo

```bash
hugo
```

Build Container

```bash
docker build -t hugo .
```

Tag

```bash
docker tag hugo \
046685909731.dkr.ecr.us-east-1.amazonaws.com/hugo:latest
```

Push

```bash
docker push \
046685909731.dkr.ecr.us-east-1.amazonaws.com/hugo:latest
```

Deploy

```bash
platform rehydrate
```

---

# 🏆 Proven Platform Behaviors

* Immutable rebuilds
* Terraform reprovisioning
* Runtime rehydration
* Automated service restoration
* Dynamic routing generation
* TLS restoration
* Docker recovery
* HAProxy safe reloads
* Hugo content publishing
* Observability validation

---

# 🔮 Future Roadmap

Phase 5

* Multi-node architecture
* Health-aware routing
* Blue/Green deployment
* Runtime reconciliation
* Alerting automation
* Distributed service registry

---

# 👤 Author

Derrick C. Onwuachi

Cloud • DevOps • Platform Engineering

Building resilient systems through automation, observability, and deterministic recovery.

