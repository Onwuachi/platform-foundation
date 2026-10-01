---
title: "FortiGate AWS HA Firmware Upgrade — Manual Upgrade, HA Behavior & Validation"
date: 2026-10-01
description: "Runbook for a manual firmware upgrade of an Active-Passive FortiGate-VM HA pair on AWS, including pre-upgrade evidence, what the HA pair does during the upgrade, and CLI validation."
tags: ["fortigate", "fortios", "ha", "aws", "firmware-upgrade", "runbook", "change-management"]
categories: ["infrastructure"]
summary: "Manual HA firmware upgrade for FortiGate-VM64-AWS (7.2.x to 7.4.x): what to capture before, what the cluster does during (temporary role changes, misleading GUI errors), and the CLI commands that prove it worked."
---

## Purpose

Upgrade an Active-Passive FortiGate-VM HA pair on AWS to a new FortiOS release using the **manual** firmware upgrade method, and prove the result with CLI evidence rather than trusting the GUI.

This runbook is based on a real production upgrade (7.2.13 build 1762 to 7.4.12 build 2902) that completed with no rollback.

## Scope

- Platform: FortiGate-VM64-AWS on EC2
- HA: Active-Passive, NAT mode, dedicated heartbeat/sync interface, session pickup enabled, override enabled
- Method: manual image upload through the GUI, **not** Fabric Upgrade
- Keep the maintenance scope narrow. Do not combine the upgrade with unrelated HA or configuration changes.
- Out of scope: standalone units, Active-Active, rollback/downgrade procedures (follow Fortinet Support)

## 1. Pre-Upgrade Evidence

Collect this before the window. If any of it is missing, that is a NO-GO.

### 1.1 Confirm the upgrade path and image

- Check the supported path in the Fortinet Support portal **Upgrade Path** tool. Do not assume a direct hop is supported. If the supported path needs an intermediate release, follow it.
- Read the Release Notes **Upgrade Information** and **Known Issues** for the target version.
- Download the image that matches the platform. For AWS VMs the filename looks like:
  `FGT_VM64_AWS-v<version>.M-build<build>-FORTINET.out`
- Verify the image checksum against the support portal. Don't rely on the filename alone.
- Do not rename or modify the `.out` file. Windows may associate `.out` with another application (it showed up as Wireshark here). That is only a file-association quirk.
- Engage Fortinet Support before the window, share the current/target versions, platform, HA topology, and backup status, and keep the ticket/reference handy. Keep any instructions Support gives with the change record.

### 1.2 Check upgrade-specific compatibility items

Ask Support or the release notes what to check for your source/target pair. In this change, Support specifically called out **SSL VPN** configuration.

```
show vpn ssl settings
show vpn ssl web portal
```

Determine whether SSL VPN is configured **and** whether anyone actually depends on it. Don't assume it's unused just because the change request doesn't mention it. If it is enabled or in use, STOP and review with Fortinet before proceeding.

### 1.3 Back up both nodes

Download a full configuration backup from **each** member (GUI: admin menu, Configuration, Backup). Use filenames that include hostname, version, and timestamp.

- Store the backups somewhere reachable independently of the FortiGates.
- Keep the originals untouched. Don't overwrite the known-good backup with post-upgrade config until the upgrade is validated.

### 1.4 Capture an HA baseline from both nodes

```
get system status
get system ha status
diagnose sys ha status
diagnose sys ha checksum cluster
show system ha
```

`show system ha` confirms the intended priority, override, session pickup, and heartbeat settings. Note them, but do not change HA configuration as part of the upgrade.

Record:

| Item | Expected before upgrade |
|---|---|
| HA Health Status | OK |
| Config status | Both members `in-sync` |
| Checksums (global / root / all) | Identical on both nodes |
| Heartbeat interface | Up, 0 drops, 0 errors |
| Session pickup | Enabled |
| Roles | Primary/secondary as designed |
| CPU / memory / session count | Baseline only, not thresholds |

Also verify the version with `get system status` on both nodes. The dashboard can show a stale version. In this change the dashboard displayed an old release while the CLI showed the true one.

## 2. GO / NO-GO

**GO** when all are true:

