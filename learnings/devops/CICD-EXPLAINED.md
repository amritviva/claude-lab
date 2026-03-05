# 🚀 CI/CD Pipeline Explained (Like You're 10 Years Old)

## ⚡ Quick Start

**Want to deploy right now?** Here's the 30-second version:

1. **Add GitHub Secrets:**
    - `AWS_ACCESS_KEY_ID` - Your AWS access key
    - `AWS_SECRET_ACCESS_KEY` - Your AWS secret key
    - `PROD_ENV_JSON` - Your environment variables (copy entire `prod-env.json` file - see below)

2. **Create Pull Request from `main` to `prod`:**
    - Create PR on GitHub
    - **See CI/CD status directly in the PR!** ✅
    - All checks must pass before merging

3. **Merge the PR:**
    - Once PR checks pass, merge to `prod` branch
    - Deployment automatically starts!

4. **Watch it deploy!** Go to GitHub → Actions tab

**That's it!** The pipeline does everything else automatically.

### 🎯 PR Status Checks

When you create a PR from `main` to `prod`, you'll see status checks in the PR:

- ✅ **Build TypeScript** - Code compiles
- ✅ **Check Formatting** - Code is formatted
- ✅ **Run Tests** - All tests pass
- ✅ **Test Docker Build** - Docker builds successfully (mimics App Runner)

All checks must pass before you can merge!

---

## 📋 Quick Reference

### Required GitHub Secrets

- `AWS_ACCESS_KEY_ID` - AWS access key
- `AWS_SECRET_ACCESS_KEY` - AWS secret key
- `PROD_ENV_JSON` - **Copy entire `prod-env.json` file content** (remove comment lines first)

### Required Environment Variables (in prod-env.json)

See "Complete List of Required Variables" section below for full details.

### IAM Policy

See "IAM Policy Document for GitHub Actions" section below, or use the file: `.github/IAM-POLICY.json`

---

## 📖 Full Guide

### What is CI/CD? 🤔

Imagine you're building a LEGO castle. Every time you finish a new room, you want to:

1. **Check** if it's built correctly (CI = Continuous Integration)
2. **Move** it to your display shelf automatically (CD = Continuous Deployment)

That's what CI/CD does for code! Every time you push code to GitHub, it:

1. **Checks** if your code works (builds, tests, etc.)
2. **Deploys** it to AWS automatically (no manual work needed!)

---

## 🎯 How Our Pipeline Works

### The Simple Version

```
You push code to "prod" branch
    ↓
GitHub Actions wakes up
    ↓
Builds your code (TypeScript → JavaScript)
    ↓
Builds a Docker container (like a lunchbox with your app inside)
    ↓
Pushes container to AWS ECR (like uploading to cloud storage)
    ↓
Deploys infrastructure with CDK (creates/updates App Runner)
    ↓
App Runner automatically starts your app
    ↓
🎉 Your app is live!
```

### The Detailed Version

1. **You push code** → GitHub receives your code
2. **GitHub Actions triggers** → Sees you pushed to "prod" branch
3. **Builds TypeScript** → Converts `.ts` files to `.js` files
4. **Builds Docker image** → Packages everything into a container
5. **Pushes to ECR** → Uploads container to AWS container registry
6. **Deploys with CDK** → Creates/updates AWS resources (App Runner, IAM roles, etc.)
7. **App Runner starts** → Automatically pulls new image and runs your app

---

## 🔐 What Credentials Do You Need?

Think of credentials like keys to your house. You need the right keys to get in!

### Required GitHub Secrets

You need to add these secrets to your GitHub repository:

1. **`AWS_ACCESS_KEY_ID`** - Your AWS username (like your email)
2. **`AWS_SECRET_ACCESS_KEY`** - Your AWS password (keep this secret!)
3. **`PROD_ENV_JSON`** (Optional but recommended) - Your environment variables as JSON string
    - This is the contents of `infra/config/prod-env.json` as a single JSON string
    - See "Environment Variables" section below for details

### How to Get AWS Credentials

#### Option 1: Create an IAM User (Recommended for CI/CD)

