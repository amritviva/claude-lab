# Pre-Deployment Checklist

Use this checklist before deploying to ensure everything is ready.

## ✅ Configuration Files

- [ ] `infra/config/prod-env.json` exists (copied from `prod-env.json.example`)
- [ ] All required variables filled in:
    - [ ] `PROD_DB_HOST` (not `PG_HOST`)
    - [ ] `PROD_DB_NAME` (not `PG_DATABASE`)
    - [ ] `PROD_DB_USER` (not `PG_USER`)
    - [ ] `PROD_DB_PASSWORD` (not `PG_PASSWORD`)
    - [ ] `PROD_DB_PORT`
    - [ ] `API_KEY` or `API_KEYS`
    - [ ] `AWS_REGION`
    - [ ] `LOCATION_TABLE_NAME`
    - [ ] `BATCH_PAYMENT_TABLE_NAME`
    - [ ] `SEND_BATCH_REMINDER_LAMBDA_NAME`
    - [ ] `CANCEL_MEMBERSHIP_LAMBDA_NAME`
- [ ] Variable names match what your app expects (check `app/src/config.ts`)

## ✅ CDK Code Verification

- [ ] TypeScript compiles: `cd infra && npm run build` (ignore test file errors)
- [ ] CDK synthesizes: `cd infra && BRANCH_NAME=prod npx cdk synth` (no errors)
- [ ] IAM policies use specific ARNs (not wildcards):
    - [ ] DynamoDB: Only the 2 specific table ARNs
    - [ ] Lambda: Only the 2 specific function ARNs
    - [ ] DynamoDB permissions: Read-only (no write/update/delete)
- [ ] App Runner configured correctly:
    - [ ] Port: 3000
    - [ ] Health check: `/health`
    - [ ] Auto-deploy: Disabled (manual deployments)

## ✅ AWS Setup

- [ ] AWS CLI installed and configured
- [ ] AWS profiles set up:
    - [ ] Test account profile configured
    - [ ] Production account profile configured
- [ ] Can verify accounts:
    ```bash
    aws sts get-caller-identity --profile test-account
    aws sts get-caller-identity --profile prod-account
    ```

## ✅ Docker Setup

- [ ] Docker installed and running
- [ ] Can build Docker image locally:
    ```bash
    docker build -f app/Dockerfile -t test-image .
    ```

## ✅ Dependencies

- [ ] Dependencies installed: `npm install` (from root)
- [ ] CDK CLI installed: `npm install -g aws-cdk`
- [ ] CDK version: `cdk --version`

## ✅ Ready to Deploy

Once all items are checked, you're ready to follow `MANUAL_DEPLOYMENT.md`!

**First deployment order:**

1. Deploy to test account first
2. Verify it works
3. Then deploy to production account
