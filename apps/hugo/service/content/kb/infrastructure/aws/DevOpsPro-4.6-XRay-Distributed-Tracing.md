+++
title = "X-Ray: Distributed Tracing"
date = "2026-08-15"
description = "X-Ray traces individual requests across microservices, Lambda, and DynamoDB — covering segments, subsegments, annotations, sampling, and the Service Map."
tags = ["aws", "xray", "tracing", "observability", "lambda", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "X-Ray architecture, sampling rules, annotation-based filtering, and the exam decision framework for when to use X-Ray vs CloudWatch metrics."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

X-Ray is AWS's distributed tracing service. While CloudWatch metrics tell you what's slow on average, X-Ray traces individual requests as they flow through multiple services — showing exactly where latency or errors occur within a single transaction.

<!--more-->

# Why It Matters

In a microservices or serverless architecture, a slow response could originate from any service in the call chain. CloudWatch metrics show aggregate latency but can't isolate which specific service call within a request caused the problem. X-Ray traces the full path of a single request and shows latency at every hop.

# Where It Fits

DOP-C02 Domain 4 — Monitoring and Logging

User request
|
v
ALB → EC2 App (200ms)
|
+-- DynamoDB query (50ms)
|
+-- Lambda call (120ms)
|
+-- S3 GetObject (30ms)
|
v
X-Ray Service Map: visual graph of call chain with latency at each node


---

# The Big Picture

CloudWatch metrics → "average API latency is 800ms" (aggregate)
X-Ray trace → "this request took 800ms: 50ms DynamoDB + 700ms Lambda cold start" (individual)


---

# Core Concepts

**Components:**

X-Ray SDK — instrument application code to emit trace data:
- Available for Java, Python, Node.js, Go, Ruby, .NET
- Wraps AWS SDK calls automatically — DynamoDB, S3, SQS calls traced without code changes
- HTTP calls to other services traced via middleware

X-Ray Daemon — sidecar process that buffers and ships trace segments:
- Runs on EC2, ECS sidecar, or Lambda layer
- Listens on UDP 2000, batches segments, ships to X-Ray service
- Required on EC2/ECS; Lambda manages it automatically

Service Map — visual graph of all services and their connections:
- Nodes = services (EC2, Lambda, DynamoDB, external HTTP)
- Edges = calls between services
- Color coding: green (healthy), yellow (slow), red (errors)

**Trace anatomy:**

Trace (one complete request)
|
+-- Segment (one service's contribution)
|
+-- Subsegment (individual operation: DB call, HTTP call, annotation)


**Annotations vs Metadata:**

Annotations — key/value indexed for filtering: user_id, order_id, tenant_id
"Show me all traces where user_id=12345"
Metadata — key/value NOT indexed, for debugging context only


**Sampling — cost control:**
Default: 5% of requests + reservoir of 1 request/second (first request per second always traced)
Custom rules: trace 100% of `/api/checkout` but 1% of `/api/health`

**Native integration (no SDK needed):**
- Lambda — enable Active Tracing with one toggle
- API Gateway — enable X-Ray tracing in stage settings
- ALB — enable access logging with X-Ray correlation IDs

---

# Real-World Example

No live lab — X-Ray requires instrumented application code.

**Exam scenarios:**

"Identify which microservice is causing latency"
→ X-Ray Service Map

"Trace a specific user's failed request through Lambda + DynamoDB"
→ X-Ray with Annotations (filter by user_id annotation)

"Reduce X-Ray cost in high-traffic production"
→ Adjust sampling rules — reduce % for high-volume low-value paths

"Enable tracing on Lambda without code changes"
→ Enable Active Tracing in Lambda configuration (one toggle)


---

# Engineering Analogy

X-Ray is the AWS equivalent of Jaeger or Zipkin — distributed tracing standards (OpenTracing/OpenTelemetry) that track requests across service boundaries. The X-Ray Service Map is equivalent to Jaeger's dependency graph. Annotations are equivalent to span tags in OpenTelemetry — indexed fields that enable trace filtering and search.

---

# Best Practices

- Enable sampling rules per path — 100% on critical paths (/checkout, /payment), 1-5% on health checks
- Use Annotations for business-relevant trace filtering (user_id, order_id, session_id)
- Use Lambda Active Tracing for serverless — no code changes, no daemon to manage
- Run X-Ray Daemon as ECS sidecar for containerized apps — one daemon per task, not per container
- Correlate X-Ray trace IDs with CloudWatch Logs using the X-Ray trace ID header

---

# Common Mistakes

- Using Metadata instead of Annotations for fields you need to filter on — Metadata is not indexed
- Not running X-Ray Daemon — SDK emits segments but nothing ships to X-Ray without the daemon
- Sampling 100% of requests in high-traffic production — cost scales linearly with request volume
- Assuming Lambda traces automatically — must enable Active Tracing explicitly in configuration

---

# Pro Tip

> X-Ray Daemon on EC2 needs UDP port 2000 open in the security group for loopback (127.0.0.1) — the SDK sends segments to the daemon locally. Outbound HTTPS to `xray.us-east-1.amazonaws.com` is also required for the daemon to ship to the X-Ray service.

---

# Key Takeaways

- X-Ray traces individual requests; CloudWatch measures aggregate metrics — they complement each other
- Trace → Segment → Subsegment is the hierarchy
- Annotations are indexed (filterable); Metadata is not
- Sampling controls cost — default is 5% + 1 req/sec reservoir
- Lambda and API Gateway have native X-Ray integration requiring no SDK or daemon

---

# Related Articles

- DevOpsPro-4.1-CloudWatch-Metrics-Alarms-and-SNS.md
- DevOpsPro-4.2-CloudWatch-Logs-and-Metric-Filters.md

---

# References

- AWS Documentation: AWS X-Ray Developer Guide
- AWS Documentation: X-Ray Sampling Rules
