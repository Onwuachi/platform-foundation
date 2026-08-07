---
title: "Linux Root Filesystem Cleanup & Disk Usage Investigation"
date: 2026-08-07
draft: false
tags:
  - linux
  - docker
  - containerd
  - disk-space
  - troubleshooting
  - operations
categories:
  - Linux
  - Troubleshooting
---

# Linux Root Filesystem Cleanup & Disk Usage Investigation

## Purpose

This runbook provides a structured process for identifying and reclaiming disk
space on Linux systems when the root filesystem becomes full.

Typical symptoms include:

- `No space left on device`
- Docker image pulls fail
- Package upgrades fail
- Log files stop writing
- Applications crash due to inability to write temporary files

---

# 1. Verify Disk Usage

Check filesystem utilization.

```bash
df -h
```

Example:

```text
Filesystem       Size  Used Avail Use%
/dev/root        8.7G  8.6G   84M 100%
```

If the root filesystem (`/`) is above 90%, continue with this runbook.

---

# 2. Find the Largest Top-Level Directories

```bash
sudo du -xh --max-depth=1 / | sort -h
```

Typical output:

```text
215M    /boot
664M    /snap
2.8G    /usr
5.8G    /var
11G     /
```

Ignore warnings from `/proc` and `/sys`; these are expected.

---

# 3. Drill Into the Largest Directory

Example:

```bash
sudo du -xh --max-depth=1 /var | sort -h
```

Example:

```text
430M    /var/log
568M    /var/cache
3.8G    /var/lib
```

Continue drilling down until the source is identified.

Example:

```bash
sudo du -xh --max-depth=1 /var/lib | sort -h
```

Example:

```text
1.3M    /var/lib/docker
3.4G    /var/lib/containerd
```

---

# 4. Common Locations

| Directory | Description |
|-----------|-------------|
| /var/log | Log files |
| /var/cache | Package manager cache |
| /var/lib/docker | Docker images and containers |
| /var/lib/containerd | Container image layers |
| /tmp | Temporary files |
| /var/tmp | Long-lived temporary files |

---

# Docker Cleanup

## View Docker Disk Usage

```bash
sudo docker system df
```

Example:

```text
TYPE            TOTAL     ACTIVE    SIZE      RECLAIMABLE
Images          13        4         3.583GB   2.066GB (57%)
Containers      4         4         147kB     0B
```

This identifies reclaimable Docker storage. :contentReference[oaicite:0]{index=0}

---

## Remove Unused Images

```bash
sudo docker system prune -af
```

Example result:

```text
Total reclaimed space: 2.066GB
```

This safely removes unused images, stopped containers, unused networks, and dangling layers managed by Docker. :contentReference[oaicite:1]{index=1}

---

## Remove Unused Images Only

```bash
sudo docker image prune -a
```

---

## Remove Build Cache

Docker Engine 25+ uses BuildKit.

```bash
sudo docker buildx prune
```

---

# Package Cache Cleanup

APT:

```bash
sudo apt clean
```

Remove obsolete packages:

```bash
sudo apt autoremove
```

---

# Journal Cleanup

Check usage:

```bash
journalctl --disk-usage
```

Limit logs to 200 MB:

```bash
sudo journalctl --vacuum-size=200M
```

---

# Log Cleanup

Identify large logs:

```bash
sudo du -sh /var/log/*
```

Truncate oversized logs without deleting them:

```bash
sudo truncate -s 0 /var/log/<logfile>
```

Never remove log files that are currently open.

---

# Temporary Files

```bash
sudo rm -rf /tmp/*
sudo rm -rf /var/tmp/*
```

Only perform this during an approved maintenance window.

---

# Verify Recovery

```bash
df -h
```

Docker:

```bash
sudo docker system df
```

---

# Best Practices

- Investigate before deleting.
- Use Docker commands instead of manually deleting `/var/lib/docker` or `/var/lib/containerd`.
- Truncate large log files instead of deleting them.
- Schedule periodic cleanup for long-running Docker hosts.
- Monitor root filesystem utilization using CloudWatch or Prometheus.

---

# Common Investigation Flow

```text
df -h
    │
    ▼
du -xh --max-depth=1 /
    │
    ▼
Identify largest directory
    │
    ▼
du -xh --max-depth=1 /largest-directory
    │
    ▼
Repeat until root cause identified
    │
    ▼
Clean up using application-specific tools
    │
    ▼
Verify with df -h
```

---

# Lessons Learned

During a Hugo deployment, Docker failed while pulling a new image:

```
failed to copy:
write .../containerd/.../data:
no space left on device
```

Investigation showed:

- Root filesystem: **100% full**
- `/var/lib/containerd`: **3.4 GB**
- Docker reported **2.066 GB reclaimable image data**

Running:

```bash
sudo docker system prune -af
```

reclaimed approximately **2 GB** of unused image layers, allowing the deployment to complete successfully. :contentReference[oaicite:2]{index=2}
