# Environment Variables: How They Flow from JSON to Container

## The Complete Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. YOU: Edit prod-env.json                                  │
│                                                              │
│ {                                                            │
│   "API_KEY": "my-secret-key",                               │
│   "PG_HOST": "db.example.com"                              │
│ }                                                            │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. CDK: Reads prod-env.json (infra-stack.ts line 149)       │
│                                                              │
│ const config = JSON.parse(configContent);                    │
│ // Result: { API_KEY: "my-secret-key", PG_HOST: "..." }    │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. CDK: Converts to App Runner Format (lines 153-158)       │
│                                                              │
│ envVars = [                                                  │
│   { name: "API_KEY", value: "my-secret-key" },             │
│   { name: "PG_HOST", value: "db.example.com" }              │
│ ]                                                            │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. CDK: Passes to App Runner (line 187)                      │
│                                                              │
│ runtimeEnvironmentVariables: envVars                         │
│                                                              │
│ This tells App Runner: "Set these env vars in the container"│
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. APP RUNNER: Injects into Container                        │
│                                                              │
│ When App Runner starts your container, it:                   │
│ - Sets: export API_KEY="my-secret-key"                      │
│ - Sets: export PG_HOST="db.example.com"                     │
│ - Makes them available as process.env in Node.js            │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. YOUR APP: Reads via process.env (config.ts)              │
│                                                              │
│ const apiKey = process.env.API_KEY;                          │
│ // Result: "my-secret-key"                                   │
│                                                              │
│ const dbHost = process.env.PG_HOST;                          │
│ // Result: "db.example.com"                                  │
└─────────────────────────────────────────────────────────────┘
```

## Format Comparison

### Local Development (.env file):

```bash
# app/.env (for local Docker)
API_KEY=my-secret-key
PG_HOST=db.example.com
PG_PASSWORD=secret123
```

### Production (prod-env.json):

```json
{
    "API_KEY": "my-secret-key",
    "PG_HOST": "db.example.com",
    "PG_PASSWORD": "secret123"
}
```

**Key Difference:**

- `.env` = Plain text, `KEY=value` format
- `prod-env.json` = JSON format, `"KEY": "value"` format

**Why JSON?**

- CDK reads it as JSON (line 150: `JSON.parse()`)
- Easier to parse programmatically
- Can include comments (keys starting with `_`)

## How App Runner Injects Variables

### Step-by-Step:

1. **CDK Deployment** (`cdk deploy`):
    - CDK reads `prod-env.json`
    - Converts to App Runner format
    - Passes to App Runner service configuration
    - App Runner stores these variables in its configuration

2. **Container Startup** (when App Runner runs your image):
    - App Runner pulls image from ECR
    - Starts container
    - **Before running your app**, App Runner sets environment variables:
        ```bash
        export API_KEY="my-secret-key"
        export PG_HOST="db.example.com"
        export PG_PASSWORD="secret123"
        # ... all other variables from prod-env.json
        ```

3. **Your App Runs**:
    - Node.js process starts
    - All environment variables are available in `process.env`
    - Your `config.ts` reads them:
        ```typescript
        process.env.API_KEY; // ✅ Available!
        process.env.PG_HOST; // ✅ Available!
        ```

## Important Notes

### Variable Names Must Match

Your app code (`app/src/config.ts`) reads specific variable names:

```typescript
// config.ts expects these names:
process.env.API_KEY; // ✅
process.env.PG_HOST; // ✅
process.env.PG_PASSWORD; // ✅
process.env.LOCATION_TABLE_NAME; // ✅
```

So `prod-env.json` must use **exactly** these names:

```json
{
    "API_KEY": "...", // ✅ Matches
    "PG_HOST": "...", // ✅ Matches
    "PG_PASSWORD": "...", // ✅ Matches
    "LOCATION_TABLE_NAME": "..." // ✅ Matches
}
```

### Comments in JSON

Keys starting with `_` are ignored (filtered out by CDK):

```json
{
    "_comment": "This is ignored",
    "API_KEY": "this-is-used" // ✅ This is used
}
```

### Adding New Variables

1. **Add to `prod-env.json`:**

    ```json
    {
        "NEW_VARIABLE": "new-value"
    }
    ```

2. **Redeploy CDK:**

    ```bash
    cd infra
    BRANCH_NAME=prod npx cdk deploy
    ```

3. **Your app automatically has access:**
    ```typescript
    const value = process.env.NEW_VARIABLE; // ✅ Available!
    ```

**No code changes needed!** Just add to JSON and redeploy.

## Example: Complete Flow

### 1. You edit `prod-env.json`:

```json
{
    "API_KEY": "abc123",
    "PG_HOST": "prod-db.example.com"
}
```

### 2. CDK reads and converts:

```typescript
// CDK code (infra-stack.ts)
const config = JSON.parse(fs.readFileSync("prod-env.json"));
// Result: { API_KEY: "abc123", PG_HOST: "prod-db.example.com" }

const envVars = [
    { name: "API_KEY", value: "abc123" },
    { name: "PG_HOST", value: "prod-db.example.com" },
];
```

### 3. CDK passes to App Runner:

```typescript
runtimeEnvironmentVariables: envVars;
```

### 4. App Runner sets in container:

```bash
# Inside the container (automatically set by App Runner)
export API_KEY="abc123"
export PG_HOST="prod-db.example.com"
```

### 5. Your app reads:

```typescript
// app/src/config.ts
const apiKey = process.env.API_KEY; // "abc123" ✅
const dbHost = process.env.PG_HOST; // "prod-db.example.com" ✅
```

## Summary

| Aspect             | Details                                           |
| ------------------ | ------------------------------------------------- |
| **Format**         | JSON (not .env format)                            |
| **Location**       | `infra/config/prod-env.json`                      |
| **Read by**        | CDK (infra-stack.ts line 149)                     |
| **Converted to**   | App Runner format (array of {name, value})        |
| **Injected by**    | App Runner (automatically when container starts)  |
| **Available as**   | `process.env.VARIABLE_NAME` in your app           |
| **Variable names** | Must match what your app expects (from config.ts) |

The container doesn't need to do anything special - App Runner automatically injects all variables from `prod-env.json` before your app starts!
