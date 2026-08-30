---
title: "Root Disk Full — Prometheus Volume Rightsizing + Docker Prune Automation"
date: 2026-08-30
description: "Diagnosed and fixed a root-disk-full incident on ops-01 (certbot failing due to no tmp space), reclaimed space via docker prune, rightsized the Prometheus EBS volume from 15G to 4G in Terraform, and added a scheduled docker prune to prevent recurrence."
tags: ["ebs", "terraform", "docker", "prometheus", "disk-space", "ops-01"]
categories: ["infrastructure"]
summary: "Root volume hit 97% full, breaking certbot cert renewal via a failed rehydrate. Root-caused to accumulated Docker images plus a 15G Prometheus EBS volume sitting at 3% utilization. Reclaimed ~1.8G via docker prune, then rightsized the Prometheus volume to 4G via Terraform (matches 15d retention at ~440M actual usage with headroom), and added a systemd timer to auto-prune Docker going forward."
---

## Problem

`platform up` / `platform rehydrate` failed with a certbot traceback:

```
File "/usr/lib/python3.12/tempfile.py", line 447, in _gettempdir
    tempdir = _get_default_tempdir()
```

Root cause: `/dev/root` was at **97% (8.4G/8.7G)**, leaving no room for `tempfile.mkdtemp()` to create certbot's working directory. Certificate renewal failed as a symptom of disk exhaustion, not a certbot-specific bug.

## Approach

### 1. Diagnose disk usage

```bash
sudo du -xh / --max-depth=2 2>/dev/null | sort -rh | head -30
```

`/var/lib/docker` was the single largest reclaimable chunk (1.1G), confirmed via:

```bash
sudo docker system df
# Images: 11 total, 4 active, 3.332GB, 1.705GB (51%) reclaimable
```

### 2. Reclaim immediate space

```bash
sudo docker system prune -af --volumes
# Total reclaimed space: 1.784GB
```

This alone took root from 97% → 82% (8.4G → 7.1G used), enough to unblock rehydrate immediately.

### 3. Identify the real waste: an oversized, near-empty EBS volume

While root was tight, a separate 15G EBS volume mounted at `/opt/prometheus/data` was sitting at **3% utilization (440M used)** — paying for capacity that wasn't needed and wasn't helping the root disk problem at all, since it's a separate filesystem.

Traced the volume's definition to `infra/ops/main.tf`, `aws_instance.ops` resource:

```hcl
ebs_block_device {
  device_name           = "/dev/sdf"
  volume_size           = 15
  volume_type           = "gp3"
  delete_on_termination = true
  encrypted             = true
}
```

Key finding: this is explicitly commented **"Prometheus Volume (Ephemeral)"** — it's provisioned inline on the instance (not a standalone `aws_ebs_volume` resource), formatted fresh via `mkfs.xfs` in `user_data` on every boot, and has `delete_on_termination = true`. There is no persistent-data concern here; the volume is designed to be wiped on every instance replacement (AMI rolls, `platform down`/`up`, etc.) — same as the instance itself.

Packer's role here is minimal and unrelated to size: `install_prometheus_dirs.sh` only creates the `/opt/prometheus/data` mount point directory inside the AMI at build time (`mkdir -p`). The actual EBS volume is provisioned and mounted later, at boot, by Terraform's `user_data` — which mounts *over* that directory. Volume sizing lives entirely in Terraform; no Packer change was needed.

### 4. Confirm retention window before rightsizing

Checked `infra/packer/ops/systemd/prometheus.service` for the actual retention config (not in `prometheus.yml` — it's a container flag):

```
--storage.tsdb.retention.time=15d
--storage.tsdb.wal-compression
```

At 440M actual usage for the current retention window, sized the new volume with headroom rather than tight to current usage — landed on **4G** (~10x current usage) to absorb scrape-target growth and WAL compaction overhead without risk of Prometheus wedging on a full disk.

### 5. Apply via Terraform

```hcl
ebs_block_device {
  device_name           = "/dev/sdf"
  volume_size           = 4   # was 15
  volume_type           = "gp3"
  delete_on_termination = true
  encrypted              = true
}
```

`terraform plan` confirmed the change forces `aws_instance.ops` + `aws_eip_association.ops` replacement — same blast radius as a routine AMI roll, EIP retained via re-association, Route53 untouched (points at the static `aws_eip.ops` resource).

```bash
terraform apply
# Plan: 2 to add, 0 to change, 2 to destroy.
# Apply complete! Resources: 2 added, 0 changed, 2 destroyed.
```

### 6. Verify

```bash
platform shell
df -hT
# /dev/root  ext4  8.7G  4.7G  4.0G  55% /

sudo systemctl status prometheus.service
# Active: active (running)
# TSDB started, WAL replay completed, config loaded, ready to receive web requests
```

### 7. Prevent recurrence — automate Docker pruning

Docker image/build-cache accumulation was the proximate cause of the root-disk crunch. Added `scripts/check-docker-disk.sh` to the Packer source tree (mirrors the existing `platform-update.sh`/`.service`/`.timer` pattern):

- Reports root disk usage and `docker system df` output
- Runs `docker system prune -af --volumes` when usage crosses a configurable threshold (default 80%) and `--prune` is passed
- Baked into the AMI with a `docker-disk-check.service` (oneshot) + `docker-disk-check.timer` (daily, `Persistent=true`, small randomized delay), enabled at build time — same pattern as `platform-update.timer`

## Result

- Root disk: 97% → 55% used (8.4G → 4.7G)
- Prometheus EBS volume: 15G → 4G (saves ~$0.88/month on gp3 storage)
- Docker disk-check/prune now runs daily via systemd timer, baked into the Packer AMI, in addition to being available as a manual command
- Prometheus confirmed healthy on the new volume — TSDB started clean, no data-loss concern given the volume's explicitly ephemeral, 15-day-retention design

## Notes / Open Items

- The `delete_on_termination = true` + `mkfs.xfs`-on-boot design means Prometheus history is wiped on every instance replacement by design — this was already true before this change, just newly confirmed/documented here
- `docker-disk-check.timer` uses a conservative 80% threshold; revisit if root disk sizing or workload changes
- Manual on-demand check remains available: `check-docker-disk.sh [--prune]` (env var `THRESHOLD` overrides default)
