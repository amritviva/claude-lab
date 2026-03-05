# Postman Setup Guide

## 📥 Import API Collection

### First Time Import

1. **Generate the OpenAPI spec**:
   ```bash
   npm run generate-postman-spec
   ```

2. **Import into Postman**:
   - Open Postman
   - Click **"Import"** (top left)
   - Select **"File"** tab
   - Choose: `openapi-spec.json` (in project root)
   - Click **"Import"**

### Updating Collection (When You Add New Endpoints)

**Postman can update existing collections!** Here's how:

1. **Regenerate the spec** (includes all new endpoints):
   ```bash
   npm run generate-postman-spec
   ```

2. **Update in Postman** (two options):

   **Option A: Re-import (Recommended)**
   - Open Postman
   - Click **"Import"** (top left)
   - Select **"File"** tab
   - Choose: `openapi-spec.json`
   - Postman will detect it's an update and show: **"Update existing"** or **"Merge"**
   - Select **"Update"** or **"Merge"** (keeps your existing requests, adds new ones)
   - Click **"Import"**

   **Option B: Replace Collection**
   - Right-click your collection → **"Edit"**
   - Go to **"Import"** tab
   - Drag & drop `openapi-spec.json`
   - Choose **"Replace"** (removes old, adds all new - you'll lose custom changes)

**Note**: Postman automatically detects if the collection name matches and offers to update/merge instead of creating duplicates.

## 🔄 Switch Between Local and Production

### Step 1: Create Environments

1. Click the **"Environments"** icon (left sidebar, or top right)
2. Click **"+"** to create a new environment

**Create "Local" environment:**
- Name: `Local`
- Add variable:
  - Variable: `baseUrl`
  - Initial Value: `http://localhost:3000`
  - Current Value: `http://localhost:3000`
- Click **"Save"**

**Create "Production" environment:**
- Name: `Production`
- Add variable:
  - Variable: `baseUrl`
  - Initial Value: `https://minihub-api.viva-sls.com`
  - Current Value: `https://minihub-api.viva-sls.com`
- Click **"Save"**

### Step 2: Select Environment

1. Click the environment dropdown (top right, next to "Environments")
2. Select **"Local"** for local development
3. Select **"Production"** for production API

### Step 3: Verify

- All API requests will automatically use the selected environment's `baseUrl`
- You can see the actual URL in the request (it will show `http://localhost:3000` or `https://minihub-api.viva-sls.com`)

## 🔑 Set Up API Key Authentication

1. Go to your **Collection** → **Authorization** tab
2. Type: **API Key**
3. Key: `X-API-Key`
4. Value: `{{apiKey}}` (use environment variable)
5. Add to: **Header**

### Add API Key to Environments

**For each environment (Local/Production):**
- Add variable:
  - Variable: `apiKey`
  - Initial Value: `your-api-key-here`
  - Current Value: `your-api-key-here`

Now you can use different API keys for local and production!

## 📝 Quick Reference

**Command to generate spec:**
```bash
npm run generate-postman-spec
```

**Environment Variables:**
- `baseUrl` - API server URL (local or prod)
- `apiKey` - API key for authentication

**Switch environments:**
- Use the dropdown in top right corner of Postman
