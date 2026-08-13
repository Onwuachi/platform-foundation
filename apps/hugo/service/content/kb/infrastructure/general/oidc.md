+++
title = 'OpenID Connect (OIDC)'
date = 2026-07-29T22:42:19-05:00
draft = false

type = "kb-article"

description = "A practical guide to OpenID Connect (OIDC), OAuth 2.0, GitHub Actions OIDC, AWS IAM workload identity federation, trust policies, claims, scoped permissions, and troubleshooting."
summary = "Understand OIDC, OAuth 2.0, and GitHub Actions workload identity federation with AWS. This article explains how GitHub workflows authenticate to AWS without long-lived access keys and how IAM trust policies and scoped roles control what those workflows can do."

tags = ["oidc", "oauth2", "github-actions", "aws", "iam", "security", "workload-identity", "devops", "cicd"]
categories = ["infrastructure", "general"]

weight = 0
+++

# Overview

OpenID Connect (OIDC) is an identity protocol built on top of OAuth 2.0. It adds a standardized identity layer that allows an application or service to verify **who or what is making a request** without directly handling the user's password or requiring long-lived credentials.

OIDC is commonly associated with user authentication and Single Sign-On (SSO), but the same underlying trust model can also be used for **workload identity federation**.

In a modern DevOps environment, GitHub Actions can use OIDC to authenticate to cloud providers such as AWS without storing long-lived cloud access keys in GitHub repository secrets.

This creates a trust chain:

```text
GitHub Actions
      │
      │ Requests short-lived OIDC token
      ▼
GitHub OIDC Provider
      │
      │ Signed JWT
      ▼
AWS IAM OIDC Provider
      │
      │ Validates token claims
      ▼
IAM Role Trust Policy
      │
      │ Allows AssumeRoleWithWebIdentity
      ▼
Temporary AWS Credentials
      │
      ▼
AWS Services
```

The result is a CI/CD system where GitHub workflows can receive **short-lived AWS credentials only when they satisfy the conditions defined by AWS IAM**.

This eliminates the need to maintain long-lived AWS access keys in GitHub Actions for supported workflows.

<!--more-->

# Why It Matters

Traditional CI/CD authentication often relies on long-lived credentials stored as secrets:

```text
GitHub Actions
      │
      │ AWS_ACCESS_KEY_ID
      │ AWS_SECRET_ACCESS_KEY
      ▼
AWS
```

This creates several security concerns:

* Credentials can remain valid for long periods.
* Secrets must be stored and rotated.
* A leaked credential may be usable outside GitHub Actions.
* It can be difficult to determine exactly which workflow should be trusted.
* Access may be broader than necessary.
* Forks, branches, or unexpected workflows can become potential attack paths if trust is not carefully scoped.

OIDC changes the model.

Instead of GitHub storing an AWS secret, the workflow proves its identity to AWS using a signed OIDC token.

AWS then evaluates the token against an IAM role trust policy.

If the token satisfies the trust conditions, AWS issues temporary credentials.

```text
No static AWS secret
        │
        ▼
GitHub issues signed identity token
        │
        ▼
AWS validates token
        │
        ▼
IAM evaluates trust policy
        │
        ▼
Temporary credentials issued
        │
        ▼
Workflow accesses only permitted AWS resources
```

The security improvement is not simply "OIDC is more secure."

The more important architectural benefit is that **identity and authorization become explicit**.

The trust policy determines:

> "Which GitHub identity is allowed to assume this role?"

The IAM permissions policy determines:

> "What can that identity do after assuming the role?"

This creates a clean separation between **authentication** and **authorization**.

---

# Where It Fits

OIDC sits between an identity issuer and the system that needs to trust that identity.

For GitHub Actions and AWS:

```text
GitHub
  │
  │ Issues OIDC JWT
  ▼
GitHub Actions Workflow
  │
  │ Presents JWT
  ▼
AWS IAM OIDC Provider
  │
  │ Establishes trust in GitHub's issuer
  ▼
IAM Role Trust Policy
  │
  │ Evaluates token claims
  ▼
STS AssumeRoleWithWebIdentity
  │
  │ Returns temporary credentials
  ▼
AWS APIs
```

In the `platform-foundation` architecture, OIDC is part of the CI/CD security boundary.

It is used to replace static AWS credentials with temporary credentials for workflows that need to interact with AWS.

A simplified architecture is:

```text
Developer
    │
    │ Git push / workflow dispatch
    ▼
GitHub Repository
    │
    ▼
GitHub Actions
    │
    │ OIDC token
    ▼
AWS IAM
    │
    ├── Trust Policy
    │      └── Who can assume the role?
    │
    └── Permissions Policy
           └── What can the role do?
    │
    ▼
Temporary AWS Credentials
    │
    ├── Terraform
    ├── Packer
    ├── ECR
    ├── S3
    ├── SSM
    ├── CloudFront
    └── Other AWS services
```

---

# The Big Picture

The most important concept is that **OIDC itself does not grant AWS permissions**.

OIDC establishes identity.

AWS IAM determines authorization.

The complete chain is:

```text
Identity
   │
   ▼
GitHub OIDC Token
   │
   │ "This workflow is from this repository,
   │  branch, environment, and workflow."
   ▼
AWS IAM Trust Policy
   │
   │ "I trust this identity under these conditions."
   ▼
STS AssumeRoleWithWebIdentity
   │
   │ "Here are temporary credentials."
   ▼
IAM Permissions Policy
   │
   │ "These are the AWS actions you may perform."
   ▼
AWS Resources
```

This distinction is critical.

A workflow can successfully authenticate to AWS and still receive:

```text
AccessDenied
```

That means the OIDC trust relationship worked, but the IAM permissions policy did not authorize the requested action.

Conversely, a workflow may have a perfectly designed IAM permissions policy but fail before receiving credentials because its OIDC token does not satisfy the IAM trust policy.

There are therefore two separate questions when troubleshooting:

1. **Can the workflow assume the IAM role?**
2. **Once assumed, does the role have permission to perform the requested action?**

---

# OIDC vs. OAuth 2.0

OIDC and OAuth 2.0 are related but solve different problems.

## OAuth 2.0

OAuth 2.0 is primarily an **authorization framework**.

It answers:

> "What is this client allowed to access?"

OAuth commonly issues an **access token** that a client presents to an API.

For example:

```text
Application
    │
    │ Access Token
    ▼
API
    │
    ▼
Protected Resource
```

OAuth 2.0 does not, by itself, define a standardized way to authenticate the identity of an end user.

---

## OpenID Connect

OIDC adds an identity layer on top of OAuth 2.0.

It answers:

> "Who is this identity?"

OIDC introduces an **ID token**, normally a signed JWT containing identity claims.

A simplified comparison:

| Concept                    | OAuth 2.0            | OpenID Connect            |
| -------------------------- | -------------------- | ------------------------- |
| Primary purpose            | Authorization        | Authentication / identity |
| Main question              | What can you access? | Who are you?              |
| Common token               | Access token         | ID token                  |
| Standardized user identity | No                   | Yes                       |
| Built on OAuth 2.0         | N/A                  | Yes                       |
| Common use                 | API access           | Login and SSO             |

A useful mental model:

```text
OAuth 2.0
"What are you allowed to do?"

OIDC
"Who are you?"
```

OIDC may also be used alongside OAuth access tokens when an application needs both identity and API authorization.

---

# Core Concepts

## Identity Provider

The **Identity Provider (IdP)** authenticates an identity and issues tokens.

Examples include:

* Microsoft Entra ID
* Google
* Okta
* Auth0
* GitHub's OIDC issuer for GitHub Actions workloads

For a traditional user login:

