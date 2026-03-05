# Deployment Summary

## What Was Created

All CDK infrastructure code is ready for deployment. **No resources have been deployed yet.**

### Files Created/Modified

1. **`infra/lib/infra-stack.ts`** - Main infrastructure code
    - ECR repository creation
    - IAM role with DynamoDB and Lambda permissions
    - App Runner service configuration
    - Reads environment variables from `config/prod-env.json`

2. **`infra/config/prod-env.json.example`** - Template for production environment variables
    - Copy this to `prod-env.json` and fill in your values
    - **DO NOT commit `prod-env.json` to git** (already in `.gitignore`)

3. **`infra/README.md`** - Complete deployment guide
    - Step-by-step instructions
    - Commands to run
    - Troubleshooting tips

4. **`.cursorrules`** - Updated with environment variable documentation

5. **`.gitignore`** - Added `infra/config/prod-env.json` to prevent committing secrets

### Resources That Will Be Created (When You Deploy)

1. **ECR Repository**: `minihubvone-prod`
    - Stores Docker images
    - Lifecycle: keeps last 10 images

2. **IAM Role**: `minihubvone-prod-apprunner-role`
    - DynamoDB read/write access
    - Lambda invoke permissions
    - CloudWatch Logs write access

3. **App Runner Service**: `minihubvone-prod-apprunner`
    - Runs your Docker container
    - Port: 3000
    - Health check: `/health`
    - CPU: 1 vCPU, Memory: 2 GB

## Next Steps

### 1. Configure Production Environment Variables

```bash
cd infra
cp config/prod-env.json.example config/prod-env.json
# Edit config/prod-env.json and fill in your values
```

### 2. Verify Code Compiles

```bash
cd infra
npm run build
```

### 3. Review What Will Be Created

```bash
cd infra
BRANCH_NAME=prod npx cdk synth
BRANCH_NAME=prod npx cdk diff
```

### 4. Deploy (When Ready)

```bash
cd infra
BRANCH_NAME=prod npx cdk deploy
```

### 5. Build and Push Docker Image

After deployment, you'll get an ECR repository URI. Then:

```bash
# Build image
docker build -f app/Dockerfile -t <ECR_URI>:latest .

# Login to ECR
aws ecr get-login-password --region ap-southeast-2 | docker login --username AWS --password-stdin <ECR_URI>

# Push image
docker push <ECR_URI>:latest
```

## Important Notes

- **Only prod environment creates resources** - dev runs locally via Docker Compose
- **Environment variables** are read from `infra/config/prod-env.json`
- **Same Dockerfile** is used for both local and production
- **IAM role** replaces AWS credentials file (no need for AWS_PROFILE in prod)
- **No deployment happens automatically** - you control when to deploy

## Commands Reference

```bash
# Compile TypeScript
cd infra && npm run build

# Synthesize CloudFormation template (see what will be created)
cd infra && BRANCH_NAME=prod npx cdk synth

# See differences
cd infra && BRANCH_NAME=prod npx cdk diff

# Deploy
cd infra && BRANCH_NAME=prod npx cdk deploy

# Destroy (CAREFUL - deletes everything!)
cd infra && BRANCH_NAME=prod npx cdk destroy
```
