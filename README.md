##
---
# Platform Foundation  
### *Stateless Infrastructure + Self‑Rehydrating Control Plane*

A production‑style platform that combines **immutable infrastructure**, **declarative state**, and a **self‑rehydrating control plane** to rebuild its entire runtime deterministically from a single source of truth.

This project evolves traditional DevOps into a **minimal platform layer (PaaS‑like)** where routing, services, and runtime configuration are reconstructed automatically and predictably.

---

## 🚀 Core Principle

> **Compute is ephemeral. State is externalized. The platform is fully reproducible on demand.**

---

## 🧠 Architecture Overview

```
+----------------------+
|      Route53 (DNS)   |
+----------+-----------+
           |
           ▼
+-------------------------------+
| HAProxy (Edge)               |
| TLS Termination + Routing    |
+-------------------------------+
           |
   ---------------- CONTROL PLANE ----------------
           |
           ▼
     S3 (Source of Truth)
   /platform/services/*
           |
           ▼
   platform-rehydrate (systemd)
           |
           ▼
   Deterministic Rebuild:
     - systemd units
     - HAProxy config
     - TLS certificates
     - Running containers
   -----------------------------------------------
           |
   ------------------- DATA LAYER ----------------
           |
           ▼
     EBS Volume (persistent state)
```

---

## 🔧 Technology Stack

- **Packer** — Immutable AMI creation  
- **Terraform** — Infrastructure provisioning  
- **HAProxy** — Edge routing + TLS termination  
- **Docker** — Application runtime  
- **systemd** — Process supervision + orchestration  
- **S3** — Declarative control plane  
- **ECR** — Container registry  
- **Certbot** — Automated TLS lifecycle  

---

## 🎯 Platform Capabilities

- Immutable infrastructure (no in‑place mutation)  
- Declarative service registry via S3  
- Deterministic HAProxy config generation  
- systemd‑managed container lifecycle  
- Full platform rehydration from control plane  
- Automated TLS provisioning + renewal  
- Private service exposure (127.0.0.1 only)  

---

## 🧱 System Design

### **Edge Layer (HAProxy)**  
Handles:
- TLS termination (443)  
- HTTP→HTTPS redirection  
- Domain‑based routing via generated backend maps  

### **Runtime Layer**  
Each service runs as a Docker container.  
systemd provides:
- Lifecycle control  
- Restart guarantees  
- Boot‑time recovery  

### **Control Plane (S3)**  
Defines the entire desired state:

```
services.list     → enabled services
<service>.port    → runtime binding
<service>.domain  → routing definition
```

No runtime decisions occur outside this state.

---

## 🔁 Rehydration Workflow

```
S3 → local sync
    → generate HAProxy config
    → generate systemd units
    → pull container images
    → start services
    → validate HAProxy
    → safe reload
```

This process is:
- **deterministic**  
- **repeatable**  
- **environment‑independent**  

---

## ⚙️ Platform CLI

### **Deploy a Service**
```
platform deploy <service>
```

Performs:
- Container build + push (ECR)  
- Port allocation  
- S3 registration  
- HAProxy regeneration  
- systemd unit creation/update  
- Service restart  

### **Rehydrate Platform**
```
platform rehydrate
```

Reconstructs the entire runtime from S3:
- Restores service registry  
- Recreates systemd units  
- Pulls latest images  
- Rebuilds routing  
- Ensures TLS certificates  
- Reloads HAProxy safely  

---

## 🔐 Security Model

- Exposed ports: **80 (redirect)**, **443 (TLS)**  
- All services bound to **127.0.0.1**  
- TLS managed via Certbot  
- Zero‑downtime renewals  
- Safe HAProxy reloads  

---

## 🏗 Lifecycle

1. **Build** → `packer build`  
2. **Provision** → `terraform apply`  
3. **Runtime** → systemd + platform‑rehydrate  

---

## 📦 Evolution

### **Phase 1 — Immutable Foundation**
- Hardened AMI  
- HAProxy baseline  
- TLS validation during build  

### **Phase 2 — Container Runtime**
- Dockerized services  
- systemd orchestration  
- Static routing  

### **Phase 3 — Edge Stability**
- Deterministic routing  
- TLS automation  
- Rebuild validation  

### **Phase 4 — Control Plane (Current)**
- S3‑backed declarative state  
- Dynamic routing generation  
- Automated rehydration  
- Stateless compute model  

> The system now operates as a **minimal platform layer**.

---

## ⚠️ Current Constraints

- Single‑node architecture  
- No autoscaling  
- No blue/green or canary deployments  
- Limited observability  
- No centralized alerting  

---

## 🔜 Next Phase: Production Maturity

- Multi‑node architecture  
- Health‑based routing  
- Blue/green deployments  
- Observability stack  
- Alerting + incident response  

---

## 🧠 Engineering Principles

- Immutability over mutation  
- Declarative state over imperative logic  
- Stateless compute, stateful recovery  
- Rebuild over repair  
- Automation as the default  

---

## 📁 Repository Structure

```
platform-foundation
├── apps/       # Application services
├── infra/      # Packer + Terraform
├── tools/      # Platform CLI
├── scripts/    # Utilities
```

---

## 📌 Status

**Phase:** 4 — Control Plane  
**System is:**  
- Deterministic  
- Rehydratable  
- Self‑healing  
- Dynamically routed  

---

## 👤 Author

**Derrick C. Onwuachi**  
Cloud / DevOps / Platform Engineer  

---

## 📦 Proven Runtime Behaviors

- Immutable AMI replacement validated  
- Full node destruction + rebuild tested  
- Runtime reconstructed from S3  
- HAProxy safe reload validated  
- TLS auto‑discovery via cert directory  
- Docker services restored automatically  
- systemd orchestration verified  

---

## 📌 Operational Commands

```
platform up
platform down
platform deploy api
platform register hugo 8081 onwuachi.com
platform rehydrate
platform shell
```

---

## 🔁 Rehydration Sequence

```
EC2 Boot
→ systemd
→ platform-rehydrate
→ S3 sync
→ generate HAProxy maps
→ generate service units
→ pull images
→ start containers
→ validate HAProxy
→ graceful reload
```

---

## 🏆 Key Engineering Achievements

- HAProxy runtime include architecture  
- Dynamic backend generation  
- TLS directory‑based SNI loading  
- Immutable rebuild validation  
- systemd‑driven service orchestration  
- Externalized control plane state  

---

If you want, I can also generate:

- A **shorter README**  
- A **diagram‑heavy README**  
- A **LinkedIn‑ready project summary**  
- A **GitHub topics + tagline set**  
- A **badge‑enhanced README**  

Just tell me which direction you want next.
