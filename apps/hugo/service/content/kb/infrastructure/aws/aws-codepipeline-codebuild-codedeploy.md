+++
title = 'Aws Codepipeline Codebuild Codedeploy'
date = 2026-07-28T17:35:24-05:00
draft = false
type = "kb-article"
description = "Understand how AWS CodePipeline, CodeBuild, and CodeDeploy work together to automate application delivery from source control through build, artifact management, and deployment."
summary = "AWS CodePipeline provides CI/CD orchestration, CodeBuild compiles and packages application code, and CodeDeploy automates application deployments to supported compute environments. Together, they form a flexible AWS-native CI/CD workflow."
tags = ["aws", "codepipeline", "codebuild", "codedeploy", "cicd", "devops", "continuous-integration", "continuous-delivery", "deployment"]
categories = ["infrastructure", "aws"]
weight = 0
+++

# Overview

AWS CodePipeline, CodeBuild, and CodeDeploy are three AWS services that can be combined to create an automated continuous integration and continuous delivery (CI/CD) workflow.

Each service has a distinct responsibility:

```text
CodePipeline
    |
    | Orchestrates the workflow
    v
CodeBuild
    |
    | Builds, tests, and packages the application
    v
Artifact
    |
    | Passed between pipeline stages
    v
CodeDeploy
    |
    | Deploys the application
    v
Target Environment
```

The simplest way to remember the three services is:

> **CodePipeline orchestrates. CodeBuild builds. CodeDeploy deploys.**

CodePipeline does not replace CodeBuild or CodeDeploy. It coordinates actions between them.

CodeBuild does not decide when a production deployment should occur. It performs the build and test work assigned to it.

CodeDeploy does not compile application source code. It takes an application revision and performs the deployment according to the configured deployment strategy.

Together, the services can provide a complete AWS-native CI/CD workflow.

<!--more-->

# Why It Matters

Manual application deployments create operational risk.

A typical manual process might look like:

```text
Developer
    |
    v
Git Repository
    |
    v
Engineer manually pulls code
    |
    v
Engineer builds application
    |
    v
Engineer creates package
    |
    v
Engineer copies package to servers
    |
    v
Engineer restarts services
    |
    v
Engineer verifies deployment
```

Every manual step creates opportunities for:

- Human error
- Inconsistent deployment procedures
- Configuration drift
- Forgotten deployment steps
- Incomplete testing
- Difficult rollback procedures
- Poor deployment auditability

A CI/CD pipeline automates these steps into a repeatable workflow:

```text
Developer Commit
      |
      v
Source Control
      |
      v
CodePipeline
      |
      v
Build and Test
      |
      v
Package Artifact
      |
      v
Deployment
      |
      v
Application Environment
```

The result is a more consistent and observable software delivery process.

A well-designed pipeline should make the path from source code to deployed application predictable, repeatable, and auditable.

---

# Where It Fits

The three services fit into different stages of the software delivery lifecycle.

```text
                    CI/CD PIPELINE
                         |
                         v
+------------------------------------------------------+
|                                                      |
|  Source        Build         Artifact       Deploy   |
|                                                      |
|    |             |              |             |     |
|    v             v              v             v     |
|                                                      |
| CodePipeline -> CodeBuild -> S3/ECR -> CodeDeploy   |
|                                                      |
+------------------------------------------------------+
```

A more complete workflow might look like:

```text
Developer
    |
    | git push
    v
Source Repository
    |
    | Source change detected
    v
CodePipeline
    |
    | Source Stage
    v
Source Artifact
    |
    | Build Stage
    v
CodeBuild
    |
    +--> Install dependencies
    |
    +--> Run tests
    |
    +--> Build application
    |
    +--> Build Docker image (if applicable)
    |
    +--> Package application
    |
    v
Build Artifact
    |
    | Deploy Stage
    v
CodeDeploy
    |
    +--> In-Place Deployment
    |
    |          OR
    |
    +--> Blue/Green Deployment
    |
    v
Application Environment
```

CodePipeline acts as the workflow engine connecting these stages.

The pipeline may also include manual approval actions, security scanning, integration tests, or additional deployment stages.

---

# The Big Picture

The three services should be thought of as separate layers.

