# CI/CD — Assembly Line

> **CI/CD is a factory assembly line. CodeCommit is the blueprint vault, CodeBuild is the build workshop, CodeDeploy is the delivery crew, CodePipeline is the assembly line manager, and CodeArtifact is the parts warehouse.**

---

## ELI10

Imagine a car factory with an assembly line. The blueprint room (CodeCommit/GitHub) stores the car designs. The build workshop (CodeBuild) takes the blueprints and builds the car — welding, painting, testing. The delivery crew (CodeDeploy) drives the finished car to the dealership, either replacing the old model on the showroom floor (in-place) or setting up a whole new showroom and redirecting customers (blue/green). The assembly line manager (CodePipeline) makes sure each step happens in the right order — blueprints → build → test → deliver. If anyone makes a mistake, the line stops.

---

## The Concept

### CI/CD Pipeline Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    CODEPIPELINE (Assembly Line Manager)        │
│                                                               │
│  SOURCE         BUILD           TEST          DEPLOY          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │ GitHub   │  │CodeBuild │  │CodeBuild │  │CodeDeploy│    │
│  │ CodeCommit│─>│ Compile  │─>│ Run tests│─>│ Deploy   │    │
│  │ S3       │  │ Package  │  │ Lint     │  │ to EC2   │    │
│  │ ECR      │  │ Docker   │  │ Security │  │ Lambda   │    │
│  └──────────┘  └──────────┘  └──────────┘  │ ECS      │    │
│       │              │              │        └──────────┘    │
│       │              │              │             │           │
│       v              v              v             v           │
│     Artifacts flow between stages via S3 bucket               │
│                                                               │
│  ┌──────────────────────────────────┐                        │
│  │  Manual Approval (optional)       │                        │
│  │  "Manager, approve for prod?"     │                        │
│  │  SNS notification → human clicks  │                        │
│  └──────────────────────────────────┘                        │
└──────────────────────────────────────────────────────────────┘
```

### CodeCommit — Blueprint Vault (DEPRECATED)

```
┌──────────────────────────────────────────────┐
│  CodeCommit (AWS-hosted Git) — DEPRECATED     │
│                                                │
│  • Fully managed Git repositories              │
│  • Being deprecated — use GitHub instead       │
│  • No new customers since July 2024            │
│  • Exam may still reference it                 │
│                                                │
│  Exam tip: If CodeCommit appears, treat it     │
│  as "AWS-hosted Git repository" and focus on   │
│  the pipeline integration, not CodeCommit      │
│  specifics.                                    │
└──────────────────────────────────────────────┘
```

### CodeBuild — Build Workshop

```
┌──────────────────────────────────────────────────────────┐
│                    CODEBUILD                               │
│                                                            │
│  Fully managed build service (like Jenkins, but serverless)│
│                                                            │
│  buildspec.yml (work instructions):                        │
│  ┌──────────────────────────────────────────────┐         │
│  │ version: 0.2                                  │         │
│  │ phases:                                       │         │
│  │   install:                                    │         │
│  │     runtime-versions:                         │         │
│  │       nodejs: 18                              │         │
│  │     commands:                                 │         │
│  │       - npm install                           │         │
│  │                                               │         │
│  │   pre_build:                                  │         │
│  │     commands:                                 │         │
│  │       - npm run lint                          │         │
│  │       - echo "Logging in to ECR..."           │         │
│  │                                               │         │
│  │   build:                                      │         │
│  │     commands:                                 │         │
│  │       - npm run build                         │         │
│  │       - docker build -t my-app .              │         │
│  │                                               │         │
│  │   post_build:                                 │         │
│  │     commands:                                 │         │
│  │       - docker push $ECR_REPO:$IMAGE_TAG      │         │
│  │       - echo "Build complete"                 │         │
│  │                                               │         │
│  │ artifacts:                                    │         │
│  │   files:                                      │         │
│  │     - '**/*'                                  │         │
│  │   base-directory: dist                        │         │
│  │                                               │         │
│  │ cache:                                        │         │
│  │   paths:                                      │         │
│  │     - 'node_modules/**/*'                     │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  Key Features:                                             │
│  • Runs in managed Docker containers                       │
│  • Build phases: install → pre_build → build → post_build  │
│  • Environment variables (plaintext or from SSM/SM)        │
│  • Caching (S3 or local) for faster builds                 │
│  • VPC support (access private resources during build)     │
│  • Build badges (pass/fail status for README)              │
│  • Reports (test results, code coverage)                   │
│  • Pay per build minute                                    │
└──────────────────────────────────────────────────────────┘
```

### CodeDeploy — Delivery Crew

```
┌──────────────────────────────────────────────────────────┐
│                    CODEDEPLOY                              │
│                                                            │
│  Deploys to: EC2/On-Premises, Lambda, ECS                  │
│                                                            │
│  appspec.yml (delivery instructions):                      │
│  ┌──────────────────────────────────────────────┐         │
│  │ # For EC2/On-Premises:                        │         │
│  │ version: 0.0                                  │         │
│  │ os: linux                                     │         │
│  │ files:                                        │         │
│  │   - source: /                                 │         │
│  │     destination: /var/www/app                 │         │
│  │ hooks:                                        │         │
│  │   BeforeInstall:                              │         │
│  │     - location: scripts/stop_server.sh        │         │
│  │   AfterInstall:                               │         │
│  │     - location: scripts/start_server.sh       │         │
│  │   ValidateService:                            │         │
│  │     - location: scripts/health_check.sh       │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  EC2 Lifecycle Hooks (in order):                           │
│  ┌──────────────────────────────────────────────┐         │
│  │ 1. ApplicationStop                            │         │
│  │ 2. DownloadBundle                             │         │
│  │ 3. BeforeInstall        ← your scripts run    │         │
│  │ 4. Install                                    │         │
│  │ 5. AfterInstall         ← your scripts run    │         │
│  │ 6. ApplicationStart     ← your scripts run    │         │
│  │ 7. ValidateService      ← your scripts run    │         │
│  └──────────────────────────────────────────────┘         │
│                                                            │
│  CodeDeploy Agent: must be installed on EC2 instances      │
│  (Pre-installed on Amazon Linux AMI via SSM)               │
└──────────────────────────────────────────────────────────┘
```

### Deployment Strategies

```
┌──────────────────────────────────────────────────────────┐
│              DEPLOYMENT STRATEGIES                         │
│                                                           │
│  ALL-AT-ONCE (Kamikaze delivery)                          │
│  ├── Deploy to ALL instances simultaneously                │
│  ├── Fastest but riskiest                                  │
│  ├── Downtime if deployment fails                          │
│  └── Good for: dev/test environments                       │
│                                                           │
│  ROLLING (Gradual delivery)                                │
│  ├── Deploy to batches of instances (e.g., 25% at a time) │
│  ├── Reduced capacity during deployment                    │
│  ├── Can rollback by redeploying previous version          │
│  └── Good for: staging, non-critical prod                  │
│                                                           │
│  ROLLING WITH ADDITIONAL BATCH                             │
│  ├── Like rolling but launches NEW instances first          │
│  ├── Maintains full capacity throughout                    │
│  ├── Costs more (extra instances during deploy)            │
│  └── Good for: prod where capacity matters                 │
│                                                           │
│  BLUE/GREEN (Build a whole new showroom)                   │
│  ├── Create entire new environment (Green)                 │
│  ├── Test the new environment                              │
│  ├── Switch traffic (ALB/Route 53) to Green                │
│  ├── Keep Blue for instant rollback                        │
│  ├── Most expensive but safest                             │
│  └── Good for: critical production                         │
│                                                           │
│  CANARY (Send a scout first)                               │
│  ├── Deploy to small % first (e.g., 10%)                   │
│  ├── Monitor for errors                                    │
│  ├── If OK, deploy to remaining 90%                        │
│  ├── If not, rollback the 10%                              │
│  └── Good for: Lambda and ECS deployments                  │
│                                                           │
│  LINEAR (Steady march)                                     │
│  ├── Deploy in equal increments over time                   │
│  ├── E.g., 10% every 10 minutes                            │
│  ├── Gradual rollout with monitoring                        │
│  └── Good for: Lambda and ECS deployments                  │
└──────────────────────────────────────────────────────────┘
```

### Lambda Deployment with CodeDeploy

```
┌──────────────────────────────────────────────────────────┐
│           LAMBDA DEPLOYMENT (Traffic Shifting)             │
│                                                           │
│  Uses ALIASES to shift traffic between versions:           │
│                                                           │
│  Lambda Function                                          │
│  ├── Version 1 (current = v1)                              │
│  ├── Version 2 (new = v2)                                  │
│  └── Alias "prod" ─── points to v1 (100%)                 │
│                                                           │
│  Deployment shifts "prod" alias:                           │
│                                                           │
│  Canary10Percent5Minutes:                                  │
│  ├── 10% traffic → v2 for 5 minutes                        │
│  ├── If no alarms → 100% traffic → v2                      │
│  └── If alarms fire → rollback to v1                       │
│                                                           │
│  Linear10PercentEvery10Minutes:                            │
│  ├── 10% → v2, wait 10 min                                 │
│  ├── 20% → v2, wait 10 min                                 │
│  ├── ... until 100% → v2                                   │
│  └── If alarms fire at any step → rollback                 │
│                                                           │
│  AllAtOnce:                                                │
│  ├── 100% traffic → v2 immediately                         │
│  └── Fastest but no gradual validation                     │
│                                                           │
│  appspec.yml for Lambda:                                   │
│  version: 0.0                                              │
│  Resources:                                                │
│    - myFunction:                                           │
│        Type: AWS::Lambda::Function                         │
│        Properties:                                         │
│          Name: processOrder                                │
│          Alias: prod                                       │
│          CurrentVersion: 1                                 │
│          TargetVersion: 2                                  │
│  Hooks:                                                    │
│    BeforeAllowTraffic: validateFunction                    │
│    AfterAllowTraffic: integrationTest                      │
└──────────────────────────────────────────────────────────┘
```

### CodePipeline — Assembly Line Manager

```
┌──────────────────────────────────────────────────────────┐
│                   CODEPIPELINE                             │
│                                                            │
│  Orchestrates the entire CI/CD flow:                       │
│                                                            │
│  Stage 1: SOURCE                                           │
│  ├── GitHub, CodeCommit, S3, ECR                           │
│  ├── Triggers on: push, webhook, polling                   │
│                                                            │
│  Stage 2: BUILD                                            │
│  ├── CodeBuild, Jenkins, custom action                     │
│  ├── Output: artifacts → S3                                │
│                                                            │
│  Stage 3: TEST (optional)                                  │
│  ├── CodeBuild (run tests), third-party tools              │
│                                                            │
│  Stage 4: APPROVAL (optional)                              │
│  ├── Manual approval action                                │
│  ├── SNS notification to approver                          │
│  ├── Approver clicks approve/reject in console             │
│  ├── Pipeline pauses until approved                        │
│                                                            │
│  Stage 5: DEPLOY                                           │
│  ├── CodeDeploy, CloudFormation, ECS, S3, Elastic Beanstalk│
│  ├── Cross-region and cross-account supported              │
│                                                            │
│  Features:                                                 │
│  • Artifacts stored in S3 (encrypted with KMS)             │
│  • CloudWatch Events/EventBridge for notifications         │
│  • Cross-region actions                                    │
│  • Cross-account deployments                               │
│  • Pipeline execution history                              │
│  • Automatic retry on transient failures                   │
└──────────────────────────────────────────────────────────┘
```

### CodeArtifact — Parts Warehouse

```
┌──────────────────────────────────────────────────────────┐
│                   CODEARTIFACT                              │
│                                                            │
│  Managed artifact/package repository:                      │
│  • npm (Node.js)                                           │
│  • Maven/Gradle (Java)                                     │
│  • pip/twine (Python)                                      │
│  • NuGet (.NET)                                            │
│  • Swift                                                   │
│  • Cargo (Rust)                                            │
│                                                            │
│  Features:                                                 │
│  • Upstream connections to public repos (npmjs, PyPI)      │
│  • Caches public packages (no internet needed for builds)  │
│  • Cross-account sharing via resource policies             │
│  • Domain: organizational boundary for repositories        │
│  • IAM-based access control                                │
│                                                            │
│  Flow:                                                     │
│  Developer → CodeArtifact → if not cached →                │
│    → upstream public repo → cache in CodeArtifact          │
└──────────────────────────────────────────────────────────┘
```

---

## Exam Angle

### SAA-C03 (Solutions Architect)
- **Deployment strategies** — Blue/Green for zero downtime, Rolling for gradual, Canary for validation
- **CodePipeline orchestration** — source → build → test → approval → deploy
- **Blue/Green for EC2** — requires ALB for traffic switching
- **Cross-region/cross-account deployments** via CodePipeline

### DVA-C02 (Developer)
- **buildspec.yml** — phases (install, pre_build, build, post_build), artifacts, cache
- **appspec.yml** — files section, hooks (BeforeInstall, AfterInstall, ValidateService)
- **Lambda deployment** — Canary, Linear, AllAtOnce with aliases and versions
- **Environment variables** — plaintext, Parameter Store, Secrets Manager in CodeBuild
- **CodeArtifact** — upstream repositories, caching, cross-account

### SOA-C02 (SysOps)
- **Rollback configuration** — automatic rollback on alarm, manual rollback
- **CodeDeploy agent** — must be installed and running on EC2 instances
- **Pipeline troubleshooting** — failed actions, insufficient permissions, artifact issues
- **Manual approval** — SNS notifications, approval/rejection flow
- **Monitoring** — CodeBuild CloudWatch metrics, CodeDeploy deployment events

---

## Key Numbers

| Fact | Value |
|------|-------|
| CodeBuild timeout max | 8 hours (480 minutes) |
| CodeBuild concurrent builds | 20 (default, can increase) |
| CodePipeline max stages | 50 |
| CodePipeline max actions per stage | 50 |
| CodePipeline artifact size max | 5 GB |
| CodeDeploy EC2 lifecycle hooks | 7 (in order) |
| Lambda Canary example | 10% for 5 minutes, then 100% |
| Lambda Linear example | 10% every 10 minutes |
| CodeArtifact asset max size | 5 GB |
| Manual approval timeout | Up to 7 days |

---

## Cheat Sheet

- **CodePipeline** = orchestrator. Source → Build → Test → Approve → Deploy.
- **CodeBuild** = serverless build service. Defined by `buildspec.yml`. Phases: install, pre_build, build, post_build.
- **CodeDeploy** = deployment service. Defined by `appspec.yml`. Deploys to EC2, Lambda, ECS.
- **CodeArtifact** = package repository (npm, pip, Maven). Caches public packages.
- **Artifacts** flow between pipeline stages via S3 (encrypted with KMS).
- **Manual approval** = pipeline pauses, SNS notifies approver, max 7-day wait.
- **Blue/Green (EC2)** = new ASG created, traffic shifted via ALB. Instant rollback = switch back.
- **Blue/Green (Lambda)** = alias traffic shifting between versions. Canary/Linear/AllAtOnce.
- **Canary** = deploy to small % first, validate, then deploy to rest. Best for Lambda/ECS.
- **Rolling** = deploy in batches. Reduced capacity during deployment.
- **buildspec.yml** must be in the root of the source code (or specified in CodeBuild project).
- **appspec.yml** must be in the root of the deployment bundle.
- **CodeDeploy agent** required on EC2 instances. Pre-installed on Amazon Linux via SSM.
- **Rollback** = automatic on CloudWatch alarm trigger or deployment failure.
- **CodeCommit is deprecated** — use GitHub. Exam may still reference it.
