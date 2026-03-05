# How to Create API Keys

## Quick Start

### Method 1: Using the Script (Recommended)

Generate a secure API key with a prefix:

```bash
# Generate key with default prefix (ang_)
npm run generate-api-key

# Generate key with specific prefix
npm run generate-api-key ang_
npm run generate-api-key mobile_
npm run generate-api-key support_
npm run generate-api-key hub_
```

**Example output:**

```
🔑 Generated API Key:
======================================================================
ang_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
======================================================================

📋 Details:
   Prefix: ang_
   Length: 40 characters

💡 Usage:
   Add to .env file:
   API_KEY=ang_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
```

---

## Method 2: Manual Creation

### Step 1: Choose a Prefix

All API keys must start with one of these prefixes:

| Prefix     | Platform     | Access Level |
| ---------- | ------------ | ------------ |
| `ang_`     | Angelo       | Full access  |
| `mobile_`  | Mobile App   | Limited      |
| `support_` | Support Team | Read-only    |
| `hub_`     | Hub Platform | Full access  |

### Step 2: Generate Random String

Use any secure random generator:

**Option A: Using Node.js**

```bash
node -e "console.log('ang_' + require('crypto').randomBytes(24).toString('hex'))"
```

**Option B: Using OpenSSL**

```bash
echo "ang_$(openssl rand -hex 24)"
```

**Option C: Online Generator**

- Use a secure random string generator
- Add your prefix manually: `ang_` + random_string

### Step 3: Format

Your API key should look like:

```
ang_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
```

**Format:** `{prefix}{random_hex_string}` (40+ characters total)

---

## Storing API Keys

### Local Development (.env file)

Create or update `app/.env`:

```bash
# Single key
API_KEY=ang_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0

# OR multiple keys (comma-separated)
API_KEYS=ang_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0,mobile_b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1,support_c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2
```

**Note:** Use either `API_KEY` (single) OR `API_KEYS` (multiple), not both.

### Production (GitHub Secrets)

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Add or update `PROD_ENV_JSON` secret
4. Include your API keys in the JSON:

```json
{
    "API_KEYS": "ang_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0,mobile_b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1"
}
```

---

## Complete Example

### 1. Generate Keys for All Platforms

```bash
# Generate keys
npm run generate-api-key ang_    # For Angelo (full access)
npm run generate-api-key mobile_ # For Mobile App (limited)
npm run generate-api-key support_ # For Support Team (read-only)
npm run generate-api-key hub_    # For Hub Platform (full access)
```

### 2. Add to .env

```bash
API_KEYS=ang_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0,mobile_b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1,support_c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2,hub_d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3
```

### 3. Test the Keys

```bash
# Test Angelo key (full access)
curl -H "X-API-Key: ang_a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0" \
  http://localhost:3000/api/locations

# Test Mobile key (limited access)
curl -H "X-API-Key: mobile_b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1" \
  http://localhost:3000/api/locations

# Test Mobile key on restricted endpoint (should fail)
curl -H "X-API-Key: mobile_b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1" \
  http://localhost:3000/api/email-attachments
# Expected: 403 Forbidden
```

---

## Security Best Practices

1. ✅ **Use the script** - It generates cryptographically secure random keys
2. ✅ **Use long keys** - At least 40 characters (prefix + 32+ random chars)
3. ✅ **Never commit keys** - Keep them in `.env` (gitignored) or GitHub Secrets
4. ✅ **Rotate keys regularly** - Generate new keys periodically
5. ✅ **Use different keys per environment** - Dev, staging, production
6. ✅ **Log key usage** - Monitor which keys access which endpoints

---

## Troubleshooting

### "Invalid API key" error

- ✅ Check the key starts with a valid prefix (`ang_`, `mobile_`, `support_`, `hub_`)
- ✅ Verify the key is in your `API_KEYS` environment variable
- ✅ Make sure there are no extra spaces or quotes
- ✅ Restart the server after updating `.env`

### "API key prefix does not have access" error

- ✅ Check which endpoints your prefix can access in `app/src/config/api-keys.ts`
- ✅ Verify you're using the correct prefix for the endpoint
- ✅ Update endpoint access in the config file if needed

### Key not working in production

- ✅ Verify `PROD_ENV_JSON` GitHub Secret is updated
- ✅ Check the JSON format is valid
- ✅ Ensure `API_KEYS` is included in the JSON
- ✅ Redeploy after updating the secret

---

## Quick Reference

```bash
# Generate key
npm run generate-api-key [prefix]

# Valid prefixes
ang_      # Angelo (full access)
mobile_   # Mobile App (limited)
support_  # Support Team (read-only)
hub_      # Hub Platform (full access)

# Add to .env
API_KEYS=key1,key2,key3

# Test key
curl -H "X-API-Key: your-key" http://localhost:3000/api/locations
```

---

## Need Help?

- See [API Keys Guide](./API-KEYS-GUIDE.md) for detailed configuration
- Check [API Naming Conventions](./API-NAMING-CONVENTIONS.md) for endpoint info
- Review logs to see which keys are being used
