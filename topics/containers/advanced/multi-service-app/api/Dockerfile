# =============================================================================
# api/Dockerfile — Multi-stage Node.js API
# =============================================================================
# Stages:
#   deps        — install all dependencies (cached layer)
#   development — dev dependencies included, source mounted at runtime
#   production  — pruned, non-root, healthcheck, minimal image
# =============================================================================

# syntax=docker/dockerfile:1

# ── Stage 1: Install all dependencies ────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app
COPY package*.json ./
RUN npm ci && npm cache clean --force

# ── Stage 2: Development ─────────────────────────────────────────────────────
FROM node:20-alpine AS development

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

ENV NODE_ENV=development
EXPOSE 3000 9229

CMD ["npm", "run", "dev"]

# ── Stage 3: Production ──────────────────────────────────────────────────────
FROM node:20-alpine AS production

RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup -s /sbin/nologin

WORKDIR /app

# Install only production deps from the cached stage
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy application source with correct ownership
COPY --chown=appuser:appgroup src ./src

USER 1001:1001

ENV NODE_ENV=production \
    PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "src/index.js"]