```text
User
  │
  ▼
Identity Provider
  │
  │ Authenticates user
  ▼
OIDC Token
  │
  ▼
Application
```

For GitHub Actions:

```text
GitHub Actions Workflow
  │
  ▼
GitHub OIDC Issuer
  │
  │ Issues signed JWT
  ▼
AWS
```

---

## Relying Party

The **Relying Party (RP)** is the application or system that trusts the identity provider.

In a traditional OIDC login:

```text
Google / Entra ID / Okta
        │
        ▼
Application
```

The application is the relying party.

In GitHub-to-AWS workload identity federation:

```text
GitHub
   │
   ▼
AWS IAM
```

AWS is effectively relying on GitHub's OIDC identity assertions.

---

## ID Token

An OIDC ID token is typically a signed JWT.

It contains claims about the authenticated identity.

A simplified token structure is:

```text
header.payload.signature
```

The payload may contain claims such as:

```text
iss
aud
sub
iat
exp
```

GitHub Actions OIDC tokens also contain GitHub-specific claims that can identify information such as the repository, ref, workflow, and environment.

The token is used to establish identity.

It is **not the same thing as an AWS access key or AWS secret key**.

---

## Access Token

An OAuth access token represents authorization to access a protected resource.

For example:

```text
Application
    │
    │ Access Token
    ▼
API
```

An access token answers:

> "What resource access has been granted?"

An ID token answers:

> "Who authenticated?"

Do not assume that an ID token should be presented to an arbitrary API.

---

## UserInfo Endpoint

OIDC providers may expose a UserInfo endpoint that allows a relying party to retrieve additional identity claims.

This is more common in traditional user authentication scenarios.

GitHub Actions-to-AWS workload federation does not depend on the UserInfo endpoint in the same way a typical "Sign in with Google" application does.

---

## Discovery Document

OIDC providers commonly publish a discovery document under:

```text
/.well-known/openid-configuration
```

The discovery document describes provider metadata such as:

* Issuer
* Authorization endpoint
* Token endpoint
* UserInfo endpoint
* Supported signing algorithms

This is primarily relevant to traditional OIDC client integrations.

---

# OIDC Authentication Flow

A traditional user-centric OIDC flow looks roughly like this:

```text
1. User
      │
      │ Click "Sign In"
      ▼
2. Application
      │
      │ Redirect
      ▼
3. Identity Provider
      │
      │ Authenticate user
      │ MFA / password / passkey
      ▼
4. Identity Provider
      │
      │ Authorization response
      ▼
5. Application
      │
      │ Receives tokens
      ▼
6. Application
      │
      │ Validates ID Token
      ▼
7. Authenticated Session
```

For modern applications, **Authorization Code Flow with PKCE** is generally preferred.

The older Implicit Flow should generally not be selected for new implementations.

---

# GitHub Actions OIDC

GitHub Actions can use OIDC to authenticate workloads to cloud providers.

The model is:

```text
GitHub Actions
      │
      │ Requests OIDC token
      ▼
GitHub OIDC Issuer
      │
      │ Signs JWT
      ▼
Cloud Provider
      │
      │ Validates token
      ▼
Federated Identity
      │
      ▼
Temporary Credentials
```

The workflow does not need to store a long-lived cloud access key.

For GitHub Actions, the workflow must explicitly request permission to obtain an OIDC token:

```yaml
permissions:
  id-token: write
  contents: read
```

The critical permission is:

```yaml
id-token: write
```

Without it, the workflow cannot request the GitHub OIDC token required for federation.

---

# GitHub OIDC with AWS

AWS uses IAM and AWS Security Token Service (STS) to establish workload identity federation.

The important AWS API is:

```text
sts:AssumeRoleWithWebIdentity
```

The simplified flow is:

