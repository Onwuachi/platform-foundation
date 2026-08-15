+++
title = "CloudWatch Agent: System Metrics and Log Shipping"
date = "2026-08-15"
description = "How the CloudWatch Agent fills the gap between native EC2 metrics and full system observability — memory, disk, and log shipping from EC2 to CloudWatch Logs."
tags = ["aws", "cloudwatch", "cloudwatch-agent", "monitoring", "ec2", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "CloudWatch Agent config structure, IAM requirements, SSM Parameter Store distribution pattern, and the mental model mapping from Node Exporter to AWS-native monitoring."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

The CloudWatch Agent is a daemon that runs on EC2 instances and ships system-level metrics (memory, disk, processes) and log files to CloudWatch. It fills the critical gap between native EC2 metrics (CPU, network only) and full system observability.

<!--more-->

# Why It Matters

Native EC2 metrics don't include memory utilization or disk space — two of the most operationally important signals. Without the CloudWatch Agent, you can't alarm on "instance is running out of memory" or "disk is 90% full" using CloudWatch alone. The agent also enables centralized log aggregation from any file on the instance filesystem.

# Where It Fits

DOP-C02 Domain 4 — Monitoring and Logging

EC2 Instance
|
+-- CloudWatch Agent (daemon)
|
+-- Collects: mem_used_percent, disk_used_percent, process metrics
| |
| v
| CloudWatch Custom Metrics (CWAgent namespace)
|
+-- Ships: /var/log/haproxy.log, /var/log/nginx/access.log
|
v
CloudWatch Log Group → Metric Filters → Alarms


---

# The Big Picture

Your platform today AWS Equivalent
------------------ --------------
Node Exporter (port 9100) → CloudWatch Agent
Prometheus scrapes it (pull) → Agent pushes to CloudWatch (push)
/proc/meminfo → mem_used_percent metric
df -h → disk_used_percent metric
/var/log/haproxy.log → CloudWatch Log Stream


Key difference: Node Exporter is pull-based (Prometheus scrapes on interval). CloudWatch Agent is push-based (agent ships on interval). Same data, opposite direction.

---

# Core Concepts

**Agent config — two sections:**
```json
{
  "metrics": {
    "metrics_collected": {
      "mem": {
        "measurement": ["mem_used_percent"]
      },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/"]
      },
      "cpu": {
        "measurement": ["cpu_usage_idle"],
        "totalcpu": true
      }
    },
    "append_dimensions": {
      "InstanceId": "${aws:InstanceId}",
      "AutoScalingGroupName": "${aws:AutoScalingGroupName}"
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/haproxy.log",
            "log_group_name": "/platform/haproxy",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/nginx/access.log",
            "log_group_name": "/platform/nginx",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

**IAM requirements — two separate policies:**

CloudWatchAgentServerPolicy — allows agent to publish metrics and logs
AmazonSSMManagedInstanceCore — allows SSM Agent for remote management

Both attached to the EC2 instance profile. They are separate — SSM Agent ≠ CloudWatch Agent.

**SSM Parameter Store distribution pattern:**
Store agent config in SSM Parameter Store under `AmazonCloudWatch-*` namespace. On instance launch (via lifecycle hook or user data), agent pulls config from SSM:
```bash
amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c ssm:/AmazonCloudWatch-platform-config
```
This means one config change in SSM rolls out to all instances on next restart — no per-instance config management.

**Metrics namespace:** Custom metrics from the agent land in `CWAgent` namespace, not `AWS/EC2`.

---

# Real-World Example

No live lab — agent requires a running EC2 instance with IAM instance profile. Config syntax is what the exam tests.

Platform-foundation mapping — what the agent config would look like for the ops instance:
```json
{
  "metrics": {
    "metrics_collected": {
      "mem": { "measurement": ["mem_used_percent"] },
      "disk": {
        "measurement": ["disk_used_percent"],
        "resources": ["/", "/var"]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/haproxy.log",
            "log_group_name": "/platform/haproxy",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/platform-rehydrate.log",
            "log_group_name": "/platform/rehydrate",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
```

---

# Engineering Analogy

The CloudWatch Agent is Node Exporter + Promtail (Grafana's log shipper) combined into one AWS-native daemon. Node Exporter exposes /proc metrics for Prometheus to scrape; Promtail tails log files and ships to Loki. CloudWatch Agent does both — ships system metrics and log files — but pushes to CloudWatch instead of waiting to be scraped.

---

# Best Practices

- Store agent config in SSM Parameter Store — enables fleet-wide config updates without per-instance changes
- Add `AutoScalingGroupName` to `append_dimensions` — enables filtering metrics by ASG in CloudWatch
- Use `{instance_id}` as log stream name — automatically unique per instance, matches CloudTrail/ASG records
- Attach `CloudWatchAgentServerPolicy` to the instance profile, not to the instance directly
- Install and start agent via Launch Template user data or lifecycle hook — ensures every ASG-launched instance has it

---

# Common Mistakes

- Assuming memory/disk metrics are available without the agent — they are not in native EC2 metrics
- Confusing CloudWatch Agent with SSM Agent — they are separate daemons with separate IAM policies
- Not adding `append_dimensions` — metrics land without ASG or instance context, making filtering impossible
- Config stored locally on instance — breaks when instance is replaced by ASG; always use SSM Parameter Store

---

# Pro Tip

> After installing the agent, run `amazon-cloudwatch-agent-ctl -a status` to confirm it's running, and check `/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log` for errors. The most common failure is a missing or incorrect IAM instance profile permission.

---

# Key Takeaways

- Native EC2 metrics exclude memory and disk — CloudWatch Agent is required for both
- Agent config has two sections: metrics (system-level) and logs (file shipping)
- Store config in SSM Parameter Store for fleet-wide distribution
- CloudWatch Agent and SSM Agent are separate — both need their own IAM policies
- Custom agent metrics land in `CWAgent` namespace, not `AWS/EC2`

---

# Related Articles

- DevOpsPro-4.1-CloudWatch-Metrics-Alarms-and-SNS.md
- DevOpsPro-4.2-CloudWatch-Logs-and-Metric-Filters.md

---

# References

- AWS Documentation: CloudWatch Agent Configuration File Reference
- AWS Documentation: Install CloudWatch Agent Using SSM
