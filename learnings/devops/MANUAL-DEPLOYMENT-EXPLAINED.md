# Manual Deployment Guide - Step by Step

This guide walks you through manually deploying the MiniHubVOne application to AWS App Runner using CDK.

## Important Concepts

### Single Source of Truth: `config/prod-env.json`

**All environment variables come from `infra/config/prod-env.json`**

- CDK reads this file when creating the App Runner service
- Every environment variable your app needs must be in this file
- This file is **NOT committed to git** (contains sensitive data)
- You must create this file before deploying

### AWS Account Selection: `AWS_PROFILE`

**You control which AWS account to deploy to using `AWS_PROFILE`**

- Each AWS account has its own profile in your AWS CLI config
- Set `export AWS_PROFILE=account-name` before deploying
- This ensures you never accidentally deploy to the wrong account
- Always verify which account you're using before deploying

## Prerequisites

Before starting, ensure you have:

1. **AWS CLI installed and configured**

    ```bash
    aws --version
    ```

2. **Docker installed and running**

    ```bash
    docker --version
    ```

3. **Node.js and npm installed**

    ```bash
    node --version
    npm --version
    ```

4. **CDK CLI installed**

    ```bash
    npm install -g aws-cdk
    cdk --version
    ```

5. **AWS accounts configured with profiles**
    - Test account profile (e.g., `test-account`)
    - Production account profile (e.g., `prod-account`)

## Step-by-Step Deployment Process

### Phase 1: Setup and Configuration

#### Step 1: Configure AWS CLI Profiles

If you haven't already, set up AWS profiles for different accounts:

```bash
# Configure test account
aws configure --profile test-account
# Enter: Access Key ID, Secret Access Key, Region (ap-southeast-2), Output format (json)

# Configure production account
aws configure --profile prod-account
# Enter: Access Key ID, Secret Access Key, Region (ap-southeast-2), Output format (json)
```

**Verify profiles are set up:**

```bash
# List all profiles
cat ~/.aws/credentials

# Test test account
aws sts get-caller-identity --profile test-account

# Test prod account
aws sts get-caller-identity --profile prod-account
```

#### Step 2: Create Production Environment Config File

Navigate to the infra directory and create the config file:

```bash
cd infra
cp config/prod-env.json.example config/prod-env.json
```

**Edit `config/prod-env.json`** and fill in ALL required values:

```json
{
    "NODE_ENV": "production",
    "PORT": "3000",
    "AWS_REGION": "ap-southeast-2",

    "API_KEY": "your-production-api-key-here",

    "PROD_DB_HOST": "your-postgres-host.example.com",
    "PROD_DB_PORT": "5432",
    "PROD_DB_NAME": "your-database-name",
    "PROD_DB_USER": "your-db-user",
    "PROD_DB_PASSWORD": "your-db-password",
    "PG_SSL": "true",

    "LOCATION_TABLE_NAME": "your-existing-location-table-name",
    "BATCH_PAYMENT_TABLE_NAME": "your-existing-batch-payment-table-name",

    "SEND_BATCH_REMINDER_LAMBDA_NAME": "your-existing-send-batch-reminder-lambda-name",
    "CANCEL_MEMBERSHIP_LAMBDA_NAME": "your-existing-cancel-membership-lambda-name",

    "WEBHOOK_SECRET": "optional-webhook-secret",
    "S3_BASE_URL": "optional-s3-base-url"
}
```

**Important:** Use `PROD_DB_*` variable names (not `PG_*`) to match your local Docker setup. Your app code (`app/src/config.ts`) checks for `PROD_DB_*` first, then falls back to `PG_*`.

**Important Notes:**

- This file is the **single source of truth** for all environment variables
- CDK reads this file and passes all values to App Runner
- Any variable you add here will be available to your application
- **DO NOT commit this file to git** (already in `.gitignore`)

#### Step 3: Install Dependencies

From the **root** of the project (not infra directory):

```bash
cd /Users/Amrit.Regmi/Desktop/minihubvone
npm install
```

This installs all dependencies including CDK libraries.

#### Step 4: Compile TypeScript

```bash
cd infra
npm run build
```

This compiles the TypeScript code to JavaScript. Fix any errors before proceeding.

**Note:** If you see an error about `test/infra.test.ts`, you can ignore it - it's just a test file issue and doesn't affect the CDK deployment code. The important files (`lib/infra-stack.ts`, `lib/blueprint/index.ts`, `bin/infra.ts`) should compile successfully.

