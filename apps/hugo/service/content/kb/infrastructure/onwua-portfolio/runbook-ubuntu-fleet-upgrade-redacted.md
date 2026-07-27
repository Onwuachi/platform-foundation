---
title: "Ubuntu In-Place OS Upgrade (20.04 → 24.04) — Production Fleet + Physical Edge Appliances"
date: 2026-07-14
draft: false
description: "Validated end-to-end procedure for upgrading Ubuntu 20.04 to 24.04 across a mixed fleet of ~36 AWS EC2 production instances and physical edge appliances."
summary: "In-place Ubuntu 20.04 → 24.04 upgrade validated in UAT before rollout across cloud and physical edge fleet."
tags: ["ubuntu", "os-upgrade", "fleet-management"]
categories: ["runbooks"]
---

# Ubuntu In-Place OS Upgrade (20.04 → 24.04) — Production Fleet + Physical Edge Appliances

**Scope:** ~36-instance AWS EC2 production fleet plus physical edge
appliances at customer sites, running a containerized real-time
communications platform.

## Summary

Validated end-to-end procedure for upgrading Ubuntu 20.04 → 24.04 across
a mixed fleet of cloud instances and physical edge hardware. All upgrade
paths validated in UAT before production. First production instance
completed with the platform running live traffic (dozens of active
sessions, live users online) immediately post-upgrade, with zero
unplanned downtime across the rollout.

## Validated Upgrade Paths

| Path | Notes |
|---|---|
| EC2 20.04 → 24.04 | Standard path — most of the fleet |
| EC2 18.04 → 24.04 | 3 hops; broken `dpkg` fix required on aged installs |
| EC2 Xen/EFI 20.04 → 24.04 | Requires a `grub-efi` fix + a small systemd service |
| Physical appliance 20.04 → 24.04 | ~2 min tunnel reconnect per reboot (access is via reverse SSH tunnel only, no direct console) |

## Timing Reference

| Step | Cloud instance | Physical appliance |
|---|---|---|
| Pre-flight | 10 min | 10 min |
| Hop 1 (20→22) | 15 min | 17 min |
| Between hops | 20 min | 20 min |
| Hop 2 (22→24) | 17 min | 18 min |
| Post-upgrade + restart | 45 min | 45 min |
| **Total** | **~90–120 min** | **~90–120 min** |

## EC2 Fleet — Pre-Flight (Every Instance)

**1. Terraform lifecycle block first (prod only):**
```hcl
lifecycle {
  ignore_changes  = [ami]
  prevent_destroy = true
}
```
```bash
terraform fmt && terraform validate
terraform plan   # must show No changes
```

**2. Snapshot:**
```bash
INSTANCE_ID="i-YOURINSTANCEID"
REGION="us-east-2"
VOLUME_ID=$(aws ec2 describe-instances \
  --instance-ids $INSTANCE_ID \
  --query 'Reservations[].Instances[].BlockDeviceMappings[?DeviceName==`/dev/sda1`].Ebs.VolumeId' \
  --output text --region $REGION)
aws ec2 create-snapshot \
  --volume-id $VOLUME_ID \
  --description "pre-upgrade $(date +%Y%m%d)" \
  --region $REGION
```

**3. Disk space — 5GB+ free required:**
```bash
df -h /
sudo apt-get autoremove -y && sudo apt-get clean
sudo ls -lah /var/crash/ && sudo rm /var/crash/core.* 2>/dev/null || true
```

**4. Fix GPG keys (required on every instance):**
```bash
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg --yes
sudo sed -i 's|deb https://packages.cloud.google.com/apt|deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt|' \
  /etc/apt/sources.list.d/google-cloud-sdk.list

sudo sed -i 's/^deb/# deb/' /etc/apt/sources.list.d/nodesource.list 2>/dev/null || true

sudo apt-get update 2>&1 | grep -i 'err\|fail\|warn'   # must be clean
```

**5. Full update:**
```bash
sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y
sudo apt list --upgradable 2>/dev/null | grep -v WARNING   # must be empty
sudo apt install -y tmux
```

## EC2 Fleet — Upgrade Procedure

**Hop 1: 20.04 → 22.04** (no reboot after hop 1 — containers stay running):
```bash
tmux new -s upgrade1
echo "Starting 20.04->22.04: $(date)" | tee ~/upgrade_timing.txt
sudo DEBIAN_FRONTEND=noninteractive \
  do-release-upgrade -f DistUpgradeViewNonInteractive
```
Validate: `lsb_release -a && df -hT && sudo docker ps && systemctl --failed`