```text
GitHub Actions Workflow
        │
        │ 1. Request OIDC token
        ▼
GitHub OIDC Provider
        │
        │ 2. Signed JWT
        ▼
AWS IAM OIDC Provider
        │
        │ 3. Validate issuer and token claims
        ▼
IAM Role Trust Policy
        │
        │ 4. Check conditions
        ▼
AWS STS
        │
        │ 5. Issue temporary credentials
        ▼
GitHub Actions
        │
        │ 6. AWS CLI / Terraform / Packer / SDK
        ▼
AWS Resources
```

The AWS credentials issued to the workflow are temporary.

The workflow does not need:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

stored as long-lived GitHub secrets for the OIDC authentication path.

---

# AWS IAM OIDC Provider

AWS must trust GitHub's OIDC issuer.

The IAM OIDC provider represents that trust relationship.

A Terraform configuration may look similar to:

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}
```

The exact provider configuration should follow the current AWS and GitHub documentation and your organization's Terraform standards.

The important concepts are:

```text
Issuer:
https://token.actions.githubusercontent.com

Audience:
sts.amazonaws.com

STS Action:
sts:AssumeRoleWithWebIdentity
```

The OIDC provider establishes that AWS recognizes GitHub as a trusted token issuer.

It does **not** automatically give every GitHub repository access to the AWS account.

The IAM role's trust policy determines which GitHub identities can assume the role.

---

# IAM Trust Policies

An IAM role has a trust policy that defines who or what may assume it.

A simplified GitHub Actions trust relationship looks like:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account-id>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:Onwuachi/platform-foundation:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

This establishes a trust boundary.

The role is not saying:

> "Any GitHub workflow can use me."

It is saying:

> "I trust tokens issued by GitHub's OIDC provider, provided the token's claims satisfy these conditions."

The `aud` condition ensures the token is intended for AWS STS.

The `sub` condition restricts which GitHub identity can assume the role.

For example:

```text
repo:Onwuachi/platform-foundation:ref:refs/heads/main
```

restricts the role to the `main` branch of the specified repository.

---

# GitHub OIDC Claims

Claims are statements contained in the OIDC token.

The most important claims to understand when integrating GitHub Actions with AWS are:

## `iss`

The issuer.

For GitHub Actions:

```text
https://token.actions.githubusercontent.com
```

This identifies who issued the token.

AWS establishes trust in this issuer through the IAM OIDC provider.

---

## `aud`

The audience.

For AWS federation, the expected audience is commonly:

```text
sts.amazonaws.com
```

The trust policy can enforce this:

```json
"StringEquals": {
  "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
}
```

---

## `sub`

The subject.

The `sub` claim is one of the most important claims for restricting GitHub Actions access.

A branch-specific example:

```text
repo:Onwuachi/platform-foundation:ref:refs/heads/main
```

A GitHub environment may produce a subject representing the environment rather than a branch-specific subject, depending on the workflow configuration.

This distinction matters when designing production trust policies.

Always verify the actual GitHub token claims generated by the workflow before designing a restrictive trust policy.

---

## `repository`

Identifies the GitHub repository.

Example:

```text
Onwuachi/platform-foundation
```

This can be useful for understanding and debugging token identity.

---

## `ref`

Identifies the Git reference associated with the workflow.

Examples:

```text
refs/heads/main
refs/heads/develop
refs/tags/v1.2.0
```

This can help distinguish branch and tag-based deployment identities.

---

## `workflow`

Identifies the GitHub Actions workflow associated with the token.

This can be useful when separating permissions between different deployment workflows.

For example:

```text
terraform-deploy.yml
packer-build.yml
ci-cd-hugo.yml
```

---

## `environment`

Identifies the GitHub environment associated with a workflow when an environment is used.

This can be useful for implementing stronger controls around environments such as:

```text
dev
uat
stage
prod
```

Production deployments can be tied to a protected GitHub environment and a dedicated AWS IAM role.

---

# Scoped IAM Roles

OIDC determines **who can authenticate**.

IAM policies determine **what that identity can do**.

A strong architecture avoids giving every workflow the same broad IAM role.

Instead, roles should be separated according to their operational responsibility and blast radius.

For example:

```text
GitHub Actions
      │
      ├── Terraform Role
      │      └── Infrastructure provisioning
      │
      ├── Packer Role
      │      └── AMI builds / SSM / EC2
      │
      ├── Deployment Role
      │      └── ECR / S3 / CloudFront
      │
      └── Backup / Operations Role
             └── Backup and operational tasks