#### Step 4.5: Verify CDK Code (Optional but Recommended)

Before deploying, verify the CDK code is correct:

```bash
cd infra

# Check that CDK can synthesize (generate CloudFormation template)
BRANCH_NAME=prod npx cdk synth

# This should complete without errors
# If there are errors, fix them before proceeding
```

**What this does:**

- Compiles TypeScript
- Generates CloudFormation template
- Validates the configuration
- **Does NOT deploy anything** - safe to run

### Phase 2: Deploy to Test Account (First Time)

**Always deploy to test account first to verify everything works.**

#### Step 5: Set AWS Profile for Test Account

```bash
export AWS_PROFILE=test-account
```

**Verify you're using the correct account:**

```bash
aws sts get-caller-identity
# Should show your test account ID
```

**Important:** Keep this terminal session open. If you open a new terminal, you'll need to set `AWS_PROFILE` again.

#### Step 6: Bootstrap CDK (First Time Only)

CDK needs to bootstrap your AWS account (creates an S3 bucket for deployment artifacts).

```bash
cd infra

# Get your account ID first
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Account ID: $ACCOUNT_ID"

# Bootstrap CDK
npx cdk bootstrap aws://$ACCOUNT_ID/ap-southeast-2
```

This only needs to be done **once per AWS account**. You'll see output like:

```
✅ Environment aws://123456789012/ap-southeast-2 bootstrapped
```

#### Step 7: Review What Will Be Created

Before deploying, see what CDK will create:

```bash
cd infra
BRANCH_NAME=prod npx cdk synth
```

This generates the CloudFormation template but **doesn't deploy anything**. Review the output in `cdk.out/` folder.

