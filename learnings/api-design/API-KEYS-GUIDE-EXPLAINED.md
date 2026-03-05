# API Keys Configuration Guide

## Overview

API keys use **prefixes** to control which endpoints each key can access. This allows you to give different platforms/teams different levels of access.

## Key Prefixes

All API keys must start with one of these prefixes:

| Prefix     | Platform     | Access Level |
| ---------- | ------------ | ------------ |
| `ang_`     | Angular/Web  | Full access  |
| `mobile_`  | Mobile App   | Limited      |
| `support_` | Support Team | Read-only    |
| `hub_`     | Hub Platform | Full access  |

## How It Works

1. **Create API keys with prefixes**:

    ```
    ang_abc123xyz
    mobile_def456uvw
    support_ghi789rst
    hub_jkl012mno
    ```

2. **Each prefix has allowed endpoints** defined in `app/src/config/api-keys.ts`

3. **The middleware checks**:
    - Does the key have a valid prefix?
    - Can this prefix access the requested endpoint?

## Current Endpoint Access

### Full Access (`ang_`, `hub_`)

- All endpoints (full access)

### Limited Access (`mobile_`, `support_`)

- `/api/locations` - Get all locations
- `/api/get-batch` - Get batch payment count
- `/api/offline-access` - Get offline access data

## Adding a New Endpoint

When you add a new endpoint, update `app/src/config/api-keys.ts`:

```typescript
export const API_KEY_CONFIG = {
    mobile_: {
        name: "Mobile App",
        allowedEndpoints: [
            "/api/locations",
            "/api/get-batch",
            "/api/offline-access",
            "/api/new-endpoint", // ← Add here
        ],
    },
    // ...
};
```

## Adding a New Prefix

1. Add to `API_KEY_CONFIG` in `app/src/config/api-keys.ts`:

    ```typescript
    newprefix_: {
        name: "New Platform",
        allowedEndpoints: ["/api/some-endpoint"],
    },
    ```

2. That's it! The system automatically recognizes the new prefix.

## Environment Variables

Set your API keys in environment variables (comma-separated):

```bash
# Single key
API_KEY=ang_abc123xyz

# Multiple keys
API_KEYS=ang_abc123xyz,mobile_def456uvw,support_ghi789rst,hub_jkl012mno
```

## Example Usage

```bash
# Full access key
curl -H "X-API-Key: ang_abc123xyz" http://localhost:3000/api/email-attachments

# Limited access key (will work)
curl -H "X-API-Key: mobile_def456uvw" http://localhost:3000/api/locations

# Limited access key (will fail - no access)
curl -H "X-API-Key: mobile_def456uvw" http://localhost:3000/api/email-attachments
# Response: 403 Forbidden - "API key prefix 'mobile_' does not have access to /api/email-attachments"
```

## Security Notes

- ✅ Keys are validated against the configured list
- ✅ Prefix must match exactly (case-sensitive)
- ✅ Endpoint access is checked on every request
- ✅ Invalid keys return 403 Forbidden
- ✅ Missing prefix returns helpful error message
