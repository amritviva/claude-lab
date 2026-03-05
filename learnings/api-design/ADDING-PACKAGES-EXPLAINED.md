# Adding Packages Guide

This guide explains how to add new npm packages to the MiniHubVOne project.

## 📋 Quick Summary

**For app packages** (like `date-fns`, `axios`, `lodash`):

1. Add to `app/package.json` → `dependencies` or `devDependencies`
2. Commit the file
3. CI/CD will install automatically, OR run `npm install` at root locally

**For shared packages** (used by both app and infra):

1. Add to root `package.json` → `dependencies` or `devDependencies`
2. Commit the file
3. CI/CD will install automatically, OR run `npm install` at root locally

---

## 🎯 Step-by-Step Process

### Method 1: Manual Edit (Recommended - No Local Install Needed)

#### For App Packages (Most Common)

1. **Edit `app/package.json`**:

    ```json
    {
        "dependencies": {
            "date-fns": "^3.6.0",
            "axios": "^1.7.0"
            // ... existing packages
        }
    }
    ```

2. **For TypeScript types** (if needed):

    ```json
    {
        "devDependencies": {
            "@types/node": "^20.11.30"
            // ... existing packages
        }
    }
    ```

3. **Commit the file**:

    ```bash
    git add app/package.json
    git commit -m "feat: add date-fns and axios packages"
    git push
    ```

4. **CI/CD will install automatically** when you push, OR run locally:
    ```bash
    npm install  # At root level
    ```

#### For Shared Packages (Rare)

1. **Edit root `package.json`**:

    ```json
    {
        "dependencies": {
            "shared-package": "^1.0.0"
        }
    }
    ```

2. **Commit and push** (same as above)

---

### Method 2: Using npm install Command

**Important**: Always run `npm install` at the **root level**, not in `app/` or `infra/` directories.

#### For App Packages

```bash
# From project root
cd /Users/Amrit.Regmi/Desktop/minihubvone

# Install to app workspace
npm install date-fns axios -w app

# For dev dependencies
npm install @types/node -w app --save-dev
```

This will:

- ✅ Automatically update `app/package.json`
- ✅ Install packages in root `node_modules/` (hoisted)
- ✅ Update `package-lock.json`

#### For Root/Shared Packages

```bash
# From project root
npm install shared-package

# For dev dependencies
npm install shared-package --save-dev
```

---

## 📦 Common Packages You Might Want

### Date/Time Utilities

```json
"date-fns": "^3.6.0"  // Modern date utility library
```

### HTTP Client

```json
"axios": "^1.7.0"  // HTTP client (alternative to fetch)
```

### Utilities

```json
"lodash": "^4.17.21"  // Utility functions
"uuid": "^10.0.0"     // UUID generation
"zod": "^3.23.0"      // Schema validation
```

### TypeScript Types (devDependencies)

```json
"@types/lodash": "^4.17.0"
"@types/uuid": "^10.0.0"
```

---

## ✅ Best Practices

### 1. Always Install at Root

```bash
# ✅ Correct
cd /Users/Amrit.Regmi/Desktop/minihubvone
npm install date-fns -w app

# ❌ Wrong
cd app
npm install date-fns
```

### 2. Use Workspace Flag for App Packages

```bash
# ✅ Correct - installs to app workspace
npm install date-fns -w app

# ⚠️ Works but installs to root (not recommended for app-specific packages)
npm install date-fns
```

### 3. Check package.json Location

- **App packages** → `app/package.json`
- **Infra packages** → `infra/package.json`
- **Shared packages** → Root `package.json`

### 4. Version Pinning

Use exact versions or caret ranges:

```json
"date-fns": "^3.6.0"  // Allows patch/minor updates
"axios": "1.7.0"      // Exact version (more strict)
```

---

## 🔍 Verifying Installation

### Check if Package is Installed

```bash
# From root
npm list date-fns -w app

# Or check node_modules
ls node_modules/date-fns
```

### Check package.json

```bash
# Verify it's in app/package.json
cat app/package.json | grep date-fns
```

---

## 🚀 Using the Package

After adding to `package.json` and installing:

```typescript
// In app/src/your-file.ts
import { format } from "date-fns";
import axios from "axios";

// Use the package
const formattedDate = format(new Date(), "yyyy-MM-dd");
const response = await axios.get("https://api.example.com");
```

---

## 🐛 Troubleshooting

### "Cannot find module" Error

**Problem**: Package not found after adding to package.json

**Solution**:

1. Make sure you ran `npm install` at root level
2. Check package is in correct `package.json` (app vs root)
3. Verify package name is correct
4. Delete `node_modules` and `package-lock.json`, then reinstall:
    ```bash
    rm -rf node_modules package-lock.json
    npm install
    ```

### Package Installed in Wrong Location

**Problem**: Package in root but should be in app

**Solution**:

1. Remove from root `package.json`
2. Add to `app/package.json`
3. Run `npm install -w app <package>`

### TypeScript Types Missing

**Problem**: TypeScript errors for installed package

**Solution**:

1. Install types package: `npm install @types/<package> -w app --save-dev`
2. Or check if package includes types (many modern packages do)

---

## 📝 Example: Adding date-fns and axios

### Step 1: Edit app/package.json

```json
{
    "dependencies": {
        "date-fns": "^3.6.0",
        "axios": "^1.7.0"
        // ... existing packages
    }
}
```

### Step 2: Install (choose one)

**Option A: Let CI/CD install** (just commit and push)

```bash
git add app/package.json
git commit -m "feat: add date-fns and axios"
git push
```

**Option B: Install locally**

```bash
npm install -w app
```

### Step 3: Use in Code

```typescript
import { format, parseISO } from "date-fns";
import axios from "axios";

// Example usage
const date = format(new Date(), "yyyy-MM-dd");
const response = await axios.get("https://api.example.com/data");
```

---

## 🎓 Key Points to Remember

1. ✅ **Always install at root level** - Never `cd app && npm install`
2. ✅ **Use `-w app` flag** for app-specific packages
3. ✅ **Edit package.json manually** if you don't want to run npm install locally
4. ✅ **CI/CD will install** automatically when you push package.json changes
5. ✅ **Dependencies are hoisted** to root `node_modules/` automatically
6. ✅ **Check both package.json files** - app and root have separate dependencies

---

## 🔗 Related Documentation

- [npm workspaces documentation](https://docs.npmjs.com/cli/v10/using-npm/workspaces)
- [Main README](./README.md) - Project overview
- [Cursor Rules](./.cursorrules) - Coding conventions

---

**Happy Coding! 🚀**
