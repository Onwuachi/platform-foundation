---
title: "Platform Validation Script"
date: 2026-07-17
draft: false

type: "kb-article"

description: "Comprehensive post-deployment validation script for Docker hosts, containers, operating system health, and platform configuration."

summary: "A reusable validation script developed for Platform Foundation that consolidates critical post-deployment health checks into a single command."

tags:
- platform
- validation
- docker
- linux
- devops
- infrastructure
- monitoring
- troubleshooting

categories:
- Infrastructure
- General

weight: 20
---

# Overview

`platform-validation.sh` is a reusable post-deployment validation script developed for the Platform Foundation project.

Rather than manually executing numerous commands after infrastructure changes, this script performs a consolidated health check of the operating system, Docker runtime, container resource limits, and overall platform configuration.

It serves as a repeatable validation step following deployments, upgrades, and maintenance windows.

<!--more-->

---

# Why It Matters

Infrastructure changes rarely fail immediately.

Most production issues occur because something appears healthy while a lower-level dependency is misconfigured.

Examples include:

- Incorrect Docker file descriptor limits
- Container runtime configuration drift
- Kernel upgrades requiring reboot
- Docker daemon configuration changes
- Operating system upgrades
- Platform deployments

Instead of remembering dozens of validation commands, `platform-validation.sh` provides a single source of truth for verifying platform health.

---

# Where It Fits

```text
Infrastructure Change
        │
        ▼
Platform Deployment
        │
        ▼
platform-validation.sh
        │
        ├── Docker Validation
        ├── Container Validation
        ├── File Descriptor Validation
        ├── Host Validation
        ├── Kernel Validation
        └── Operating System Validation
```

---

# Current Validation Checks

The script currently collects the following information:

## Container Health

- Running containers
- Container PID
- Open file descriptor count
- Maximum file descriptor limit

## Platform Health

- Total file descriptor usage
- Host file descriptor configuration
- Docker daemon configuration

## Software Versions

- Docker Engine
- containerd
- Ubuntu Release
- Hostname
- Kernel Version

---

# Script Source

```bash
#!/usr/bin/env bash

echo "======================================="
echo "Docker File Descriptor Health Check"
echo "Host: $(hostname)"
echo "Time: $(date)"
echo "======================================="

printf "\n%-35s %-8s %-8s %-8s\n" \
"Container" "PID" "FDs" "Limit"

TOTAL=0

for c in $(docker ps --format '{{.Names}}'); do

    PID=$(docker inspect --format '{{.State.Pid}}' "$c" 2>/dev/null)

    [ -z "$PID" ] && continue
    [ "$PID" = "0" ] && continue

    FD_COUNT=$(ls /proc/$PID/fd 2>/dev/null | wc -l)
    FD_LIMIT=$(awk '/Max open files/ {print $4}' /proc/$PID/limits)

    TOTAL=$((TOTAL+FD_COUNT))

    printf "%-35s %-8s %-8s %-8s\n" \
    "$c" "$PID" "$FD_COUNT" "$FD_LIMIT"

done

echo
echo "---------------------------------------"
echo "Total Stack FDs : $TOTAL"

echo
echo "Host file-max:"
cat /proc/sys/fs/file-nr

echo
echo "Docker daemon ulimits:"
cat /etc/docker/daemon.json

echo
docker version --format 'Docker {{.Server.Version}}'
containerd --version
lsb_release -a
hostnamectl
uname -r
```

---

# Example Output

```text
=======================================
Docker File Descriptor Health Check

Host: secure23
Time: Fri Jul 17 10:34:19 CDT 2026

Container                           PID      FDs     Limit
----------------------------------------------------------
haproxy                             1254      52     524288
prometheus                          1321      87     524288
grafana                             1498      74     524288
node-exporter                       1612      18     524288

---------------------------------------
Total Stack FDs : 231

Host file-max:
2848    0    9223372036854775807

Docker daemon ulimits:
{
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Soft": 524288,
      "Hard": 524288
    }
  }
}

Docker 29.0.1
containerd 2.2.x
Ubuntu 24.04 LTS
Kernel 6.8.x
```

---

# Real-World Background

This script originated during production Ubuntu upgrade testing.

During validation it became apparent that checking whether Docker was running was insufficient.

A Docker Engine upgrade changed the default container file descriptor limits, causing new containers to inherit Linux's default limit of **1024** instead of the expected **524288**.

The containers appeared healthy but would eventually fail under higher connection loads.

The script was expanded to verify container limits directly rather than relying solely on Docker service status.

---

# Usage

Execute from the platform repository:

```bash
./platform-validation.sh
```

or

```bash
bash platform-validation.sh
```

---

# Typical Use Cases

Run after:

- Ubuntu upgrades
- Docker upgrades
- containerd upgrades
- Kernel upgrades
- Platform deployments
- Packer image validation
- Terraform provisioning
- Disaster recovery testing
- Maintenance windows
- Production validation

---

# Engineering Analogy

Think of `platform-validation.sh` as the infrastructure equivalent of an aircraft pre-flight inspection.

A pilot does not simply verify that the engines start.

Instead, they confirm fuel systems, hydraulics, navigation, instrumentation, weather, communications, and flight controls before takeoff.

Likewise, this script verifies multiple layers of platform health before declaring a deployment successful.

---

# Best Practices

- Execute after every infrastructure change.
- Store validation output with deployment records.
- Compare results across environments.
- Keep the script under version control.
- Expand the script instead of creating one-off validation commands.

---

# Common Mistakes

- Assuming Docker running means the platform is healthy.
- Ignoring container resource limits.
- Forgetting to validate after kernel updates.
- Only checking service status.
- Skipping post-maintenance validation.

---

# Future Improvements

Planned additions include:

- Filesystem utilization
- Memory pressure
- CPU utilization
- Swap usage
- systemd failed services
- Prometheus exporter health
- HAProxy status
- Certificate expiration
- Network connectivity tests
- Docker image inventory
- Terraform version
- Git commit information
- Platform service validation

---

# Pro Tip

Treat `platform-validation.sh` as the central health validation framework for Platform Foundation.

Every new subsystem—Docker, Terraform, HAProxy, Prometheus, AWS services, certificates, backups, or monitoring—should contribute additional validation checks to this script instead of creating standalone utilities.

The goal is a single command capable of validating the entire platform after any infrastructure change.

---

# Key Takeaways

- Consolidates critical platform validation into one command.
- Eliminates repetitive manual health checks.
- Detects configuration drift early.
- Verifies both host and container health.
- Originated from production operational experience.
- Designed to evolve alongside Platform Foundation.

---

# Related Articles

- Ubuntu In-Place Upgrade Runbook
- Docker Resource Limits
- Docker File Descriptor Limits
- Platform Monitoring
- Prometheus Monitoring
- Packer Image Pipeline

---

# References

- Docker Documentation
- Ubuntu Server Documentation
- Linux `/proc` Filesystem Documentation
- Platform Foundation Operations

