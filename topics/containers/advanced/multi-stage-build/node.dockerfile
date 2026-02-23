# =============================================================================
# node.dockerfile — Multi-stage Node.js / TypeScript build
# =============================================================================
# Stages:
#   deps        — install ALL npm dependencies (cache-optimized)
#   builder     — compile TypeScript, then prune dev deps
#   production  — minimal runtime image (no compiler, no devDependencies)
#
# Build:
#   docker build -f node.dockerfile -t myapp-node:prod --target production .
#
# Run tests against builder stage (has devDeps):
#   docker build -f node.dockerfile -t myapp-node:test --target builder .
#   docker run --rm myapp-node:test npm test
# =============================================================================

# syntax=docker/dockerfile:1

# ── Stage 1: Install all dependencies ────────────────────────────────────────
# Separate stage so the npm install layer is cached independently.
# Re-runs only when package.json or package-lock.json changes.
FROM node:20-alpine AS deps

WORKDIR /app

# Copy manifests first — not source code
COPY package*.json ./

# npm ci = clean install from lockfile (reproducible, fast in CI)
RUN npm ci && npm cache clean --force

# ── Stage 2: Build (compile TypeScript / run bundler) ────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy node_modules from deps stage (avoids re-downloading)
COPY --from=deps /app/node_modules ./node_modules

# Copy source code
COPY . .

# Compile TypeScript → JavaScript (output goes to ./dist/)
RUN npm run build

# Remove devDependencies from node_modules in-place.
# This is faster than re-installing from scratch.
RUN npm prune --omit=dev

# ── Stage 3: Production runtime ──────────────────────────────────────────────
# Starts fresh — nothing from previous stages is included unless explicitly COPY'd.
FROM node:20-alpine AS production

# Non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup -s /sbin/nologin

WORKDIR /app

# Copy ONLY what the app needs to run:
#   dist/          — compiled JavaScript output
#   node_modules/  — production dependencies only (pruned in builder stage)
#   package.json   — needed for npm scripts and metadata
COPY --from=builder --chown=appuser:appgroup /app/dist         ./dist
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules
COPY --from=builder --chown=appuser:appgroup /app/package.json ./package.json

# NOT copied:
#   src/           — TypeScript source (compiled → dist)
#   tsconfig.json  — TypeScript config (compile-time only)
#   *.test.ts      — test files
#   devDependencies — ts-node, typescript, jest, etc.

USER 1001:1001

ENV NODE_ENV=production \
    PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/index.js"]