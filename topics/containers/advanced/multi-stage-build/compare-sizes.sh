#!/usr/bin/env bash
# =============================================================================
# compare-sizes.sh — Build all multi-stage variants and compare image sizes
# =============================================================================
# Prerequisites: Docker running, build context for each app available
#
# Usage: ./compare-sizes.sh
#
# What it does:
#   1. Pulls common base images
#   2. Builds each multi-stage variant
#   3. Prints a formatted size comparison table
# =============================================================================

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${BLUE}▶ $1${NC}"; }
ok()   { echo -e "${GREEN}  ✅ $1${NC}"; }

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Multi-Stage Build — Image Size Comparison"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Pull base images for comparison ──────────────────────────────────────────
info "Pulling base images for reference..."
docker pull --quiet node:20           && ok "node:20 pulled"
docker pull --quiet node:20-alpine    && ok "node:20-alpine pulled"
docker pull --quiet python:3.12       && ok "python:3.12 pulled"
docker pull --quiet python:3.12-slim  && ok "python:3.12-slim pulled"
docker pull --quiet golang:1.22-alpine && ok "golang:1.22-alpine pulled"

# ── Tag base images so they appear in our table ───────────────────────────────
docker tag node:20            size-compare:node-full-base
docker tag node:20-alpine     size-compare:node-alpine-base
docker tag python:3.12        size-compare:python-full-base
docker tag python:3.12-slim   size-compare:python-slim-base
docker tag golang:1.22-alpine size-compare:go-sdk-base

# ── Build multi-stage variants ────────────────────────────────────────────────
echo ""
info "Building Node.js multi-stage (node.dockerfile)..."
if [[ -d node-app ]]; then
  docker build -f node.dockerfile -t size-compare:node-multistage ./node-app 2>/dev/null
  ok "Node.js multi-stage built"
else
  echo -e "${YELLOW}  ⚠ node-app/ directory not found — skipping Node.js build${NC}"
fi

info "Building Python multi-stage (python.dockerfile)..."
if [[ -d python-app ]]; then
  docker build -f python.dockerfile -t size-compare:python-multistage ./python-app 2>/dev/null
  ok "Python multi-stage built"
else
  echo -e "${YELLOW}  ⚠ python-app/ directory not found — skipping Python build${NC}"
fi

info "Building Go → scratch (go.dockerfile)..."
if [[ -d go-app ]]; then
  docker build -f go.dockerfile -t size-compare:go-scratch ./go-app 2>/dev/null
  ok "Go scratch image built"
else
  echo -e "${YELLOW}  ⚠ go-app/ directory not found — skipping Go build${NC}"
fi

# ── Print comparison table ────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "  %-40s %s\n" "IMAGE" "SIZE"
printf "  %-40s %s\n" "─────────────────────────────────────" "────────"

docker images size-compare \
  --format "  {{printf \"%-40s\" .Tag}} {{.Size}}" \
  | sort

echo ""
echo "  Legend:"
echo "  *-base       = unmodified base image (reference point)"
echo "  *-multistage = your production image after multi-stage build"
echo "  go-scratch   = Go binary on scratch (zero OS)"
echo ""

# ── Cleanup ───────────────────────────────────────────────────────────────────
read -r -p "Remove size-compare images? [y/N] " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  docker images size-compare -q | xargs -r docker rmi -f
  echo "Cleaned up."
fi