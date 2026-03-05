# Architecture & Deployment Flow Explained

This document explains how everything connects: CDK, Docker images, ECR, App Runner, and your application.

## The Two "Zones": CDK vs Application

### Zone 1: CDK (Infrastructure as Code)

**Location:** `infra/` directory
**Purpose:** Creates AWS resources
**Language:** TypeScript
**What it does:**

- Creates ECR repository (empty container registry)
- Creates IAM role (permissions)
- Creates App Runner service (tells AWS where to find your app)
- Reads `prod-env.json` and passes variables to App Runner

**CDK does NOT:**

- ❌ Build your Docker image
- ❌ Push images to ECR
- ❌ Run your application code
- ❌ Know about your app's internal structure

### Zone 2: Your Application

**Location:** `app/` directory
**Purpose:** Your Express.js API application
**Language:** TypeScript (compiled to JavaScript)
**What it does:**

- Runs your API endpoints
- Connects to PostgreSQL
- Accesses DynamoDB
- Invokes Lambda functions
- Reads environment variables from `process.env`

**Your app does NOT:**

- ❌ Know about CDK
- ❌ Know about ECR
- ❌ Know about App Runner
- ❌ Create AWS resources

## How They Connect: The Complete Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: CDK Creates Infrastructure (You run: cdk deploy)       │
└─────────────────────────────────────────────────────────────────┘

1. You: Run `cdk deploy`
   ↓
2. CDK: Reads `infra/lib/infra-stack.ts`
   ↓
3. CDK: Reads `infra/config/prod-env.json` (environment variables)
   ↓
4. CDK: Creates CloudFormation template
   ↓
5. AWS CloudFormation creates:
   ├─ ECR Repository (empty - no images yet!)
   ├─ IAM Role (permissions)
   └─ App Runner Service (configured but not running - no image!)
   ↓
6. CDK outputs: ECR Repository URI
   Example: "123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod"

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: You Build & Push Docker Image (Manual Step)           │
└─────────────────────────────────────────────────────────────────┘

7. You: Build Docker image from your app code
   Command: docker build -f app/Dockerfile -t <ECR_URI>:latest .
   ↓
8. Docker: Creates image containing:
   ├─ Your compiled app code (app/dist/)
   ├─ Node.js runtime
   ├─ All dependencies (node_modules)
   └─ Dockerfile instructions
   ↓
9. You: Login to ECR
   Command: aws ecr get-login-password | docker login ...
   ↓
10. You: Push image to ECR
    Command: docker push <ECR_URI>:latest
    ↓
11. ECR: Stores your Docker image (now ECR has something!)

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 3: App Runner Runs Your Container (Automatic)              │
└─────────────────────────────────────────────────────────────────┘

12. You: Manually trigger deployment in AWS Console
    (or App Runner auto-detects new image if auto-deploy enabled)
    ↓
13. App Runner: Pulls image from ECR
    ↓
14. App Runner: Starts container
    ↓
15. App Runner: Injects environment variables (from prod-env.json)
    Sets: export PROD_DB_HOST="..."
          export API_KEY="..."
          etc.
    ↓
16. App Runner: Runs: node app/dist/server.js
    ↓
17. Your App: Starts Express server
    ↓
18. Your App: Reads process.env.PROD_DB_HOST, process.env.API_KEY, etc.
    ↓
19. Your App: Connects to PostgreSQL, DynamoDB, etc.
    ↓
20. Your App: Serves API requests on port 3000
```

## When is the Docker Image Uploaded?

**Answer: It's NOT automatic! You do it manually after CDK creates the ECR repository.**

### Step-by-Step Image Upload Process:

1. **CDK creates ECR repository** (empty, no images)

    ```bash
    cd infra
    BRANCH_NAME=prod npx cdk deploy
    # Output: EcrRepositoryUri = 123456789012.dkr.ecr.../minihubvone-prod
    ```

2. **You build Docker image** (from your app code)

    ```bash
    cd /Users/Amrit.Regmi/Desktop/minihubvone
    ECR_URI="123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod"
    docker build -f app/Dockerfile -t $ECR_URI:latest .
    ```

3. **You login to ECR** (authenticate Docker with AWS)

    ```bash
    aws ecr get-login-password --region ap-southeast-2 | \
      docker login --username AWS --password-stdin $ECR_URI
    ```

4. **You push image to ECR** (upload the image)

    ```bash
    docker push $ECR_URI:latest
    ```

5. **App Runner pulls image** (when you trigger deployment)

**Why manual?**

- CDK doesn't know about your app code
- CDK doesn't have Docker installed
- You control when to deploy new versions
- Safer for production (you review before deploying)

## Environment Variables: How They Flow

### The Connection Chain:

```
┌─────────────────────────────────────────────────────────────┐
│ 1. You edit: infra/config/prod-env.json                     │
│    {                                                         │
│      "PROD_DB_HOST": "db.example.com",                      │
│      "API_KEY": "secret123"                                 │
│    }                                                         │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. CDK reads: infra/lib/infra-stack.ts (line 149)           │
│    const config = JSON.parse(fs.readFileSync(...))         │
│    // Result: { PROD_DB_HOST: "db.example.com", ... }       │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. CDK converts: (lines 153-158)                            │
│    envVars = [                                              │
│      { name: "PROD_DB_HOST", value: "db.example.com" },    │
│      { name: "API_KEY", value: "secret123" }                │
│    ]                                                         │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. CDK passes to App Runner: (line 187)                     │
│    runtimeEnvironmentVariables: envVars                     │
│    // Tells App Runner: "Set these env vars in container"  │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. App Runner stores in its configuration                   │
│    (This is part of the App Runner service definition)      │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. When container starts, App Runner automatically:         │
│    export PROD_DB_HOST="db.example.com"                    │
│    export API_KEY="secret123"                               │
│    // These are available as process.env in your app        │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Your app reads: app/src/config.ts                        │
│    const dbHost = process.env.PROD_DB_HOST;                  │
│    // Result: "db.example.com" ✅                            │
│                                                              │
│    const apiKey = process.env.API_KEY;                       │
│    // Result: "secret123" ✅                                │
└─────────────────────────────────────────────────────────────┘
```

### Key Points:

- **CDK doesn't know about your app code** - it just passes variables
- **Your app doesn't know about CDK** - it just reads `process.env`
- **App Runner is the bridge** - it connects CDK config to your container
- **Environment variables are NOT in the Docker image** - they're injected at runtime

## Deploying to Different AWS Accounts

### Can you deploy to an account without DynamoDB/Lambda?

**Yes, but your app will fail when it tries to access them.**

### What Happens:

1. **CDK deployment succeeds:**
    - Creates ECR repository ✅
    - Creates IAM role ✅
    - Creates App Runner service ✅
    - All infrastructure resources created ✅

2. **Docker image push succeeds:**
    - Image uploaded to ECR ✅

3. **App Runner starts container:**
    - Container starts ✅
    - Your app starts ✅

4. **Your app tries to access DynamoDB:**
    - IAM role has permissions ✅
    - But DynamoDB tables don't exist ❌
    - **Error:** "ResourceNotFoundException: Table not found"

5. **Your app tries to invoke Lambda:**
    - IAM role has permissions ✅
    - But Lambda functions don't exist ❌
    - **Error:** "ResourceNotFoundException: Function not found"

### Testing in Different Account:

**Good for:**

- Testing CDK deployment process
- Verifying infrastructure is created correctly
- Testing App Runner service creation
- Verifying environment variables are injected

**Not good for:**

- Testing actual app functionality
- Testing DynamoDB/Lambda integration
- End-to-end testing

**Recommendation:**

- Use test account to verify infrastructure
- Use production account for actual deployment
- Or create mock/test DynamoDB tables and Lambda functions in test account

## Stack Destruction: How to Remove Everything

### Destroying the Stack

**Warning:** This deletes ALL resources created by CDK!

```bash
# 1. Set AWS profile (make sure it's the right account!)
export AWS_PROFILE=test-account  # or prod-account