**Between hops — critical order for production stacks.** Always stop
containers **before** apt operations — doing apt operations while
containers are running can corrupt the stack:
```bash
# 1. Stop stack first
export SERVICE_INSTANCE=INSTANCENAME
/mnt/efs/AppStack/stopStack.sh
sudo docker ps   # must be empty

# 2. Re-enable Docker repo for the current codename (jammy, not noble yet)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg --yes
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu jammy stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list

# 3. Full update
sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y
sudo apt list --upgradable 2>/dev/null | grep -v WARNING   # must be empty

# 4. Reboot
sudo reboot
```

**Hop 2: 22.04 → 24.04:**
```bash
tmux new -s upgrade2
echo "Starting 22.04->24.04: $(date)" | tee -a ~/upgrade_timing.txt
sudo DEBIAN_FRONTEND=noninteractive \
  do-release-upgrade -f DistUpgradeViewNonInteractive
```
EC2 may not auto-reboot after hop 2 — if the upgrader exits without
rebooting:
```bash
/mnt/efs/AppStack/stopStack.sh
sudo docker ps   # must be empty
sudo reboot
```

**Post-upgrade:**
```bash
lsb_release -a && uname -r && df -hT && systemctl --failed && dpkg --audit

# Fix hostname
echo "127.0.0.1 $(hostname)" | sudo tee -a /etc/hosts

# Fix Docker group
sudo usermod -aG docker USERNAME

# Re-enable repos for noble
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg --yes
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu noble stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update 2>&1 | grep -i 'err\|fail\|warn'

# Start stack
export SERVICE_INSTANCE=INSTANCENAME
/mnt/efs/AppStack/startStack.sh
sleep 60 && docker ps

# Terraform validation (prod)
terraform plan   # must show No changes
```

## Known Issues by Instance Type

**EC2 18.04 instances — extra steps required.** Three hops:
18.04 → 20.04 → 22.04 → 24.04. Check for broken `dpkg` (common on aged
18.04 installs):
```bash
sudo dpkg --audit
sudo dpkg --configure -a
# If it fails — remove maintainer scripts:
sudo rm -f /var/lib/dpkg/info/PACKAGENAME.{prerm,postrm,postinst,preinst}
sudo dpkg --remove --force-remove-reinstreq PACKAGENAME
```

**grub-pc NVMe mismatch on EC2 NVMe instances:**
```bash
echo "(hd0) /dev/nvme0n1" | sudo tee /boot/grub/device.map
sudo grub-install /dev/nvme0n1
sudo update-grub && sudo dpkg --configure -a
```

**EC2 Xen/EFI instances — grub-efi fix.** Detect: `lsblk` shows `xvda`
not `nvme`, `/boot/efi` mounted:
```bash
# Get the exact device ID grub needs
sudo dpkg --configure -a 2>&1 | grep "special device"

mkdir -p /dev/disk/by-id
ln -sf /dev/xvda /dev/disk/by-id/virtio-$(blkid -s UUID -o value /dev/xvda1)
ln -sf /dev/xvda15 /dev/disk/by-id/nvme-<volume-id>-part15

# Permanent fix — recreate the symlinks on every boot
sudo tee /etc/systemd/system/grub-disk-symlinks.service > /dev/null <<'EOF'
[Unit]
Description=Recreate /dev/disk/by-id symlinks for grub-efi on Xen
DefaultDependencies=no
Before=local-fs.target
[Service]
Type=oneshot
ExecStart=/bin/bash -c 'mkdir -p /dev/disk/by-id && \
  ln -sf /dev/xvda /dev/disk/by-id/virtio-$(blkid -s UUID -o value /dev/xvda1) 2>/dev/null; \
  ln -sf /dev/xvda15 /dev/disk/by-id/nvme-<volume-id>-part15 2>/dev/null'
RemainAfterExit=yes
[Install]
WantedBy=sysinit.target
EOF
sudo systemctl enable grub-disk-symlinks.service
```
Expected warnings on Xen EFI (harmless): `grub-install: warning: EFI
variables are not supported on this system. Installation finished. No
error reported.`

**Docker repo codename mismatch.** Setting the `noble` repo while still on
`jammy` causes a `libc6` dependency failure — always match the repo
codename to the current OS (22.04 → `jammy`, 24.04 → `noble`).

## Docker 25+ Silently Drops Container `nofile` Limit (Critical)

