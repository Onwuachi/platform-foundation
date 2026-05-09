tform Foundation
Stateless Infrastructure + Self-Rehydrating Control Plane

A production-style platform that applies immutable infrastructure, declarative state management, and automated rehydration to create a lightweight, self-healing system.

This project evolves beyond traditional DevOps into a platform layer (PaaS-like) where services, routing, and runtime configuration are reconstructed deterministically from a centralized control plane.

🚀 Core Principle

Compute is ephemeral.
State is externalized.
The platform is fully reproducible on demand.

🧠 Architecture Overview
                +----------------------+
                |     Route53 (DNS)    |
                +----------+-----------+
                           |
                           ▼
                    HAProxy (Edge)
                TLS Termination + Routing
                           |
        +------------------+------------------+
        |                                     |
        ▼                                     ▼
  Application Services                Certbot (ACME)
 (Docker + systemd)                  (webroot validation)
        |
        ▼
   127.0.0.1:<ports>

---------------- CONTROL PLANE ----------------

        S3 (Source of Truth)
   /platform/services/*
        |
        ▼
platform-rehydrate (systemd)
        |
        ▼
Deterministic Rebuild:
- systemd units
- HAProxy configuration
- TLS certificates
- running containers

---------------- DATA LAYER ----------------

EBS Volume (persistent state)
🔧 Technology Stack
Packer – Immutable AMI creation
Terraform – Infrastructure provisioning
HAProxy – Edge routing and TLS termination
Docker – Application runtime
systemd – Process supervision and orchestration
S3 – Declarative control plane (source of truth)
ECR – Container registry
Certbot (Let’s Encrypt) – Automated TLS lifecycle
🎯 Platform Capabilities
Immutable infrastructure (no in-place mutation)
Declarative service registration via S3
Deterministic HAProxy configuration generation
systemd-managed container lifecycle
Full platform rehydration from control plane
Automated TLS provisioning and renewal
Private service exposure (127.0.0.1 only)
🧱 System Design
Edge Layer

HAProxy is responsible for:

TLS termination (443)
HTTP → HTTPS redirection
Domain-based routing via generated backend maps
Runtime Layer
Each service runs as a Docker container
systemd provides:
lifecycle control
restart guarantees
boot-time recovery
Control Plane (Key Design)

S3 acts as the single source of truth for platform state:

services.list   → desired services
<service>.port  → runtime binding
<service>.domain → routing definition

No runtime decisions are made outside this state.

Rehydration Workflow
S3 → local state sync
   → generate HAProxy config
   → generate systemd units
   → pull container images
   → start services
   → validate configuration
   → reload HAProxy

This process is:

deterministic
repeatable
environment-independent
⚙️ Platform CLI
Deploy a Service
platform deploy <service>

Performs:

Container build and push (ECR)
Port allocation
Service registration in S3
HAProxy config regeneration
systemd service creation/update
Service restart
Rehydrate Platform
platform rehydrate

Reconstructs the entire runtime environment from S3:

Restores service registry
Recreates systemd units
Pulls latest container images
Rebuilds HAProxy routing
Ensures TLS certificates
Reloads edge proxy safely
🔐 Security Model
Only exposed ports:
80 (redirect)
443 (TLS)
All services:
bound to 127.0.0.1
inaccessible externally
TLS:
Managed via Certbot
Zero-downtime renewal
Safe HAProxy reloads
🏗 Lifecycle
Build
packer build → AMI
Provision
terraform apply → EC2 instance
Runtime
systemd → platform-rehydrate
📦 Evolution
Phase 1 – Immutable Foundation
Hardened AMI
HAProxy baseline
TLS validation during build
Phase 2 – Container Runtime
Dockerized services
systemd orchestration
Static routing
Phase 3 – Edge Stability
Deterministic routing
TLS automation
Rebuild validation
Phase 4 – Control Plane (Current)
S3-backed declarative state
Dynamic routing generation
Automated rehydration
Stateless compute model

The system now operates as a minimal platform layer


⚠️  Constraints
Single-node architecture
No autoscaling
No deployment strategies (blue/green, canary)
Limited observability isolation
No centralized alerting

🔜 Next Phase: Production Maturity
Multi-node architecture
Health-based routing
Blue/green deployments
Dedicated observability stack
Alerting and incident response

🧠 Engineering Principles
Immutability over mutation
Declarative state over imperative logic
Stateless compute, stateful recovery
Rebuild over repair
Automation as the default

📁 Repository Structure
platform-foundation
├── apps/           # Application services
├── infra/          # Packer + Terraform
├── tools/          # Platform CLI
├── scripts/        # Utilities

📌 Status

Phase: 4 – Control Plane
System is:
Deterministic
Rehydratable
Self-healing
Dynamically routed
👤 Author

Derrick C. Onwuachi
Cloud / DevOps Engineer

💡 Summary

This project demonstrates the progression from:

Infrastructure → Platform

A system designed not just to deploy services—but to reconstruct and operate them reliably from first principles.

📁 Proven Runtime Behaviors

Immutable AMI replacement validated
Full node destruction/rebuild tested
Runtime reconstructed from S3 state
HAProxy safe reload validated
TLS auto-discovery via cert directory
Docker services restored automatically
systemd orchestration verified

📌 Operational Commands
platform up
platform down
platform deploy api
platform register hugo 8081 onwuachi.com
platform rehydrate
platform shell

📌 Rehydration Sequence
EC2 Boot
 → systemd
 → platform-rehydrate
 → S3 state sync
 → generate HAProxy maps
 → generate service units
 → pull images
 → start containers
 → validate HAProxy
 → graceful edge reload


📦 Key Engineering Achievements
HAProxy runtime include architecture
Dynamic backend generation
TLS directory-based SNI loading
Immutable rebuild validation
Service orchestration via generated systemd
Externalized control plane state