```

This creates a clearer security boundary.

---

# Terraform Deployment Role

Terraform is often the workflow with the largest AWS blast radius.

Depending on the infrastructure managed by Terraform, it may require access to:

* EC2
* VPC
* Subnets
* Route tables
* Internet gateways
* Security groups
* IAM
* S3
* SSM Parameter Store
* Secrets Manager
* Route 53
* Other platform resources

A dedicated Terraform role is therefore preferable to reusing a narrowly scoped Packer role.

Example conceptual architecture:

```text
GitHub Actions
      │
      │ OIDC
      ▼
github-terraform-role
      │
      ├── EC2 / VPC
      ├── IAM
      ├── S3
      ├── SSM
      ├── Secrets Manager
      ├── Route 53
      └── Other Terraform-managed resources
```

The permissions should be scoped as tightly as practical.

Using broad permissions such as:

```text
ec2:*
```

may be acceptable as a deliberate simplification for a personal platform or lab environment, but it should be recognized as a known tradeoff.

The goal should still be to reduce permissions over time where the operational cost of maintaining a least-privilege policy is justified.

---

# Packer Role

Packer has a narrower purpose.

The role may need access to:

* EC2
* AMI creation
* EBS snapshots
* SSM
* IAM PassRole
* Related instance profile operations

Conceptually:

```text
GitHub Actions
      │
      │ OIDC
      ▼
github-oidc-role
      │
      ├── Build EC2 instance
      ├── Run SSM commands
      ├── Create AMI
      ├── Create snapshots
      └── Pass required instance role
```

The Packer role should not automatically receive permissions for unrelated infrastructure management.

This is an example of minimizing blast radius through role separation.

---

# Build and Deployment Roles

Application build and deployment workflows generally have a different permission profile.

For example, a Hugo deployment may need:

```text
ECR
S3
CloudFront
```

An application container build may only need:

```text
ECR
```

A deployment workflow may need:

```text
S3
CloudFront
```

A conceptual deployment role might therefore look like:

```text
github-deploy-role
      │
      ├── ECR
      │
      ├── S3
      │
      └── CloudFront
```

The exact role design depends on whether applications share deployment boundaries or require stronger isolation.

For a smaller platform, one shared deployment role may be reasonable.

For higher-risk production systems, separate roles per application or environment may be preferable.

---

# GitHub OIDC and Secret Elimination

One of the primary benefits of migrating CI/CD workflows to OIDC is removing static cloud credentials.

The old model:

```text
GitHub Secret
    │
    ├── AWS_ACCESS_KEY_ID
    └── AWS_SECRET_ACCESS_KEY
             │
             ▼
        AWS Account
```

The OIDC model:

```text
GitHub Actions
    │
    │ OIDC JWT
    ▼
AWS IAM
    │
    │ Temporary credentials
    ▼
AWS Account
```

This should be treated as a security architecture improvement, not simply a credential-management convenience.

When migrating workflows, search for static credential usage:

```bash
grep -R "AWS_ACCESS_KEY_ID" .github/workflows/
grep -R "AWS_SECRET_ACCESS_KEY" .github/workflows/
grep -R "aws-access-key" .github/workflows/
grep -R "aws-secret-key" .github/workflows/
```

Also look for secrets being unnecessarily printed to logs.

For example, a step such as:

```yaml
- name: Debug MongoDB URL
  run: echo "MongoDB Atlas URL: ${{ secrets.MONGODB_ATLAS_URL }}"