**Discovered via a production incident** that caused a multi-hour outage
on two high-volume production hosts — the service hit its file descriptor
ceiling under normal load and couldn't bind ports or create new
sockets/files.

Docker Engine 25.0+ removed the explicit `LimitNOFILE=infinity` line from
containerd's shipped systemd service unit. Any container started without
an explicit `--ulimit nofile` override now silently inherits systemd's own
default (1024 soft) instead of the previous effectively-unlimited value
(1,048,576). **This is a real upstream Docker/containerd packaging
change, not something specific to any one team's scripts** — nothing was
"broken," a default that used to be set was removed upstream. It wasn't
caught in advance because it only manifests under sustained production
load, not in normal validation — it took the whole team digging into it
together to trace container resource exhaustion back to this one
removed line.

**This affects every instance upgraded through this procedure**, since
the standard path upgrades Docker alongside the OS. Treat this as a
required step, not optional.

**Detect** (check containerd, not `docker.service` — that shows nothing
either way):
```bash
cat /lib/systemd/system/containerd.service | grep -i limit
# Docker < 25: LimitNOFILE=infinity present
# Docker 25+: LimitNOFILE line absent entirely

sudo docker run --rm busybox:musl sh -c "ulimit -n"
# Pre-existing containers (created before the Docker 25+ upgrade): 1048576
# Freshly created containers on Docker 25+: 1024
```

**Fix** — apply as part of every OS/Docker upgrade going forward:
```bash
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "default-ulimits": {
    "nofile": { "Name": "nofile", "Soft": 524288, "Hard": 524288 }
  }
}
EOF
sudo systemctl restart docker
```
> This restarts every container on the host — fold this into the same
> post-upgrade window, don't schedule it as a separate outage.

**Validate:**
```bash
docker cp /usr/bin/busybox <container>:/opt/tools
docker exec <container> /opt/tools/busybox sh -c 'ulimit -n'
# Expect 524288
```

## Physical Edge Appliances (Reverse-Tunnel Managed)

**Key differences from EC2:**

- Access via reverse SSH tunnel only — no direct SSH, no cloud console
- `/dev/disk/by-id` exists correctly on physical hardware — no grub fix
  needed
- Tunnel reconnect after reboot: ~2 minutes
- No containers — legacy service runs as a systemd unit
- Bootstrap/recovery tunnel must exist before starting the upgrade

**Monitoring terminal (keep open throughout):**
```bash
watch -n3 'echo "=Primary=" && ss -tlnp | grep PRIMARYPORT; \
           echo "=Recovery=" && ss -tlnp | grep RECOVERYPORT'
```

**Upgrade procedure — same as EC2 but:** stop the legacy service before
reboots; wait 2 minutes after each reboot for tunnel reconnect; use the
recovery tunnel if the primary fails.

**Add bootstrap tunnel (if missing — do before upgrade):**
```bash
sudo tee /etc/systemd/system/bootstrap-tunnel.service > /dev/null <<'EOF'
[Unit]
Description=Backup Reverse SSH Tunnel
After=network-online.target
Wants=network-online.target
[Service]
Type=simple
User=root
ExecStart=/usr/bin/ssh -qNn \
  -o ServerAliveInterval=30 -o ServerAliveCountMax=3 \
  -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -i /etc/sshtunnel/id_rsa \
  -R RECOVERYPORT:127.0.0.1:22 \
  -R RECOVERYUIPORT:127.0.0.1:8080 \
  tunnel-user@<tunnel-host> -p 22
Restart=always
RestartSec=60
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now bootstrap-tunnel.service
```

**Critical operating rules for edge appliances:**
- The legacy service must use host networking — never bridge mode
- `bootstrap-tunnel.service` must always exist — never remove it
- Container images must be locally staged — no registry pulls in
  production
- Never copy tunnel keys between devices — each device generates its own
- Never run `docker system prune -a`

## Terraform Fleet Management

**Lifecycle block pattern** (apply to each instance before upgrade):
```hcl
lifecycle {
  ignore_changes  = [ami]
  prevent_destroy = true
}
```

**Resize test** (validates the lifecycle block after each prod upgrade):
```bash
# Change instance_type in main.tf temporarily
terraform plan     # must show ~ not -/+
terraform apply -target=aws_instance.INSTANCENAME_prod
# Revert and apply again
terraform plan     # must show No changes
```

