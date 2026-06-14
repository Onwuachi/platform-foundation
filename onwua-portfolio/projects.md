---
title: "Projects"
---

## Platform Foundation

**Production AWS platform · Personal lab · Active development**

A single-engineer AWS platform implementing immutable infrastructure, declarative runtime state, and a self-rehydrating control plane. The platform rebuilds its entire runtime deterministically from a single source of truth — no manual steps required.

Built and operated end-to-end: AMI → edge routing → CI/CD → disaster recovery → observability → documentation.

**What makes it real:** This isn't a tutorial follow-along. It's a working platform that has been destroyed and recovered, scaled and broken, monitored and debugged. Every design decision came from an operational constraint.

**Stack:** Terraform · Packer · Docker · HAProxy · GitHub Actions (OIDC) · Prometheus · Grafana · Blackbox Exporter · Hugo · AWS SSM · ECR · S3 · Route53 · CloudFront · ACM

**Architecture highlights:**
- Packer builds immutable AMIs → SSM Parameter Store hands off to Terraform (no hardcoded IDs)
- Clear ownership boundary: Terraform owns infrastructure, S3 owns runtime state, `platform-rehydrate` owns recovery
- Full node loss recovery: `terraform apply` + `platform-rehydrate` → platform online, zero manual steps
- HAProxy with dynamic backend maps (rendered from S3, not static config)
- GitHub Actions authenticates via OIDC — no long-lived AWS credentials anywhere
- This portfolio site (onwua.com) is part of the platform: Hugo → S3 → CloudFront, deployed on every push

[View on GitHub →](https://github.com/Onwuachi/platform-foundation)

---

## LLCI UC Appliance Architecture & Deployment System

**Internal engineering initiative · Architecture & operations design**

Designed and documented a standardized deployment and recovery architecture for containerized UC appliances operating in isolated customer environments. This wasn't a build-and-hand-off task — it was taking a loosely-defined deployment problem and building an architecture, deployment model, operational standard, and recovery process around it.

**What was actually built:**
- Analyzed the legacy deployment model and identified operational and recovery risks
- Designed artifact distribution flow using GCP Artifact Registry, controlled service accounts, and jumphost-based secure transfers
- Designed access model using reverse SSH tunnel architecture for remote administration in isolated environments
- Standardized Ubuntu 24.04 deployment with Docker-based host-networked UC workloads
- Created deterministic rebuild procedures and operational runbooks

**Stack:** Docker · Ubuntu 24.04 · GCP Artifact Registry · SSH tunneling · Bash

---

## Coming next

**EKS module** — adding a minimal, billing-safe EKS cluster to Platform Foundation using Terraform. Fargate-based so it costs $0 when idle. Will integrate with existing GitHub Actions OIDC, Prometheus observability, and the platform CLI.

**Prometheus/Grafana completion** — standardizing all scrape targets to `127.0.0.1`, wiring Grafana alerts, completing the observability stack that's currently ~70% there.
