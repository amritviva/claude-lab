# 🐳 Docker Guide - Understanding Containerization

## 📖 The Story: What is Docker?

Imagine you're packing for a trip. You want to make sure everything you need is in your suitcase:

- Your clothes (application code)
- Your toiletries (dependencies)
- Your travel guide (configuration)

Docker does the same thing for software. It packages your application with everything it needs to run, creating a "container" that works the same way on:

- Your laptop (development)
- Your teammate's laptop
- A server in the cloud
- AWS App Runner

**The Magic**: "It works on my machine" becomes "It works everywhere!"

---

## 🎯 What We're Building

We're creating containers that:

1. **Development**: Sync code changes instantly (no rebuild needed)
2. **Production**: Optimized, compiled, and ready for deployment

---

## 📁 File Structure

```
minihubvone/
├── docker-compose.dev.yml      # Development configuration (with code syncing)
├── docker-compose.prod.yml     # Production configuration (optimized)
├── app/
│   ├── Dockerfile              # Production build (multi-stage, optimized)
│   ├── Dockerfile.dev          # Development build (with hot reload)
│   ├── .dockerignore           # Files to exclude from container
│   ├── .env                    # Environment variables (secrets!)
│   └── src/                    # Our application code
└── app/DOCKER.md               # This file
```

---

## 🔍 Understanding the Dockerfiles

### Development Dockerfile (`Dockerfile.dev`)

**Purpose**: Local development with live code syncing

```dockerfile
FROM node:22-alpine
```

- Starts with Node.js 22 on Alpine Linux
- Alpine = tiny (5MB vs 150MB)

```dockerfile
WORKDIR /app
```

- Sets working directory to `/app`

```dockerfile
COPY package.json package-lock.json ./
RUN npm ci
```

- Copies package files and installs dependencies
- Includes dev dependencies (TypeScript, ts-node-dev)

```dockerfile
CMD ["npx", "ts-node-dev", "--respawn", "--transpile-only", "src/server.ts"]
```

- Uses `ts-node-dev` for hot reloading
- `--respawn` = restart on file changes
- `--transpile-only` = faster (skips type checking)

**Key Point**: Source code is NOT copied into image. It's synced via volumes!

---

### Production Dockerfile (`Dockerfile`)

**Purpose**: Optimized production build

**Stage 1: Builder**

- Compiles TypeScript → JavaScript
- Includes all dependencies (needed for compilation)

**Stage 2: Runner**

- Only production dependencies
- Only compiled code (no source files)
- Much smaller image size

**Key Point**: Everything is baked into the image. No code syncing!

---

## 🎮 Understanding Docker Compose

Docker Compose orchestrates containers. Instead of long Docker commands, you write config files.

### Development vs Production

| Feature          | Development          | Production           |
| ---------------- | -------------------- | -------------------- |
| **Code Syncing** | ✅ Yes (volumes)     | ❌ No (baked in)     |
| **Hot Reload**   | ✅ Yes (ts-node-dev) | ❌ No (compiled)     |
| **Image Size**   | Larger (dev deps)    | Smaller (prod only)  |
| **Build Time**   | Fast (no compile)    | Slower (compiles TS) |
| **Use Case**     | Local development    | Deployment           |

---

## 🚀 How to Use Docker

### Development Mode (Live Code Syncing)

**Step 1: Prepare Environment**

```bash
# Create .env file if it doesn't exist
cp app/.env.example app/.env  # if you have an example file
# Edit with your values
nano app/.env
```

**Step 2: Start Development Container**

```bash
# Build and start (first time)
docker-compose -f docker-compose.dev.yml up --build

# Or start in background
docker-compose -f docker-compose.dev.yml up -d --build
```

**What Happens:**

1. Docker builds image from `Dockerfile.dev`
2. Creates container with volume mounts
3. Your `src/` folder is synced to container
4. `ts-node-dev` watches for changes
5. When you edit code → container automatically restarts!

**Step 3: Make Changes**

```bash
# Edit any file in app/src/
# Example: app/src/routes/health.ts

# Save the file
# Container automatically detects change and restarts!
# Check logs to see it restarting
docker-compose -f docker-compose.dev.yml logs -f
```

**Step 4: View Logs**

```bash
# Follow logs
docker-compose -f docker-compose.dev.yml logs -f

# See last 50 lines
docker-compose -f docker-compose.dev.yml logs --tail=50
```

**Step 5: Stop Container**

```bash
docker-compose -f docker-compose.dev.yml down
```

---

### Production Mode (Optimized Build)

**Step 1: Build Production Image**