1. Go to AWS Console → IAM → Users
2. Click "Create user"
3. Name it: `github-actions-deployer-apprunner`
4. Click "Next"
5. **Choose "Attach policies directly"**
6. **Option A: Use PowerUserAccess (Easier, but broader permissions)**
    - Search for and select `PowerUserAccess`
    - Click "Next"
    - Click "Create user"

    **Option B: Use Custom Policy (More Secure, Recommended)**

    **Important**: AWS inline policies have a 2048 character limit. Since our policy is larger, we'll create a **managed policy** instead.

    **Step 1: Create Managed Policy**
    1. Go to AWS Console → IAM → Policies
    2. Click "Create policy"
    3. Click "JSON" tab
    4. Paste the policy document below (see "IAM Policy Document" section)
    5. Click "Next"
    6. Name it: `GitHubActionsDeployPolicy`
    7. Description: "Policy for GitHub Actions to deploy to App Runner"
    8. Click "Create policy"

    **Step 2: Attach Policy to User**
    1. Go to IAM → Users → `github-actions-deployer-apprunner`
    2. Click "Add permissions" → "Attach policies directly"
    3. Search for `GitHubActionsDeployPolicy`
    4. Select the policy
    5. Click "Next"
    6. Click "Add permissions"

7. Go to "Security credentials" tab
8. Click "Create access key"
9. Choose "Application running outside AWS"
10. Copy the **Access Key ID** and **Secret Access Key**
11. **Save these immediately!** You can't see the secret key again

#### Option 2: Use Existing Credentials

If you already have AWS credentials, you can use those. Just make sure they have the permissions listed above.

---

## 🔑 IAM Policy Document for GitHub Actions

If you chose **Option B** (Custom Policy) above, use this policy document. It grants only the minimum permissions needed for deployment.

