+++
title = "GCP Container Image Pipeline — Jump Host to Edge Node"
date = 2026-07-07T00:00:00-05:00
draft = false

type = "kb-article"

description = "End-to-end workflow for pulling container images from GCP Artifact Registry and delivering them to offline or restricted edge nodes via a jump host."
summary = "GCP Service Account setup, Docker image export, SSH tunnel transfer, and edge node loading — for environments where edge nodes cannot reach GCP directly."

tags = ["gcp", "docker", "artifact-registry", "edge", "ssh-tunnel", "scp", "service-account"]
categories = ["infrastructure", "gcp"]

weight = 0
+++

# Overview

This runbook documents the end-to-end workflow for delivering container images
from GCP Artifact Registry to edge nodes that cannot reach GCP directly.

The architecture uses a jump host as a staging layer — it authenticates to GCP,
pulls and caches images, then transfers them to edge nodes via SCP over an SSH tunnel.

Edge nodes never need cloud credentials. Images arrive as portable tar artifacts.

<!--more-->

# Architecture

```
GCP Artifact Registry
        │
        │  (Service Account auth)
        ▼
Jump Host
        │  docker pull → docker save → scp
        ▼
Edge Node
        │  docker load → docker run
        ▼
Running Container
```

**Why this model:**
- Edge nodes remain lightweight with no cloud dependencies
- No GCP credentials on edge devices
- Works in air-gapped or restricted network environments
- Image artifacts are portable and verifiable

---

# Phase 1 — GCP Service Account Setup

Create a dedicated service account for image pulls. Never use personal credentials
or project owner accounts for automated workflows.

```bash
gcloud iam service-accounts create gcr-pull-jumphost \
  --display-name="GCR Pull via Jump Host"
```

Grant the minimum required role — read-only access to Artifact Registry:

```bash
gcloud projects add-iam-policy-binding YOUR_PROJECT_ID \
  --member="serviceAccount:gcr-pull-jumphost@YOUR_PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.reader"
```

Create and download the key file:

```bash
gcloud iam service-accounts keys create gcr-pull-jumphost.json \
  --iam-account=gcr-pull-jumphost@YOUR_PROJECT_ID.iam.gserviceaccount.com
```

Transfer the key file securely to the jump host. Do not commit it to git.

---

# Phase 2 — Jump Host Setup

Create the directory structure:

```bash
sudo mkdir -p /opt/gcp/keys
sudo mkdir -p /opt/gcp/logs
sudo mkdir -p /opt/docker-cache
sudo chmod 755 /opt/docker-cache /opt/gcp
```

Secure the key file:

```bash
sudo cp gcr-pull-jumphost.json /opt/gcp/keys/
sudo chown root:root /opt/gcp/keys/gcr-pull-jumphost.json
sudo chmod 400 /opt/gcp/keys/gcr-pull-jumphost.json
```

Authenticate Docker to GCP:

```bash
gcloud auth activate-service-account \
  --key-file=/opt/gcp/keys/gcr-pull-jumphost.json

gcloud config set project YOUR_PROJECT_ID

gcloud auth configure-docker gcr.io
```

---

# Phase 3 — Pull and Cache Images

Pull images from GCP Artifact Registry:

```bash
docker pull gcr.io/YOUR_PROJECT_ID/YOUR_IMAGE:latest
```

Verify images are present:

```bash
docker images
```

Export to a portable tar artifact:

```bash
docker save gcr.io/YOUR_PROJECT_ID/YOUR_IMAGE:latest \
  -o /opt/docker-cache/your-image.tar
```

---

# Phase 4 — Transfer to Edge Node

Transfer the tar file via SCP over the SSH tunnel:

```bash
scp -P TUNNEL_PORT \
  /opt/docker-cache/your-image.tar \
  user@localhost:/tmp/
```

Connect to the edge node:

```bash
ssh user@localhost -p TUNNEL_PORT
```

Verify the file arrived:

```bash
ls -lh /tmp/your-image.tar
```

---

# Phase 5 — Load and Run on Edge Node

Load the image into the local Docker daemon:

```bash
docker load -i /tmp/your-image.tar
```

Verify the image loaded:

```bash
docker images
```

Run the container:

```bash
docker run -d YOUR_IMAGE:latest
```

---

# Edge Node Prerequisites

Before the load step will work, the edge node must have Docker installed.

If Docker is missing:

```bash
# Install Docker on Ubuntu
apt-get update
apt-get install -y \
  ca-certificates curl gnupg lsb-release

mkdir -p /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io

systemctl enable docker
systemctl start docker
```

Verify:

```bash
docker version
docker ps
```

---

# Verification Checklist

| Step | Command | Expected Result |
|---|---|---|
| SA auth | `gcloud auth list` | Service account active |
| Docker auth | `docker pull gcr.io/...` | Pull succeeds |
| Image export | `ls -lh /opt/docker-cache/` | tar file present |
| SCP transfer | `ls -lh /tmp/` on edge node | tar file present |
| Docker runtime | `docker version` on edge node | Daemon running |
| Image load | `docker load -i /tmp/image.tar` | Loaded |
| Container run | `docker ps` | Container running |

---

# Common Failures

**`permission denied` on `docker images`**
Running without sudo. Either add your user to the docker group or use `sudo`.

**`docker: command not found` on edge node**
Docker runtime not installed. See Edge Node Prerequisites above.

**`scp` hangs or times out**
SSH tunnel not established or port incorrect. Verify tunnel is active before transfer.

**`unauthorized` on `docker pull`**
Service account not authenticated or wrong project set.
Run `gcloud auth activate-service-account` again.

---

# Security Notes

- Service account key files must never be committed to git
- Use `chmod 400` on key files — read by owner only
- Rotate service account keys periodically
- Use `roles/artifactregistry.reader` — never grant broader roles for pull-only workflows
- Edge nodes should never have GCP credentials — the jump host is the auth boundary

---

# Related Articles

- `aws-ssm-plugin-setup.md` — SSM-based operational access (alternative to SSH tunnels)
- `docker-networking-ssm.md` — Docker networking patterns