```bash
docker-compose -f docker-compose.prod.yml build
```

**What Happens:**

1. Docker reads `Dockerfile`
2. Stage 1: Compiles TypeScript → JavaScript
3. Stage 2: Creates lean production image
4. Only production dependencies included

**Step 2: Start Production Container**

```bash
docker-compose -f docker-compose.prod.yml up -d
```

**Step 3: Test**

```bash
curl http://localhost:3000/health
```

**Step 4: Stop**

```bash
docker-compose -f docker-compose.prod.yml down
```

---

## 🔄 Understanding Code Syncing (Development)

### How Volumes Work

```yaml
volumes:
    - ./app/src:/app/src:ro
```

**Breaking it down:**

- `./app/src` = your local folder (on your computer)
- `:/app/src` = container folder (inside container)
- `:ro` = read-only (container can't modify your files)

**What happens:**

1. You edit `app/src/routes/health.ts` on your computer
2. Docker immediately syncs it to `/app/src/routes/health.ts` in container
3. `ts-node-dev` detects the change
4. Container restarts automatically
5. Your changes are live!

**Visual:**

```
Your Computer          Docker Container
─────────────          ────────────────
app/src/      ──────>  /app/src/
  health.ts   ──────>    health.ts
  (you edit)            (auto-synced!)
```

---

## 🧠 Understanding .dockerignore

`.dockerignore` tells Docker what NOT to copy into the container.

**Why it matters:**

- Smaller images (faster builds, faster downloads)
- Security (don't copy secrets)
- Efficiency (don't copy unnecessary files)

**What we exclude:**

- `node_modules` - installed inside container
- `dist` - generated during build
- `.env` - loaded via docker-compose
- `test/` - not needed in production
- `*.md` - documentation not needed

**Example:**

```
# Without .dockerignore
Image size: 500MB (includes test files, docs, etc.)

# With .dockerignore
Image size: 150MB (only what's needed)
```

---

## 🔧 Common Commands

### Development

```bash
# Start development container
docker-compose -f docker-compose.dev.yml up --build

# Start in background
docker-compose -f docker-compose.dev.yml up -d --build

# View logs
docker-compose -f docker-compose.dev.yml logs -f

# Stop
docker-compose -f docker-compose.dev.yml down

# Restart (if something breaks)
docker-compose -f docker-compose.dev.yml restart
```

### Production

```bash
# Build production image
docker-compose -f docker-compose.prod.yml build

# Start production container
docker-compose -f docker-compose.prod.yml up -d

# View logs
docker-compose -f docker-compose.prod.yml logs -f

# Stop
docker-compose -f docker-compose.prod.yml down
```

### Getting Inside Container

```bash
# Development container
docker-compose -f docker-compose.dev.yml exec minihubvone-app sh

# Production container
docker-compose -f docker-compose.prod.yml exec minihubvone-app sh

# Once inside, you can:
ls -la              # See files
pwd                 # Current directory
cat package.json    # View file
env                 # See environment variables
exit                # Leave container
```

### Debugging

```bash
# Rebuild from scratch (no cache)
docker-compose -f docker-compose.dev.yml build --no-cache

# See what Docker is doing
docker-compose -f docker-compose.dev.yml up --build

# Check if port is in use
lsof -i :3000

# Remove all stopped containers
docker container prune

# See container resource usage
docker stats minihubvone-app-dev
```

---

## 🧠 Understanding the Request/Response Cycle

```
┌─────────────────────────────────────────────────────────────┐
│ 1. You type: curl http://localhost:3000/health            │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. Request goes to your computer's port 3000               │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. Docker intercepts (port mapping 3000:3000)            │
│    "Oh! This is for the container!"                        │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. Request enters the container                            │
│    Goes to container's port 3000                           │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. Express app receives the request                        │
│    - Request logger logs it                                │
│    - Routes to /health handler                             │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. Handler processes and returns response                  │
│    { "status": "ok" }                                       │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. Response travels back through Docker port mapping       │
└───────────────────────┬───────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│ 8. You receive the response                                │
└─────────────────────────────────────────────────────────────┘
```

**Key Point**: The container is like a separate computer inside your computer. Docker handles the networking between them.

---

## 🎓 Key Concepts Explained

### Image vs Container

**Image** = Blueprint (like a recipe)

- Created by `docker build`
- Immutable (can't change it)
- Can create many containers from one image

**Container** = Running instance (like a house built from blueprint)

- Created by `docker-compose up`
- Mutable (can change while running)
- Can start/stop/restart

**Analogy**:

- Image = Cookie cutter
- Container = Cookie (you can make many cookies from one cutter)

---

### Volumes (Code Syncing)

**Volume** = Shared folder between your computer and container

**Development:**

```yaml
volumes:
    - ./app/src:/app/src:ro
```

- Your `app/src/` folder is shared with container
- Changes sync instantly
- `:ro` = read-only (container can't modify)

**Production:**

- No volumes (code is baked into image)
- Faster, more secure

---

### Layers (Docker Caching)

Docker builds images in layers. Each instruction creates a layer:

```
Layer 1: FROM node:22-alpine
Layer 2: COPY package.json
Layer 3: RUN npm ci
Layer 4: COPY src
Layer 5: RUN npm run build
```

**Why it matters**: If `package.json` doesn't change, Docker reuses layers 1-3 (saves time!)

---

## 🐛 Troubleshooting

### Code Changes Not Reflecting (Development)

```bash
# Check if volumes are mounted correctly
docker-compose -f docker-compose.dev.yml exec minihubvone-app ls -la /app/src

# Restart container
docker-compose -f docker-compose.dev.yml restart

# Rebuild and restart
docker-compose -f docker-compose.dev.yml up --build -d
```

### Container Won't Start

```bash
# Check logs
docker-compose -f docker-compose.dev.yml logs

# Common issues:
# - Port 3000 already in use → Change port in docker-compose.dev.yml
# - Missing .env file → Create app/.env
# - Build failed → Check Dockerfile syntax
```

### Can't Connect to Database

```bash
# Check environment variables
docker-compose -f docker-compose.dev.yml exec minihubvone-app env | grep DB

# Test from inside container
docker-compose -f docker-compose.dev.yml exec minihubvone-app sh
# Then: node -e "console.log(process.env.PROD_DB_HOST)"
```

### Container Keeps Restarting

```bash
# Check logs for errors
docker-compose -f docker-compose.dev.yml logs --tail=50

# Check health status
docker ps  # Look at STATUS column
```

---

## 📚 Quick Reference

### Development Workflow

```bash
# 1. Start container
docker-compose -f docker-compose.dev.yml up -d --build

# 2. Edit code in app/src/
#    (Changes sync automatically!)

# 3. View logs to see changes
docker-compose -f docker-compose.dev.yml logs -f

# 4. Stop when done
docker-compose -f docker-compose.dev.yml down
```

### Production Workflow

```bash
# 1. Build optimized image
docker-compose -f docker-compose.prod.yml build

# 2. Start container
docker-compose -f docker-compose.prod.yml up -d

# 3. Test
curl http://localhost:3000/health

# 4. Stop
docker-compose -f docker-compose.prod.yml down
```

---

## 🎉 Summary

**Development:**

- ✅ Code syncing (edit files, see changes instantly)
- ✅ Hot reload (automatic restarts)
- ✅ Fast iteration

**Production:**

- ✅ Optimized (small image, fast startup)
- ✅ Compiled (TypeScript → JavaScript)
- ✅ Secure (no source code in image)

**You now understand:**

- ✅ How Docker works
- ✅ Development vs Production
- ✅ Code syncing with volumes
- ✅ .dockerignore for optimization
- ✅ How to debug and troubleshoot

You're ready to containerize any application! 🚀

---

## 🚀 Quick Start Guide

### First Time Setup

```bash
# 1. Create .env file (if it doesn't exist)
# Copy from example or create new
nano app/.env

# 2. Start development container
npm run docker:dev:up

# 3. Check logs to see it starting
npm run docker:dev:logs

# 4. Test it
curl http://localhost:3000/health
```

### Daily Development Workflow

```bash
# Start container (if not running)
npm run docker:dev:up

# Edit code in app/src/
# (Changes sync automatically - no rebuild needed!)

# View logs
npm run docker:dev:logs

# Get inside container
npm run docker:dev:shell

# Stop when done
npm run docker:dev:down
```

### Production Testing

```bash
# Build production image
npm run docker:prod:build

# Start production container
npm run docker:prod:up

# Test
curl http://localhost:3000/health

# View logs
npm run docker:prod:logs

# Stop
npm run docker:prod:down
```

---

## 💡 Key Takeaways

1. **Development**: Use `docker-compose.dev.yml` - code syncs automatically
2. **Production**: Use `docker-compose.prod.yml` - optimized build
3. **Code Changes**: In dev mode, just save files - container restarts automatically
4. **.dockerignore**: Excludes unnecessary files (smaller images)
5. **Volumes**: Enable live code syncing in development mode

Happy containerizing! 🐳
