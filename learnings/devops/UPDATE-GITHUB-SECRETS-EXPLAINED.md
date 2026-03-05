# How to Update GitHub Secrets for Production

## Overview

When you update your production environment variables (especially API keys), you need to update the GitHub Secret `PROD_ENV_JSON` so that CI/CD deployments use the latest values.

---

## Step 1: Update Your Local `prod-env.json`

1. Copy the example file:

    ```bash
    cp infra/config/prod-env.json.example infra/config/prod-env.json
    ```

2. Fill in your production values in `infra/config/prod-env.json`

3. **Important**: Include all your API keys with prefixes:
    ```json
    {
        "API_KEY": "ang_your-key-here,mobile_your-key-here,support_your-key-here,hub_your-key-here"
    }
    ```

---

## Step 2: Copy JSON to GitHub Secret

### Option A: Using GitHub Web UI (Recommended)

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Find `PROD_ENV_JSON` secret
4. Click **Update** (or create it if it doesn't exist)
5. Copy the **entire JSON** from `infra/config/prod-env.json`
6. Paste it into the secret value
7. Click **Update secret**

### Option B: Using GitHub CLI

```bash
# Read your prod-env.json file
cat infra/config/prod-env.json | gh secret set PROD_ENV_JSON
```

---

## Step 3: Verify the Secret

The secret should contain valid JSON. Example structure:

```json
{
    "NODE_ENV": "production",
    "PORT": "3000",
    "AWS_REGION": "ap-southeast-2",
    "API_KEY": "ang_abc123...,mobile_def456...,support_ghi789...,hub_jkl012...",
    "PROD_DB_HOST": "your-host.example.com",
    "PROD_DB_PORT": "5432",
    "PROD_DB_NAME": "your_database",
    "PROD_DB_USER": "your_user",
    "PROD_DB_PASSWORD": "your_password",
    "PG_SSL": "true",
    "S3_BASE_URL": "https://your-bucket.s3.region.amazonaws.com"
}
```

---

## Important Notes

### ✅ What to Include

- **API_KEY** or **API_KEYS**: All your API keys (comma-separated, with prefixes)
- **Database credentials**: PROD*DB*\_ or PG\_\_ variables
- **AWS_REGION**: Your AWS region
- **Optional variables**: WEBHOOK_SECRET, S3_BASE_URL

### ❌ What NOT to Include

- **Table names**: Stored in `app/src/config/aws-resources.ts` (not secrets)
- **Lambda names**: Stored in `app/src/config/aws-resources.ts` (not secrets)
- **Comments**: Remove `_comment`, `_note`, etc. from JSON (or keep them, they're ignored)

### 🔒 Security

- ✅ GitHub Secrets are encrypted
- ✅ Never commit `prod-env.json` to git (it's in `.gitignore`)
- ✅ Use different keys for dev/staging/production
- ✅ Rotate keys regularly

---

## After Updating

1. **Next deployment** will automatically use the new values
2. **No code changes needed** - just update the secret
3. **App Runner** will restart with new environment variables

---

## Troubleshooting

### "Invalid JSON" error

- ✅ Check that your JSON is valid (use a JSON validator)
- ✅ Remove trailing commas
- ✅ Ensure all strings are quoted
- ✅ Escape special characters in passwords

### "Missing environment variable" error

- ✅ Verify all required variables are in the secret
- ✅ Check variable names match exactly (case-sensitive)
- ✅ Ensure API_KEY includes all prefixes you need

### Keys not working after update

- ✅ Verify keys are comma-separated (no spaces around commas)
- ✅ Check that keys start with correct prefixes (`ang_`, `mobile_`, etc.)
- ✅ Restart App Runner service if needed

---

## Quick Reference

```bash
# 1. Update local file
nano infra/config/prod-env.json

# 2. Copy JSON content
cat infra/config/prod-env.json

# 3. Paste into GitHub Secret: Settings → Secrets → PROD_ENV_JSON

# 4. Next deployment will use new values automatically
```

---

## Example: Adding a New API Key

1. Generate new key:

    ```bash
    npm run generate-api-key mobile_
    ```

2. Add to `infra/config/prod-env.json`:

    ```json
    {
        "API_KEY": "ang_existing...,mobile_new-key-here,support_existing...,hub_existing..."
    }
    ```

3. Update GitHub Secret `PROD_ENV_JSON` with the new JSON

4. Done! Next deployment will include the new key.
