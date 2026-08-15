+++
title = "CloudWatch Metrics, Alarms, and SNS Notifications"
date = "2026-08-15"
description = "CloudWatch metric tiers, alarm states, treat-missing-data behavior, and SNS notification wiring — proven live with an ASG capacity alarm."
tags = ["aws", "cloudwatch", "alarms", "sns", "monitoring", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "Built a CloudWatch alarm on ASG capacity with SNS email delivery — covering metric tiers, alarm states, treat-missing-data, and composite alarms."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

CloudWatch is AWS's managed monitoring platform — equivalent to a hosted Prometheus + Alertmanager stack. It collects metrics from AWS services and custom sources, evaluates thresholds via alarms, and routes notifications through SNS to email, Lambda, or other targets.

<!--more-->

# Why It Matters

Without CloudWatch alarms, AWS infrastructure fails silently. An ASG at zero capacity, an EC2 instance with 100% CPU, an ALB returning 5xx errors — none of these page anyone unless an alarm is wired up. CloudWatch is the difference between reactive firefighting and proactive operations.

# Where It Fits

DOP-C02 Domain 4 — Monitoring and Logging

AWS Service (EC2, ASG, ALB)
|
v
CloudWatch Metric (time-series datapoint)
|
v
CloudWatch Alarm (threshold evaluation)
|
v
Alarm Action (SNS → email / Lambda / ASG scaling policy)


---

# The Big Picture

Your platform today AWS Equivalent
------------------ --------------
Prometheus metric → CloudWatch Metric
PromQL threshold rule → CloudWatch Alarm
Alertmanager → Alarm Action (SNS)
Grafana dashboard → CloudWatch Dashboard


---

# Core Concepts

**Two metric tiers:**

Native AWS Metrics (free) — every AWS service publishes automatically:
- EC2: CPUUtilization, NetworkIn, NetworkOut, StatusCheckFailed
- ASG: GroupInServiceInstances, GroupDesiredCapacity
- ALB: RequestCount, TargetResponseTime, HTTPCode_Target_5XX

Custom Metrics (~$0.30/metric/month) — your app or CloudWatch Agent publishes via PutMetricData:
- Memory utilization (not in native EC2 metrics)
- Disk usage (not in native EC2 metrics)
- Application-specific counters

**Exam trap:** EC2 native metrics do NOT include memory or disk — those require the CloudWatch Agent.

**Alarm states:**

OK — metric within threshold
ALARM — metric breached threshold
INSUFFICIENT_DATA — not enough datapoints yet (new resources)


**treat-missing-data — critical for exam:**

breaching — missing data = bad (capacity/availability alarms)
notBreaching — missing data = ok (error rate alarms — no traffic = no errors)
ignore — keep current state
missing — INSUFFICIENT_DATA (default)


**Alarm types:**
- Standard alarm — single metric, single threshold
- Composite alarm — AND/OR logic across multiple alarms; reduces alert noise

**Alarm actions:**
- SNS topic → email, Lambda, PagerDuty webhook
- ASG scaling policy → scale out/in
- EC2 action → stop, terminate, reboot
- SSM OpsItem → creates incident ticket

---

# Real-World Example

Live lab in devopslab, account 046685909731:

Created alarm `dop-lab-asg-low-capacity` on `GroupInServiceInstances` for ASG `dop-lab-asg`:
- Period: 60s, threshold < 1, evaluation-periods: 1
- treat-missing-data: breaching
- Alarm fired immediately — ASG at 0/0/0, no datapoints, treated as breach

SNS topic `dop-lab-alerts` created, `onwuabus@gmail.com` subscribed and confirmed. Alarm wired to SNS via `--alarm-actions` and `--ok-actions`.

Key observation: fresh ASGs can take 5-10 minutes to start publishing group metrics to CloudWatch. `INSUFFICIENT_DATA` or no datapoints on a new ASG is expected — not a misconfiguration.

**Alarm creation runbook:**
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name <name> \
  --metric-name GroupInServiceInstances \
  --namespace AWS/AutoScaling \
  --dimensions Name=AutoScalingGroupName,Value=<asg-name> \
  --statistic Average \
  --period 60 \
  --threshold 1 \
  --comparison-operator LessThanThreshold \
  --evaluation-periods 1 \
  --treat-missing-data breaching \
  --alarm-actions <sns-arn> \
  --ok-actions <sns-arn>

# Verify state
aws cloudwatch describe-alarms \
  --alarm-names <name> \
  --query "MetricAlarms[0].{State:StateValue,Reason:StateReason}" \
  --output table
```

---

# Engineering Analogy

CloudWatch alarms are Prometheus alerting rules — a threshold evaluated against a time-series metric that fires a notification when breached. The difference: CloudWatch is pull-free (AWS pushes metrics automatically), whereas Prometheus requires a scrape target. SNS is Alertmanager — routes the alert to the right destination.

---

# Best Practices

- Set `treat-missing-data: breaching` for capacity and availability alarms — silence should be an alert
- Set `treat-missing-data: notBreaching` for error rate alarms — no traffic means no errors, not a problem
- Use Composite alarms to reduce noise — only alert when CPU AND memory are both high, not either alone
- Wire both `--alarm-actions` (ALARM state) and `--ok-actions` (recovery) to SNS so you know when issues resolve
- Always verify SNS topic policy allows the alarm's service to publish

---

# Common Mistakes

- Assuming EC2 memory/disk metrics are native — they require CloudWatch Agent
- Wrong `treat-missing-data` setting causing false alarms or missed alerts
- SNS topic missing resource policy for the calling service (EventBridge, CloudWatch) — silent delivery failure
- Not subscribing and confirming the SNS endpoint — SNS won't deliver to unconfirmed subscriptions

---

# Pro Tip

> `aws cloudwatch list-metrics --namespace AWS/AutoScaling` shows what metrics are actually being published for your ASG. If `GroupInServiceInstances` doesn't appear, the ASG hasn't emitted a datapoint yet — wait 5-10 minutes before assuming a misconfiguration.

---

# Key Takeaways

- EC2 native metrics exclude memory and disk — CloudWatch Agent required for those
- `treat-missing-data: breaching` is correct for capacity alarms; `notBreaching` for error rate alarms
- Alarm states: OK, ALARM, INSUFFICIENT_DATA — know what triggers each
- Composite alarms reduce noise by requiring multiple conditions simultaneously
- SNS topic resource policy must explicitly allow the publishing service

---

# Related Articles

- DevOpsPro-4.2-CloudWatch-Logs-and-Metric-Filters.md
- DevOpsPro-4.3-CloudWatch-Agent-System-Metrics-and-Log-Shipping.md
- DevOpsPro-4.4-EventBridge-Event-Driven-Automation.md

---

# References

- AWS Documentation: Amazon CloudWatch Alarms
- Live lab performed in devopslab-vpc, account 046685909731, 2026-08-10
