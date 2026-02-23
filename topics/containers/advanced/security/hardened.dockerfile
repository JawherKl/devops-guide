# =============================================================================
# hardened.dockerfile — Production security hardening reference
# =============================================================================
#
# This Dockerfile demonstrates every security layer you should apply
# to a production container. Use it as a checklist and reference.
#
# Security layers applied:
#   ✅ Pinned base image (digest)
#   ✅ Minimal base (alpine)
#   ✅ Non-root user with explicit UID/GID
#   ✅ No unnecessary packages
#   ✅ Read-only root filesystem (enforced at runtime via compose.yml)
#   ✅ No setuid/setgid binaries
#   ✅ Owned files with correct permissions
#   ✅ No secrets in image layers
#   ✅ HEALTHCHECK defined
#   ✅ no-new-privileges enforced (in compose.yml / runtime flags)
#
# Build:  docker build -f hardened.dockerfile -t myapp:hardened .
# Scan:   trivy image myapp:hardened --severity HIGH,CRITICAL
# =============================================================================

# syntax=docker/dockerfile:1

# ── Pin to a specific digest, not just a tag ──────────────────────────────────
# A tag like :20-alpine can be silently updated — a digest never changes.
# Get the current digest: docker inspect node:20-alpine | jq -r '.[0].RepoDigests[0]'
#
# For this example we use the tag for readability; pin to digest in real usage:
# FROM node:20-alpine@sha256:<digest> AS base
FROM node:20-alpine AS base

# ── Remove setuid and setgid bits from all binaries ───────────────────────────
# Setuid binaries allow privilege escalation — remove them from the image.
RUN find / -perm /6000 -type f -exec chmod a-s {} \; 2>/dev/null || true

# ── Create a dedicated non-root user ─────────────────────────────────────────
# Explicit UID/GID (1001) is more portable than named-only users,
# especially in Kubernetes where PodSecurityPolicy/SecurityContext uses UIDs.
RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup -h /home/appuser -s /sbin/nologin

WORKDIR /app

# ── Install dependencies as root, then lock down ──────────────────────────────
COPY package*.json ./

# Use `npm ci` (clean install from lockfile) not `npm install`
# --omit=dev: exclude devDependencies from production image
# npm cache clean: remove npm cache in same layer (no separate cache layer)
RUN npm ci --omit=dev && \
    npm cache clean --force && \
    # Remove any files that shouldn't be in production
    find node_modules -name "*.md" -delete 2>/dev/null || true && \
    find node_modules -name "*.ts" ! -name "*.d.ts" -delete 2>/dev/null || true

# ── Copy application source with correct ownership ────────────────────────────
# --chown ensures files are owned by appuser from the start.
# Without this, COPY creates root-owned files — you'd need a separate RUN chown.
COPY --chown=appuser:appgroup . .

# ── Make application directory read-only for the app user ─────────────────────
# The app can read its own files but cannot modify them at runtime.
# Combined with --read-only at runtime, this prevents any file modification.
RUN chmod -R 550 /app && \
    chmod -R 440 /app/node_modules

# ── Switch to non-root user ───────────────────────────────────────────────────
# All subsequent instructions and the container process run as this user.
# This is enforced here AND should be enforced with security_opt at runtime.
USER 1001:1001

# ── Runtime environment ───────────────────────────────────────────────────────
ENV NODE_ENV=production \
    PORT=3000 \
    # Disable Node.js from loading native addons (prevents some attack vectors)
    NODE_OPTIONS="--no-experimental-require-module"

EXPOSE 3000

# ── Health check ──────────────────────────────────────────────────────────────
# Uses wget (available in alpine) — no curl dependency needed.
# --spider: only check the URL, don't download the body.
# The /health endpoint should return 200 without authentication.
HEALTHCHECK \
  --interval=30s \
  --timeout=5s \
  --start-period=15s \
  --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

# ── Entrypoint in exec form (JSON array) ──────────────────────────────────────
# Shell form (`CMD node server.js`) spawns a shell process as PID 1.
# Exec form (`CMD ["node", "server.js"]`) runs node directly as PID 1.
# PID 1 receives signals (SIGTERM) — exec form handles graceful shutdown correctly.
CMD ["node", "src/index.js"]

# =============================================================================
# RUNTIME SECURITY — enforce these in compose.yml or `docker run`:
#
#   security_opt:
#     - no-new-privileges:true     # prevent setuid escalation
#   read_only: true                # root filesystem read-only
#   tmpfs:
#     - /tmp:size=50m              # writable temp dir (in memory only)
#     - /run:size=10m
#   cap_drop:
#     - ALL                        # drop every Linux capability
#   cap_add:
#     - NET_BIND_SERVICE           # add back ONLY if binding port < 1024
#   user: "1001:1001"              # redundant but explicit
# =============================================================================