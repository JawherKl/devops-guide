# Multi-Stage Builds

> Produce small, secure, production-ready images by separating the build environment from the runtime environment. Build tools never ship to production.

---

## 💡 The Core Problem Multi-Stage Solves

```
Without multi-stage:                 With multi-stage:
┌─────────────────────┐              ┌─────────────────────┐
│ Compiler / SDK      │ ← ships!     │ Compiler / SDK      │ ← discarded
│ Build tools (make)  │ ← ships!     │ Build tools (make)  │ ← discarded
│ Dev dependencies    │ ← ships!     │ Dev dependencies    │ ← discarded
│ Test frameworks     │ ← ships!     │ Test frameworks     │ ← discarded
│ Source code         │ ← ships!     │ Source code         │ ← discarded
│ Compiled artifact   │ ← ships ✅   ├─────────────────────┤
└─────────────────────┘              │ Compiled artifact   │ ← ships ✅
  ~1.2 GB                            └─────────────────────┘
                                       ~80-120 MB (or ~8 MB for Go → scratch)
```

---

## 📁 Files in This Section

| File | Language | Base → Final | Approx. size |
|------|----------|-------------|--------------|
| `node.dockerfile` | Node.js / TypeScript | `node:20-alpine` → `node:20-alpine` | ~120 MB |
| `python.dockerfile` | Python | `python:3.12-slim` → `python:3.12-slim` | ~160 MB |
| `go.dockerfile` | Go | `golang:1.22-alpine` → **`scratch`** | ~8–15 MB |

---

## 🏗️ How Multi-Stage Works

Each `FROM` instruction starts a **new build stage**. Stages are isolated from each other. You use `COPY --from=<stage>` to selectively copy artifacts between them.

```dockerfile
# Stage 1 — named 'builder': has all tools, does the work
FROM golang:1.22-alpine AS builder
RUN go build -o /app/server ./cmd/server

# Stage 2 — named 'production': starts fresh, gets only the binary
FROM scratch AS production
COPY --from=builder /app/server /server   # ← only this crosses the boundary
ENTRYPOINT ["/server"]
```

Docker builds all stages sequentially but **only the final stage becomes the image**. Everything in intermediate stages is discarded.

---

## 📐 Pattern 1 — Node.js (TypeScript build + prune)

```dockerfile
# node.dockerfile — 3 stages: deps → builder → production
```

**Stages:**
1. `deps` — install all dependencies (including devDependencies)
2. `builder` — compile TypeScript / run bundler, then prune dev deps
3. `production` — copy only `dist/` + `node_modules/` (production only)

```bash
# Build
docker build -f node.dockerfile -t myapp-node:prod --target production .

# Compare intermediate vs final
docker build -f node.dockerfile -t myapp-node:builder --target builder .
docker images myapp-node
```

---

## 📐 Pattern 2 — Python (virtualenv isolation)

```dockerfile
# python.dockerfile — 2 stages: builder (with gcc) → production (no gcc)
```

**Stages:**
1. `builder` — install gcc + build tools, create virtualenv, install all packages
2. `production` — copy only the virtualenv (`/opt/venv`) + source code, no compilers

The key insight: Python packages that require compilation (like `psycopg2`, `Pillow`) need `gcc` to install but not to run. The builder has gcc; the final image doesn't.

```bash
docker build -f python.dockerfile -t myapp-python:prod --target production .
```

---

## 📐 Pattern 3 — Go → scratch (most minimal)

```dockerfile
# go.dockerfile — 2 stages: builder (full Go SDK) → scratch (nothing)
```

**Stages:**
1. `builder` — full Go toolchain, compiles a **statically linked** binary (no libc)
2. `production` — `scratch` base + binary + CA certs + passwd file = nothing else

`scratch` is a special Docker keyword meaning "completely empty image." There is no shell, no OS utilities, no package manager. The binary must be statically compiled to run without libc.

```bash
# Build
docker build -f go.dockerfile -t myapp-go:prod --target production .

# Verify it's tiny
docker images myapp-go:prod

# Verify there's no shell (this should fail — correct behavior)
docker run --rm myapp-go:prod sh
# exec: "sh": executable file not found ✅
```

---

## 🎯 Targeting Specific Stages

```bash
# Build only the builder stage (useful for running tests in CI)
docker build --target builder -t myapp:test -f node.dockerfile .
docker run --rm myapp:test npm test

# Build the production stage (what you push to registry)
docker build --target production -t myapp:prod -f node.dockerfile .
```

---

## 📊 Size Comparison Lab

Run this to see the impact of multi-stage builds side by side:

```bash
# ── Node.js ──────────────────────────────────────────────────────────────────
# Single-stage (everything included)
docker build -f node.single.dockerfile -t size-demo:node-single .

# Multi-stage (production only)
docker build -f node.dockerfile --target production -t size-demo:node-multi .

# ── Go ───────────────────────────────────────────────────────────────────────
# Full Go SDK image
docker pull golang:1.22-alpine
docker tag golang:1.22-alpine size-demo:go-full

# Multi-stage scratch image
docker build -f go.dockerfile --target production -t size-demo:go-scratch .

# ── Compare all ──────────────────────────────────────────────────────────────
docker images size-demo --format "table {{.Tag}}\t{{.Size}}"

# Expected output:
# TAG              SIZE
# node-single      ~1.1GB
# node-multi       ~120MB
# go-full          ~250MB
# go-scratch       ~10MB
```

---

## ⚡ Build Optimization Tips

**1. Cache dependency layers**
Always copy dependency manifests before source code. The dependency install layer is only rebuilt when the manifest changes.

```dockerfile
# ✅ Correct order — deps cached separately from source
COPY go.mod go.sum ./
RUN go mod download
COPY . .

# ❌ Wrong — source change rebuilds go mod download every time
COPY . .
RUN go mod download
```

**2. Use BuildKit for parallel stages**
```bash
DOCKER_BUILDKIT=1 docker build -t myapp .
# Stages that don't depend on each other build in parallel
```

**3. Verify binary is statically linked (Go)**
```bash
docker run --rm size-demo:go-scratch file /server
# /server: ELF 64-bit LSB executable, statically linked ✅
```

---

## ✅ Checklist

- [ ] No build tools (gcc, npm devDependencies, Go SDK) in the final image
- [ ] Dependency manifests copied before source code in every stage
- [ ] `--target` used in CI to build test stage vs production stage
- [ ] Go binaries compiled with `CGO_ENABLED=0` for static linking
- [ ] `scratch` or `distroless` used as final base for compiled languages
- [ ] CA certificates copied into scratch/distroless images (HTTPS support)
- [ ] Non-root user defined and used in the final stage
- [ ] Final image size verified and tracked in CI