```text
+------------------------------------------------------+
|                    CodePipeline                      |
|                                                      |
|   Orchestration / Workflow / Stage Management        |
+------------------------------------------------------+
                       |
                       v
+------------------------------------------------------+
|                     CodeBuild                        |
|                                                      |
|   Compile / Test / Package / Container Build         |
+------------------------------------------------------+
                       |
                       v
+------------------------------------------------------+
|                     Artifact                         |
|                                                      |
|       Immutable version of deployable output         |
+------------------------------------------------------+
                       |
                       v
+------------------------------------------------------+
|                    CodeDeploy                        |
|                                                      |
|       Deployment Strategy / Lifecycle / Hooks        |
+------------------------------------------------------+
                       |
                       v
+------------------------------------------------------+
|                 Application Environment              |
|                                                      |
|       EC2 / Auto Scaling Group / Supported Target    |
+------------------------------------------------------+
```

The most important architectural concept is the **artifact**.

The build process should produce a versioned, identifiable output that can be passed to later stages.

Conceptually:

```text
Source Code
    |
    v
Build
    |
    v
Artifact
    |
    v
Test
    |
    v
Deploy
```

The deployment stage should deploy the artifact produced by the pipeline rather than rebuilding the application independently.

This helps ensure that the application tested during the pipeline is the same application that gets deployed.

---

# Core Concepts

## CodePipeline

AWS CodePipeline is the orchestration layer.

It defines the sequence of actions that move an application through the CI/CD workflow.

A pipeline is organized into **stages**.

A simplified pipeline might contain:

```text
Source
  |
  v
Build
  |
  v
Deploy to Staging
  |
  v
Manual Approval
  |
  v
Deploy to Production
```

Each stage can contain one or more actions.

For example:

```text
Stage: Source

Action:
  Source Provider
```

```text
Stage: Build

Action:
  CodeBuild
```

```text
Stage: Deploy

Action:
  CodeDeploy
```

The pipeline controls the workflow, while the individual services perform the actual work.

### Pipeline Stages

A common pipeline structure is:

```text
Source
   |
   v
Build
   |
   v
Test
   |
   v
Staging
   |
   v
Approval
   |
   v
Production
```

Not every pipeline needs all of these stages.

The important concept is that each stage represents a logical part of the delivery workflow.

### Actions

Stages contain actions.

For example:

```text
Stage: Build
    |
    +--> CodeBuild Action
```

Or:

```text
Stage: Production
    |
    +--> Manual Approval
    |
    +--> CodeDeploy Action
```

Multiple actions can also exist within a stage.

This allows pipelines to perform parallel or sequential operations depending on the design.

---

## CodePipeline Artifacts

Artifacts are outputs passed between pipeline actions.

A simplified example:

```text
Source Repository
      |
      v
Source Artifact
      |
      v
CodeBuild
      |
      v
Build Artifact
      |
      v
CodeDeploy
```

Artifacts may be stored in Amazon S3 or represented through other supported integration mechanisms depending on the action and workflow.

The key concept is:

> **Artifacts are the handoff point between pipeline stages.**

For a traditional application deployment, the artifact might contain:

```text
application/
├── appspec.yml
├── scripts/
│   ├── install.sh
│   ├── start.sh
│   └── stop.sh
├── config/
└── application binaries
```

For containerized workloads, the artifact may instead contain deployment metadata while the actual container image is stored in Amazon ECR.

For example:

```text
Source
   |
   v
CodeBuild
   |
   +--> Build Docker Image
   |
   +--> Push Image to ECR
   |
   v
Deployment Artifact
   |
   v
Deployment Service
```

The exact artifact structure depends on the application architecture and deployment target.

---

## CodeBuild

AWS CodeBuild is the managed build service.

It provides a build environment where source code can be compiled, tested, packaged, and prepared for deployment.

A CodeBuild project generally defines:

- Source location
- Build environment
- Compute configuration
- Operating system image
- Runtime versions
- Environment variables
- IAM service role
- Build commands
- Artifact configuration
- Cache configuration
- Optional VPC configuration

CodeBuild executes instructions defined by the build configuration.

The most common configuration file is:

```text
buildspec.yml
```

---

## buildspec.yml

The `buildspec.yml` file defines the commands CodeBuild should execute.

A simplified example:

```yaml
version: 0.2

phases:
  install:
    runtime-versions:
      nodejs: 20

  pre_build:
    commands:
      - npm ci

  build:
    commands:
      - npm test
      - npm run build

  post_build:
    commands:
      - echo "Build completed"

artifacts:
  files:
    - '**/*'
```

The build phases commonly include:

```text
install
    |
    v
pre_build
    |
    v
build
    |
    v
post_build
```

The exact phases and commands depend on the application.

### Install

Used to prepare dependencies and runtime requirements.

Example:

```bash
npm ci
```

### Pre-build

Used for preparation before the primary build.

Examples:

```bash
npm test
docker login
```

### Build

Used to compile, package, or build the application.

Examples:

```bash
npm run build
mvn package
docker build
```

### Post-build

Used for finalization.

Examples:

```bash
docker push
echo "Build complete"
```

The `buildspec.yml` file should be treated as code and stored with the application source.

---

## CodeBuild Environment Variables

CodeBuild supports environment variables that can be used by build commands.

Examples include:

```text
AWS_REGION
CODEBUILD_BUILD_ID
CODEBUILD_RESOLVED_SOURCE_VERSION
CODEBUILD_SRC_DIR
```

Custom environment variables can also be defined for the build.

Avoid placing sensitive credentials directly into `buildspec.yml`.

Use appropriate AWS services and mechanisms for secrets, such as:

- AWS Secrets Manager
- AWS Systems Manager Parameter Store
- IAM roles

The CodeBuild service role should receive only the permissions required for the build.

---

## CodeBuild IAM Service Role

CodeBuild executes AWS API operations using an IAM service role.

Depending on the build, the role may need permissions to:

- Read source artifacts
- Write build artifacts
- Access Amazon ECR
- Access S3
- Read secrets or parameters
- Publish logs
- Interact with other AWS services

The role should follow least-privilege principles.

For example:

```text
CodeBuild
    |
    | Assumes
    v
IAM Service Role
    |
    +--> S3
    +--> ECR
    +--> CloudWatch Logs
    +--> Secrets Manager
```

Do not give CodeBuild unrestricted administrator permissions simply because the build needs access to several services.

---

## CodeBuild Privileged Mode

Privileged mode is important when CodeBuild needs to run Docker commands that require access to the Docker daemon.

For example:

```bash
docker build -t my-application .
docker push my-application
```

A common architecture is:

```text
CodeBuild
    |
    | Privileged Mode
    v
Docker Build
    |
    v
Container Image
    |
    v
Amazon ECR
```

If a CodeBuild project needs to build Docker images using Docker-in-Docker style workflows or the CodeBuild Docker environment, privileged mode may be required.

This should be enabled only when necessary.

If the build does not require Docker daemon access, there is generally no reason to enable privileged mode.

---

## CodeBuild VPC Configuration

By default, CodeBuild builds run outside your VPC.

A build can be configured to run inside a VPC when it needs access to private resources.

For example:

```text
CodeBuild
    |
    v
VPC Subnet
    |
    +--> Private RDS
    |
    +--> Internal API
    |
    +--> Private Service
```

When configuring CodeBuild inside a VPC, consider:

- Subnet selection
- Security Groups
- Route tables
- NAT Gateway requirements
- VPC endpoints
- DNS resolution
- Internet access
- Access to S3 and other AWS services

A common mistake is placing CodeBuild into a private subnet and then discovering that dependency downloads fail because the build has no path to the internet.

A VPC-connected build may require:

```text
Private Subnet
    |
    v
NAT Gateway
    |
    v
Internet
```

or appropriate VPC endpoints for AWS services.

VPC configuration should therefore be intentional rather than enabled by default.

---

## CodeDeploy

AWS CodeDeploy automates application deployments to supported compute environments.

CodeDeploy manages the deployment process rather than performing the application build.

A simplified workflow is:

```text
Application Artifact
       |
       v
CodeDeploy
       |
       v
Deployment Group
       |
       v
Target Instances
       |
       v
Application Updated
```

CodeDeploy can coordinate deployment lifecycle events and execute scripts at specific points in the deployment process.

---

## AppSpec

CodeDeploy deployments commonly use an application specification file.

For EC2 or on-premises deployments, this is commonly:

```text
appspec.yml
```