```

should be removed unless there is a legitimate, safe reason to expose that value.

Secrets should never be printed to CI/CD logs.

---

# Real-World Example

A GitHub Actions workflow using AWS OIDC may look like:

```yaml
name: Terraform Deploy

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Target environment"
        required: true
        default: "dev"

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    name: Deploy to ${{ inputs.environment }}
    runs-on: ubuntu-latest

    environment:
      name: ${{ inputs.environment }}

    defaults:
      run:
        working-directory: infra

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::<account-id>:role/github-terraform-role
          aws-region: us-east-1

      - name: Verify AWS identity
        run: aws sts get-caller-identity

      - name: Set up Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        run: terraform init

      - name: Terraform Plan
        run: terraform plan

      - name: Terraform Apply
        run: terraform apply -auto-approve
```

The important sequence is:

```text
permissions:
  id-token: write
        │
        ▼
GitHub issues OIDC token
        │
        ▼
configure-aws-credentials
        │
        ▼
AWS STS AssumeRoleWithWebIdentity
        │
        ▼
github-terraform-role
        │
        ▼
Temporary AWS credentials
        │
        ▼
Terraform
```

The workflow does not need to store an AWS access key and secret key.

---

# GitHub OIDC Migration Strategy

OIDC migrations should be performed systematically.

Do not simply replace every workflow's AWS credentials with the same IAM role.

First classify workflows by responsibility.

For a platform such as `platform-foundation`, a practical classification might be:

| Workflow         | Responsibility              | Recommended Role        |
| ---------------- | --------------------------- | ----------------------- |
| Terraform deploy | Infrastructure provisioning | Terraform role          |
| Packer build     | AMI creation                | Packer role             |
| Hugo deploy      | Static site deployment      | Deployment role         |
| API build        | Container image publishing  | Build/deployment role   |
| WordPress build  | Container image publishing  | Build/deployment role   |
| Roll services    | SSM operations              | Operations/Packer role  |
| Backup workflow  | Backup operations           | Backup role             |
| Legacy workflows | Unknown                     | Review before migration |

The recommended migration sequence is:

```text
1. Identify active workflows
        │
        ▼
2. Identify static AWS credentials
        │
        ▼
3. Identify each workflow's AWS actions
        │
        ▼
4. Define IAM role boundaries
        │
        ▼
5. Create OIDC trust relationships
        │
        ▼
6. Apply IAM role using existing bootstrap credentials
        │
        ▼
7. Confirm role exists
        │
        ▼
8. Update workflow to use OIDC
        │
        ▼
9. Verify AWS identity
        │
        ▼
10. Run workflow
        │
        ▼
11. Review CloudTrail / IAM failures
        │
        ▼
12. Remove obsolete static credentials
```

The sequencing matters.

If the workflow is updated before the IAM role exists, the workflow cannot authenticate.

The bootstrap process is therefore:

```text
Existing AWS Credentials
        │
        │ One-time bootstrap
        ▼
Create OIDC Provider / IAM Role
        │
        ▼
Verify Role
        │
        ▼
Migrate GitHub Workflow
        │
        ▼
OIDC Authentication
        │
        ▼
Temporary Credentials
        │
        ▼
Remove Static Credentials
```

The objective is to make the static credential path unnecessary, not to maintain both paths indefinitely.

---

# Debugging OIDC

OIDC troubleshooting should be separated into two categories:

```text
Authentication / Trust
        │
        └── Can GitHub assume the role?

Authorization
        │
        └── Can the assumed role perform the AWS action?
```

---

## Step 1: Verify the AWS Identity

The simplest diagnostic step is:

```yaml
- name: Who am I?
  run: aws sts get-caller-identity
```

A successful response confirms that the workflow obtained AWS credentials and successfully authenticated.

If this fails, investigate the OIDC trust relationship.

---

## Step 2: Check `id-token` Permission

Confirm the workflow contains:

```yaml
permissions:
  id-token: write
  contents: read
