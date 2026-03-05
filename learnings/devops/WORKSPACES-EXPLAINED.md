# NPM Workspaces Explained - Local vs Container

## 📦 How NPM Workspaces Work

### Your Project Structure

```
chargebacks/ (root)
├── package.json          ← Defines workspaces: ["app", "infra"]
├── package-lock.json     ← Contains ALL dependencies from ALL workspaces
├── node_modules/         ← ALL dependencies hoisted here (shared)
│
├── app/
│   ├── package.json      ← App-specific dependencies (dotenv, express, etc.)
│   ├── src/
│   └── (NO node_modules here - dependencies hoisted to root)
│
└── infra/
    ├── package.json      ← Infra-specific dependencies
    └── (NO node_modules here - dependencies hoisted to root)
```

## 🏠 Local Development (On Your Machine)

### What Happens When You Run `npm install` (at root):

1. **npm reads root `package.json`**:

    ```json
    {
      "workspaces": ["app", "infra"]  ← npm sees this
    }
    ```

2. **npm discovers all workspaces**:
    - Finds `app/package.json`
    - Finds `infra/package.json`
    - Reads ALL their dependencies

3. **npm installs everything in root `node_modules/`**:

    ```
    node_modules/
    ├── dotenv/              ← from app/package.json
    ├── express/             ← from app/package.json
    ├── @aws-sdk/...         ← from root/package.json
    ├── prettier/            ← from root/package.json
    └── @minihubvone/
        └── app -> ../../app ← Symlink to app workspace
    ```

4. **Dependencies are "hoisted"**:
    - All packages go to root `node_modules/`
    - No `app/node_modules/` or `infra/node_modules/`
    - This saves disk space (shared dependencies)

### Running Commands Locally:

```bash
# From root directory:
npm run dev -w app        # Runs app's "dev" script
npm run build -w app       # Runs app's "build" script

# What happens:
# 1. npm looks at root package.json
# 2. Sees "app" workspace
# 3. Runs script from app/package.json
# 4. Node.js resolves modules from root node_modules/
```

### Which `package.json` is Used?

**BOTH are used, but for different purposes:**

- **Root `package.json`**:
    - Defines workspace structure
    - Contains root-level dependencies (shared tools like Prettier, AWS SDK)
    - Contains scripts to run workspace commands

- **`app/package.json`**:
    - Defines app-specific dependencies (express, dotenv, pg, etc.)
    - Contains app-specific scripts (dev, build, start)

**When installing:**

- npm reads BOTH files
- Combines all dependencies
- Installs everything in root `node_modules/`
- Creates one `package-lock.json` at root (contains everything)

## 🐳 Container (Docker) - What's Different?

### Container Structure:

```
/app (container root)
├── package.json          ← Root workspace config (COPIED from your root)
├── package-lock.json     ← All dependencies (COPIED from your root)
├── node_modules/         ← Dependencies installed HERE (same as local)
│
└── app/
    ├── package.json      ← App dependencies (COPIED from your app/)
    ├── tsconfig.json
    ├── src/              ← Your code (mounted as volume in dev)
    └── dist/             ← Compiled code (production only)
```

### What Happens in Container:

1. **Dockerfile copies files**:

    ```dockerfile
    COPY package.json package-lock.json ./        # Root workspace config
    COPY app/package.json ./app/                   # App workspace
    ```

2. **We run `npm ci -w app`**:

    ```dockerfile
    RUN npm ci -w app
    ```

    **What `-w app` does:**
    - `-w app` = "work with app workspace only"
    - npm reads root `package.json` (sees workspaces)
    - npm reads `app/package.json` (app dependencies)
    - npm installs ONLY app workspace dependencies
    - Still installs in root `node_modules/` (hoisting)
    - Skips `infra/` workspace dependencies (we don't need them in container)

3. **Result**:
    ```
    /app/node_modules/
    ├── dotenv/              ← from app/package.json
    ├── express/             ← from app/package.json
    ├── typescript/          ← from app/package.json (dev dependency)
    └── (NO infra dependencies - we skipped them!)
    ```

### Why Use `-w app` in Container?

**Without `-w app`:**

```bash
npm ci  # Installs ALL workspaces (app + infra)
```

- Would install infra dependencies (CDK, etc.) - **we don't need them!**
- Larger Docker image
- Slower builds

**With `-w app`:**

```bash
npm ci -w app  # Installs ONLY app workspace
```

- Only installs app dependencies
- Smaller Docker image
- Faster builds
- Still uses workspace structure (root node_modules/)

## 🔄 Key Differences: Local vs Container

| Aspect                     | Local Development               | Container                            |
| -------------------------- | ------------------------------- | ------------------------------------ |
| **Where you run commands** | From root: `npm run dev -w app` | Container runs: `npm run dev -w app` |
| **node_modules location**  | Root `node_modules/`            | Container root `/app/node_modules/`  |
| **Which dependencies**     | ALL workspaces (app + infra)    | ONLY app workspace (`-w app`)        |
| **package.json used**      | Both (root + app)               | Both (root + app)                    |
| **package-lock.json**      | Root (contains everything)      | Root (contains everything)           |
| **Workspace structure**    | Maintained                      | Maintained (copied into container)   |

## 🎯 Summary

### Local Development:

- Run `npm install` at root → installs everything
- Dependencies in root `node_modules/`
- Run commands: `npm run dev -w app`
- Both `package.json` files are used (root defines workspaces, app defines dependencies)

### Container:

- Copy root `package.json` + `package-lock.json` + `app/package.json`
- Run `npm ci -w app` → installs ONLY app dependencies
- Dependencies in `/app/node_modules/` (container root)
- Run commands: `npm run dev -w app`
- Same workspace structure, but only app workspace installed

### The Connection:

**Both local and container use the SAME workspace structure:**

- Root `package.json` = workspace configuration
- `app/package.json` = app dependencies
- Root `node_modules/` = where dependencies live (hoisting)
- `package-lock.json` = exact versions (at root)

**The difference:**

- **Local**: You might install all workspaces (app + infra)
- **Container**: We install only app workspace (`-w app`) to keep image small

## 💡 Why This Works

npm workspaces are designed for monorepos:

- Multiple packages in one repo
- Shared dependencies (hoisted to root)
- Independent packages (app, infra)
- One lock file (root `package-lock.json`)

Docker respects this structure:

- We copy the workspace structure
- We install dependencies the same way (hoisted to root)
- We just limit which workspace to install (`-w app`)
