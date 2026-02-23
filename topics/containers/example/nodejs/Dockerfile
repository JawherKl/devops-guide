# =============================================================================
# app/Dockerfile — Multi-stage Node.js API
# =============================================================================
# Stages:
#   deps         → install all npm dependencies (cache layer)
#   development  → dev deps, source mounted at runtime via bind mount
#   production   → non-root, production deps only, healthcheck
#
# Build production:   docker build --target production -t taskapp-api .
# Build dev:          docker build --target development -t taskapp-api:dev .
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

ENV NODE_ENV=development \
    PORT=3000

EXPOSE 3000 9229
# Source is bind-mounted at runtime — no COPY of src needed here

CMD ["npm", "run", "dev"]

# ── Stage 3: Production ──────────────────────────────────────────────────────
FROM node:20-alpine AS production

# Non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser  -u 1001 -S appuser -G appgroup -s /sbin/nologin

WORKDIR /app

# Install only production dependencies
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy application source with correct ownership
COPY --chown=appuser:appgroup src ./src

USER 1001:1001

ENV NODE_ENV=production \
    PORT=3000

EXPOSE 3000

HEALTHCHECK --interval=20s --timeout=5s --start-period=20s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1

CMD ["node", "src/index.js"]