```

Without:

```yaml
id-token: write
```

the workflow cannot request the OIDC token.

---

## Step 3: Check the IAM OIDC Provider

Verify:

```text
Issuer:
https://token.actions.githubusercontent.com
```

Verify that AWS IAM has an OIDC provider configured for GitHub.

---

## Step 4: Check the Audience

For AWS, the trust policy commonly expects:

```text
sts.amazonaws.com
```

A mismatch between the token's audience and the trust policy can cause role assumption failures.

---

## Step 5: Check the Subject

The `sub` claim must match the IAM trust policy.

For example:

```text
repo:Onwuachi/platform-foundation:ref:refs/heads/main
```

If the workflow runs from another branch:

```text
refs/heads/develop
```

the trust relationship above will not match.

Similarly, GitHub environment-based workflows may use a different subject structure.

Do not guess the subject format when implementing a restrictive production trust policy.

Verify the actual token claims generated by the workflow.

---

## Step 6: Check the IAM Role ARN

Confirm the workflow is assuming the intended role:

```yaml
with:
  role-to-assume: arn:aws:iam::<account-id>:role/github-terraform-role
```

A typo or incorrect account ID can cause authentication failures.

---

## Step 7: Check IAM Permissions

If:

```bash
aws sts get-caller-identity
```

succeeds but Terraform or another AWS command fails with:

```text
AccessDenied
```

the OIDC authentication succeeded.

The problem is now likely the IAM permissions policy.

Review:

* Requested AWS API action
* IAM policy action
* Resource ARN
* Resource-level restrictions
* Explicit denies
* Service control policies
* Permission boundaries

CloudTrail can help identify the exact denied API operation.

---

# Common Failure Modes

## `AccessDenied` During Role Assumption

Likely causes:

* Incorrect `sub`
* Incorrect `aud`
* Wrong OIDC provider
* Workflow running from an unexpected branch
* GitHub environment changing the subject
* Missing `id-token: write`
* Incorrect IAM role ARN

---

## Role Assumption Works but AWS API Calls Fail

This usually means:

```text
OIDC authentication succeeded
        │
        ▼
IAM authorization failed
```

The IAM permissions policy needs to be reviewed.

---

## Workflow Works on `main` but Not a Feature Branch

A trust policy restricted to:

```text
repo:Onwuachi/platform-foundation:ref:refs/heads/main
```

will intentionally reject workflows running on other branches.

This is o desirable for production deployments.

A common pattern is:

```text
Feature branches
    │
    └── No production AWS access

main
    │
    └── Production deployment role

GitHub Environment: prod
    │
    └── Additional protection / approval
```

---

## Static Credentials Still Exist

A successful OIDC migration does not automatically remove old secrets.

After verifying the workflow:

1. Confirm OIDC authentication works.
2. Confirm the workflow performs successfully.
3. Confirrkflow no longer references static AWS credentials.
4. Remove obsolete repository or organization secrets.
5. Audit remaining workflows.

The goal is to eliminate unused credentials rather than simply adding OIDC alongside them.

---

# Best Practices

* Use OIDC instead of long-lived AWS access keys for GitHub Actions whenever practical.
* Grant `id-token: write` only to workflows that require OIDC.
* Restrict IAM trust policies using appropriate claims.
* Restrict production roles to trusted branches, tags, and/or GitHub environments.
* Use dedicated IAM roles when workflows have substantially different blast radii.
* Separate authentication from authorization.
* Give each role only the permissions required for its job.
* Prefer resource-level restrictions when practical.
* Use protected GitHub environments for sensitive deployments.
* Review CloudTrail when diagnosing unexpected AWS API failures.
* Verify `aws sts get-caller-identity` before troubleshooting downstream AWS operations.
* Never print secrets to CI/CD logs.
* Remove static credentials after successful migration.
* Audit workflows regularly for stale or unused AWS credentials.
* Treat broad IAM permissions as an explicit technical tradeoff and document them.
* Avoid creating a single "god role" for every GitHub Actions workflow.

---

# Engineering Analogy

Think of GitHub OIDC as the **identity badge** and IAM as the **access-control system**.

Imagine an employee entering a secure building.

```text
GitHub OIDC Token
        │
        ▼
