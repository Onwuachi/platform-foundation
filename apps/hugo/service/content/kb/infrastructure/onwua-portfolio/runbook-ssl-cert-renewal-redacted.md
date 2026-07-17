---
title: "---"
date: 2026-07-14
draft: false
summary: ""
tags: []
categories: ["runbooks"]
---

---
title: "TLS/SSL Certificate Renewal Process (HAProxy, Multi-Environment)"
date: 2026-07-14
draft: false
description: ""
summary: ""
tags: []
categories: ["runbooks"]
---

# TLS/SSL Certificate Renewal Process (HAProxy, Multi-Environment)

## 1. Overview

Standard process for renewing, validating, and deploying TLS/SSL
certificates across a multi-environment platform (Production, UAT, Dev).

Covers: certificate inventory, deployment locations, HAProxy certificate
reloads, validation steps, rollback procedures, troubleshooting, and
operational best practices.

**Scope:** HAProxy, application layer, MMP, and other TLS-enabled services
across Production/UAT/Dev.

## 2. Deployment Mapping

Maintaining an explicit mapping of certificate → environment → host →
storage → container → path → reload method is one of the most valuable
things a team can have on hand — it turns an emergency into a checklist.
Example shape:

| Certificate | Environment | Storage | Container | Reload Method |
|---|---|---|---|---|
| `*.example.com` | Prod | Shared network storage | haproxy | HUP |
| `*.example.com` | Stage | Shared network storage | haproxy | HUP |

## 3. Renewal Preparation

Before making changes:

- Verify certificate expiration
- Verify maintenance window
- Confirm shared-storage replication completed
- Verify current certificate fingerprint
- Backup existing PEM
- Validate PEM format
- Notify stakeholders

## 4. Deployment Procedure

1. Upload new certificate
2. Replace PEM
3. Verify permissions (`ls -l`)
4. Validate configuration:
   ```bash
   docker exec haproxy-<env> \
     sh -c "haproxy -f /usr/local/etc/haproxy/haproxy.cfg -c"
   ```
   Expected: `Configuration file is valid` (warnings may also appear —
   see below).

**Important:** the following warnings are expected and do **not** indicate
a failed deployment:
```
option httplog not usable...
option forwardfor ignored...
```
These occur because several frontends/backends operate in TCP mode while
those directives only apply to HTTP mode. Deployment should continue
provided the configuration is reported as valid.

## 5. Graceful HAProxy Reload

Instead of restarting the container:
```bash
docker kill -s HUP haproxy-<env>
```

Expected log output:
```
New worker forked
Reexecuting Master process
Stopping backend...
```

This indicates: existing connections drain, the new worker accepts
traffic, zero-downtime reload.

## 6. Validation Checklist

| Validation | Command | Expected |
|---|---|---|
| Config | `haproxy -c` | Valid |
| Reload | `docker kill -s HUP` | Success |
| Process | `ps` | New worker |
| Connections | `ss` | Active connections |
| Certificate | `openssl s_client` | New cert |
| Containers | `docker ps` | Healthy |
| Logs | `docker logs` | No persistent alerts |

```bash
docker exec haproxy-<env> sh -c "haproxy -f /usr/local/etc/haproxy/haproxy.cfg -c"
docker kill -s HUP haproxy-<env>
docker logs -f haproxy-<env>
ps -eo pid,etime,cmd | grep haproxy
watch -n1 "ss -ntp | grep haproxy"
openssl s_client -connect <host>:443
docker ps
```

Expected `openssl s_client` output:
```
Verify return code: 0 (ok)
TLSv1.3
TLS_AES_256_GCM_SHA384
```

## 7. Expected Log Messages

This is the section most runbooks skip, and it's the most useful part.

**Expected:**
```
Configuration file is valid
New worker forked
Reexecuting Master process
Server ... UP
Layer6 check passed
```

**Acceptable during reload** (only if they immediately recover):
```
Server DOWN
Layer4 timeout
backend has no server available
```

**Requires investigation:**
```
Configuration file is invalid
cannot bind socket
Permission denied
Verify return code != 0
Backend remains DOWN
```

## 8. Rollback

Restore previous PEM → validate configuration → send HUP again → verify
certificate → monitor logs.

## 9. Troubleshooting

| Problem | Cause | Resolution |
|---|---|---|
| Config invalid | PEM formatting | Verify certificate chain |
| Verify return code != 0 | Missing intermediate | Rebuild bundle |
| Backend stays DOWN | Service unavailable | Verify backend container |
| TLS still shows old cert | Reload not completed | Verify new worker |

## 10. Post-Deployment Validation

- Configuration valid
- HAProxy reload successful
- New worker active
- Certificate updated
- TLS handshake successful
- Containers healthy
- Backend services healthy
- Monitor for 5–10 minutes
- Close maintenance window
