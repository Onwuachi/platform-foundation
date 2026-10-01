---
title: "FortiGate Administrator Trusted Host Update via AWS Serial Console"
date: 2026-10-01
description: "How to update a FortiGate administrator's trusted-host entry from the AWS EC2 Serial Console when your public IP changes and the GUI is blocked, including HA verification."
tags: ["fortigate", "fortios", "aws", "serial-console", "trusthost", "ha", "runbook"]
categories: ["infrastructure"]
summary: "Regain or maintain FortiGate admin access after a public IP change by editing the admin trusthost entry through the AWS EC2 Serial Console: identify the device, find the right slot, change it, verify, and confirm HA sync."
---

## Purpose

Update a FortiGate administrator's trusted-host entry when the administrator's public IP changes and GUI access is blocked by the existing trusted-host configuration.

The AWS EC2 Serial Console is out-of-band: it doesn't depend on the network path or the trusted-host list, so it works even when the GUI and SSH reject you.

## Scope

Use this when all of these are true:

- The FortiGate is an AWS EC2 instance
- GUI/SSH access is restricted by the administrator `trusthost` entries
- Your public IP changed
- EC2 Serial Console access is available to you
- The FortiGate may be part of an HA pair

The procedure is intentionally limited to the administrator trusted-host configuration. Nothing else changes.

## 1. Connect Through the AWS Serial Console

1. In AWS, locate the FortiGate EC2 instance.
2. Choose **Connect**, then **EC2 Serial Console**.
3. Log in with the FortiGate administrative account.

For an HA pair, start with the **passive/secondary** member where practical, so the active traffic node isn't the first system you modify.

## 2. Verify You're on the Right FortiGate

```
get system status
```

Confirm:

- Hostname
- Serial number
- FortiOS version
- HA role
- License status

**Do not rely on the EC2 instance name.** The FortiGate's own hostname and serial number are what confirm you've reached the intended device. Don't make any change until they match.

## 3. Review the Existing Trusted Hosts

```
show system admin
```

Find the administrator account and read its existing `trusthost` entries. Determine:

1. Which entry contains the **old** public IP
2. Whether the old IP is still needed by anyone
3. Whether an unused slot exists

A FortiGate admin account has a limited number of IPv4 trusted-host slots (typically `trusthost1` through `trusthost10`). Don't try to create an entry beyond the supported range.

**Do not guess which slot to replace.**

- If the old IP is no longer needed, replace that entry.
- If it is still needed, use an empty slot instead.
- If every slot is populated, reuse one only after confirming the address in it is no longer required.

## 4. Update the Trusted Host

Edit the slot you identified in step 3:

```
config system admin
edit <ADMIN_USERNAME>
set trusthost<N> <NEW_PUBLIC_IP> 255.255.255.255
end
```

Example (documentation-range IP, slot 7):

```
config system admin
edit admin
set trusthost7 203.0.113.50 255.255.255.255
end
```

Notes:

- A single public IPv4 address is `<IP> 255.255.255.255`. Check the mask so you don't grant a larger network by accident.
- Don't "fix" access by setting `0.0.0.0 0.0.0.0`. That opens admin access to everywhere.
- Use the real slot number from your own review, not the example's `7`.

## 5. Verify the Configuration

```
show system admin
```

Confirm:

- The intended slot now shows the new address with the `255.255.255.255` mask
- The old entry you replaced is gone
- Other trusted hosts are unchanged
- No unrelated administrator settings changed

## 6. Test GUI Access

From a workstation using the **new** public IP:

1. Open the normal FortiGate GUI.
2. Log in with the existing administrator credentials.
3. Confirm you've reached the intended FortiGate.
4. Confirm the expected hostname and HA role.

Don't consider the change complete until access is validated. Keep the Serial Console session open until then, in case you need to correct something.

## 7. Verify HA Synchronization

For an HA pair:

```
get system ha status
```

Then check the peer:

```
show system admin
```

Confirm the trusted-host change appears on the other member.

In practice the entry propagated to the peer through HA config sync. **Don't assume it did. Verify.**

If it didn't sync:

- Stop and investigate sync status (`get system ha status`, `diagnose sys ha checksum cluster`).
- Don't edit both members by hand just to force them to match before you understand why sync didn't happen.

## 8. HA Pair Sequence

**First member (start with the passive one where practical)**

- [ ] Connect through AWS Serial Console
- [ ] `get system status`, verify hostname, serial, HA role
- [ ] `show system admin`, find the entry with the old IP
- [ ] Confirm the old IP can be replaced
- [ ] Update the trusted-host entry
- [ ] `show system admin`, verify
- [ ] Test GUI access from the new IP

**Peer member**

- [ ] `get system ha status`, confirm the pair is in sync
- [ ] `show system admin`, confirm the new entry is present
- [ ] Confirm no unintended admin changes
- [ ] Test GUI access if required

For multiple HA pairs, repeat the sequence per pair and verify each device's hostname and serial separately.

## Operational Safety

- Don't reboot the FortiGate for a trusted-host change.
- Don't fail over the HA pair for this change.
- Don't touch firmware or HA settings.
- Don't remove other trusted hosts without confirming they're no longer required.
- Don't create entries past the supported slot range.
- Don't trust the EC2 instance name. Verify hostname and serial first.
- Keep the change limited to the trusted-host entry.
- Test access right after the change.

## Troubleshooting

### GUI still rejects the connection

Check `show system admin` and verify:

- You modified the correct administrator account
- The new public IP is correct (confirm your real egress IP, since VPNs and proxies change it)
- The mask is `255.255.255.255` for a single address
- You made the change on the intended FortiGate (and the correct HA member)

### Not sure which slot to replace

Don't guess. Run `show system admin`, identify the entry containing the old address, and decide whether it's still required. If it is, use an empty slot.

### HA peer doesn't show the change

Check `get system ha status`, then `show system admin` on the peer. Find out why sync didn't happen before changing anything on the other member.

### Can't reach the Serial Console

Serial Console access must be enabled for the account/region and your IAM identity must be permitted to use it. Sort that out before you need it in an emergency.

## Quick Command Reference

```
# Identify the FortiGate
get system status

# Review admin configuration (trusthost entries)
show system admin

# Update a trusted host
config system admin
edit <ADMIN_USERNAME>
set trusthost<N> <NEW_PUBLIC_IP> 255.255.255.255
end

# Verify
show system admin

# HA status / sync
get system ha status
```

### Minimal sequence (device already positively identified)

```
get system status
show system admin
config system admin
edit <ADMIN_USERNAME>
set trusthost<N> <NEW_PUBLIC_IP> 255.255.255.255
end
show system admin
get system ha status
```

Then test GUI access from the new public IP. Always identify the correct `trusthost<N>` slot first.

## Related

- FortiGate AWS HA Firmware Upgrade — Manual Upgrade, HA Behavior & Validation (this procedure keeps admin access working for maintenance like that)