- [ ] HA Health OK, both members present and in-sync, checksums match, heartbeat up
- [ ] Priority/override/session pickup behavior understood
- [ ] Both config backups saved and accessible from the workstation doing the work
- [ ] Correct, checksum-verified image on hand
- [ ] Supported upgrade path confirmed
- [ ] Compatibility items (e.g., SSL VPN) checked and clear
- [ ] Support ticket/reference available
- [ ] Stakeholders notified, window active, no active incident, traffic at an acceptable level
- [ ] Application checks defined (e.g., SIP/VoIP call tests)
- [ ] Rollback/escalation path understood

**NO-GO** if any of these appear:

- Anything other than healthy/in-sync, a missing member, or differing checksums
- Heartbeat down
- Image can't be verified or doesn't match the platform
- Support's path differs from your plan, or Support identifies a blocker
- The upgrade UI reports an unsupported/incompatible image
- Any critical prerequisite is unknown. Stop and resolve it first.

## 3. Upgrade Procedure (Manual)

1. Run the CLI baseline capture (section 1.4) on both nodes immediately before starting and save the output.
2. Confirm baseline production traffic works (for UC/VoIP environments: a representative inbound and outbound call).
3. In the GUI, open the firmware upgrade function and choose **manual upload**.
4. Select the verified `.out` image.
5. Review the confirmation screen: correct device, correct target version. If offered, enable the config backup option.
6. Start the upgrade.

**Do not:**

- Use Fabric Upgrade for this
- Manually reboot either node
- Manually force a failover
- Manually modify HA upgrade flags
- Change HA priority or other HA settings mid-upgrade
- Restart or cancel the upgrade because the GUI looks wrong
- Use historical upgrade duration as a hard timeout

## 4. What to Expect During the Upgrade

The cluster upgrades members in sequence and **role changes are normal**. Expect to see:

1. The GUI on one node disconnects with "Lost Connection to FortiGate."
2. The other node shows "System Rebooting" and stays unreachable for several minutes.
3. A browser reconnect may land on a **setup wizard** page (FortiCare registration, automatic patch upgrade options) on a node that has just rebooted onto the new version. Don't use the wizard to change configuration. Decline or skip automatic patch upgrades unless you actually want them.
4. The GUI may show an "Image upgrade failed" style message even though the HA upgrade is still proceeding. The target release's Known Issues documented a case where a secondary taking several minutes to boot triggers a misleading GUI error. Check actual node state before acting.

**Rule of thumb: wait, then verify the real state from the CLI. Don't intervene based on the GUI alone.**

### Monitor, don't interfere

While waiting, observe only:

- Which node is currently active and forwarding traffic
- Whether the other node is rebooting/upgrading
- Whether the heartbeat returns
- Whether the upgraded member rejoins
- Whether roles normalize after both members return
- AWS instance health, session count, and production traffic (SIP/VoIP if applicable)
- FortiGate logs/events

Don't make changes just because the cluster temporarily looks different from its normal state.

### Example HA role-transition log (sanitized)

From the secondary's HA event log during the real upgrade (times relative to the start of the sequence):

| T+ | Event |
|---|---|
| 0:00 | Original primary is selected as primary because the UPGRADE_PRIMARY flag is unset on the peer |
| +1:10 | Secondary is selected as primary because the UPGRADE_SECONDARY flag is set on the original primary |
| +1:18 | Secondary is selected as primary because it is the only member in the cluster |
| +3:10 | Original primary is selected as primary again because its override priority is larger than the peer's |

This matches expected behavior:

- The original primary goes through its upgrade/reboot.
- The secondary briefly serves as the only member.
- When the original primary returns, **HA priority + override** restores it as primary automatically.

A manual failover was not required.

Timeline reference from this change: the first GUI disconnects appeared quickly after starting. The primary GUI still showed the reboot state around 18 minutes in, and CLI access returned around 23 minutes in. Treat these as reference points, not timeouts.

## 5. Post-Upgrade Validation

Run on **both** nodes. Do not rely on the GUI. Verify each member independently: one node reporting the target version does not mean the cluster is done.

```
get system status
get system ha status
diagnose sys ha status
diagnose sys ha checksum cluster
```

### What good looks like

| Check | Expected |
|---|---|
| `get system status` (each node) | Target version and build; branch point matches; license valid; last reboot reason is warm reboot |
| `get system ha status` | HA Health Status OK; both members `in-sync`; heartbeat interface up with 0 dropped / 0 errors; 2 members |
| `diagnose sys ha status` | Primary: `is_manage_primary=1`, vcluster state `work`; Secondary: `is_manage_primary=0`, state `standby`; `silent=0` |
| `diagnose sys ha checksum cluster` | Global, root, and all checksums identical on both nodes; primary shows `is_root_primary()=1`, secondary `0` |
| CPU / memory / sessions | Normal compared to the baseline |