**Quick Access:** The policy is also saved in `.github/IAM-POLICY.json` for easy reference.

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ECRPermissions",
            "Effect": "Allow",
            "Action": [
                "ecr:CreateRepository",
                "ecr:DescribeRepositories",
                "ecr:DescribeImages",
                "ecr:GetAuthorizationToken",
                "ecr:BatchCheckLayerAvailability",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:PutImage",
                "ecr:InitiateLayerUpload",
                "ecr:UploadLayerPart",
                "ecr:CompleteLayerUpload"
            ],
            "Resource": "*"
        },
        {
            "Sid": "AppRunnerPermissions",
            "Effect": "Allow",
            "Action": [
                "apprunner:CreateService",
                "apprunner:UpdateService",
                "apprunner:DeleteService",
                "apprunner:DescribeService",
                "apprunner:ListServices",
                "apprunner:ListOperations",
                "apprunner:StartDeployment",
                "apprunner:TagResource",
                "apprunner:UntagResource",
                "apprunner:ListTagsForResource"
            ],
            "Resource": "*"
        },
        {
            "Sid": "CloudFormationPermissions",
            "Effect": "Allow",
            "Action": [
                "cloudformation:CreateStack",
                "cloudformation:UpdateStack",
                "cloudformation:DeleteStack",
                "cloudformation:DescribeStacks",
                "cloudformation:DescribeStackEvents",
                "cloudformation:DescribeStackResources",
                "cloudformation:GetTemplate",
                "cloudformation:ValidateTemplate",
                "cloudformation:ListStacks",
                "cloudformation:CreateChangeSet",
                "cloudformation:DescribeChangeSet",
                "cloudformation:ExecuteChangeSet",
                "cloudformation:DeleteChangeSet",
                "cloudformation:ListChangeSets"
            ],
            "Resource": "*"
        },
        {
            "Sid": "IAMPermissions",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:DeleteRole",
                "iam:GetRole",
                "iam:ListRoles",
                "iam:UpdateRole",
                "iam:AttachRolePolicy",
                "iam:DetachRolePolicy",
                "iam:PutRolePolicy",
                "iam:DeleteRolePolicy",
                "iam:GetRolePolicy",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "iam:PassRole",
                "iam:TagRole",
                "iam:UntagRole",
                "iam:ListRoleTags"
            ],
            "Resource": ["arn:aws:iam::*:role/minihubvone-prod-*"]
        },
        {
            "Sid": "CloudWatchLogsPermissions",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutRetentionPolicy",
                "logs:TagLogGroup"
            ],
            "Resource": "arn:aws:logs:*:*:log-group:/aws/apprunner/*"
        },
        {
            "Sid": "STSPermissions",
            "Effect": "Allow",
            "Action": ["sts:GetCallerIdentity"],
            "Resource": "*"
        },
        {
            "Sid": "S3PermissionsForCDKBootstrap",
            "Effect": "Allow",
            "Action": [
                "s3:CreateBucket",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": ["arn:aws:s3:::cdk-*", "arn:aws:s3:::cdk-*/*"]
        }
    ]
}
```

**How to use this policy:**

**Important**: This policy is too large for an inline policy (AWS limit: 2048 characters). Create it as a **managed policy** instead.

**Option 1: Create Managed Policy from File (Easier)**

1. Open `.github/IAM-POLICY.json` in your editor
2. Copy the entire JSON content
3. Go to AWS Console → IAM → Policies
4. Click "Create policy"
5. Click "JSON" tab
6. Paste the policy
7. Click "Next"
8. Name it: `GitHubActionsDeployPolicy`
9. Description: "Policy for GitHub Actions to deploy to App Runner"
10. Click "Create policy"
11. Go to IAM → Users → `github-actions-deployer-apprunner`
12. Click "Add permissions" → "Attach policies directly"
13. Search for and select `GitHubActionsDeployPolicyApprunner`
14. Click "Add permissions"

**Option 2: Create Managed Policy from Documentation**

1. Copy the JSON policy from the section above
2. Follow steps 3-14 from Option 1

**Why Managed Policy?**

- Inline policies have a 2048 character limit
- Our policy exceeds this limit
- Managed policies have no character limit
- Managed policies are reusable and easier to manage

**Note:** This policy is more restrictive than `PowerUserAccess` and only grants permissions needed for deployment. It's the recommended approach for better security.

---

## 📝 How to Add Secrets to GitHub

1. Go to your GitHub repository
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions** (left sidebar)
4. Click **New repository secret**
5. Add each secret:
    - **Name:** `AWS_ACCESS_KEY_ID`
    - **Value:** Your access key ID
    - Click **Add secret**
6. Repeat for `AWS_SECRET_ACCESS_KEY`

**Important:** Secrets are encrypted and never shown in logs. They're safe!

---

## 🌍 Environment Variables: Where Do They Come From?

### The Simple Answer

Environment variables come from **CDK**, not from the GitHub Actions pipeline!

### How It Works

1. **You store variables** in `infra/config/prod-env.json` (or GitHub Secret)
2. **CDK reads the file** when deploying
3. **CDK passes variables** to App Runner
4. **App Runner injects them** into your running container

### Two Ways to Store Environment Variables

#### Option 1: GitHub Secret (Recommended for CI/CD) ✅

**Best for:** Public repositories or when you want extra security

**YES! You can copy the entire JSON file directly!** 🎉

1. **Create `prod-env.json` locally:**

    ```bash
    cd infra/config
    cp prod-env.json.example prod-env.json
    # Edit prod-env.json and fill in your values
    # IMPORTANT: Remove all lines starting with "_" (these are comments)
    ```

2. **Copy the entire file content:**
    - Open `infra/config/prod-env.json` in your editor
    - Select ALL content (Cmd+A / Ctrl+A)
    - Copy it (Cmd+C / Ctrl+C)
    - **That's it!** You don't need to convert to single-line or remove newlines

3. **Add as GitHub Secret:**
    - Go to GitHub → Settings → Secrets → Actions
    - Click "New repository secret"
    - **Name:** `PROD_ENV_JSON`
    - **Value:** Paste the entire JSON file content (with newlines is fine!)
    - Click "Add secret"

4. **The workflow automatically creates the file** from the secret during deployment

**Important Notes:**

- ✅ You can paste the JSON with newlines - GitHub Actions handles it
- ✅ Remove lines starting with `"_"` (comments) before copying
- ✅ Make sure it's valid JSON (no trailing commas, proper quotes, etc.)

**Pros:**

- ✅ Secrets never stored in code
- ✅ Works with public repositories
- ✅ Easy to update (just change the secret)
- ✅ Can copy entire file directly (no conversion needed!)

**Cons:**

- ⚠️ Need to remove comment lines (starting with `"_"`) manually

#### Option 2: Commit to Repository (Simpler) ✅

**Best for:** Private repositories where you're comfortable committing secrets

1. **Create `prod-env.json`:**

    ```bash
    cd infra/config
    cp prod-env.json.example prod-env.json
    # Edit prod-env.json and fill in your values
    ```

2. **Temporarily remove from .gitignore:**

    ```bash
    # Edit .gitignore and comment out or remove this line:
    # infra/config/prod-env.json
    ```

3. **Commit the file:**

    ```bash
    git add infra/config/prod-env.json
    git commit -m "Add production environment variables"
    git push
    ```

4. **The workflow uses the committed file** directly

**Pros:**

- ✅ Simple - just commit the file
- ✅ Easy to see what variables are set
- ✅ No secret management needed

**Cons:**

- ⚠️ Secrets stored in git history (even if you delete later)
- ⚠️ Only safe for private repositories
- ⚠️ Anyone with repo access can see secrets

### Why Not From Pipeline Directly?

- **Security:** Secrets stay encrypted in GitHub Secrets or private repo
- **Simplicity:** One place to manage all variables (CDK reads the file)
- **Flexibility:** Easy to change without touching pipeline code
- **Consistency:** Same approach for local development and CI/CD

### What Variables Are Needed?

All variables are in `infra/config/prod-env.json`. The CDK automatically reads this file and passes all variables to App Runner.

#### Complete List of Required Variables

Here's the **complete list** of all variables you need in `prod-env.json`:

| Variable Name                     | Required    | Description                     | Example                                    |
| --------------------------------- | ----------- | ------------------------------- | ------------------------------------------ |
| `NODE_ENV`                        | ✅ Yes      | Environment name                | `"production"`                             |
| `PORT`                            | ✅ Yes      | Server port                     | `"3000"`                                   |
| `AWS_REGION`                      | ✅ Yes      | AWS region                      | `"ap-southeast-2"`                         |
| `API_KEY`                         | ✅ Yes\*    | Single API key                  | `"your-api-key"`                           |
| `API_KEYS`                        | ✅ Yes\*    | Multiple keys (comma-separated) | `"key1,key2,key3"`                         |
| `PROD_DB_HOST`                    | ✅ Yes      | Database hostname               | `"db.example.com"`                         |
| `PROD_DB_PORT`                    | ✅ Yes      | Database port                   | `"5432"`                                   |
| `PROD_DB_NAME`                    | ✅ Yes      | Database name                   | `"my_database"`                            |
| `PROD_DB_USER`                    | ✅ Yes      | Database username               | `"db_user"`                                |
| `PROD_DB_PASSWORD`                | ✅ Yes      | Database password               | `"secure-password"`                        |
| `PG_SSL`                          | ✅ Yes      | Enable SSL                      | `"true"`                                   |
| `LOCATION_TABLE_NAME`             | ✅ Yes      | DynamoDB location table         | `"Location-xxx-prod"`                      |
| `BATCH_PAYMENT_TABLE_NAME`        | ✅ Yes      | DynamoDB batch payment table    | `"BatchPayment-xxx-prod"`                  |
| `SEND_BATCH_REMINDER_LAMBDA_NAME` | ✅ Yes      | Lambda function name            | `"sendBatchFailureReminder-prod"`          |
| `CANCEL_MEMBERSHIP_LAMBDA_NAME`   | ✅ Yes      | Lambda function name            | `"cancelMembership-prod"`                  |
| `WEBHOOK_SECRET`                  | ⚠️ Optional | Webhook secret                  | `"optional-secret"`                        |
| `S3_BASE_URL`                     | ⚠️ Optional | S3 bucket URL                   | `"https://bucket.s3.region.amazonaws.com"` |

\*Use either `API_KEY` OR `API_KEYS`, not both.

**Application Configuration (Required):**

- `NODE_ENV` - Environment name (`"production"`)
- `PORT` - Server port number (`"3000"`)
- `AWS_REGION` - AWS region (`"ap-southeast-2"`)

**API Authentication (Required - choose one):**

- `API_KEY` - Single API key for authentication (e.g., `"your-api-key-here"`)
- **OR** `API_KEYS` - Multiple API keys, comma-separated (e.g., `"key1,key2,key3"`)

**PostgreSQL Database (Required):**

- `PROD_DB_HOST` - Database hostname (e.g., `"your-db-host.rds.amazonaws.com"`)
- `PROD_DB_PORT` - Database port (`"5432"`)
- `PROD_DB_NAME` - Database name (e.g., `"your_database_name"`)
- `PROD_DB_USER` - Database username (e.g., `"your_db_user"`)
- `PROD_DB_PASSWORD` - Database password (e.g., `"your-secure-password"`)
- `PG_SSL` - Enable SSL (`"true"` or `"false"`)

**DynamoDB Tables (Required):**

- `LOCATION_TABLE_NAME` - Location table name (e.g., `"Location-k5r5hyaijzgszl2xs5ysna5urq-prod"`)
- `BATCH_PAYMENT_TABLE_NAME` - Batch payment table name (e.g., `"BatchPayment-k5r5hyaijzgszl2xs5ysna5urq-prod"`)

**Lambda Functions (Required):**

- `SEND_BATCH_REMINDER_LAMBDA_NAME` - Lambda function name (e.g., `"sendBatchFailureReminder-prod"`)
- `CANCEL_MEMBERSHIP_LAMBDA_NAME` - Lambda function name (e.g., `"cancelMembership-prod"`)

**Optional Variables:**

- `WEBHOOK_SECRET` - Secret for webhook authentication (optional)
- `S3_BASE_URL` - S3 bucket base URL for contract PDFs (optional)

#### Example prod-env.json

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

**See `infra/config/prod-env.json.example` for the template with all options.**

**Note:** The workflow supports both approaches. If `PROD_ENV_JSON` secret is set, it uses that. Otherwise, it looks for `infra/config/prod-env.json` in the repository.

---

## 📋 Step-by-Step: How to Deploy

### First Time Setup (One-Time)

1. **Create AWS credentials** (see "How to Get AWS Credentials" above)
2. **Add AWS secrets to GitHub:**
    - `AWS_ACCESS_KEY_ID`
    - `AWS_SECRET_ACCESS_KEY`
    - (See "How to Add Secrets to GitHub" above)

3. **Set up environment variables** (choose one method):

    **Method A: GitHub Secret (Recommended)**

    ```bash
    # 1. Create prod-env.json locally
    cd infra/config
    cp prod-env.json.example prod-env.json
    # Edit prod-env.json and fill in your values
    # IMPORTANT: Remove all lines starting with "_" (comments)

    # 2. Open the file in your editor and copy everything
    # - Select all (Cmd+A / Ctrl+A)
    # - Copy (Cmd+C / Ctrl+C)
    # That's it! You can paste the entire file directly.

    # 3. Add as GitHub Secret:
    # - Go to GitHub → Settings → Secrets → Actions
    # - Click "New repository secret"
    # - Name: PROD_ENV_JSON
    # - Value: Paste the entire JSON file content (with newlines is fine!)
    # - Click "Add secret"
    ```

    **That's it!** You can copy the entire JSON file and paste it directly. GitHub Actions handles newlines automatically. Just make sure to remove comment lines (starting with `"_"`) first.

    **Method B: Commit to Repository (Private repos only)**

    ```bash
    # Create prod-env.json
    cd infra/config
    cp prod-env.json.example prod-env.json
    # Edit prod-env.json and fill in your values

    # Temporarily allow committing it (edit .gitignore)
    # Then commit:
    git add infra/config/prod-env.json
    git commit -m "Add production environment variables"
    git push
    ```

### Every Deployment (Automatic!)

1. **Work on your code** in the `main` branch
2. **Test locally** to make sure everything works
3. **Create Pull Request** from `main` to `prod`:
    - Go to GitHub → Create Pull Request
    - **See CI/CD status checks in the PR!** 🎯
    - All checks must pass (TypeScript build, formatting, tests, Docker build)
4. **Merge the PR** once all checks pass
5. **GitHub Actions automatically:**
    - Builds your code
    - Deploys to AWS
    - Shows you the service URL when done!

**Pro Tip**: The PR checks show you exactly what will happen in deployment. If PR checks pass, deployment will succeed!

### Manual Trigger (Optional)

You can also trigger deployment manually:

1. Go to GitHub → **Actions** tab
2. Click **Deploy to Production** workflow
3. Click **Run workflow** button
4. Select `prod` branch
5. Click **Run workflow**

---

## 🆕 New Deployment vs. Update

### New Deployment (First Time)

When deploying to a **brand new AWS account** or **first time ever**:

1. **Pipeline automatically handles it!**
    - Step 8 checks if ECR repository exists
    - If not, creates it first (with `SKIP_APP_RUNNER=true`)
    - Then continues with image push and full deployment

2. **What gets created:**
    - ECR repository (to store Docker images)
    - IAM roles (for App Runner to access AWS services)
    - App Runner service (the running application)
    - CloudWatch log groups (for application logs)

3. **No manual steps needed!** The pipeline does everything.

### Update (Existing Deployment)

When you push new code to `prod` branch:

1. **Pipeline automatically:**
    - Builds new code
    - Builds new Docker image
    - Pushes to ECR (overwrites `latest` tag)
    - CDK detects changes and updates App Runner
    - App Runner automatically pulls new image and restarts

2. **Zero downtime!** App Runner does a rolling update:
    - Starts new instances with new image
    - Routes traffic to new instances
    - Stops old instances
    - Your app stays available the whole time!

---

## 🔍 How to Check If It Worked

### During Deployment

1. Go to GitHub → **Actions** tab
2. Click on the running workflow
3. Watch the steps execute in real-time
4. Green checkmarks = success ✅
5. Red X = failure ❌

### After Deployment

1. **Check the workflow output:**
    - Scroll to bottom of workflow run
    - Look for "Deployment Summary"
    - You'll see the service URL

2. **Test the health endpoint:**

    ```bash
    curl https://<your-service-url>/health
    ```

    Should return: `{"status":"ok"}`

3. **Check AWS Console:**
    - Go to AWS → App Runner
    - Find your service
    - Check status (should be "Running")

4. **View logs:**
    ```bash
    aws logs tail /aws/apprunner/*/application --region ap-southeast-2 --follow
    ```

---

## 🐛 Troubleshooting

### "Access Denied" Error

**Problem:** GitHub Actions can't access AWS

**Solution:**

1. Check if secrets are set correctly in GitHub
2. Verify AWS credentials have correct permissions
3. Make sure IAM user has `PowerUserAccess` or custom policy

### "ECR Repository Not Found"

**Problem:** First deployment, ECR doesn't exist yet

**Solution:**

- The pipeline should handle this automatically
- If it fails, check Step 8 in the workflow
- Make sure IAM user has `ecr:*` permissions

### "CDK Deployment Failed"

**Problem:** Infrastructure deployment failed

**Solution:**

1. Check CloudFormation in AWS Console
2. Look at the error message
3. Common issues:
    - Missing environment variables in `prod-env.json`
    - IAM permissions insufficient
    - Resource limits (e.g., too many App Runner services)

### "App Runner Service Not Starting"

**Problem:** Service created but not running

**Solution:**

1. Check App Runner service status in AWS Console
2. View logs: `aws logs tail /aws/apprunner/*/application --region ap-southeast-2`
3. Common issues:
    - Health check failing (check `/health` endpoint)
    - Environment variables missing
    - Database connection issues

---

## 🔒 Security Best Practices

### 1. Keep Secrets Secret

- ✅ Store secrets in GitHub Secrets (encrypted)
- ✅ Never commit secrets to code
- ✅ Use `prod-env.json.example` as template
- ❌ Don't share secrets in chat/email

### 2. Use Least Privilege

- ✅ Create IAM user with only needed permissions
- ✅ Don't use root AWS account credentials
- ✅ Review permissions regularly

### 3. Protect Your Branches

- ✅ Use branch protection rules on `prod` branch
- ✅ Require pull request reviews
- ✅ Require status checks to pass

### 4. Monitor Deployments

- ✅ Check deployment logs regularly
- ✅ Set up CloudWatch alarms
- ✅ Review App Runner service metrics

---

## 📚 Key Concepts Explained

### What is GitHub Actions?

GitHub Actions is like a robot assistant that:

- Watches your code
- Runs commands when you push code
- Can do anything you can do manually (but automatically!)

### What is AWS ECR?

ECR = Elastic Container Registry

- Like a private Docker Hub on AWS
- Stores your Docker images
- App Runner pulls images from here

### What is AWS App Runner?

App Runner = Serverless container platform

- Runs your Docker containers
- Automatically scales up/down
- Handles load balancing
- No servers to manage!

### What is AWS CDK?

CDK = Cloud Development Kit

- Write infrastructure as code (TypeScript)
- CDK converts it to CloudFormation
- CloudFormation creates AWS resources
- Like LEGO instructions for AWS!

---

## 🎓 Summary

**What happens when you push to `prod`:**

1. ✅ Code is built
2. ✅ Docker image is created
3. ✅ Image is pushed to ECR
4. ✅ Infrastructure is deployed
5. ✅ App Runner starts your app
6. ✅ Your app is live!

**What you need:**

1. ✅ AWS credentials (Access Key ID + Secret Access Key)
2. ✅ GitHub Secrets configured
3. ✅ `prod-env.json` file with environment variables
4. ✅ Push code to `prod` branch

**That's it!** The pipeline does everything else automatically. 🎉

---

## 📞 Need Help?

If something doesn't work:

1. Check the GitHub Actions logs
2. Check AWS CloudWatch logs
3. Verify all secrets are set correctly
4. Make sure `prod-env.json` exists and has all required variables
5. Check IAM permissions

Remember: The pipeline is designed to work for both **new deployments** and **updates**. It automatically detects what needs to be created or updated!
