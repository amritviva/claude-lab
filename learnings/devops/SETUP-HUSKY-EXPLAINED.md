# Husky Setup Instructions

## ⚠️ Important: One-Time Setup Required

Husky needs to be initialized **once** after installing dependencies. This sets up git hooks to run on **ALL branches** (main, prod, feature branches, etc.).

## 🚀 Setup Steps

### Step 1: Install Dependencies

```bash
# From project root
npm install
```

This installs Husky and lint-staged.

### Step 2: Initialize Husky

```bash
# This sets up git hooks
npm run prepare
```

Or manually:

```bash
npx husky install
git config core.hooksPath .husky
```

### Step 3: Verify It Works

Try making a small change and committing:

```bash
# Make a test change
echo "# Test" >> test-file.md

# Stage it
git add test-file.md

# Try to commit - hooks should run now
git commit -m "test: verify pre-commit hooks"
```

You should see the pre-commit checks running!

### Step 4: Clean Up Test File

```bash
git reset HEAD test-file.md
rm test-file.md
```

## ✅ Verification

Check that git hooks are configured:

```bash
git config core.hooksPath
```

Should output: `.husky`

## 🔍 How It Works

- **Runs on ALL branches** - main, prod, feature branches, etc.
- **Blocks commits** if any check fails
- **Auto-fixes formatting** before committing
- **Tests Docker build** to catch App Runner issues early

## 🐛 Troubleshooting

### "Husky command not found"

**Solution**: Run `npm install` first to install Husky.

### "Hooks not running"

**Solution**:

1. Run `npm run prepare`
2. Verify: `git config core.hooksPath` should show `.husky`
3. Check `.husky/pre-commit` is executable: `chmod +x .husky/pre-commit`

### "Permission denied"

**Solution**:

```bash
chmod +x .husky/pre-commit
chmod +x .husky/_/husky.sh
```

---

**After setup, pre-commit hooks will run automatically on every commit! 🎉**