The AppSpec file describes how the application should be deployed.

A simplified example:

```yaml
version: 0.0

os: linux

files:
  - source: /
    destination: /opt/myapp

hooks:
  ApplicationStop:
    - location: scripts/stop.sh

  BeforeInstall:
    - location: scripts/install.sh

  AfterInstall:
    - location: scripts/configure.sh

  ApplicationStart:
    - location: scripts/start.sh

  ValidateService:
    - location: scripts/health-check.sh
```

The AppSpec file defines the deployment behavior.

The deployment artifact therefore contains both the application and the instructions CodeDeploy needs to deploy it.

---

## CodeDeploy Lifecycle Hooks

Lifecycle hooks allow scripts to run at specific points during deployment.

Common hooks include:

```text
ApplicationStop
        |
        v
BeforeInstall
        |
        v
AfterInstall
        |
        v
ApplicationStart
        |
        v
ValidateService
```

The exact lifecycle events depend on the deployment type and target platform.

A useful mental model is:

```text
Old Application
      |
      v
Stop
      |
      v
Prepare Target
      |
      v
Install New Version
      |
      v
Configure
      |
      v
Start
      |
      v
Validate
```

The `ValidateService` stage is especially useful because it allows the deployment process to verify that the newly deployed application is healthy.

For example:

```bash
curl -f http://localhost:8080/health
```

If the health check fails, the deployment should be considered unsuccessful.

---

## In-Place Deployments

In an in-place deployment, the existing compute environment is updated.

Conceptually:

```text
Before

EC2 Instance
    |
    v
Application v1


Deployment

Stop / Update / Start


After

EC2 Instance
    |
    v
Application v2
```

Advantages:

- Lower infrastructure overhead
- Simpler architecture
- No need to maintain a second environment

Disadvantages:

- Potential downtime
- Existing instances are modified directly
- Rollback may be more disruptive
- Deployment failures can affect the active environment

In-place deployments can be appropriate when downtime is acceptable or the application architecture supports the deployment process.

---

## Blue/Green Deployments

Blue/green deployment creates or uses a separate environment for the new application version.

Conceptually:

```text
                    Load Balancer
                         |
                         v
                   Traffic Router
                    /           \
                   /             \
                  v               v
             Blue Environment   Green Environment
                 v1                  v2
              Current             New Version
```

The new version is deployed to the green environment.

After validation, traffic can be shifted from blue to green.

Advantages:

- Reduced deployment risk
- New version can be tested before receiving production traffic
- Faster rollback by shifting traffic back
- Old environment can remain available during deployment

Disadvantages:

- Higher infrastructure requirements
- More complex deployment architecture
- Potentially higher temporary cost
- Requires careful handling of databases and stateful systems

Blue/green deployments are particularly useful for high-availability production systems where downtime is unacceptable or deployment risk must be minimized.

---

## Deployment Configurations

CodeDeploy deployment configurations determine how much of the target environment is updated at a time.

The strategy depends on the deployment type.

Conceptually:

```text
All At Once
------------
100% of targets
       |
       v
Deploy simultaneously
```

```text
Rolling / Batch
---------------
Batch 1
   |
   v
Batch 2
   |
   v
Batch 3
```

```text
Blue/Green
----------
Environment A
     |
     | Traffic shift
     v
Environment B
```

The correct configuration depends on:

- Availability requirements
- Application architecture
- Deployment speed
- Rollback requirements
- Capacity
- Cost

The safest deployment strategy is not always the fastest one.

---

## CodePipeline + CodeBuild + CodeDeploy

A complete workflow might look like:

```text
Developer
    |
    | Push
    v
Git Repository
    |
    v
CodePipeline
    |
    +----------------------+
    |                      |
    v                      |
Source Stage               |
    |                      |
    v                      |
Source Artifact            |
    |                      |
    +----------+-----------+
               |
               v
          Build Stage
               |
               v
           CodeBuild
               |
        +------+------+
        |             |
        v             v
      Tests       Build Package
        |             |
        +------+------+
               |
               v
          Build Artifact
               |
               v
        Deploy Stage
               |
               v
          CodeDeploy
               |
       +-------+-------+
       |               |
       v               v
    In-Place        Blue/Green
       |               |
       +-------+-------+
               |
               v
       Application Environment
```