**See differences** (if you've deployed before):

```bash
cd infra
BRANCH_NAME=prod npx cdk diff
```

This shows what will change compared to what's already deployed.

#### Step 8: Deploy to Test Account (Two-Step Process)

**Important:** App Runner requires a Docker image to exist in ECR before it can create the service. To avoid the "chicken-and-egg" problem, we use a two-step deployment:

**Step 8a: Deploy ECR Repository Only (First Time)**

```bash
cd infra
SKIP_APP_RUNNER=true BRANCH_NAME=prod npx cdk deploy
```

**What happens:**

1. CDK creates CloudFormation template
2. AWS CloudFormation creates:
    - ✅ ECR repository: `minihubvone-prod`
    - ❌ Skips App Runner (will create in Step 8c)

**You'll see output like:**

```
✅  minihubvone-prod-foundation

Outputs:
minihubvone-prod-foundation.EcrRepositoryUri = 123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod
minihubvone-prod-foundation.NextStep = 1. Push Docker image to ECR
2. Deploy again without SKIP_APP_RUNNER flag
```

**Save the ECR repository URI!** You'll need it in the next step.

**Note:** If you've already deployed before and the ECR repository exists, you can skip Step 8a and go directly to Step 8b.

#### Step 8b: Build and Push Docker Image to ECR

**Step 8b.1: Get ECR Repository URI**

First, get the ECR repository URI from the CDK deployment output:

```bash
# If you just deployed, the URI is in the CDK output
# Look for: minihubvone-prod-foundation.EcrRepositoryUri = <URI>

# Or get it from AWS directly
aws ecr describe-repositories \
  --repository-names minihubvone-prod \
  --region ap-southeast-2 \
  --query 'repositories[0].repositoryUri' \
  --output text
```

**Step 8b.2: Set ECR_URI Variable and Verify**

```bash
# Go back to project root
cd /Users/Amrit.Regmi/Desktop/minihubvone

# Set ECR_URI variable - REPLACE with your actual ECR URI from Step 8b.1
# IMPORTANT: The repository name must be exactly "minihubvone-prod" (not "minihubvone-prodatest" or anything else)
export ECR_URI="006543401432.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod"

# VERIFY the variable is set correctly
echo "ECR_URI is set to: $ECR_URI"

# Check that it ends with "/minihubvone-prod" (not "prodatest" or anything else)
# If it's wrong, Docker will tag the image incorrectly and push will fail!
```

**Why Docker uses the wrong tag:**

- Docker tags images with **exactly** what you specify in the `-t` flag
- If `$ECR_URI` contains the wrong repository name, Docker will tag it with that wrong name
- Example: If `ECR_URI="...minihubvone-prodatest"`, Docker tags it as `...minihubvone-prodatest:latest`
- When you push, it tries to push to a repository that doesn't exist → 404 error

**Step 8b.3: Clean Up Any Old Incorrectly Tagged Images**

Before building, remove any Docker images with incorrect tags:

```bash
# List all ECR-tagged images to see what you have
docker images | grep "dkr.ecr"

# If you see any with wrong repository name (like "minihubvone-prodatest"), delete them:
# docker rmi <wrong-image-name>:latest

# Example (only if you have the wrong tag):
# docker rmi 006543401432.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prodatest:latest
```

**Step 8b.4: Build Docker Image with Correct Tag**

**IMPORTANT:** If you're experiencing issues where Docker tags the image incorrectly (e.g., `prodatest` instead of `prod`), use the **exact value directly** instead of a variable.

**Method 1: Using Variable (if it works correctly)**

```bash
# Build the image - Docker will tag it with whatever $ECR_URI contains
# Make sure $ECR_URI is correct before running this!
docker build -f app/Dockerfile -t $ECR_URI:latest .

# VERIFY the image was tagged correctly
docker images | grep "$ECR_URI"
# Should show: 006543401432.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod   latest

# If it shows "minihubvone-prodatest" or anything else, your $ECR_URI variable is wrong!
```

**Method 2: Using Exact Value Directly (Foolproof - Recommended if Method 1 fails)**

If the variable approach isn't working, use the exact ECR URI directly in the command:

```bash
# Replace <ACCOUNT-ID> with your actual AWS account ID (e.g., 006543401432)
# Use the EXACT value - copy it from CDK output or AWS Console
docker build -f app/Dockerfile -t 006543401432.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod:latest .

# VERIFY the image was tagged correctly
docker images | grep "minihubvone-prod"
# Should show: 006543401432.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod   latest

# If you see "prodatest" in the output, you made a typo in the command above!
```

**Troubleshooting: Why Docker might tag incorrectly**

If Docker is still creating `prodatest` even with the correct value:

1. **Check for typos** - Make sure you're typing `minihubvone-prod` not `minihubvone-prodatest`
2. **Copy-paste the exact value** from CDK output or AWS Console
3. **Check shell history** - Your shell might be auto-completing with a wrong value
4. **Use Method 2** - Type the exact value directly instead of using `$ECR_URI`

This builds the same Docker image you use locally, but tagged for ECR. The tag must match the ECR repository name exactly.

**Step 8b.5: Get ECR Login Credentials**

ECR uses temporary credentials that expire after 12 hours. You need to authenticate Docker with ECR before pushing images.

**How ECR authentication works:**

- ECR doesn't use a static username/password
- Instead, AWS CLI generates a temporary password using your AWS credentials
- This password is valid for 12 hours
- You must re-authenticate after it expires

**Login to ECR:**

```bash
# Make sure AWS_PROFILE is still set
echo $AWS_PROFILE  # Should show: test-account

# Authenticate Docker with ECR
# This command:
# 1. Gets a temporary password from AWS (valid for 12 hours)
# 2. Logs Docker into ECR using that password
aws ecr get-login-password --region ap-southeast-2 | \
  docker login --username AWS --password-stdin $ECR_URI
```

**What this does:**

- `aws ecr get-login-password` - Gets a temporary password from AWS using your current AWS credentials
- `--region ap-southeast-2` - Specifies the AWS region
- `docker login --username AWS --password-stdin` - Logs Docker into ECR using the password from stdin
- `$ECR_URI` - The ECR repository URI (e.g., `123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod`)

**You should see:** `Login Succeeded`

**If login fails:**

- Check that `AWS_PROFILE` is set correctly: `echo $AWS_PROFILE`
- Verify AWS credentials: `aws sts get-caller-identity`
- Make sure you have ECR permissions in your AWS account
- Try logging in again (password might have expired)

**Step 8b.6: Push Docker Image to ECR**

**Method 1: Using Variable**

```bash
# Double-check ECR_URI is still set correctly
echo "Pushing to: $ECR_URI:latest"
# Should show: Pushing to: 006543401432.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod:latest
# If it shows "prodatest", the variable is wrong - use Method 2 instead!

# Push the image
docker push $ECR_URI:latest
```

**Method 2: Using Exact Value (If variable doesn't work)**

```bash
# Use the exact ECR URI directly (replace <ACCOUNT-ID> with your account ID)
docker push 006543401432.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod:latest
```

**What to expect:**

- You should see output showing image layers being pushed
- If you get "404 Not Found", check:
    1. Is `$ECR_URI` set correctly? Run `echo $ECR_URI`
    2. Does the repository name match exactly? Should end with `/minihubvone-prod`
    3. Did you login to ECR? Run the login command again
    4. Does the repository exist? Check: `aws ecr describe-repositories --region ap-southeast-2`

**Verify the image was pushed successfully:**

```bash
# List images in ECR repository
aws ecr list-images --repository-name minihubvone-prod --region ap-southeast-2
```

You should see your image with tag `latest`. If the list is empty, the push failed.

#### Step 8c: Deploy App Runner Service (Second Deployment)

Now that the Docker image exists in ECR, deploy the App Runner service:

```bash
cd infra
BRANCH_NAME=prod npx cdk deploy  # No SKIP_APP_RUNNER flag this time
```

**What happens:**

1. CDK reads `config/prod-env.json` (all environment variables)
2. CDK creates CloudFormation template
3. AWS CloudFormation creates:
    - ✅ IAM role: `minihubvone-prod-apprunner-role`
    - ✅ ECR access role: `minihubvone-prod-ecr-access-role`
    - ✅ App Runner service: `minihubvone-prod-apprunner` (image now exists, so it works!)

**You'll see output like:**

```
✅  minihubvone-prod-foundation

Outputs:
minihubvone-prod-foundation.EcrRepositoryUri = 123456789012.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod
minihubvone-prod-foundation.AppRunnerServiceUrl = https://abc123.ap-southeast-2.awsapprunner.com
```

**Save the App Runner service URL!** This is your production API endpoint.

**Note:** If you've already deployed App Runner before, this step will update it. The service should start automatically since the image exists.

#### Step 9: Verify App Runner Deployment

**Important:** Since `autoDeploymentsEnabled: false` (for safety), App Runner won't automatically deploy new images. You need to manually trigger a deployment.

**Option 1: Via AWS Console (Easiest)**

1. Go to AWS Console → App Runner → Services
2. Find `minihubvone-prod-apprunner`
3. Click on the service
4. Click "Deploy" or "Create new revision"
5. App Runner will pull the latest image from ECR and deploy it

**What happens after deployment:**

1. App Runner pulls the image from ECR
2. Starts the container
3. Sets all environment variables from `prod-env.json`
4. Runs health checks on `/health` endpoint
5. Your app is live!

**Check the App Runner service:**

- Go to AWS Console → App Runner → Services
- Find `minihubvone-prod-apprunner`
- Click on it to see status and URL
- Status should be "Running" (green) when ready

**If the service is not running:**

- Check CloudWatch logs for errors
- Verify the Docker image exists in ECR
- Check that environment variables are correct in `prod-env.json`
- Verify health check endpoint `/health` is working

**Test the health endpoint:**

```bash
# Get the App Runner URL from Step 8 output or AWS Console
APP_URL="https://abc123.ap-southeast-2.awsapprunner.com"

# Test health check
curl $APP_URL/health

# Should return: {"status":"ok"}
```

**Check CloudWatch Logs:**

1. Go to AWS Console → CloudWatch → Log groups
2. Find: `/aws/apprunner/minihubvone-prod-apprunner/...`
3. Click on a log stream to see your application logs

**Test an API endpoint:**

```bash
# Get your API key from config/prod-env.json
API_KEY="your-api-key"

# Test an endpoint
curl -H "X-API-Key: $API_KEY" $APP_URL/api/locations
```

### Phase 3: Deploy to Production Account

**Once test deployment works, deploy to production.**

#### Step 14: Switch to Production Account

**Close the current terminal or unset the profile:**

```bash
unset AWS_PROFILE
```

**Set production profile:**

```bash
export AWS_PROFILE=prod-account
```

**VERIFY you're on the correct account:**

```bash
aws sts get-caller-identity
# Should show your PRODUCTION account ID (different from test)
```

**Double-check:** Make sure the account ID is different from your test account!

#### Step 15: Update Config for Production

**Edit `infra/config/prod-env.json`** with **PRODUCTION** values:

- Production database credentials
- Production API keys
- Production DynamoDB table names
- Production Lambda function names

**Important:** These values are different from test account!

#### Step 16: Bootstrap CDK for Production (First Time Only)

```bash
cd infra

# Get production account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Production Account ID: $ACCOUNT_ID"

# Bootstrap (only needed once)
npx cdk bootstrap aws://$ACCOUNT_ID/ap-southeast-2
```

#### Step 17: Review Production Deployment

```bash
cd infra
BRANCH_NAME=prod npx cdk synth
```

Review the template to ensure everything looks correct.

#### Step 18: Deploy to Production (Two-Step Process)

**Step 18a: Deploy ECR Repository Only (First Time)**

```bash
cd infra
SKIP_APP_RUNNER=true BRANCH_NAME=prod npx cdk deploy
```

**Wait for confirmation:** CDK will ask you to confirm. Type `y` and press Enter.

**Save the ECR repository URI from the output!**

**Note:** If you've already deployed before and the ECR repository exists, you can skip Step 18a and go directly to Step 18b.

**Step 18b: Build and Push Production Image**

```bash
# Go to project root
cd /Users/Amrit.Regmi/Desktop/minihubvone

# Use PRODUCTION ECR URI from Step 18a
ECR_URI="987654321098.dkr.ecr.ap-southeast-2.amazonaws.com/minihubvone-prod"

# Build
docker build -f app/Dockerfile -t $ECR_URI:latest .

# Login to ECR (make sure AWS_PROFILE=prod-account is set)
# This gets a temporary password from AWS and logs Docker into ECR
aws ecr get-login-password --region ap-southeast-2 | \
  docker login --username AWS --password-stdin $ECR_URI

# You should see: Login Succeeded

# Push
docker push $ECR_URI:latest
```

**Verify the image was pushed:**

```bash
aws ecr list-images --repository-name minihubvone-prod --region ap-southeast-2
```

**Step 18c: Deploy App Runner Service (Second Deployment)**

```bash
cd infra
BRANCH_NAME=prod npx cdk deploy  # No SKIP_APP_RUNNER flag this time
```

**Wait for confirmation:** CDK will ask you to confirm. Type `y` and press Enter.

**Save the outputs:**

- ECR repository URI (production)
- App Runner service URL (production)

#### Step 19: Verify Production Deployment

**Important:** Since auto-deploy is disabled, manually trigger deployment:

1. Go to AWS Console → App Runner → Services
2. Find `minihubvone-prod-apprunner`
3. Click "Deploy" or "Create new revision"
4. App Runner will pull the image and start the service

#### Step 21: Verify Production Deployment

Same as Step 13, but using production URLs and API keys.

## Stack Destruction: Removing All Resources

**⚠️ WARNING:** This deletes ALL resources created by CDK. Use only for testing or cleanup.

### When to Destroy:

- Testing deployment process
- Cleaning up test account
- Starting fresh
- **NOT for production** (unless you really want to delete everything)

### How to Destroy:

```bash
# 1. Set AWS profile (VERIFY THIS IS THE RIGHT ACCOUNT!)
export AWS_PROFILE=test-account  # or prod-account

# 2. Double-check account
aws sts get-caller-identity
# Make sure the account ID matches what you expect!

# 3. Go to infra directory
cd infra

# 4. Destroy the stack
BRANCH_NAME=prod npx cdk destroy

# 5. CDK will show what will be deleted and ask for confirmation
# Review carefully, then type: y
```

### What Gets Deleted:

✅ **App Runner Service** - Deleted
✅ **IAM Role** - Deleted
❌ **ECR Repository** - **NOT deleted** (removal policy: RETAIN for safety)
❌ **Docker images in ECR** - **NOT deleted** (preserved)

### Manual Cleanup (Optional):

If you want to delete the ECR repository too:

```bash
# Delete ECR repository (this deletes all images!)
aws ecr delete-repository \
  --repository-name minihubvone-prod \
  --force \
  --region ap-southeast-2

# Delete CloudWatch log groups (optional)
aws logs describe-log-groups \
  --log-group-name-prefix "/aws/apprunner/minihubvone-prod" \
  --region ap-southeast-2 \
  --query 'logGroups[*].logGroupName' \
  --output text | \
  xargs -I {} aws logs delete-log-group \
    --log-group-name {} \
    --region ap-southeast-2
```

### Redeploying After Destruction:

If you destroy and want to redeploy:

1. Run `cdk deploy` again (creates fresh resources)
2. Build and push Docker image again
3. Trigger App Runner deployment

**Note:** ECR repository might still exist (if you didn't manually delete it). That's fine - CDK will use the existing one.

## Updating the Application

When you make code changes and want to redeploy:

### For Test Account:

```bash
# 1. Set profile
export AWS_PROFILE=test-account

# 2. Build new image
cd /Users/Amrit.Regmi/Desktop/minihubvone
ECR_URI="your-test-ecr-uri"
docker build -f app/Dockerfile -t $ECR_URI:v1.0.1 .

# 3. Login and push
aws ecr get-login-password --region ap-southeast-2 | \
  docker login --username AWS --password-stdin $ECR_URI
docker push $ECR_URI:v1.0.1

# 4. Update App Runner to use new tag (via AWS Console or CDK)
```

### For Production Account:

Same process, but:

1. Set `export AWS_PROFILE=prod-account`
2. Use production ECR URI
3. Use production API keys for testing

## Environment Variables: How They Work

### The Flow:

```
1. You edit: infra/config/prod-env.json
   ↓
2. CDK reads: infra/lib/infra-stack.ts (line ~150)
   ↓
3. CDK loads: fs.readFileSync("config/prod-env.json")
   ↓
4. CDK converts: { "API_KEY": "value" } → [{ name: "API_KEY", value: "value" }]
   ↓
5. CDK passes to: App Runner service configuration
   ↓
6. App Runner sets: Environment variables in container
   ↓
7. Your app reads: process.env.API_KEY (in app/src/config.ts)
```

### Adding New Environment Variables:

1. **Add to `config/prod-env.json`:**

    ```json
    {
        "NEW_VARIABLE": "new-value"
    }
    ```

2. **Redeploy:**

    ```bash
    cd infra
    BRANCH_NAME=prod npx cdk deploy
    ```

3. **Your app automatically has access:**
    ```typescript
    // In your app code
    const value = process.env.NEW_VARIABLE;
    ```

**No code changes needed in CDK!** CDK automatically reads all keys from `prod-env.json` and passes them to App Runner.

## AWS Account Switching: Best Practices

### Always Verify Before Deploying:

```bash
# 1. Check which profile is active
echo $AWS_PROFILE

# 2. Check which account you're using
aws sts get-caller-identity

# 3. Verify account ID matches your intention
# Test account: 123456789012
# Prod account: 987654321098
```

### Create Helper Scripts (Optional):

Create `deploy-test.sh`:

```bash
#!/bin/bash
export AWS_PROFILE=test-account
cd infra
BRANCH_NAME=prod npx cdk deploy
```

Create `deploy-prod.sh`:

```bash
#!/bin/bash
export AWS_PROFILE=prod-account
cd infra
BRANCH_NAME=prod npx cdk deploy
```

Make them executable:

```bash
chmod +x deploy-test.sh deploy-prod.sh
```

## Troubleshooting

### Error: "Production config file not found"

- Make sure `infra/config/prod-env.json` exists
- Copy from `prod-env.json.example` if needed

### Error: "ECR login failed" or "unauthorized: authentication required"

- **ECR passwords expire after 12 hours** - you need to re-authenticate
- Run the login command again:
    ```bash
    aws ecr get-login-password --region ap-southeast-2 | \
      docker login --username AWS --password-stdin $ECR_URI
    ```
- Verify `AWS_PROFILE` is set correctly: `echo $AWS_PROFILE`
- Check AWS credentials: `aws sts get-caller-identity`
- Make sure you have ECR permissions in your AWS account

### Error: "App Runner service failed to create"

- **Most common cause:** ECR repository is empty (no Docker image)
- **Solution:** Use two-step deployment:
    1. Deploy with `SKIP_APP_RUNNER=true` to create ECR
    2. Push Docker image to ECR
    3. Deploy again without the flag to create App Runner
- Check CloudWatch logs for specific error messages

### Error: "Cannot assume role"

- Check `AWS_PROFILE` is set correctly
- Verify AWS credentials: `aws sts get-caller-identity`

### Error: "Repository does not exist"

- Make sure CDK deployment completed successfully
- Check ECR repository exists in AWS Console

### App Runner service not starting

- Check CloudWatch logs for errors
- Verify environment variables are correct in `prod-env.json`
- Check health endpoint: `/health` should return 200

### Why did App Runner resources get deleted after health check failure?

**Short answer:** CloudFormation automatically deletes resources when creation fails. This only happens during initial creation, not after the service is successfully running.

**Detailed explanation:**

1. **During Initial Creation (First Deployment):**
    - If App Runner service creation fails (e.g., health check fails), CloudFormation performs a **rollback**
    - Rollback means: "Creation failed, so delete everything we just created"
    - This is standard CloudFormation behavior - it ensures you don't have partially created resources
    - **Result:** App Runner service is deleted, but ECR repository is retained (because of `RemovalPolicy.RETAIN`)

2. **After Successful Creation:**
    - Once App Runner service is successfully created and running, health check failures **will NOT delete the service**
    - The service will just be marked as "unhealthy" but will remain running
    - You can fix the issue (e.g., update environment variables, push new image) and the service will recover
    - **Result:** Service stays running, you just need to fix the underlying issue

3. **What This Means for You:**
    - ✅ **First time only:** If health check fails during initial creation, resources get deleted (this is normal)
    - ✅ **After that:** Once service exists, health check failures won't delete it
    - ✅ **Solution:** Fix the health check issue (see below), then redeploy

**What does App Runner's health check do?**

App Runner's health check is **very simple**:

- Makes an HTTP GET request to `/health` endpoint
- Expects a 200 OK response within the timeout (5 seconds)
- **Does NOT check:**
    - Database connections
    - AWS service availability (DynamoDB, Lambda, etc.)
    - Any business logic
    - Just checks if the HTTP endpoint responds

**If health check fails, it means:**

1. The app isn't responding on port 3000 (most common)
2. The app crashed before it could respond
3. The app is taking too long to respond (timeout)

**Common causes of health check failure:**

1. **App not binding to 0.0.0.0 (MOST COMMON - FIXED):**
    - **Problem:** Express server binds to `localhost` (127.0.0.1) by default
    - **Symptom:** App starts successfully, but health check fails with "connection refused"
    - **Fix:** Server must bind to `0.0.0.0` to be accessible from outside the container
    - **Solution:** Use `app.listen(port, '0.0.0.0', callback)` in `server.ts`
    - **Status:** ✅ Fixed in code - rebuild and push Docker image

2. **App crashing on startup (check CloudWatch logs):**
    - **Missing `AWS_REGION`:** App will crash immediately when importing `config.ts`
    - **Invalid environment variables:** Check all required vars are in `prod-env.json`
    - **Postgres connection issues:** Won't block startup (it's async), but check logs
    - **AWS client initialization:** Shouldn't crash, but check if IAM role has permissions

3. **Missing `AWS_REGION` environment variable:**
    - The app requires `AWS_REGION` and will crash on startup if it's missing
    - Check `infra/config/prod-env.json` has `"AWS_REGION": "ap-southeast-2"`
    - This is a common cause of startup failures

4. **App not listening on port 3000:**
    - Check `config.ts` and `server.ts` - port should be 3000
    - Verify `PORT` environment variable is set in `prod-env.json`

5. **App crashing on startup:**
    - Missing required environment variables
    - Database connection failing (check PostgreSQL credentials)
    - AWS client initialization failing

6. **Wrong health check path:**
    - Should be `/health`, not `/health/`
    - Health endpoint is defined in `app/src/routes/health.ts`

7. **Database connection blocking startup:**
    - The app tests DB connection on startup but doesn't block
    - However, if DB credentials are wrong, it might cause issues later

**How to fix:**

1. **Test the app locally first** (recommended before deploying):

    **Option A: Use the test script (easiest):**

    ```bash
    # From project root
    ./test-prod-startup.js
    ```

    This script will:
    - Load all environment variables from `infra/config/prod-env.json`
    - Check that all required variables are present
    - Build the app
    - Start the app
    - Test the `/health` endpoint
    - Report any errors

    **Option B: Manual testing:**

    ```bash
    # From project root
    cd app

    # Load environment variables from prod-env.json
    # (You'll need to export them manually or use a script)
    export $(cat ../infra/config/prod-env.json | grep -v '^_' | grep -v '^$' | xargs)

    # Build and run
    npm run build
    npm start

    # In another terminal, test health endpoint
    curl http://localhost:3000/health
    # Should return: {"ok":true,"status":"healthy","ts":"..."}
    ```

2. **Verify all required environment variables are in `prod-env.json`:**
    - `AWS_REGION` (required - app will crash without it)
    - `PORT` (defaults to 3000 if missing)
    - Database credentials (`PROD_DB_HOST`, `PROD_DB_NAME`, etc.)
    - API keys (`API_KEY` or `API_KEYS`)

3. **Check for common startup errors:**
    - Missing `AWS_REGION`: App will throw error on startup
    - Database connection failure: Check credentials and network access
    - Missing API keys: App might start but API routes won't work

4. **Once fixed, redeploy:**
    ```bash
    cd infra
    BRANCH_NAME=prod npx cdk deploy
    ```

**Note:** If the service was deleted due to rollback, you'll need to redeploy. The ECR repository should still exist (it has `RemovalPolicy.RETAIN`), so you can skip the two-step deployment and go straight to full deployment if the image is already in ECR.

### Wrong account deployed to

- Always verify with `aws sts get-caller-identity` before deploying
- Use `export AWS_PROFILE=account-name` to switch accounts

### Deploying to Account Without DynamoDB/Lambda

**Question:** Can I deploy to a test account that doesn't have DynamoDB tables or Lambda functions?

**Answer:** Yes, but your app will fail when it tries to access them.

**What happens:**

1. ✅ CDK deployment succeeds (creates ECR, IAM, App Runner)
2. ✅ Docker image push succeeds
3. ✅ App Runner starts container
4. ❌ App fails when accessing DynamoDB: "Table not found"
5. ❌ App fails when invoking Lambda: "Function not found"

**Good for:**

- Testing CDK deployment process
- Verifying infrastructure creation
- Testing App Runner service setup
- Verifying environment variable injection

**Not good for:**

- Testing actual app functionality
- End-to-end testing
- Production deployment

**Recommendation:**

- Use test account to verify infrastructure setup
- Create mock/test DynamoDB tables and Lambda functions in test account if needed
- Use production account for actual deployment with real resources

## Quick Reference Commands

```bash
# Set account
export AWS_PROFILE=test-account  # or prod-account

# Verify account
aws sts get-caller-identity

# Compile
cd infra && npm run build

# Review
cd infra && BRANCH_NAME=prod npx cdk synth

# Deploy infrastructure (TWO-STEP PROCESS)

# Step 1: Deploy ECR only (first time)
cd infra && SKIP_APP_RUNNER=true BRANCH_NAME=prod npx cdk deploy

# Step 2: Build and push Docker image
ECR_URI="<from-cdk-output>"
docker build -f app/Dockerfile -t $ECR_URI:latest .
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin $ECR_URI
docker push $ECR_URI:latest

# Step 3: Deploy App Runner (second deployment)
cd infra && BRANCH_NAME=prod npx cdk deploy  # No SKIP_APP_RUNNER flag

# Verify ECR login (if expired, re-run login command)
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin $ECR_URI

# List images in ECR
aws ecr list-images --repository-name minihubvone-prod --region ap-southeast-2

# Destroy stack (CAREFUL!)
cd infra && BRANCH_NAME=prod npx cdk destroy
```

## Summary Checklist

**Before First Deployment:**

- [ ] AWS CLI profiles configured (test and prod)
- [ ] `config/prod-env.json` created and filled in
- [ ] Dependencies installed (`npm install`)
- [ ] TypeScript compiles (`npm run build`)

**For Test Deployment:**

- [ ] `export AWS_PROFILE=test-account`
- [ ] Verified account with `aws sts get-caller-identity`
- [ ] CDK bootstrapped
- [ ] `cdk deploy` completed
- [ ] Docker image built and pushed
- [ ] App Runner service running
- [ ] Health check passes

**For Production Deployment:**

- [ ] `export AWS_PROFILE=prod-account`
- [ ] Verified PRODUCTION account
- [ ] Updated `prod-env.json` with production values
- [ ] CDK bootstrapped
- [ ] `cdk deploy` completed
- [ ] Docker image built and pushed
- [ ] App Runner service running
- [ ] Health check passes

---

**Remember:**

- `config/prod-env.json` is the **single source of truth** for environment variables
- Use `PROD_DB_*` variable names (not `PG_*`) to match your app code
- `AWS_PROFILE` controls which AWS account you deploy to
- Always verify the account before deploying
- Test account first, then production
- App Runner auto-deploy is disabled - manually trigger deployments after pushing images

## CDK Code Verification

Before deploying, you can verify the CDK code is correct:

**See:** `infra/CDK_VERIFICATION.md` for a complete checklist of what the CDK code creates.

**Quick verification:**

```bash
cd infra
BRANCH_NAME=prod npx cdk synth
```

This generates the CloudFormation template without deploying. Review it to ensure:

- ✅ ECR repository will be created
- ✅ IAM role has correct permissions (read-only DynamoDB, invoke Lambda)
- ✅ App Runner service is configured correctly
- ✅ Environment variables from `prod-env.json` are included

If `cdk synth` succeeds without errors, your CDK code is ready!