Idey Badge
        │
        ▼
AWS IAM Trust Policy
        │
        │ "Is this a valid person
        │  from a trusted organization?"
        ▼
Temporary Credentials
        │
        ▼
IAM Permissions
        │
        │ "Which rooms can they enter?"
        ▼
AWS Resources
```

The trust policy answers:

> "Do I trust this identity?"

The permissions policy answers:

> "What is this identity allowed to do?"

Having a valid badge does not mean the employee can enter every room.

Similsuccessfully assuming an AWS IAM role does not mean the workflow can perform every AWS operation.

---

# Pro Tip

> When debugging GitHub OIDC, always separate **role assumption** from **AWS permissions**.

Start with:

```bash
aws sts get-caller-identity
```

If that fails, troubleshoot:

```text
GitHub OIDC
IAM OIDC Provider
Trust Policy
Claims
```

If that succeeds, troubleshoot:

```text
IAM Permissions
Resource ARNs
Explicit Denies
SCPs
Permission Boundaries
```

This simple separation prevents a lot of wasted time.

Another important operational lesson is to **create the IAM role before migrating the workflow**.

For a bootstrap migration:

```text
1. Use existing authentication
2. Create OIDC provider / IAM role
3. Verify role
4. Update GitHub workflow
5. Test workflow
6. Remove static credentials
```

Do not reverse steps 2 and 4.

---

# Key Takeaways

* **OAuth 2.0** is primarily an authorization framework.
* **OIDC** adds an identity layer on top of OAuth 2.0.
* OIDC allows systems to establish identity without directly sharing passwords.
* GitHub Actions can use OIDC to authenticate to AWS without storing long-lived AWS access keys.
* AWS uses `sts:AssumeRoleWithWebIdentity` to exchange the GitHub identity assertion for temporary credentials.
* The AWS IAM OIDC provider establishes trust in GitHub's OIDC issuer.
* The IAM role trust policy determines **who can assume the role**.
* The IAM permissions policy determines **what the role can do**.
* `aud` and `sub` are particularly important claims when restricting GitHub-to-AWS trust.
* GitHub environments can provide an additional security boundary for sensitive deployments.
* Terraform, Packer, application deployment, and operational workflows may warrant separate IAM roles.
* OIDC migration should be performed by workflow classification rather than blindly assigning one role to everything.
* A successful OIDC role assumption does not guarantee that the workflow has permission to perform a specific AWS API operation.
* The long-term goal is to eliminate unnecessary static credentials, not maintain both authentication models indefinitely.

The fundamental architecture is:

```text
GitHub Workflow
      │
      │ Identity
      ▼
OIDC Token
      │
      │ Trust
      ▼
AWS IAM Role
      │
      │ Authorization
      ▼
IAM Permissions
      │
      │ Temporary Credentials
      ▼
AWS Services
```

> **OIDC establishes who you are. IAM determines what you can do.**

---

# Related Articles

* AWS IAM
* AWS STS
* GitHub Actions
* Giions Workflows
* Terraform
* Packer
* AWS ECR
* AWS S3
* AWS CloudFront
* AWS Systems Manager (SSM)
* CI/CD Security
* Secrets Management
* Workload Identity Federation

---

# References

* OpenID Connect Core 1.0
* OAuth 2.0 Authorization Framework
* GitHub Actions OIDC documentation
* AWS IAM OpenID Connect identity providers
* AWS Security Token Service `AssumeRoleWithWebIdentity`
* AWS IAM roles and trust policies
* AWS IAM policy reference
* GitHub Actions security hardening documentation

