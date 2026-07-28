+++
title = 'Aws CloudFormation Drift Detection'
date = 2026-07-28T17:19:45-05:00
draft = false
type = "kb-article"
description = "Understand how AWS CloudFormation detects out-of-band infrastructure changes, how to perform drift detection with the AWS CLI, and how to investigate and remediate drift."
summary = "CloudFormation drift detection identifies when AWS resources managed by a CloudFormation stack differ from the configuration defined in the stack template. This article covers the drift lifecycle, the AWS CLI workflow, a hands-on Security Group example, operational considerations, and the relationship between drift detection and infrastructure as code."
tags = ["aws", "cloudformation", "infrastructure-as-code", "devops", "drift-detection", "compliance", "configuration-management"]
categories = ["infrastructure", "aws"]
weight = 0
+++

# Overview

AWS CloudFormation drift detection identifies whether resources managed by a CloudFormation stack have been changed outside of CloudFormation and no longer match the configuration defined by the stack template.

CloudFormation maintains an expected configuration based on the template used to create or update the stack. If an administrator changes a resource directly through the AWS Console, AWS CLI, SDK, Terraform, or another management tool, the actual resource configuration can become different from the configuration CloudFormation expects.

This difference is known as **drift**.

CloudFormation does not continuously reconcile every resource back to the template. A resource can therefore be changed outside CloudFormation without immediately causing the stack's normal lifecycle status to change.

Drift detection provides a way to explicitly compare the expected configuration with the actual configuration.

<!--more-->

# Why It Matters

Infrastructure as code is most effective when the code and the deployed environment remain consistent.

For example, a CloudFormation template might define a Security Group that allows SSH access only from an internal network:

```yaml
SecurityGroupIngress:
  - IpProtocol: tcp
    FromPort: 22
    ToPort: 22
    CidrIp: 10.50.0.0/16
```

An administrator might later modify the Security Group directly through the AWS Console and change the rule to:

```text
0.0.0.0/0
```

The AWS resource has now changed, but the CloudFormation template has not.

The infrastructure has drifted.

This matters because the deployed environment may no longer represent the approved infrastructure definition.

Drift detection can help identify:

- Unauthorized or undocumented infrastructure changes
- Configuration differences between IaC and deployed resources
- Security configuration changes
- Changes made during emergency troubleshooting
- Resources modified by other automation systems
- Configuration inconsistencies that may affect future deployments
- Evidence relevant to change-control and configuration-management processes

For compliance programs such as SOC 2 or HITRUST, drift detection can support configuration-management and change-control processes by helping demonstrate that infrastructure is periodically checked for unexpected changes.

Drift detection itself, however, is not a complete compliance control. It is one mechanism that can contribute to a broader change-management and infrastructure-governance process.

---

# Where It Fits

CloudFormation drift detection fits into the infrastructure-as-code lifecycle after resources have been deployed.

A simplified workflow looks like this:

```text
CloudFormation Template
        |
        | Defines expected configuration
        v
CloudFormation Stack
        |
        | Provisions and manages
        v
AWS Resources
        |
        | Out-of-band change
        | Console / CLI / SDK / Other Tool
        v
Actual Resource State
        |
        | Expected != Actual
        v
Potential Drift
        |
        | Explicit drift detection
        v
CloudFormation Drift Status
        |
        +----------------------+
        |                      |
        v                      v
     IN_SYNC                DRIFTED
                               |
                               v
                         Investigation
                               |
                 +-------------+-------------+
                 |                           |
                 v                           v
          Revert change              Update IaC
          to expected state          and/or stack
```

The important point is that CloudFormation does not automatically perform this comparison continuously.

The drift detection operation must be initiated explicitly, either manually or through automation.

A production environment can automate this process using services such as EventBridge, Lambda, SNS, or an incident-management workflow.

---

# The Big Picture

The CloudFormation drift model can be understood as three separate concepts:

```text
1. CloudFormation Template
   --------------------------------
   What the infrastructure should be

2. Actual AWS Resource
   --------------------------------
   What the infrastructure currently is

3. Drift Detection
   --------------------------------
   The comparison between expected and actual
```

The result can be represented as:

```text
                CloudFormation
                Template
                    |
                    | Expected State
                    v
              +-------------+
              |             |
              | Comparison  |
              |             |
              +-------------+
                    ^
                    |
                    | Actual State
                    |
              AWS Resource
```

If the expected and actual configurations match:

```text
Expected State == Actual State
                |
                v
             IN_SYNC
```

