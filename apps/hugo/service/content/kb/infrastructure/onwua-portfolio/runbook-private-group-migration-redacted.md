---
title: "Runbook — Private Group Migration (Zero-Downtime, Single-Active-UC Model)"
date: 2026-07-14
draft: false
description: "Controlled migration process for moving a customer group between UC environments with zero downtime under a single-active-UC constraint."
summary: "Zero-downtime customer group migration between UC-A and UC-B under a single-active-UC (no dual event processing) constraint."
tags: ["migration", "zero-downtime"]
categories: ["runbooks"]
---

# Runbook — Private Group Migration (Zero-Downtime, Single-Active-UC Model)

**By:** Derrick Onwuachi
**Customer:** [Enterprise customer, redacted]
**Source Environment:** UC-A
**Target Environment:** UC-B
**Constraint:** Single-active UC only (no dual event processing)

## 1. Overview

This runbook defines the controlled migration of a customer group (PG) from
one UC environment to another using a staged sync, atomic cutover, and
strict state-control model.

> **Critical constraint:** only one UC environment may actively process PG
> events at any time. There is no event deduplication at the backend/event
> layer, therefore dual processing is not supported — routing control is
> the only enforcement mechanism.

## 2. Backup & Rollback Preparation (Source = Source of Truth)

**Required backups:**

1. **Group Configuration** — `GroupDump.xml` (authoritative PG definition)
2. **User Data** — `.../users/${group}`
3. **UC Resources** — resources, AutoAssistants, HuntGroups, notifications,
   calendars under `.../uc/{resource-type}/${group}`
4. **SBC-HTTP (UI / Branding / Integrations)** — `.../sbc-http/www/${group}`,
   used for chat UI, widgets, branding, embedded integrations
5. **Logs (validation only)** — EBS logs under `.../logs/${group}`; S3
   archive is not used for migration or rollback decisions

**Rollback package definition** — rollback is valid only if the PG has NOT
been deleted from the source environment:

- `GroupDump.xml` → full rebuild
- Users → identity/session state
- Resources → UC behavior/config
- SBC-HTTP → UI + integration layer
- Logs (EBS) → validation + troubleshooting only

## 3. Pre-Migration (Controlled State + Drift Protection)

**Execution window:** off-hours maintenance window (customer closed period)

**3.1 Source state control** — source environment remains active during
staging but is placed into a controlled migration window state: no
intentional PG configuration changes during the migration window, to
prevent drift between the staged copy and the final GroupDump snapshot.

**3.2 Pre-cutover delta sync (critical step)** — immediately before
GroupDump generation, sync latest PG state from source → target: users,
resources (AutoAssistants, HuntGroups, notifications), SBC-HTTP
`/www/${group}`, logs (EBS only). This ensures the target reflects
final-state consistency.

**3.3 GroupDump generation** — generate `GroupDump.xml` from the source,
validate trunk bindings, endpoint mappings, and target-environment
compatibility adjustments.

## 4. Cutover Execution (Atomic Switch)

**Step 1 — Import to target.** Import `GroupDump.xml` into target UC
Admin. Validate: users/presentities, AutoAssistants, HuntGroups, routing
behavior, login/session creation, IVA readiness (if applicable).

**Step 2 — Routing cutover (traffic switch).** Redirect external
dependencies to the target: MMP/event routing, ITSP voice routing
(carrier-dependent), DNS updates.

**Step 3 — Active processor state.** After routing propagation: target =
active PG processor, source = no longer receiving PG events (routing
removed).

> Transitional state exists briefly: PG exists in both environments, but
> only the target is authoritative.

## 5. Validation Window (Rollback-Safe Phase)

**Do not delete the PG from the source yet.** Validate: event ingestion
(no duplicates), session creation, voice/IVA functionality, SBC-HTTP UI
(`/www` rendering), logs flowing correctly.

Recommended duration: minimum 30–60 minutes, preferred extended off-hours
monitoring.

## 6. Rollback Procedure (Routing-Based Only)

Rollback is only valid prior to PG deletion. Steps: revert MMP routing,
ITSP routing, DNS entries. Result: source resumes processing, target stops
receiving traffic.

Notes: no rebuild required if PG not modified post-cutover. Rollback does
**not** recover target-side changes made after import.

## 7. Finalization (Point of No Return)

After successful validation: delete PG from source (UC Admin → Private
Groups → Delete → select PG → confirm). Outcome: PG fully removed from
source, no further event ingestion from source, target becomes sole active
processor.

## 8. Completion Criteria

Migration is complete when: target is the only active PG processor, source
PG has been deleted, no duplicate event ingestion observed, all external
integrations stable, voice + IVA fully operational.

## Key Operational Constraints

- No dual-active UC processing supported
- No event deduplication at backend layer
- Routing is the only control plane for cutover
- Rollback is routing-only and time-bound
- PG deletion is the final consistency-enforcement step
