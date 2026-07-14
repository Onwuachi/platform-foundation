# FortiGate HA Upgrade Runbook (AWS Production)

## Overview

Standardized process for performing a zero-downtime firmware upgrade on
FortiGate HA clusters in AWS.

**Architecture:**
- HA Mode: Active-Passive
- Platform: FortiGate-VM64-AWS
- Failover Type: Automatic (override enabled)

## Upgrade Flow

```
[Primary Active]
      │
      ▼
[Upgrade Secondary]
      │
      ▼
[Failover → Secondary Active]
      │
      ▼
[Upgrade Primary]
      │
      ▼
[Primary Rejoins]
      │
      ▼
[HA Sync + Stable State]
```

## Pre-Maintenance Requirements

- HA cluster must be in-sync
- Backup completed
- Correct firmware downloaded
- Monitoring ready (GUI / AWS)

## Execution Summary

1. Upgrade initiated from GUI on primary node
2. Secondary upgraded first, automatically
3. Failover occurs during process
4. Primary upgraded and rejoins cluster
5. HA re-synchronizes

## Validation Criteria

- HA Health = OK
- Configuration = In Sync
- Firmware versions match
- Traffic stable (sessions maintained)

## Success Criteria

- No production downtime
- Successful failover during upgrade
- Cluster returns to stable HA state

## Latest Execution (Reference)

- Upgrade: v7.2.11 → v7.2.13
- Duration: ~9 minutes
- Result: Successful
- HA Status: Healthy / In Sync
- Security Posture: A

**Operational notes:** always validate firmware matches platform; never
upgrade if HA is not clean; let HA automation handle sequencing.

## "Game Day" Reference (What You Actually Use Live)

**Before you click upgrade:**
```
✓ HA in-sync?
✓ Backup downloaded?
✓ Correct firmware file?
✓ Monitoring open?
```

**Start upgrade:** `System → Firmware → Upload → Confirm`

**Watch for this:**
```
1. Secondary upgrades
2. Secondary becomes ACTIVE
3. Primary upgrades
4. Primary rejoins
5. HA sync completes
```

**If something looks off:**
```bash
get system ha status
```
Look for: missing node, out-of-sync — both are red flags.

**Final check** — you want: same firmware, HA OK, sessions flowing:
```bash
get system status
get system ha status
diagnose sys session stat
```

**Optional force-failover test:**
```bash
execute ha failover set 1
```

**Done when:**
```
HA = OK
In Sync
Traffic Stable
```
