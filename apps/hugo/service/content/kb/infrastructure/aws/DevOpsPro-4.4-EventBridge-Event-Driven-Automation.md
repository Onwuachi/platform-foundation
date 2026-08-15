+++
title = "EventBridge: Event-Driven Automation"
date = "2026-08-15"
description = "EventBridge scheduled and pattern rules for automating responses to AWS service events — proven live with an ASG launch event routed to SNS email."
tags = ["aws", "eventbridge", "events", "automation", "sns", "dop-c02"]
categories = ["aws", "dop-c02"]
summary = "Built an EventBridge rule catching ASG launch events and routing to SNS — confirmed end-to-end email delivery with full event JSON payload."
draft = false
type = "kb-article"
weight = 0
+++

# Overview

EventBridge is AWS's event bus — it routes events from AWS services, custom applications, and SaaS partners to targets like Lambda, SNS, SSM, and Step Functions. It replaces polling and cron jobs with event-driven automation: when X happens, do Y automatically.

<!--more-->

# Why It Matters

Without EventBridge, reacting to AWS infrastructure events requires polling APIs on a schedule, missing events between polls, or building custom webhook infrastructure. EventBridge makes every AWS service emit events that can trigger immediate automated responses — no polling, no missed events, no custom infrastructure.

# Where It Fits

DOP-C02 Domain 4 — Monitoring and Logging

AWS Service emits event (ASG launch, CodePipeline state change, Config violation)
|
v
EventBridge default event bus
|
v
Rule evaluation (pattern match or schedule)
|
v
Target (Lambda / SNS / SSM Automation / Step Functions / SQS)


---

# The Big Picture

Your platform today AWS Equivalent

Cron job (polling) → EventBridge Scheduled Rule
"if X happens, run Y" → EventBridge Pattern Rule → Target
Manual runbook trigger → EventBridge → SSM Automation


---

# Core Concepts

**Two rule types:**

Scheduled rules — replace cron jobs:

rate(5 minutes) — every 5 minutes
rate(1 hour) — every hour
cron(0 2 * * ? *) — every day at 2am UTC
cron(0 8 ? * MON-FRI *) — weekdays at 8am UTC


Event pattern rules — react to AWS service events:
```json
{
  "source": ["aws.autoscaling"],
  "detail-type": ["EC2 Instance Launch Successful"],
  "detail": {
    "AutoScalingGroupName": ["dop-lab-asg"]
  }
}
```
Filter on any field in the event detail — specific ASG, region, instance type, status.

**Common targets:**

Lambda — run custom code
SNS — notify humans or other systems
SSM Automation — run a runbook (remediation)
Step Functions — start a workflow
SQS — queue for async processing
EC2 / ECS — start/stop instances or tasks


**SNS topic resource policy requirement:**
EventBridge must be explicitly allowed to publish to SNS:
```json
{
  "Effect": "Allow",
  "Principal": {"Service": "events.amazonaws.com"},
  "Action": "sns:Publish",
  "Resource": "<topic-arn>"
}
```
Without this policy, EventBridge silently fails to deliver — no error surfaced in the rule itself.

**Custom events — source namespace restriction:**
`put-events` cannot use `aws.*` as source — that namespace is reserved for AWS services. Custom events must use your own source name: `custom.myapp`, `platform.ops`, etc.

---

# Real-World Example

Live lab in devopslab, account 046685909731:

1. Created rule `dop-lab-asg-launch-notify` — pattern matching `EC2 Instance Launch Successful` for `dop-lab-asg`
2. Wired SNS topic `dop-lab-alerts` as target
3. First attempt: no email — SNS topic missing EventBridge resource policy
4. Added resource policy allowing `events.amazonaws.com` to publish
5. Scaled ASG to desired=1 — instance launched
6. Email received at `onwuabus@gmail.com` with full event JSON payload including instance ID, subnet, AZ, cause, and timestamps

