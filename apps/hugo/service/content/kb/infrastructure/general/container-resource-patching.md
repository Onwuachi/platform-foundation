# Container Resource Patching Runbook

## Overview

Procedure for temporarily replacing a resource file inside a running container without rebuilding or redeploying the container image.

This method is intended for controlled, temporary remediation when a permanent image-based fix is not immediately available.

A resource-level patch should be treated as a **temporary operational change**, not a replacement for updating the underlying image.

---

## Prerequisites

* [ ] Correct target host identified
* [ ] Correct target container identified
* [ ] Current container/image version verified
* [ ] Patched file validated before deployment
* [ ] Original file backed up before replacement
* [ ] Patched file staged in a known location
* [ ] Rollback procedure understood
* [ ] Change documented for later removal or incorporation into the image

---

# Procedure

## 1. Connect to the Host

```bash
ssh <instance-host>
```

Obtain the required privileges:

```bash
sudo -i
```

---

## 2. Verify the Container Version

Before changing anything, determine exactly which image/version the container is running.

Examples:

```bash
docker ps
```

```bash
docker inspect <container-name> \
  --format '{{.Config.Image}}'
```

If the application exposes its version through logs:

```bash
docker logs <container-name> | grep -i version
```

Do not assume that every container requires the patch.

---

## 3. Confirm the Target File Exists

Inspect the container:

```bash
docker exec <container-name> ls -la /path/to/resource/
```

If the container does not have a usable shell, a minimal shell utility may need to be copied into the container.

For example, if BusyBox is available on the host:

```bash
docker cp /usr/bin/busybox \
  <container-name>:/tmp/busybox
```

Then:

```bash
docker exec -it <container-name> /tmp/busybox sh
```

---

## 4. Back Up the Existing File

Inside the container:

```bash
cd /path/to/resource/
```

Create a backup:

```bash
cp resource-file resource-file-bak
```

Verify:

```bash
ls -l resource-file*
```

**Never overwrite the original file before creating a rollback copy.**

---

## 5. Copy the Patched File Into the Container

From the host:

```bash
docker cp \
  /path/to/staged/patch/resource-file \
  <container-name>:/path/to/resource/resource-file
```

Verify:

```bash
docker exec <container-name> \
  ls -l /path/to/resource/resource-file
```

If appropriate, compare the file:

```bash
docker exec <container-name> \
  md5sum /path/to/resource/resource-file
```

---

## 6. Verify Application Behavior

Determine whether the application automatically reloads the resource.

If it does not, the container/application may need to be restarted:

```bash
docker restart <container-name>
```

Only restart when the operational impact is understood.

Then verify:

```bash
docker ps
docker logs <container-name> --tail 100
```

Confirm the specific behavior being remediated is resolved.

---

# Important Gotchas

### 1. Container filesystem layouts can differ

Do not assume the target path exists in every container.

If:

```bash
cd /path/to/resource/
```

returns:

```text
No such file or directory
```

stop and inspect the image/container layout.

The container may be running a different version or use a different filesystem structure.

---

### 2. Always create a rollback copy

Before replacing:

```bash
cp resource-file resource-file-bak
```

Without a backup, rollback may require restarting/redeploying the container from its original image.

---

### 3. Verify the version before patching

A resource patch may only apply to certain application versions.

Check the running version first and skip containers where:

* The fix is already included.
* The filesystem layout is different.
* The patch is incompatible.
* The container is already running a corrected image.

---

### 4. Track every modified container

Maintain a simple record:

| Host     | Container     | Version     | Patched | Reason     |
| -------- | ------------- | ----------- | ------- | ---------- |
| `<host>` | `<container>` | `<version>` | Yes/No  | `<reason>` |

This makes subsequent cleanup and permanent remediation much easier.

---

### 5. Remember that container changes are ephemeral

A file copied into a running container's writable layer can disappear when the container is replaced.

A later:

```bash
docker pull
docker compose up
```

or equivalent redeployment may restore the original image contents.

Therefore, a manual container patch is **not a permanent fix**.

---

# Rollback

If the patch causes problems:

```bash
docker exec <container-name> \
  cp /path/to/resource/resource-file-bak \
     /path/to/resource/resource-file
```

Verify:

```bash
docker exec <container-name> \
  ls -l /path/to/resource/resource-file
```

Restart the container if required:

```bash
docker restart <container-name>
```

Then verify application behavior.

---

# Post-Patch Checklist

* [ ] Original resource file backed up
* [ ] Patched file copied successfully
* [ ] File contents/hash verified
* [ ] Container version recorded
* [ ] Application behavior verified
* [ ] Container restart performed only if required
* [ ] Patched hosts/containers recorded
* [ ] Original patch file retained until remediation is complete
* [ ] Permanent image-based fix identified
* [ ] Temporary patch scheduled for removal or superseded by a new image

---

# tmux / nohup

For container patching, **tmux is strongly preferred** because the operator may need to inspect logs, execute rollback commands, or interact with the container.

Start:

```bash
tmux new -s container-patch
```

Detach:

```text
Ctrl-b
  ↓ release
d
```

Reattach:

```bash
tmux attach -t container-patch
```

List sessions:

```bash
tmux ls
```

Do not use `nohup` for an interactive patch procedure unless the actual operation has been reduced to a non-interactive script that can safely run unattended.

For fire-and-forget work:

```bash
nohup ./script.sh > /path/to/out.log 2>&1 &
```