If they differ:

```text
Expected State != Actual State
                |
                v
             DRIFTED
```

Drift detection is therefore a **detection mechanism**, not a remediation mechanism.

CloudFormation identifies the difference, but it does not automatically decide whether the manual change was intentional or unauthorized.

---

# Core Concepts

## Expected State vs. Actual State

CloudFormation maintains an expected configuration for resources based on the stack template.

The actual resource exists in AWS and can potentially be modified independently.

For example:

```text
CloudFormation Template
-----------------------
SSH allowed from:
10.50.0.0/16


Actual Security Group
---------------------
SSH allowed from:
0.0.0.0/0
```

The resource is now different from the expected configuration. That is drift.

## Stack Lifecycle Status vs. Drift Status

One of the most important concepts is that a stack's normal lifecycle status and its drift status are different things.

A stack might show:

```text
StackStatus: CREATE_COMPLETE
```

while its drift status is:

```text
StackDriftStatus: DRIFTED
```

The stack successfully completed its original creation. That does not mean that the current AWS resources still match the CloudFormation template.

```text
Stack Lifecycle Status        Drift Status
-----------------------       ------------
CREATE_COMPLETE                IN_SYNC
UPDATE_COMPLETE                DRIFTED
UPDATE_FAILED                  NOT_CHECKED
DELETE_COMPLETE
```

A successful CloudFormation deployment therefore does not guarantee that the environment remains synchronized forever.

## Drift Detection Is Not Automatic Reconciliation

CloudFormation should not be thought of as continuously reconciling resources in the same way that Kubernetes controllers continuously work toward a desired state.

A manual change can remain in place until:

1. Drift detection is performed.
2. The drift is identified.
3. Someone investigates the change.
4. The organization determines whether the change was intentional.
5. The configuration is remediated if necessary.

## Resource Drift Status

CloudFormation can report drift at the resource level. Common statuses include:

| Status | Meaning |
|---|---|
| `IN_SYNC` | Actual resource configuration matches expected configuration |
| `MODIFIED` | One or more properties differ from the expected configuration |
| `DELETED` | The resource expected by CloudFormation no longer exists |
| `NOT_CHECKED` | Drift detection has not been performed for the resource |

The stack-level drift status provides an overall view, while resource-level drift information helps identify exactly what changed.

## Drift Detection Is Asynchronous

The AWS CLI command `aws cloudformation detect-stack-drift` does not immediately return the final drift results. Instead, CloudFormation starts an asynchronous detection operation and returns a `StackDriftDetectionId`.

```text
detect-stack-drift
        |
        v
StackDriftDetectionId
        |
        v
describe-stack-drift-detection-status
        |
        v
DETECTION_IN_PROGRESS  →  DETECTION_COMPLETE
        |
        v
describe-stack-resource-drifts
```

A script should not assume that calling `detect-stack-drift` means the results are immediately available.

---

# Real-World Example

A CloudFormation stack creates an EC2 Security Group. The template allows SSH only from an internal network (`10.50.0.0/16`). The stack is created successfully.

An administrator later manually changes the Security Group to allow `0.0.0.0/0` instead. The Security Group is now different from the CloudFormation template, but the stack's lifecycle status may still show `CREATE_COMPLETE`.

Running drift detection allows CloudFormation to identify the difference — this exact scenario is walked through hands-on below.

---

# Hands-On Lab

This lab creates a simple Security Group, manually changes it outside CloudFormation, detects the resulting drift, and cleans up. A Security Group is used because it has no hourly infrastructure charge — the full exercise runs at **$0**.

### Step 1 — Create the template and stack

```bash
cat > /tmp/drift-test.yaml << 'EOF'
AWSTemplateFormatVersion: '2010-09-09'
Description: CloudFormation drift detection demo

Resources:
  DemoSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Drift detection demo
      VpcId: <your-vpc-id>
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 10.50.0.0/16
EOF

aws cloudformation create-stack \
  --stack-name drift-demo \
  --template-body file:///tmp/drift-test.yaml \
  --region us-east-1
```

Check status until `CREATE_COMPLETE`:

```bash
aws cloudformation describe-stacks \
  --stack-name drift-demo --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

### Step 2 — Retrieve the physical Security Group ID

```bash
aws cloudformation describe-stack-resources \
  --stack-name drift-demo --region us-east-1 \
  --query 'StackResources[0].PhysicalResourceId' --output text
```

### Step 3 — Verify the original configuration

```bash
aws ec2 describe-security-groups \
  --group-ids <sg-id> --region us-east-1 \
  --query 'SecurityGroups[0].IpPermissions'