**Email payload confirmed:**
```json
{
  "detail-type": "EC2 Instance Launch Successful",
  "source": "aws.autoscaling",
  "detail": {
    "AutoScalingGroupName": "dop-lab-asg",
    "EC2InstanceId": "i-0a160351f94acc722",
    "Cause": "a user request update...increasing the capacity from 0 to 1"
  }
}
```

**Common exam scenarios:**

"Notify team when CodePipeline fails"
→ EventBridge (pipeline state change FAILED) → SNS → email

"Stop dev instances every night at 10pm"
→ EventBridge scheduled rule cron(0 3 * * ? *) → Lambda → ec2:StopInstances

"Auto-remediate non-compliant Config resources"
→ AWS Config rule → EventBridge → SSM Automation

"Trigger runbook when ASG launches instance"
→ EventBridge (EC2 Instance Launch Successful) → SSM Automation


**Rule creation runbook:**
```bash
# Create rule
aws events put-rule \
  --name <rule-name> \
  --event-pattern '<json-pattern>' \
  --state ENABLED

# Wire target
aws events put-targets \
  --rule <rule-name> \
  --targets "Id=1,Arn=<target-arn>"

# Add SNS resource policy for EventBridge
aws sns set-topic-attributes \
  --topic-arn <topic-arn> \
  --attribute-name Policy \
  --attribute-value '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"events.amazonaws.com"},"Action":"sns:Publish","Resource":"<topic-arn>"}]}'

# Verify rule
aws events describe-rule --name <rule-name> --output table
```

---

# Engineering Analogy

EventBridge pattern rules are the AWS equivalent of systemd socket activation or inotify watches — something happens (a file changes, a socket receives a connection, an AWS service emits an event) and a handler fires immediately without polling. The difference is EventBridge operates at the AWS control plane level, reacting to infrastructure events across your entire account.

---

# Best Practices

- Always set SNS topic resource policy when using EventBridge → SNS — silent failures are hard to debug
- Use specific event patterns (filter by ASG name, pipeline name) — avoid broad patterns that fire on every resource
- Test rules with `put-events` using a custom source name — can't spoof `aws.*` namespace
- Use scheduled rules for operational tasks (nightly cleanup, cost reports) instead of cron on EC2
- Check EventBridge rule metrics in CloudWatch (`TriggeredRules`, `FailedInvocations`) when debugging delivery

---

# Common Mistakes

- Missing SNS resource policy — EventBridge silently fails to publish, no error in rule metrics
- Trying to use `aws.*` source in `put-events` — reserved namespace, returns `NotAuthorizedForSourceException`
- Overly broad event patterns — rule fires on every ASG in the account, not just the intended one
- No IAM role on Lambda/SSM targets — EventBridge can't invoke the target without explicit permission

---

# Pro Tip

> When EventBridge → SNS delivery fails silently, check two things in order: (1) SNS topic resource policy for `events.amazonaws.com`, (2) EventBridge rule's `FailedInvocations` CloudWatch metric. The resource policy is the most common miss and produces no visible error on the rule itself.

---

# Key Takeaways

- EventBridge replaces polling and cron with event-driven automation
- Two rule types: scheduled (rate/cron) and event pattern (react to AWS service events)
- SNS targets require explicit resource policy allowing `events.amazonaws.com` to publish
- Custom `put-events` cannot use `aws.*` source namespace — use your own source name
- EventBridge is the glue between AWS Config, CloudTrail, ASG, CodePipeline and your automation targets

---

# Related Articles

- DevOpsPro-4.1-CloudWatch-Metrics-Alarms-and-SNS.md
- DevOpsPro-4.5-CloudTrail-API-Audit-and-Event-History.md
- DevOpsPro-4.7-AWS-Config-Compliance-and-Auto-Remediation.md

---

# References

- AWS Documentation: Amazon EventBridge Rules
- Live lab performed in devopslab-vpc, account 046685909731, 2026-08-14