**Post-upgrade Terraform validation:**
```bash
terraform plan   # must show No changes after every upgrade
```
Terraform cannot see OS-level changes — in-place upgrades are invisible
to state. The AMI reference stays as the original launch AMI, which is
correct behavior with `ignore_changes = [ami]`.

## Production Validation Checklist (Required)

**Purpose:** validate the OS upgrade, Docker runtime, storage, application
services, and runtime resource limits before returning the host to
production. This checklist exists because of the file-descriptor incident
above — don't skip it.

**Operating system:**
```bash
lsb_release -a
uname -r
hostnamectl
systemctl --failed
```
Expected: Ubuntu 24.04.x LTS, correct kernel, no failed services.

**Docker runtime:**
```bash
docker version
docker info
containerd --version
```
Record the Docker Engine and containerd versions in the maintenance log.

**Docker resource limits (critical):**
```bash
cat /etc/docker/daemon.json
```
Expected: contains `default-ulimits` with `nofile` Soft/Hard = 524288. If
missing, apply the fix above, then `sudo systemctl restart docker`.

**Verify container `nofile` limit:**
```bash
docker exec <container> bash -c "ulimit -n"
```
Expected: `524288`. **If not: stop — do not return the stack to
production.**

**Verify process limits:**
```bash
docker inspect -f '{{.State.Pid}}' <container>
cat /proc/<PID>/limits
```
Confirm: Max open files → 524288.

**Verify mounts:**
```bash
mount | grep nfs          # network storage — mounted, writable
mount | grep fuse.s3fs     # object storage — log bucket mounted
lsblk && df -h             # block storage — expected mount points present
```

**Verify containers:** `docker ps` — all running, no restart loop.

**Verify application functionality:** connectivity/registration to
upstream services succeeds; recording/playback (if applicable) works;
core call/session processing works; existing sessions remain healthy.

**Verify file descriptor usage:**
```bash
lsof | wc -l
docker exec <container> bash -c "lsof | wc -l"
```
Compare against a historical baseline — record the number every time,
since this is how future incidents get caught earlier.

**Verify container restart behavior:**
```bash
docker restart <container>
```
Confirm it inherits the 524288 limit, rejoins the network, and services
recover.

**Terraform validation:** `terraform plan` — expected: no changes.

## Lessons Learned

During the fleet-wide 24.04 rollout, an upstream Docker runtime change
altered the default file descriptor limits inherited by newly recreated
containers. This behavior only manifested on the highest-volume
production hosts under sustained load, where the reduced limit led to
resource exhaustion and service degradation. The team traced it back to
the removed `LimitNOFILE` line, mitigated it with a host-wide Docker
configuration (`default-ulimits`), and validated the fix across the fleet.
As a direct result, Docker runtime validation and resource-limit
verification are now mandatory steps in every OS upgrade procedure, not
just a nice-to-have.

## Future Improvement — High-Load Validation

Current validation confirms functionality but does not fully simulate
production-scale workloads — this gap is what let the file descriptor
issue go undetected until it hit production. Planned enhancements:
synthetic high-volume load testing, file descriptor growth monitoring
under sustained load, long-duration soak testing (30–60 min), concurrent
functional-load validation, and Docker/containerd runtime validation
under load.

## Quick Fixes Reference

| Symptom | Fix |
|---|---|
| `sudo: unable to resolve hostname` | `echo "127.0.0.1 $(hostname)" >> /etc/hosts` |
| `docker ps` requires sudo | `sudo usermod -aG docker USERNAME` then re-login |
| `containerd.io` held back | `sudo apt-get install -y containerd.io` |
| `do-release-upgrade` refuses | Fully empty `apt list --upgradable` first |
| GPG key expired | Re-fetch with `gpg --dearmor` and update sources |
| `/var/crash` full | `sudo rm /var/crash/core.*` |
| Xen `grub-efi` `/dev/disk/by-id` missing | Create symlinks + systemd service |
| EC2 18.04 broken `dpkg` state | Remove maintainer scripts + force-remove package |
| EC2 18.04 grub-pc NVMe mismatch | `device.map` fix + `grub-install` |
| Docker fails after dist-upgrade | Reboot first — iptables/kernel mismatch |
| EC2 hop 2 doesn't auto-reboot | Stop the stack, then `sudo reboot` manually |
| Containers corrupt during upgrade | Always stop the stack **before** apt operations |
| Docker 25+ silently drops container `nofile` to 1024 | Add `default-ulimits` to `/etc/docker/daemon.json`, restart docker |
