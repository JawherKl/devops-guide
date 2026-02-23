# 04 — Image Management

> Build, tag, push, inspect, and optimize Docker images. Understand layers, choose the right base, and keep your registry clean.

---

## 🏗️ Building Images

```bash
# Basic build (Dockerfile in current directory)
docker build -t myapp:1.0 .

# Build with specific Dockerfile
docker build -f node.dockerfile -t myapp:1.0 .

# Build with build arguments
docker build \
  --build-arg NODE_ENV=production \
  --build-arg BUILD_DATE=$(date -u +%Y-%m-%d) \
  -t myapp:1.0 .

# Build without using cache (force fresh build)
docker build --no-cache -t myapp:1.0 .

# Build a specific stage only (multi-stage)
docker build --target builder -t myapp:builder .

# Build with verbose output (see exact commands per layer)
DOCKER_BUILDKIT=1 docker build --progress=plain -t myapp:1.0 .

# Multi-arch build (requires buildx)
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t myapp:1.0 \
  --push .
```

---

## 🏷️ Tagging Strategy

Never use `:latest` in production — it's ambiguous and makes rollback impossible.

```bash
# Apply multiple tags to the same image in one build
GIT_SHA=$(git rev-parse --short HEAD)
VERSION="1.4.2"

docker build \
  -t myapp:${VERSION} \
  -t myapp:${GIT_SHA} \
  -t myapp:stable \
  .

# Retag an existing image (no rebuild)
docker tag myapp:1.4.2 registry.example.com/team/myapp:1.4.2
docker tag myapp:1.4.2 registry.example.com/team/myapp:stable
```

### Convention table

| Tag | Example | Purpose |
|-----|---------|---------|
| Semantic version | `1.4.2` | Stable release — use in production deployments |
| Git SHA | `a3f8c1d` | Per-commit CI build — fully traceable |
| Branch | `main`, `develop` | Latest from a branch |
| Environment | `staging`, `prod` | After promotion through pipeline |
| Date | `2025-02-21` | Time-based rollback reference |

---

## 🔍 Inspecting Images

```bash
# List local images
docker images
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"

# Show layer history — what each layer does and how large it is
docker history myapp:1.0
docker history --no-trunc myapp:1.0     # full commands (not truncated)

# Full JSON metadata
docker inspect myapp:1.0

# Number of layers
docker inspect myapp:1.0 | jq '.[0].RootFS.Layers | length'

# Image digest (content-addressable hash — unique per content)
docker inspect myapp:1.0 --format='{{index .RepoDigests 0}}'

# All labels baked into the image
docker inspect myapp:1.0 | jq '.[0].Config.Labels'
```

---

## 📦 Pushing to a Registry

```bash
# Docker Hub
docker login
docker push yourusername/myapp:1.0

# GitHub Container Registry (GHCR)
echo $GITHUB_TOKEN | docker login ghcr.io -u $GITHUB_USERNAME --password-stdin
docker tag myapp:1.0 ghcr.io/jawherKl/myapp:1.0
docker push ghcr.io/jawherKl/myapp:1.0

# Private registry
docker login registry.example.com
docker tag myapp:1.0 registry.example.com/team/myapp:1.0
docker push registry.example.com/team/myapp:1.0

# Pull from private registry
docker pull registry.example.com/team/myapp:1.0
```

---

## 📉 Image Size Optimization

### 1. Choose the right base

```bash
# Pull and compare common bases
docker pull node:20
docker pull node:20-slim
docker pull node:20-alpine

docker images node --format "table {{.Tag}}\t{{.Size}}"
# 20          ~1.1GB
# 20-slim     ~230MB
# 20-alpine   ~50MB
```

### 2. Minimize RUN layers — clean up in the same layer

```dockerfile
# ❌ 3 separate layers — apt cache stays in layer 2
RUN apt-get update
RUN apt-get install -y curl
RUN rm -rf /var/lib/apt/lists/*

# ✅ 1 layer — cleanup happens before the layer is committed
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*
```

### 3. Use multi-stage builds for compiled languages

See [advanced/multi-stage-build](../../advanced/multi-stage-build/) for complete examples.

### 4. Use .dockerignore

```bash
# Check your build context size
docker build -t test . 2>&1 | grep "Sending build context"
```

---

## 🧹 Cleanup

```bash
# Show disk usage
docker system df

# Remove a specific image
docker rmi myapp:1.4.2

# Remove all dangling (untagged) images
docker image prune

# Remove ALL unused images (not used by any container)
docker image prune -a

# Remove images older than 48h
docker image prune -a --filter "until=48h"

# Clean the build cache
docker builder prune

# Remove everything unused (images, containers, networks, cache)
docker system prune -a
```

---

## 🧪 Lab: Tag and trace a build

```bash
# 1. Set up traceability variables
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")
BUILD_DATE=$(date -u +%Y-%m-%dT%H:%M:%SZ)
VERSION="1.0.0"

# 2. Build with metadata labels baked in
docker build \
  -t image-lab:${VERSION} \
  -t image-lab:${GIT_SHA} \
  --label "git.sha=${GIT_SHA}" \
  --label "build.date=${BUILD_DATE}" \
  --label "version=${VERSION}" \
  -f ../03-dockerfile/node.dockerfile \
  . 2>/dev/null || docker build -t image-lab:${VERSION} -t image-lab:${GIT_SHA} .

# 3. Inspect labels
docker inspect image-lab:${VERSION} | jq '.[0].Config.Labels'

# 4. Compare size to full node:20
docker pull node:20 -q
docker images node:20 image-lab --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}"

# 5. Count layers
docker history image-lab:${VERSION} | wc -l
echo "layers in image-lab"

# 6. Cleanup
docker rmi image-lab:${VERSION} image-lab:${GIT_SHA}
echo "✅ Lab complete"
```

---

## ✅ Image Management Checklist

- [ ] Never use `:latest` tag in production — use semantic version or git SHA
- [ ] Build with `--label` to embed git SHA, build date, version
- [ ] Use alpine or slim base images
- [ ] Combine `RUN` commands to minimize layers
- [ ] `rm -rf /var/lib/apt/lists/*` in the same `RUN` as `apt-get install`
- [ ] `.dockerignore` excludes `node_modules`, `.env`, `.git`, test files
- [ ] Run `docker image prune -a` regularly on CI runners
- [ ] Use `docker system df` to monitor disk usage

---

**Next:** [05 — Volumes & Storage →](../05-volumes/)