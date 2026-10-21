---
title: "SSM Session Manager: Shell Access Without SSH, Bastions, or Open Ports"
date: 2026-09-30
description: "Using AWS Systems Manager Session Manager for secure, auditable shell access to EC2 instances with no inbound ports, no SSH keys, and no bastion hosts."
tags: ["aws", "ssm", "systems-manager", "session-manager", "security", "devops-pro", "dop-c02"]
categories: ["AWS", "DevOps Pro"]
summary: "SSM Session Manager replaces SSH/bastion access with IAM-controlled, fully logged shell sessions to EC2 instances — no open inbound ports required."
---

## Why This Matters (DOP-C02 Domain 5.1)

Session Manager is Domain 5's answer to "how do you get a shell on a production instance without exposing SSH to the internet or maintaining a bastion host." It shows up on the exam as:

- Replacing bastion/jump-box architectures for compliance reasons (no inbound SSH rule required at all)
- IAM-based access control instead of SSH key distribution
- Full session logging to S3/CloudWatch Logs for audit trails (SOC2, PCI, etc.)
- The prerequisite building block for SSM Automation, Run Command, and Patch Manager

## Requirements for an Instance to Be "Managed"

1. **SSM Agent installed and running** (pre-installed on most current AMIs — Amazon Linux 2/2023, Ubuntu via snap, etc.)
2. **IAM instance profile** attached with a policy allowing SSM (`AmazonSSMManagedInstanceCore` managed policy is the standard starting point)
3. **Network path to SSM endpoints** — either public internet egress, or VPC endpoints for `ssm`, `ssmmessages`, `ec2messages` if fully private
4. No inbound security group rules are required — Session Manager uses an outbound-initiated connection from the agent

## Lab: Connect via Session Manager

Confirm the instance shows as managed:

```bash
aws ssm describe-instance-information \
  --profile platform-foundation --region us-east-1 \
  --filters "Key=InstanceIds,Values=<INSTANCE_ID>" \
  --query "InstanceInformationList[0].[PingStatus,PlatformType,PlatformName]" \
  --output table
```

Expect `Online` in the `PingStatus` column. If it shows nothing, the agent isn't registered — check IAM role and network path first, not SSH.

Start an interactive session:

```bash
aws ssm start-session \
  --profile platform-foundation --region us-east-1 \
  --target <INSTANCE_ID>
```

Run a one-off command without an interactive session (useful for automation/scripting, not just humans):

```bash
aws ssm send-command \
  --profile platform-foundation --region us-east-1 \
  --instance-ids "<INSTANCE_ID>" \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["hostname","uptime","df -h"]'
```

Fetch results from a `send-command` invocation:

```bash
aws ssm get-command-invocation \
  --profile platform-foundation --region us-east-1 \
  --command-id <COMMAND_ID> \
  --instance-id <INSTANCE_ID>
```

## Known Issue: Default Shell on Snap-Based SSM Agent (Ubuntu)

On Ubuntu instances where the SSM Agent is installed via snap, the `ssm-user` session drops into `/bin/sh` rather than `/bin/bash`, and shell customization (`.bashrc`, profile settings) does not persist across sessions the way it would on a normal SSH login.

**Workaround (per-session):** type `bash` immediately after connecting.

**Permanent fix (account-wide):** In the console, go to **Systems Manager → Session Manager → Preferences**, and set the default shell/session document to explicitly launch `/bin/bash`. This is the correct fix — don't rely on the manual workaround for anything you do repeatedly.

## Exam-Relevant Distinctions

| Concept | Session Manager | Run Command | Automation |
|---|---|---|---|
| Use case | Interactive shell | Fire-and-forget command(s) | Multi-step orchestrated workflow |
| Human present? | Yes (typically) | Either | Typically no (triggered by events) |
| Can call AWS APIs directly? | No (shell only) | No (shell only) | Yes (`aws:executeAwsApi`) |
| Logged where? | S3/CloudWatch (session) | CloudWatch/S3 (command output) | Automation execution history |

## $0-Cost Note

Session Manager itself has no additional charge — you pay only for the instance already running and any CloudWatch Logs/S3 storage of session output if enabled. No bastion host, no NAT-dependent SSH tunnel required.
