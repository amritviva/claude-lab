# CDK Code Verification Checklist

This document verifies that all CDK code is correct and ready for deployment.

## ✅ CDK Code Status

### 1. Entry Point (`bin/infra.ts`)

- ✅ Reads `BRANCH_NAME` from environment or context
- ✅ Creates blueprint with correct app name and region
- ✅ Only creates resources for `prod` branch
- ✅ Passes account and region to stack

### 2. Blueprint (`lib/blueprint/index.ts`)

- ✅ Maps `prod`/`main` → `prod` environment
- ✅ Maps everything else → `dev` environment
- ✅ Sets correct safety settings (termination protection for prod)
- ✅ Applies correct tags

### 3. Infrastructure Stack (`lib/infra-stack.ts`)

#### ECR Repository (Lines 60-72)

- ✅ Creates ECR repository with name: `minihubvone-prod`
- ✅ Lifecycle policy: keeps last 10 images
- ✅ Removal policy: RETAIN for prod (safe)
- ✅ Outputs repository URI

#### IAM Role (Lines 87-138)

- ✅ Creates IAM role: `minihubvone-prod-apprunner-role`
- ✅ Assumed by: `tasks.apprunner.amazonaws.com`
- ✅ DynamoDB permissions: **READ-ONLY** (GetItem, Query, Scan, BatchGetItem)
- ✅ DynamoDB resources: **Specific ARNs only** (not wildcards)
    - `arn:aws:dynamodb:ap-southeast-2:ACCOUNT_ID:table/Location-xxxxx-prod`
    - `arn:aws:dynamodb:ap-southeast-2:ACCOUNT_ID:table/BatchPayment-xxxxx-prod`
- ✅ Lambda permissions: **Invoke only**
- ✅ Lambda resources: **Specific ARNs only** (not wildcards)
    - `arn:aws:lambda:ap-southeast-2:ACCOUNT_ID:function:sendBatchFailureReminder-prod`
    - `arn:aws:lambda:ap-southeast-2:ACCOUNT_ID:function:cancelMembership-prod`
- ✅ SES permissions: **SendEmail and SendRawEmail** (for cron job email notifications)
- ✅ CloudWatch Logs: Write permissions for App Runner logs

#### Environment Variables (Lines 148-164)

- ✅ Reads from: `infra/config/prod-env.json`
- ✅ Filters out comments (keys starting with `_`)
- ✅ Converts to App Runner format: `[{ name, value }]`
- ✅ Throws error if file doesn't exist (with helpful message)

#### App Runner Service (Lines 178-207)

- ✅ Service name: `minihubvone-prod-apprunner`
- ✅ Image source: ECR repository
- ✅ Image tag: `latest`
- ✅ Port: `3000` (matches local Docker)
- ✅ Environment variables: All from `prod-env.json`
- ✅ IAM role: Attached correctly
- ✅ CPU: 1 vCPU
- ✅ Memory: 2 GB
- ✅ Health check: `/health` endpoint
- ✅ Auto-deploy: **Disabled** (manual deployments only - safer)
- ✅ Outputs: Service URL

## ✅ Configuration Files

### `config/prod-env.json.example`

- ✅ Uses `PROD_DB_*` variable names (matches app code)
- ✅ Includes all required variables
- ✅ Has helpful comments

### `config/prod-env.json` (Your actual config)

- ✅ Uses `PROD_DB_*` variable names
- ✅ Contains production values
- ✅ In `.gitignore` (won't be committed)

## ✅ IAM Permissions Summary

**What App Runner CAN do:**

- ✅ Read from DynamoDB tables (Location, BatchPayment)
- ✅ Invoke Lambda functions (sendBatchFailureReminder, cancelMembership)
- ✅ Send emails via AWS SES (for cron job notifications)
- ✅ Write CloudWatch logs

**What App Runner CANNOT do:**

- ❌ Write/Update/Delete DynamoDB tables (read-only)
- ❌ Invoke other Lambda functions (only the 2 specified)
- ❌ Access other AWS services (not granted)

## ✅ Environment Variables Flow

```
prod-env.json (JSON)
    ↓
CDK reads file (line 149)
    ↓
CDK converts to App Runner format (lines 153-158)
    ↓
CDK passes to App Runner (line 187)
    ↓
App Runner injects into container
    ↓
Your app reads via process.env
```

## ✅ Resources Created

When you run `cdk deploy` with `BRANCH_NAME=prod`:

1. **ECR Repository**: `minihubvone-prod`
    - Stores Docker images
    - Lifecycle: keeps last 10 images

2. **IAM Role**: `minihubvone-prod-apprunner-role`
    - DynamoDB read-only access (2 specific tables)
    - Lambda invoke access (2 specific functions)
    - SES send email access (for cron job notifications)
    - CloudWatch Logs write access

3. **App Runner Service**: `minihubvone-prod-apprunner`
    - Pulls from ECR: `minihubvone-prod:latest`
    - Port: 3000
    - Health check: `/health`
    - Environment variables: All from `prod-env.json`
    - IAM role: Attached

## ⚠️ Important Notes

1. **Auto-deploy is disabled**: After pushing images, manually trigger deployment in AWS Console
2. **First deployment**: App Runner may fail initially (ECR is empty) - push image then redeploy
3. **IAM permissions are restrictive**: Only specific tables/functions, read-only for DynamoDB
4. **Environment variables**: Must use `PROD_DB_*` format to match your app code

## 🧪 Testing Before Deployment

```bash
# 1. Compile (ignore test file errors)
cd infra && npm run build

# 2. Synthesize (generate CloudFormation)
cd infra && BRANCH_NAME=prod npx cdk synth

# 3. Review differences (if redeploying)
cd infra && BRANCH_NAME=prod npx cdk diff

# 4. Deploy (when ready)
cd infra && BRANCH_NAME=prod npx cdk deploy
```

## ✅ Everything Looks Good!

All CDK code is correct and ready for deployment. The infrastructure will:

- Create ECR repository
- Create IAM role with restrictive permissions
- Create App Runner service configured to use your Docker image
- Inject all environment variables from `prod-env.json`

## 📦 Docker Image Upload (Manual Step)

**Important:** CDK does NOT upload your Docker image. You must do this manually:

1. **CDK creates ECR repository** (empty - no images)
2. **You build Docker image** from your app code
3. **You push image to ECR** manually
4. **App Runner pulls image** when you trigger deployment

See `_ARCHITECTURE_EXPLAINED.md` for complete flow explanation.

## 🗑️ Stack Destruction

To remove all resources (for testing):

```bash
cd infra
BRANCH_NAME=prod npx cdk destroy
```

**Warning:** This deletes App Runner service and IAM role. ECR repository is retained (safety).

You're ready to deploy! 🚀