Note: the **checksum values will change** after the upgrade because the config is re-serialized by the new version. Compare the two nodes to each other, not to the pre-upgrade values.

### System health

Beyond "it's online," confirm the firewall is operating normally:

- Interfaces up, routing table as expected
- Licenses valid
- No new system alarms or unexpected errors in logs/events
- No unresolved upgrade messages

### Production validation

- Internet connectivity, DNS, NAT, routing
- Required VPN/connectivity paths
- SIP/VoIP (if applicable): registration, signaling, inbound call, outbound call, two-way audio (RTP/media), call stays up
- Critical application traffic and external integrations
- FortiGuard connectivity: `diagnose test update info`
- Monitoring/alerting still working
- Admin access to both nodes

Don't consider the upgrade complete just because the GUI is reachable.

## 6. Optional: Controlled Failover Validation

Only if your procedure or Support calls for it. Don't fail over a freshly upgraded cluster just to prove HA works. In the real change this wasn't needed, because the primary returned on its own through override.

Prerequisites: firmware correct, HA healthy, members in-sync, checksums match, heartbeat healthy, production traffic healthy, and no calls or test traffic that must not be interrupted.

After failover, verify:

- New active member is as expected
- Traffic and application behavior (SIP/VoIP test if applicable)
- Former primary rejoins and synchronizes
- HA returns to the intended operating state

Record when the failover started, when the new primary became active, the session count, any observed interruption, and when HA stabilized.

## 7. Final State Checklist

- [ ] Both nodes on the target version and build
- [ ] HA Health OK, both in-sync
- [ ] Checksums identical (global, root, all)
- [ ] Heartbeat up, 0 drops, 0 errors
- [ ] Roles as designed (primary returned via override)
- [ ] CPU/memory normal, licenses valid, no unresolved errors
- [ ] Routing, NAT, and VPN verified as applicable
- [ ] SIP/VoIP and application traffic validated
- [ ] No unnecessary HA changes made, no rollback required
- [ ] CLI output and timestamps saved with the change record
- [ ] Support ticket updated
- [ ] Stakeholders notified

## 8. Rollback / Escalation

Do not improvise a rollback.

1. Stop making changes.
2. Preserve the current state and error messages.
3. Record which node(s) rebooted and what version each is running.
4. Capture the four CLI commands from section 5 on whatever is reachable, plus:
   - Relevant system and HA logs
   - Upgrade messages and screenshots
   - Console output (the AWS EC2 Serial Console works if the GUI/SSH are unavailable)
   - Connectivity symptoms
5. Contact Fortinet Support under the existing ticket and provide the pre-upgrade backups and the captured state.
6. Follow Support's recovery instructions. Provide captured state instead of repeatedly changing the environment.

Release notes may warn that downgrading can cause configuration loss. Treat downgrade as a Support-guided last resort, not a first response.

## 9. Quick Command Reference

```
# Identify node and version
get system status

# HA overview, config sync, heartbeat
get system ha status

# Per-member roles and vcluster state
diagnose sys ha status

# Config consistency between members
diagnose sys ha checksum cluster

# HA configuration (priority, override, session pickup)
show system ha

# FortiGuard / update status
diagnose test update info

# SSL VPN compatibility check (when Support flags it)
show vpn ssl settings
show vpn ssl web portal
```

Minimum post-upgrade validation, on both nodes: the first four commands above.

## 10. Lessons Learned

- Pre-upgrade evidence (backups, baseline, checksums, Support confirmation) made go/no-go a checklist decision instead of a judgment call.
- The GUI is the least reliable source of truth during an HA upgrade. The CLI on each node is the real evidence.
- Role flapping during the upgrade is expected. Waiting was the correct action. Fighting the HA process risks creating a problem that wasn't there.
- Validate both nodes independently. The real completion criteria are: both nodes upgraded, HA healthy, members in-sync, checksums matching, heartbeat clean, and production traffic verified.
- The dashboard can show a stale firmware version. Verify with `get system status`.
- Keep the maintenance scope narrow. Don't bundle unrelated changes into the window.

## Related

- FortiGate Administrator Trusted Host Update via AWS Serial Console (maintaining admin access to these appliances)