```

Confirm the rule shows `10.50.0.0/16` — expected and actual should be in sync here.

### Step 4 — Manually create drift

```bash
aws ec2 revoke-security-group-ingress \
  --group-id <sg-id> --protocol tcp --port 22 \
  --cidr 10.50.0.0/16 --region us-east-1

aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> --protocol tcp --port 22 \
  --cidr 0.0.0.0/0 --region us-east-1
```

### Step 5 — Confirm the stack lifecycle status is unaffected

```bash
aws cloudformation describe-stacks \
  --stack-name drift-demo --region us-east-1 \
  --query 'Stacks[0].StackStatus'
```

Still reports `CREATE_COMPLETE` — proof that drift is invisible until explicitly checked.

### Step 6 — Start drift detection

```bash
aws cloudformation detect-stack-drift \
  --stack-name drift-demo --region us-east-1
```

Returns a `StackDriftDetectionId`.

### Step 7 — Check detection progress

```bash
aws cloudformation describe-stack-drift-detection-status \
  --stack-drift-detection-id <id> --region us-east-1
```

Wait for `DetectionStatus: DETECTION_COMPLETE` before querying results.

### Step 8 — Check the stack drift status

```bash
aws cloudformation describe-stacks \
  --stack-name drift-demo --region us-east-1 \
  --query 'Stacks[0].{StackStatus:StackStatus,DriftStatus:DriftInformation.StackDriftStatus}'
```

Expected result:

```json
{
    "StackStatus": "CREATE_COMPLETE",
    "DriftStatus": "DRIFTED"
}
```

### Step 9 — Identify the drifted resource

```bash
aws cloudformation describe-stack-resource-drifts \
  --stack-name drift-demo --region us-east-1 \
  --query 'StackResourceDrifts[].{LogicalId:LogicalResourceId,Status:StackResourceDriftStatus,Actual:ActualProperties,Expected:ExpectedProperties}'
```

Reports `StackResourceDriftStatus: MODIFIED`, with `Expected` showing `10.50.0.0/16` and `Actual` showing `0.0.0.0/0`.

### Step 10 — Remediate

**Option 1 — Revert the resource** (if the change was unauthorized):

```bash
aws ec2 revoke-security-group-ingress \
  --group-id <sg-id> --protocol tcp --port 22 \
  --cidr 0.0.0.0/0 --region us-east-1

aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> --protocol tcp --port 22 \
  --cidr 10.50.0.0/16 --region us-east-1
```

**Option 2 — Update the template** (if the change was intentional and should become the new approved state).

**Option 3 — Investigate first** — who made the change, why, was it approved, will reverting cause an outage. Drift is a signal that expected and actual disagree; the correct remediation depends on why.

### Step 11 — Clean up

```bash
aws cloudformation delete-stack \
  --stack-name drift-demo --region us-east-1
```

Confirm removal — the describe-stacks call should error with "does not exist."

---

# Engineering Analogy

## CloudFormation Drift vs. Terraform Plan

```text
Terraform                          CloudFormation
---------                          --------------
Terraform Configuration            CloudFormation Template
        |                                  |
        v                                  v
terraform plan                     Deployed AWS Resources
        |                                  |
  Compare desired config             detect-stack-drift
  with Terraform state                    |
  + refresh/query infra                   v
        |                          Drift Report
        v
Proposed Changes
```

> **Terraform plan is part of the normal planning workflow. CloudFormation drift detection is an explicit check for differences between a CloudFormation-managed resource and its expected configuration.**

They should not be treated as exact equivalents. Terraform has a broader planning workflow that evaluates proposed changes before applying them. CloudFormation drift detection specifically answers whether supported resource properties have diverged from the expected CloudFormation configuration.

## CloudFormation Drift vs. Kubernetes Reconciliation

```text
Kubernetes                         CloudFormation
-----------                        --------------
Desired State                      Expected State
     |                                    |
     v                                    v
Controller                          AWS Resource
     |                                    |
     v                              Out-of-band change
Actual State                              |
     |                                    v
Difference? --Yes--> Reconcile      Actual State
     |                                    |
     No -> Continue               No automatic reconciliation
                                          |
                                          v
                                  Drift Detection Requested
                                          |
                                          v
                                  Difference Reported