# 2. Verify you're on the correct account
aws sts get-caller-identity

# 3. Go to infra directory
cd infra

# 4. Destroy the stack
BRANCH_NAME=prod npx cdk destroy

# 5. CDK will ask for confirmation
# Type: y
```

### What Gets Deleted:

1. **App Runner Service** - Deleted ✅
2. **IAM Role** - Deleted ✅
3. **ECR Repository** - **NOT deleted** (removal policy: RETAIN)
    - Images are preserved
    - You can manually delete if needed

### What Stays:

- **ECR Repository** - Kept (safety measure)
- **Docker images in ECR** - Kept
- **CloudWatch Logs** - Kept (for debugging)

### Manual Cleanup (if needed):

```bash
# Delete ECR repository manually
aws ecr delete-repository \
  --repository-name minihubvone-prod \
  --force \
  --region ap-southeast-2

# Delete CloudWatch log groups
aws logs delete-log-group \
  --log-group-name /aws/apprunner/minihubvone-prod-apprunner/... \
  --region ap-southeast-2
```

## Complete Deployment & Destruction Workflow

### Full Deployment (First Time):

```bash
# 1. Setup
export AWS_PROFILE=test-account
cd infra
cp config/prod-env.json.example config/prod-env.json
# Edit prod-env.json with your values

# 2. Bootstrap (first time only)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
npx cdk bootstrap aws://$ACCOUNT_ID/ap-southeast-2

# 3. Deploy infrastructure
BRANCH_NAME=prod npx cdk deploy
# Save ECR_URI from output

# 4. Build and push image
cd /Users/Amrit.Regmi/Desktop/minihubvone
ECR_URI="<from-cdk-output>"
docker build -f app/Dockerfile -t $ECR_URI:latest .
aws ecr get-login-password --region ap-southeast-2 | \
  docker login --username AWS --password-stdin $ECR_URI
docker push $ECR_URI:latest

# 5. Trigger App Runner deployment (AWS Console)
# Go to App Runner → Services → minihubvone-prod-apprunner → Deploy
```

### Full Destruction (Cleanup):

```bash
# 1. Set profile
export AWS_PROFILE=test-account

# 2. Verify account
aws sts get-caller-identity

# 3. Destroy stack
cd infra
BRANCH_NAME=prod npx cdk destroy
# Type: y to confirm

# 4. (Optional) Delete ECR repository
aws ecr delete-repository \
  --repository-name minihubvone-prod \
  --force \
  --region ap-southeast-2
```

## Summary: The Two Worlds

| Aspect                  | CDK (Infrastructure)         | Your App (Application)        |
| ----------------------- | ---------------------------- | ----------------------------- |
| **Location**            | `infra/`                     | `app/`                        |
| **Purpose**             | Creates AWS resources        | Runs your API                 |
| **Knows about**         | AWS services, IAM, ECR       | Express, PostgreSQL, DynamoDB |
| **Does NOT know about** | Your app code                | CDK, ECR, App Runner          |
| **Environment vars**    | Reads from `prod-env.json`   | Reads from `process.env`      |
| **Docker image**        | Creates ECR repo (empty)     | Gets built into image         |
| **Connection**          | Via App Runner configuration | Via environment variables     |

**The Bridge:** App Runner connects them:

- Gets image from ECR (created by CDK)
- Gets env vars from CDK config
- Runs your container
- Injects env vars into container
- Your app reads them via `process.env`