CodePipeline coordinates the process.

CodeBuild creates the deployable output.

CodeDeploy performs the deployment.

---

# Real-World Example

Consider a company running a web application on EC2 instances behind a load balancer.

The desired workflow is:

```text
Developer pushes code
        |
        v
CodePipeline starts
        |
        v
Source artifact created
        |
        v
CodeBuild starts
        |
        +--> Install dependencies
        |
        +--> Run unit tests
        |
        +--> Build application
        |
        +--> Package artifact
        |
        v
CodePipeline receives artifact
        |
        v
CodeDeploy starts
        |
        v
Deployment Group selected
        |
        v
Application deployed
        |
        v
ValidateService health check
        |
        v
Deployment succeeds
```

A production deployment might add a manual approval:

```text
Source
   |
   v
Build
   |
   v
Staging
   |
   v
Integration Tests
   |
   v
Manual Approval
   |
   v
Production
```

This creates a controlled promotion path from development through production.

The same architecture can be extended with:

- Security scanning
- Infrastructure validation
- Automated integration tests
- Manual approvals
- Change-management gates
- Notifications
- Automated rollback
- CloudWatch monitoring

---

# Engineering Analogy

Think of the three services like a software delivery team.

```text
CodePipeline
    =
Project Manager / Orchestrator

CodeBuild
    =
Builder / Factory

CodeDeploy
    =
Deployment Team
```

CodePipeline says:

> "The source changed. Start the build."

CodeBuild says:

> "The application compiled, tests passed, and here is the artifact."

CodePipeline says:

> "The artifact is ready. Move to deployment."

CodeDeploy says:

> "I will deploy this exact artifact according to the configured deployment strategy."

This separation of responsibilities is important.

A pipeline is easier to understand and troubleshoot when each service has a clear role.

Another useful analogy is a restaurant:

```text
CodePipeline
    =
Expediter coordinating the order

CodeBuild
    =
Kitchen preparing the meal

Artifact
    =
Completed meal ready for delivery

CodeDeploy
    =
Delivery process getting the meal to the customer
```

The kitchen should not decide where the order goes.

The delivery process should not cook the meal.

The coordinator connects the two.

---

# Best Practices

- Keep CodePipeline focused on orchestration rather than application build logic.
- Keep build commands in `buildspec.yml` and version them with application source code.
- Treat build artifacts as immutable deployment inputs.
- Deploy the artifact produced by the build rather than rebuilding during deployment.
- Use least-privilege IAM roles for CodePipeline, CodeBuild, and CodeDeploy.
- Store secrets in AWS Secrets Manager or Systems Manager Parameter Store rather than source code.
- Enable CodeBuild privileged mode only when Docker builds require it.
- Configure CodeBuild VPC access only when private resource access is necessary.
- Verify private-subnet builds have the required network path to dependencies and AWS services.
- Use health checks during deployments.
- Prefer blue/green deployment strategies for applications where downtime or deployment risk is unacceptable.
- Use manual approval gates for sensitive production promotion workflows when appropriate.
- Make deployment scripts idempotent where practical.
- Keep application deployment logic in version-controlled AppSpec and lifecycle hook scripts.
- Monitor pipeline execution and deployment failures.
- Use CloudWatch Logs for CodeBuild build logs and application deployment troubleshooting.
- Define clear rollback procedures before deploying to production.
- Keep development, staging, and production environments logically separated.
- Use artifact versioning and traceability so a deployed application can be mapped back to a specific source revision.
- Avoid embedding long-lived AWS access keys in build environments.
- Test the full deployment process in a non-production environment before enabling production automation.

---

# Common Mistakes

