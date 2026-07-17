---
title: "---"
date: 2026-07-14
draft: false
summary: ""
tags: []
categories: ["runbooks"]
---

---
title: "Oracle OCI DNS Access & Onboarding Runbook"
date: 2026-07-14
draft: false
description: ""
summary: ""
tags: []
categories: ["runbooks"]
---

# Oracle OCI DNS Access & Onboarding Runbook

## Overview

Defines how DNS records are managed in OCI for a multi-domain SaaS
platform.

**Goal:** eliminate shared admin credentials and move to per-user OCI
identity, group-based DNS access, console + CLI support, and controlled
RRSet updates via script.

## 1. Identity & Access Setup (IAM First)

**Step 1 — Create group (one-time setup).** OCI Console → Identity &
Security → Groups → Create Group. Name: `dns-operators`. Description:
"Allows users to manage DNS zones and records."

**Step 2 — Create IAM policy (root compartment).** Policy name:
`dns-operators-policy`. Statement:
```
Allow group dns-operators to manage dns in tenancy
```

Optional, more restrictive, for later:
```
Allow group dns-operators to manage dns-zones in tenancy
Allow group dns-operators to manage dns-records in tenancy
Allow group dns-operators to read dns-zones in tenancy
```

**Step 3 — Create or confirm user.** Identity → Users → Create User.

**Step 4 — Add user to group.** User → Groups → Add User to
`dns-operators`.

**Result of Section 1:** user can now access the DNS console and manage
zones per policy, but still cannot use the CLI until an API key is
configured.

## 2. API Key + CLI Configuration (Per-User Setup)

Done on the user's own machine, not by an admin.

**Step 1 — Generate API key pair:**
```bash
mkdir -p ~/.oci
openssl genrsa -out ~/.oci/oci_api_key.pem 2048
openssl rsa -pubout \
  -in ~/.oci/oci_api_key.pem \
  -out ~/.oci/oci_api_key_public.pem
chmod 600 ~/.oci/oci_api_key.pem
```

**Step 2 — Upload public key to OCI.** User → API Keys → Add API Key,
paste `cat ~/.oci/oci_api_key_public.pem`. OCI generates a fingerprint.

**Step 3 — Create OCI CLI config:**
```bash
oci setup config
```
Generates `~/.oci/config`:
```ini
[DEFAULT]
user=ocid1.user.oc1..xxxxx
fingerprint=xx:xx:xx:xx
tenancy=<tenancy-ocid>
region=us-ashburn-1
key_file=/home/<USER>/.oci/oci_api_key.pem
```

**Step 4 — Validate authentication:**
```bash
oci iam region list
```
Expected: list of regions returned successfully.

## 3. DNS Access Validation (Safe Read-Only Test)

**Step 1 — Test zone access:**
```bash
oci dns zone list --compartment-id <compartment_ocid>
```
Expected: sees the managed domains for the tenancy.

**Step 2 — Test record read (safe):**
```bash
oci dns record rrset get \
  --zone-name-or-id example.com \
  --domain test.example.com \
  --rtype CNAME
```

## 4. DNS Write Operations (High Risk)

**`publish_dns.sh` behavior:** input is JSON per RRSet; operation is
`oci dns record rrset update`, which is a **full replacement**, not
additive:

| Behavior | Impact |
|---|---|
| Replace RRSet | Yes |
| Add-only | No |
| Patch single record | No |

> **Risk:** the script performs full RRSet replacement per domain/type.
> Incorrect or incomplete JSON input may unintentionally remove existing
> DNS records.

**Step 1 — Always check first, before any update:**
```bash
oci dns record rrset get \
  --zone-name-or-id example.com \
  --domain <record> \
  --rtype CNAME
```

**Step 2 — Decision.** If `"items": []` → safe to create. If items exist
→ manually verify before overwrite.

**Step 3 — Apply update:**
```bash
oci dns record rrset update \
  --zone-name-or-id example.com \
  --domain <record> \
  --rtype CNAME \
  --items file://record.json \
  --force
```

**Step 4 — Verify:**
```bash
oci dns record rrset get ...
```

**Key safety rule:** never run `update_rrset` without first checking
whether the RRSet already exists, because `update_rrset` is a full
replacement, not a patch. If a record already exists (`"items": [...]`) —
**stop**, validate intent, confirm with the requester that the change is
expected, before proceeding.

## 5. Validation Summary

Validated: DNS read (`rrset get` works), DNS write (`rrset update`
works), propagation (`nslookup` resolves correctly).

## Security Summary

All DNS modifications performed via OCI Console or CLI are fully audit
logged via OCI Audit Service, including user identity, timestamp, and
target zone/record — no additional configuration required, immutable
logs, fully traceable DNS changes.

**Audit & tracking:** OCI Console → Observability & Management → Audit.
Filter by Service: `dns`, Event name: `UpdateRRSet`, Compartment, and User.
Each entry shows who made the change (user OCID), timestamp, source IP,
and the full request payload.