```

This is why drift detection should be viewed as **detection and visibility**, not automatic continuous enforcement.

---

# Best Practices

- Treat the CloudFormation template as the authoritative desired configuration.
- Prefer making infrastructure changes through CloudFormation rather than directly modifying managed resources.
- Run drift detection periodically for important CloudFormation stacks.
- Automate drift detection for production environments where practical.
- Investigate drift before blindly reverting or overwriting resources.
- Record the reason for intentional out-of-band changes.
- Update infrastructure as code when an intentional change becomes the new approved configuration.
- Use AWS CloudTrail to investigate who made an out-of-band change and when.
- Combine CloudFormation drift detection with AWS Config where broader configuration compliance is required.
- Integrate detected drift with EventBridge, Lambda, SNS, ticketing, or incident-management workflows where appropriate.
- Avoid treating `CREATE_COMPLETE` or `UPDATE_COMPLETE` as proof that resources are still synchronized with the template.
- Test drift detection against the specific AWS resource types and properties that matter to the environment.
- Include drift detection in infrastructure governance and operational reviews where appropriate.

---

# Common Mistakes

- Assuming CloudFormation automatically detects every out-of-band change.
- Assuming a `CREATE_COMPLETE` stack cannot be drifted.
- Forgetting that drift detection runs asynchronously.
- Querying resource drift results before detection has completed.
- Confusing stack lifecycle status with stack drift status.
- Assuming drift detection automatically remediates the resource.
- Immediately overwriting a drifted production resource without investigating the change.
- Treating all manually changed resources as unauthorized without checking change records.
- Assuming every resource property is necessarily supported by CloudFormation drift detection.
- Using drift detection as a replacement for proper infrastructure-as-code change management.
- Forgetting that another automation system may be intentionally modifying a resource managed by CloudFormation.
- Ignoring the security implications of drifted resources.

---

# Pro Tip

> **Always remember: "CREATE_COMPLETE" does not mean "IN_SYNC."**

A CloudFormation stack can have successfully completed its last lifecycle operation while the actual resources have subsequently changed. For operational troubleshooting, think in two dimensions — did CloudFormation successfully deploy the stack (`StackStatus`), and does the deployed infrastructure still match the template (`StackDriftStatus`)?

A practical investigation workflow:

1. Check `StackStatus`
2. Check `StackDriftStatus`
3. Identify drifted resources
4. Compare expected vs. actual properties
5. Review CloudTrail for the change
6. Check change tickets / deployment history
7. Determine whether the change was intentional
8. Remediate through the approved process
9. Re-run drift detection

---

# Key Takeaways

- CloudFormation drift occurs when an AWS resource differs from the configuration CloudFormation expects.
- Out-of-band changes can be made through the AWS Console, CLI, SDK, Terraform, or other systems.
- CloudFormation does not continuously reconcile all managed resources back to the template.
- Drift detection is an explicit operation that compares expected and actual resource configuration.
- Drift detection is asynchronous and must be monitored until `DETECTION_COMPLETE`.
- A stack can have `StackStatus = CREATE_COMPLETE` while `StackDriftStatus = DRIFTED`.
- Resource-level drift can be reported as `IN_SYNC`, `MODIFIED`, `DELETED`, or `NOT_CHECKED`.
- Drift detection identifies differences but does not automatically remediate them.
- Remediation requires determining whether the drift was intentional and then restoring alignment between the infrastructure and the source of truth.
- CloudFormation drift detection is useful for infrastructure governance, configuration management, security, and change-control processes.
- Automated drift detection can be integrated into a broader operational workflow using AWS services such as EventBridge, Lambda, SNS, CloudTrail, and AWS Config.
- The key mental model is: **CloudFormation defines expected state; drift detection compares expected state with actual state.**

---

# Related Articles

- AWS CloudFormation Fundamentals
- AWS CloudFormation Stack Operations
- AWS CloudFormation Change Sets
- Infrastructure as Code
- Terraform Plan and Apply
- AWS Config
- AWS CloudTrail
- AWS EventBridge
- Infrastructure Change Management
- AWS Security and Compliance Monitoring

---

# References

- AWS CloudFormation User Guide — Detect unmanaged configuration changes
- AWS CloudFormation API Reference — `DetectStackDrift`
- AWS CloudFormation API Reference — `DescribeStackDriftDetectionStatus`
- AWS CloudFormation API Reference — `DescribeStackResourceDrifts`
- AWS CLI Command Reference — `cloudformation detect-stack-drift`
- AWS CLI Command Reference — `cloudformation describe-stack-drift-detection-status`
- AWS CLI Command Reference — `cloudformation describe-stack-resource-drifts`