- Treating CodePipeline as the build system instead of the orchestration layer.
- Putting all build commands directly into CodePipeline instead of using CodeBuild and `buildspec.yml`.
- Forgetting that CodeBuild requires an IAM service role.
- Enabling CodeBuild privileged mode without understanding why it is required.
- Putting CodeBuild into a VPC without providing required network access.
- Assuming a private subnet automatically has internet access.
- Forgetting NAT Gateway or VPC endpoint requirements for private CodeBuild builds.
- Storing AWS credentials directly in `buildspec.yml`.
- Giving CodeBuild administrator permissions when only limited access is required.
- Rebuilding an application during deployment instead of deploying the artifact produced by the build.
- Forgetting to include `appspec.yml` in the CodeDeploy deployment artifact.
- Writing deployment hooks that are not idempotent.
- Deploying without a health check.
- Using in-place deployments when the application cannot tolerate downtime.
- Using blue/green deployments without planning for database schema compatibility.
- Assuming blue/green automatically solves all rollback problems.
- Failing to monitor deployment lifecycle hooks.
- Not testing rollback procedures before a production incident.
- Treating a successful build as proof that the application will successfully deploy.
- Treating a successful deployment as proof that the application is healthy.
- Creating a single pipeline with excessive complexity instead of separating reusable concerns.

---

# Pro Tip

> **The artifact is the contract between build and deployment.**

One of the most useful CI/CD design principles is to separate:

```text
Build Once
    |
    v
Test What You Built
    |
    v
Package the Artifact
    |
    v
Promote the Same Artifact
    |
    v
Deploy to Higher Environments
```

Avoid this pattern:

```text
Build for Dev
    |
    v
Rebuild for Staging
    |
    v
Rebuild for Production
```

Each rebuild creates an opportunity for the output to differ.

A better approach is:

```text
Source Commit
     |
     v
CodeBuild
     |
     v
Immutable Artifact
     |
     +--------> Dev
     |
     +--------> Staging
     |
     +--------> Production
```

The artifact should be traceable to:

- Source repository
- Commit SHA
- Build ID
- Pipeline execution
- Deployment execution

This creates a clear chain:

```text
Git Commit
    |
    v
Pipeline Execution
    |
    v
CodeBuild Execution
    |
    v
Artifact
    |
    v
CodeDeploy Execution
    |
    v
Production
```

When an incident occurs, this traceability makes it much easier to answer:

> "Exactly what code is running in production, and how did it get there?"

---

# Key Takeaways

- CodePipeline is the CI/CD orchestration service.
- CodeBuild is the managed build and test service.
- CodeDeploy automates application deployment.
- The simple mental model is: **Pipeline orchestrates → Build builds → Deploy deploys**.
- CodePipeline organizes workflows into stages and actions.
- Artifacts are the handoff between pipeline stages.
- `buildspec.yml` defines CodeBuild build instructions.
- CodeBuild requires an appropriate IAM service role.
- CodeBuild privileged mode may be required for Docker builds.
- CodeBuild VPC configuration enables access to private resources but introduces additional networking requirements.
- CodeDeploy uses deployment groups and deployment configurations to control deployments.
- AppSpec files define deployment instructions and lifecycle hooks.
- In-place deployments update existing compute resources.
- Blue/green deployments use separate environments and shift traffic between versions.
- Deployment lifecycle hooks provide controlled points for stopping, installing, configuring, starting, and validating applications.
- Health checks are critical for determining whether a deployment actually succeeded.
- The same artifact should ideally be promoted through environments rather than rebuilt for each environment.
- CodePipeline, CodeBuild, and CodeDeploy can be combined into a complete AWS-native CI/CD workflow.
- A successful build does not guarantee a successful deployment.
- A successful deployment does not guarantee a healthy application.
- Good CI/CD design provides repeatability, traceability, controlled promotion, and reliable rollback.

---

# Related Articles

- AWS CloudFormation Drift Detection
- AWS CloudFormation Fundamentals
- Infrastructure as Code
- AWS IAM Roles and Policies
- Amazon S3
- Amazon ECR
- AWS Systems Manager Parameter Store
- AWS Secrets Manager
- AWS CloudWatch
- AWS EventBridge
- CI/CD Pipeline Design
- Docker Image Build and Deployment
- Infrastructure Change Management

---

# References

- AWS CodePipeline User Guide
- AWS CodePipeline Concepts — Stages, Actions, and Artifacts
- AWS CodeBuild User Guide
- AWS CodeBuild Build Specification Reference
- AWS CodeBuild Environment Variables
- AWS CodeBuild VPC Configuration
- AWS CodeDeploy User Guide
- AWS CodeDeploy AppSpec File Reference
- AWS CodeDeploy Deployment Configurations
- AWS CodeDeploy In-Place Deployments
- AWS CodeDeploy Blue/Green Deployments
