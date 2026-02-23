# =============================================================================
# react-nginx.dockerfile — Multi-stage React/Next.js → Nginx
# =============================================================================
# Stages:
#   deps        — install npm dependencies
#   builder     — run the production build (vite/webpack/next)
#   production  — nginx serving only the static output (no Node.js runtime)
#
# Final image: ~25MB (nginx:alpine + static assets only)
# Without multi-stage: ~1.2GB (full Node.js + dev deps + source)
#
# Build:
#   docker build -f react-nginx.dockerfile -t myapp-react:prod \
#     --build-arg VITE_API_URL=https://api.example.com .
# =============================================================================

# syntax=docker/dockerfile:1

# ── Stage 1: Install dependencies ────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

COPY package*.json ./
RUN npm ci && npm cache clean --force

# ── Stage 2: Build ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# Build-time environment variables (injected at compile time into the bundle)
# These are NOT secrets — they become part of the public JS bundle.
# For runtime config, use window._env_ or a config endpoint instead.
ARG VITE_API_URL=http://localhost:3000
ARG VITE_APP_VERSION=1.0.0
ENV VITE_API_URL=$VITE_API_URL \
    VITE_APP_VERSION=$VITE_APP_VERSION

# Run the production build — output goes to ./dist (Vite) or ./.next (Next.js)
RUN npm run build

# ── Stage 3: Production — nginx serving static files ─────────────────────────
FROM nginx:1.25-alpine AS production

# Remove nginx default site and default config
RUN rm -rf /usr/share/nginx/html/* && \
    rm /etc/nginx/conf.d/default.conf

# Copy compiled static assets from builder
COPY --from=builder /app/dist /usr/share/nginx/html

# Custom nginx config for SPA (single page application) routing
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Use a non-root user for nginx (nginx:alpine includes the nginx user)
# nginx worker processes run as 'nginx' user; master runs as root for port binding.
# For full rootless nginx, use a custom image or listen on port >= 1024.

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/health || exit 1

CMD ["nginx", "-g", "daemon off;"]