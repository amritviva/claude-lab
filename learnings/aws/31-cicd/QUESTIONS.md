# CI/CD — Exam Practice Questions

---

## Q1: buildspec.yml Phases

A developer's CodeBuild project fails during the build phase. They notice that `npm install` runs in the `build` phase. The logs show the build container doesn't have Node.js installed. What should the developer fix?

**A)** Move `npm install` to the `post_build` phase
**B)** Add a `runtime-versions` section in the `install` phase to specify Node.js
**C)** Use a custom Docker image with Node.js pre-installed
**D)** Both B and C would work

### Answer: D

**Why:** The `install` phase is where you specify runtime versions. Adding `runtime-versions: { nodejs: 18 }` in the install phase tells CodeBuild to set up Node.js before the build runs. Alternatively, using a custom Docker image with Node.js pre-installed also works. Both are valid approaches — runtime-versions for managed images, custom images for full control.

- **A is wrong:** `post_build` runs AFTER the build phase. Moving `npm install` there is too late — the build phase already failed.
- **B is correct:** The standard approach using AWS managed build images.
- **C is correct:** The alternative approach using custom images when you need specific tools/versions.

---

## Q2: Deployment Strategy Selection

A company deploys a critical e-commerce application on EC2 instances behind an ALB. They need zero-downtime deployments with the ability to instantly rollback if the new version has issues. Which deployment strategy should they use?

**A)** All-at-once
**B)** Rolling
**C)** Blue/Green
**D)** In-place with manual rollback

### Answer: C

**Why:** Blue/Green creates an entirely new set of instances (Green), deploys the new version, tests it, then switches ALB traffic from Blue to Green. Rollback = instantly switch traffic back to Blue (old instances are still running). Zero downtime because traffic switches atomically at the load balancer level.

- **A is wrong:** All-at-once causes downtime during deployment and has no instant rollback — you'd need to redeploy the old version.
- **B is wrong:** Rolling deploys in batches, so some instances run old code and some run new code simultaneously. Rollback requires redeploying the previous version across all instances — not instant.
- **D is wrong:** In-place deployment modifies existing instances. Manual rollback means redeploying the old version — slow and risky for a critical e-commerce app.

---

## Q3: Lambda Canary Deployment

A developer wants to deploy a new Lambda version with minimal risk. They want to send 10% of traffic to the new version for 10 minutes, and if CloudWatch alarms don't trigger, shift all traffic. Which deployment configuration should they use?

**A)** `AllAtOnce`
**B)** `Canary10Percent10Minutes`
**C)** `Linear10PercentEvery10Minutes`
**D)** `Canary10Percent5Minutes`

### Answer: B

**Why:** Canary shifts a fixed percentage to the new version for a specified time, then shifts all remaining traffic at once. `Canary10Percent10Minutes` sends 10% for 10 minutes, then 100%. If alarms fire during the 10-minute window, it automatically rolls back to the previous version.

- **A is wrong:** AllAtOnce shifts 100% immediately — no validation window.
- **C is wrong:** Linear10PercentEvery10Minutes adds 10% every 10 minutes incrementally (10%, 20%, 30%... 100%). Takes 100 minutes total. The requirement is a single validation window, not gradual increase.
- **D is wrong:** Canary10Percent5Minutes only waits 5 minutes, but the requirement specifies 10 minutes of validation.

---

## Q4: appspec.yml for EC2

A developer's CodeDeploy deployment to EC2 instances fails at the `AfterInstall` hook. The hook script is supposed to start the application. What is the MOST LIKELY issue?

**A)** The CodeDeploy agent is not installed on the EC2 instances
**B)** The hook script doesn't have execute permissions or has a syntax error
**C)** The appspec.yml is not in YAML format
**D)** The deployment group is configured for Lambda, not EC2

### Answer: B

**Why:** If the deployment reaches `AfterInstall`, the agent is working and the appspec.yml parsed correctly. The hook SCRIPT itself is the problem — it either lacks execute permissions (`chmod +x`), has a bash syntax error, or fails to start the application. Check the CodeDeploy agent logs on the instance for the specific error.

- **A is wrong:** If the agent weren't installed, the deployment would fail before reaching any hook — it wouldn't get to AfterInstall.
- **C is wrong:** If appspec.yml had a format error, the deployment would fail at parsing, not at a specific hook.
- **D is wrong:** If configured for Lambda, the deployment wouldn't attempt EC2 hooks at all.

---

## Q5: Pipeline Manual Approval

A company requires a manager to approve deployments to production. The development pipeline should automatically deploy to staging, then wait for approval before deploying to production. How should this be configured in CodePipeline?

**A)** Add a manual approval action between the staging deploy stage and the production deploy stage, with SNS notification
**B)** Create two separate pipelines — one for staging, one for production
**C)** Use a Lambda function to check a database flag before deploying to production
**D)** Configure CodeDeploy to require approval before each deployment

### Answer: A

**Why:** CodePipeline has a built-in **Manual Approval** action type. Add it as a stage between staging and production deployments. Configure an SNS topic to notify the approver. The pipeline pauses until the approver clicks Approve or Reject in the console (up to 7 days). This is the native, supported pattern.

- **B is wrong:** Two separate pipelines break the automated flow. You'd need to manually trigger the production pipeline after staging succeeds.
- **C is wrong:** Custom Lambda approval works but is unnecessary complexity when CodePipeline has built-in approval actions.
- **D is wrong:** CodeDeploy doesn't have a built-in approval mechanism. Approval is a CodePipeline feature.

---

## Q6: CodeBuild Environment Variables

A developer needs to pass a database password to a CodeBuild project without exposing it in the buildspec.yml or build logs. What is the BEST approach?

