# 03 — Writing Dockerfiles

> Every Dockerfile instruction explained, with caching rules, `.dockerignore`, and production patterns for Node.js, Python, and Nginx.

---

## 📖 Instruction Reference

```dockerfile
# ── Syntax directive (enable BuildKit features) ───────────────────────────────
# syntax=docker/dockerfile:1

# ── Base image ────────────────────────────────────────────────────────────────
FROM node:20-alpine
# Always pin to a specific tag — never FROM node:latest in production
# Use alpine or slim variants for smaller images

# ── Metadata labels ───────────────────────────────────────────────────────────
LABEL maintainer="you@example.com"
LABEL org.opencontainers.image.source="https://github.com/you/repo"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.description="My production API"

# ── Build arguments (set at build time, not runtime) ──────────────────────────
ARG NODE_VERSION=20
ARG BUILD_DATE
# Override at build: docker build --build-arg BUILD_DATE=$(date -u +%Y-%m-%d) .

# ── Environment variables (available at build AND runtime) ────────────────────
ENV NODE_ENV=production \
    PORT=3000 \
    LOG_LEVEL=info
# Combine into one ENV — each ENV creates a layer

# ── Working directory ─────────────────────────────────────────────────────────
WORKDIR /app
# Creates the directory if it doesn't exist
# All subsequent instructions run relative to this path

# ── Copy files (cache-optimized — see caching section below) ──────────────────
COPY package*.json ./
# Copy only manifests first, not source code

RUN npm ci --omit=dev && npm cache clean --force
# npm ci = reproducible install from lockfile (faster than npm install)

COPY . .
# Copy source code AFTER installing deps (cache hit when only code changes)

# ── Expose port (documentation only — does NOT publish) ───────────────────────
EXPOSE 3000
# Required for `docker run -P` (publish all) to work
# Good practice even though it's just documentation

# ── User (always switch to non-root before running the app) ───────────────────
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# ── Healthcheck ───────────────────────────────────────────────────────────────
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# ── Volume (declare a mount point — optional but documents intent) ─────────────
VOLUME /app/data

# ── Entrypoint vs CMD ─────────────────────────────────────────────────────────
ENTRYPOINT ["node"]     # fixed executable — cannot be overridden (only with --entrypoint)
CMD ["src/index.js"]    # default argument — can be overridden at runtime

# docker run myimage                  → runs: node src/index.js
# docker run myimage src/other.js     → runs: node src/other.js
# docker run --entrypoint sh myimage  → overrides ENTRYPOINT
```

---

## ⚡ The Caching Golden Rule

**Order instructions from LEAST frequently changed to MOST frequently changed.**

Docker rebuilds from the first changed layer downward. Expensive operations (npm install, pip install, apt-get) should be in early layers that rarely change.

```dockerfile
# ❌ BAD — source code change triggers npm install every time
COPY . .
RUN npm install

# ✅ GOOD — npm install only runs when package.json changes
COPY package*.json ./
RUN npm install
COPY . .
```

```bash
# Visualize your cache behavior
docker build -t myapp .                   # first build — all layers
touch src/index.js                         # change only source code
docker build -t myapp .                   # second build — npm install is CACHED ✅

# Build with verbose output (shows CACHED vs rebuilt)
DOCKER_BUILDKIT=1 docker build --progress=plain -t myapp .
```

---

## 🚫 .dockerignore

Always create `.dockerignore` — it prevents sending unnecessary files to the build context. This speeds up builds and prevents leaking secrets.

```dockerignore
# .dockerignore
.git
.gitignore
*.md
Dockerfile*
docker-compose*.yml
.dockerignore

node_modules
npm-debug.log*

.env
.env.*
*.pem
*.key

test/
coverage/
.nyc_output/

.vscode/
.idea/
.DS_Store
```

```bash
# See build context size (before and after .dockerignore)
docker build -t test . 2>&1 | grep "Sending build context"
# Sending build context to Docker daemon  12.3MB   ← without .dockerignore
# Sending build context to Docker daemon  245.3kB  ← with .dockerignore ✅
```

---

## 📁 Language Examples

### Node.js

```dockerfile
FROM node:20-alpine

RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

COPY --chown=appuser:appgroup . .

USER appuser

ENV NODE_ENV=production PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]
```

### Python

```dockerfile
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN groupadd -r appgroup && useradd -r -g appgroup appuser

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY --chown=appuser:appgroup . .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')"

CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "4", "app:app"]
```

### Nginx (static site)

```dockerfile
FROM nginx:1.25-alpine

RUN rm /etc/nginx/conf.d/default.conf

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY dist/ /usr/share/nginx/html/

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

---

## 🧪 Lab: Build your first image

```bash
# 1. Create a minimal Node.js app
mkdir my-first-image && cd my-first-image

cat > index.js << 'EOF'
const http = require('http');
http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'application/json'});
  res.end(JSON.stringify({
    message: 'Hello from my first Docker image!',
    hostname: require('os').hostname(),
    timestamp: new Date().toISOString()
  }));
}).listen(3000, () => console.log('Listening on :3000'));
EOF

cat > package.json << 'EOF'
{"name":"my-first-image","version":"1.0.0","main":"index.js"}
EOF

# 2. Write a Dockerfile
cat > Dockerfile << 'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
COPY index.js ./
EXPOSE 3000
CMD ["node", "index.js"]
EOF

# 3. Build
docker build -t my-first-image:1.0 .

# 4. Run
docker run -d --name my-first -p 3000:3000 my-first-image:1.0

# 5. Test
curl http://localhost:3000

# 6. Check layers
docker history my-first-image:1.0

# 7. Clean up
docker rm -f my-first && docker rmi my-first-image:1.0
cd .. && rm -rf my-first-image
echo "✅ Lab complete"
```

---

## ✅ Dockerfile Checklist

- [ ] Base image pinned to a specific tag (no `:latest`)
- [ ] Use slim/alpine variant for smaller attack surface
- [ ] Dependency manifests (`package.json`, `requirements.txt`) copied before source code
- [ ] `.dockerignore` file exists and excludes `node_modules`, `.env`, `.git`
- [ ] Non-root user created and switched to with `USER`
- [ ] `--chown` used on `COPY` to set correct file ownership
- [ ] `HEALTHCHECK` defined with realistic intervals
- [ ] `CMD` uses exec form (`["node", "index.js"]`), not shell form (`node index.js`)
- [ ] Package manager caches cleaned in same `RUN` layer (`npm cache clean --force`)
- [ ] `EXPOSE` documents the container's port

---

**Next:** [04 — Image Management →](../04-images/)