+++
title = "CloudWatch Logs and Metric Filters"
date = "2026-08-15"
description = "CloudWatch Logs structure, retention policies, and metric filters that turn log patterns into CloudWatch metrics — proven with a live HAProxy 503 error counter."
tags = ["aws", "cloudwatch", "logs", "metric-filters", "monitoring", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "Built a log group, shipped fake HAProxy 503 events, created a metric filter, and confirmed Sum=15 in GetMetricStatistics — the full logs-to-alerts pipeline."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

CloudWatch Logs is a managed log aggregation service. It stores log events in Log Groups and Log Streams, applies retention policies, and most importantly — converts log patterns into CloudWatch metrics via Metric Filters. This is the bridge between raw log data and actionable alerts.

<!--more-->

# Why It Matters

Logs contain signal that metrics don't capture — specific error messages, user IDs, request paths, stack traces. Metric Filters extract that signal into quantifiable metrics without requiring a separate log analytics platform. Combined with CloudWatch Alarms, they enable alerting on application-level behavior from raw log data.

# Where It Fits

DOP-C02 Domain 4 — Monitoring and Logging

Application log line ("503 GET /api/health")
|
v
CloudWatch Log Stream (instance-id)
|
v
CloudWatch Log Group (/platform/haproxy)
|
v
Metric Filter (pattern: "503" → HAProxy5xxErrors +1)
|
v
CloudWatch Metric (DopLab/HAProxy5xxErrors)
|
v
CloudWatch Alarm → SNS → email


---

# The Big Picture

Your platform today AWS Equivalent

/var/log/haproxy.log → CloudWatch Log Stream
HAProxy server logs → Log Group (/platform/haproxy)
grep "503" logs | wc -l → Metric Filter → custom metric
Prometheus alert rule → CloudWatch Alarm on that metric


---

# Core Concepts

**Log Group** — the container for related log streams. Has a retention policy. One per application/service.

**Log Stream** — one per source: one per EC2 instance, one per Lambda invocation, one per container. Named by instance ID for EC2.

**Log Events** — individual log lines with millisecond timestamps.

**Retention policies** — how long logs are kept:

1 day, 3 days, 7 days, 14 days, 30 days, 60 days, 90 days,
120 days, 150 days, 180 days, 1 year, 2 years, 5 years, 10 years, Never expire

Default is Never Expire — always set a retention policy to control cost.

**Metric Filters — the exam-critical feature:**
Converts log patterns to CloudWatch metrics:

Pattern → Metric increment
"503" → +1 to HAProxy5xxErrors
"ERROR" → +1 to ApplicationErrors
"FATAL" → +1 to FatalErrors


**Filter pattern syntax:**

"ERROR" — contains the word ERROR
"ERROR" - "TIMEOUT" — contains ERROR but not TIMEOUT
"[ip, id, status=5*]" — structured: status starts with 5
{ $.level = "ERROR" } — JSON logs: field matching
{ $.httpStatusCode = 5* } — JSON: status code starts with 5


**defaultValue on metric transformation:**
- `0` — periods with no matches report 0 (correct for error counters — no errors = report 0, not silence)
- omitted — periods with no matches report no datapoint (silence)

Use `defaultValue: 0` for error rate metrics so `treat-missing-data: notBreaching` works correctly.

---

# Real-World Example

Live lab in devopslab, account 046685909731:

1. Created log group `/dop-lab/haproxy` with 7-day retention
2. Created log stream `test-instance-001`
3. Pushed 16 fake HAProxy 503 log events across three batches using `put-log-events`
4. Created metric filter `haproxy-503-errors` — pattern `"503"`, namespace `DopLab`, metric `HAProxy5xxErrors`, defaultValue `0`
5. Queried metric after ~3 minutes — confirmed `Sum: 15.0` in `GetMetricStatistics`
6. Deleted log group after lab

**Key observation:** Metric Filter propagation takes 2-3 minutes after log events are ingested. Query with a wide enough time window and period.

**Lab runbook:**
```bash
# Create log group with retention
aws logs create-log-group --log-group-name /dop-lab/haproxy
aws logs put-retention-policy --log-group-name /dop-lab/haproxy --retention-in-days 7

# Create log stream
aws logs create-log-stream \
  --log-group-name /dop-lab/haproxy \
  --log-stream-name test-instance-001

# Push log event
aws logs put-log-events \
  --log-group-name /dop-lab/haproxy \
  --log-stream-name test-instance-001\
  --log-events "[{\"timestamp\": $(date +%s%3N), \"message\": \"haproxy 503 GET /api/health\"}]"

# Create metric filter
aws logs put-metric-filter \
  --log-group-name /dop-lab/haproxy \
  --filter-name haproxy-503-errors \
  --filter-pattern "503" \
  --metric-transformations \
    metricName=HAProxy5xxErrors,metricNamespace=DopLab,metricValue=1,defaultValue=0

# Query metric (wait 2-3 min)
aws cloudwatch get-metric-statistics \
  --namespace DopLab \
  --metric-name HAProxy5xxErrors \
  --start-time $(date -u -d '15 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 900 \
  --statistics Sum \
  --output table

# Cleanup
aws logs delete-log-group --log-group-name /dop-lab/haproxy
```

---

# Engineering Analogy

Metric Filters are the equivalent of `grep "503" /var/log/haproxy.log | wc -l` run continuously against a streaming log, publishing the count as a metric every minute. The difference: it's serverless, always-on, and feeds directly into CloudWatch Alarms without any cron job or script.

---

# Best Practices

- Always set retention policy on log groups — default is Never Expire which accumulates cost
- Use `defaultValue: 0` on metric filters for error counters — ensures silence means zero errors, not unknown
- Name log groups by service path: `/platform/haproxy`, `/platform/nginx`, `/app/api`
- Name log streams by instance ID — CloudWatch Agent does this automatically
- Query with a period at least as wide as your filter propagation window (2-3 min minimum)

---

# Common Mistakes

- No retention policy — logs accumulate indefinitely, cost grows silently
- Missing `defaultValue` on metric filter — zero-error periods produce no datapoint, confusing alarm behavior
- Filter pattern too broad (`"5"` matches everything containing 5, not just 503s) — use structured patterns for precision
- Querying metric too soon after log ingestion — allow 2-3 minutes for propagation

---

# Pro Tip

> `aws logs filter-log-events --log-group-name <group> --filter-pattern "503"` lets you search log events directly via CLI without a metric filter — useful for ad-hoc incident investigation. It's the CLI equivalent of CloudWatch Logs Insights for simple pattern searches.

---

# Key Takeaways

- Log Group → Log Streams → Log Events is the hierarchy
- Always set retention policies — never leave log groups at Never Expire
- Metric Filters convert log patterns into CloudWatch metrics — no separate analytics platform needed
- `defaultValue: 0` ensures error-free periods report 0, not silence
- Filter propagation takes 2-3 minutes — account for this when testing

---

# Related Articles

- DevOpsPro-4.1-CloudWatch-Metrics-Alarms-and-SNS.md
- DevOpsPro-4.3-CloudWatch-Agent-System-Metrics-and-Log-Shipping.md
- DevOpsPro-4.5-CloudTrail-API-Audit-and-Event-History.md

---

# References

- AWS Documentation: Amazon CloudWatch Logs
- Live lab performed in devopslab-vpc, account 046685909731, 2026-08-10