**A)** Hardcode the password in the buildspec.yml `env` section
**B)** Store the password in Secrets Manager and reference it in the CodeBuild environment variables with type `SECRETS_MANAGER`
**C)** Pass the password as a plaintext environment variable in the CodeBuild project
**D)** Store the password in a file in the S3 source bucket

### Answer: B

**Why:** CodeBuild supports environment variables from Secrets Manager (type `SECRETS_MANAGER`) and Parameter Store (type `PARAMETER_STORE`). The secret is resolved at build time and available as an environment variable. It's never stored in the buildspec.yml, never visible in the project configuration, and CodeBuild automatically masks it in build logs.

- **A is wrong:** Hardcoding passwords in buildspec.yml is a security anti-pattern. Anyone with access to the source repo can see it.
- **C is wrong:** Plaintext environment variables are visible in the CodeBuild project configuration in the console and API.
- **D is wrong:** Files in S3 could be accessed by anyone with bucket permissions. Not a secure secret storage mechanism.

---

## Q7: CodeDeploy Rollback

A CodeDeploy deployment to EC2 instances succeeds, but 5 minutes later, a CloudWatch alarm fires indicating high error rates from the new version. The deployment is configured with automatic rollback on alarm. What happens?

**A)** CodeDeploy automatically deploys the PREVIOUS version to all instances
**B)** CodeDeploy stops the current deployment and leaves instances in mixed state
**C)** CodeDeploy notifies the team but takes no action
**D)** CloudWatch fixes the issue by scaling up more instances

### Answer: A

**Why:** When automatic rollback on alarm is configured, CodeDeploy monitors the specified CloudWatch alarms after deployment. If an alarm triggers within the monitoring window, CodeDeploy automatically creates a NEW deployment using the last known good revision and deploys it to all instances. The rollback is itself a deployment — you can see it in the deployment history.

- **B is wrong:** CodeDeploy doesn't stop mid-deployment for alarm-based rollback. It deploys the complete previous version as a new deployment.
- **C is wrong:** With automatic rollback configured, CodeDeploy takes action — it doesn't just notify.
- **D is wrong:** CloudWatch is a monitoring service. It doesn't scale instances or fix deployments.

---

## Q8: Cross-Account Pipeline

A company has separate AWS accounts for Dev, Staging, and Production. They want a single CodePipeline in the Dev account to deploy to all three accounts. What is required?

**A)** CodePipeline cannot work across accounts
**B)** Cross-account IAM roles in Staging and Prod accounts, with the pipeline assuming those roles for deployment actions
**C)** Copy the pipeline to each account
**D)** Use VPC peering between all three accounts

### Answer: B

**Why:** CodePipeline supports cross-account deployments. You create IAM roles in the target accounts (Staging, Prod) that trust the Dev account's pipeline role. The pipeline assumes these cross-account roles when executing deployment actions. Artifacts are shared via S3 with cross-account bucket policies and KMS key sharing.

- **A is wrong:** CodePipeline explicitly supports cross-account actions. It's a common enterprise pattern.
- **C is wrong:** Copying pipelines to each account defeats the purpose of a single automated pipeline. It creates drift and maintenance overhead.
- **D is wrong:** VPC peering is for network connectivity between VPCs. CodePipeline uses IAM roles and S3 for cross-account operations, not VPC networking.

---

## Q9: CodeArtifact

A development team spends significant time downloading npm packages from the public registry. Some builds fail because packages are temporarily unavailable on npmjs.com. How can CodeArtifact help?

**A)** CodeArtifact replaces npm entirely
**B)** CodeArtifact caches public packages locally; builds use the cache even if npmjs.com is unavailable
**C)** CodeArtifact compresses npm packages for faster downloads
**D)** CodeArtifact pre-installs all npm packages on CodeBuild instances

### Answer: B

**Why:** CodeArtifact acts as a proxy/cache. Configure it with an upstream connection to npmjs.com. First request fetches from npmjs.com and caches locally. Subsequent requests serve from cache. If npmjs.com goes down, builds still succeed from the cache. This provides reliability and reduces external dependency.

- **A is wrong:** CodeArtifact doesn't replace npm — it's a registry that npm CLI points to. You still use `npm install`, just with a different registry URL.
- **C is wrong:** CodeArtifact stores packages as-is. It doesn't compress them. The benefit is caching and availability, not compression.
- **D is wrong:** CodeArtifact is a registry service, not a CodeBuild feature. Packages are installed during the build from the registry.

---

## Q10: ECS Blue/Green Deployment

A team deploys their ECS Fargate service using CodeDeploy Blue/Green deployment. During the deployment, they want to test the new version on the replacement (Green) task set before shifting production traffic. What should they configure?

**A)** Manual approval in CodePipeline before the deploy stage
**B)** A test listener on the ALB that routes to the Green target group, with a termination wait time
**C)** Run integration tests in a CodeBuild stage before deployment
**D)** Set the deployment to AllAtOnce for immediate traffic shift

### Answer: B

**Why:** ECS Blue/Green deployments support a **test listener** (separate port) on the ALB that routes to the Green (replacement) target group. During deployment, you can send test traffic to the test listener to validate the new version. The `terminationWaitTimeInMinutes` keeps the Blue (original) task set alive for a configurable period, allowing manual verification before traffic shifts AND providing a rollback window.

- **A is wrong:** Manual approval in CodePipeline is before the deployment starts, not during the deployment's test phase. You can't test the Green environment before it's deployed.
- **C is wrong:** CodeBuild tests run BEFORE deployment against the current version or build artifacts, not against the live Green task set.
- **D is wrong:** AllAtOnce shifts all traffic immediately with no testing window. The opposite of what's needed.
