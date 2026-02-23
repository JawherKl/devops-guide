#!/usr/bin/env bash
# =============================================================================
# verify-isolation.sh — Prove the network isolation is actually working
# =============================================================================
# Run AFTER: docker compose up -d
#
# Each test checks a specific network boundary and prints PASS or FAIL.
# All expected results are documented inline.
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}  ✅ PASS${NC} — $1"; ((PASS++)); }
fail() { echo -e "${RED}  ❌ FAIL${NC} — $1"; ((FAIL++)); }
info() { echo -e "\n${BLUE}▶ $1${NC}"; }
warn() { echo -e "${YELLOW}  ⚠ WARN${NC} — $1"; }

# ── Wait for stack to be healthy ──────────────────────────────────────────────
echo -e "${BLUE}Waiting for services to be healthy...${NC}"
sleep 5

# ── Test 1: Proxy can reach API (both on frontend) ────────────────────────────
info "Test 1: proxy → api  (frontend network — SHOULD SUCCEED)"
if docker compose exec -T proxy wget -qO- http://api:3000/health 2>/dev/null | grep -q "ok"; then
  pass "proxy reached api on port 3000"
else
  fail "proxy could not reach api — check compose logs"
fi

# ── Test 2: API can reach PostgreSQL (both on backend) ────────────────────────
info "Test 2: api → postgres  (backend network — SHOULD SUCCEED)"
if docker compose exec -T api wget -qO- http://localhost:3000/db 2>/dev/null | grep -q '"reachable":true'; then
  pass "api reached postgres on port 5432"
else
  fail "api could not reach postgres"
fi

# ── Test 3: API can reach Redis (both on backend) ─────────────────────────────
info "Test 3: api → redis  (backend network — SHOULD SUCCEED)"
if docker compose exec -T api wget -qO- http://localhost:3000/cache 2>/dev/null | grep -q '"reachable":true'; then
  pass "api reached redis on port 6379"
else
  fail "api could not reach redis"
fi

# ── Test 4: External access works through proxy ───────────────────────────────
info "Test 4: host → proxy → api  (external → SHOULD SUCCEED)"
if curl -sf http://localhost/health | grep -q "ok"; then
  pass "external request reached api via proxy on port 80"
else
  fail "external request failed — is the stack running?"
fi

# ── Test 5: Proxy CANNOT reach PostgreSQL (proxy not on backend) ──────────────
info "Test 5: proxy → postgres  (proxy not on backend — SHOULD BE BLOCKED)"
if docker compose exec -T proxy sh -c "nc -zw2 postgres 5432" 2>/dev/null; then
  fail "proxy reached postgres — isolation broken!"
else
  pass "proxy cannot reach postgres (correct — not on backend network)"
fi

# ── Test 6: Proxy CANNOT reach Redis ─────────────────────────────────────────
info "Test 6: proxy → redis  (proxy not on backend — SHOULD BE BLOCKED)"
if docker compose exec -T proxy sh -c "nc -zw2 redis 6379" 2>/dev/null; then
  fail "proxy reached redis — isolation broken!"
else
  pass "proxy cannot reach redis (correct — not on backend network)"
fi

# ── Test 7: PostgreSQL has NO internet access (internal network) ───────────────
info "Test 7: postgres → internet  (backend is internal — SHOULD BE BLOCKED)"
if docker compose exec -T postgres sh -c "nc -zw2 8.8.8.8 53" 2>/dev/null; then
  fail "postgres has internet access — internal network not working!"
else
  pass "postgres cannot reach internet (correct — backend is internal: true)"
fi

# ── Test 8: Redis has NO internet access ──────────────────────────────────────
info "Test 8: redis → internet  (backend is internal — SHOULD BE BLOCKED)"
if docker compose exec -T redis sh -c "nc -zw2 8.8.8.8 53" 2>/dev/null; then
  fail "redis has internet access — internal network not working!"
else
  pass "redis cannot reach internet (correct — backend is internal: true)"
fi

# ── Test 9: DNS resolves by container name ────────────────────────────────────
info "Test 9: DNS resolution by service name inside API container"
if docker compose exec -T api sh -c "nslookup postgres 2>/dev/null | grep -q Address"; then
  pass "DNS resolves 'postgres' by name inside api container"
else
  warn "nslookup not available — trying nc-based resolution"
  if docker compose exec -T api sh -c "nc -zw2 postgres 5432" 2>/dev/null; then
    pass "name resolution works (nc succeeded)"
  else
    fail "could not resolve or reach 'postgres' by name"
  fi
fi

# ── Test 10: No direct external access to PostgreSQL port ─────────────────────
info "Test 10: host → postgres:5432 directly  (no published port — SHOULD FAIL)"
if nc -zw2 localhost 5432 2>/dev/null; then
  fail "postgres port 5432 is exposed on host — remove ports: from postgres service!"
else
  pass "postgres port 5432 is NOT published to host (correct)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  Results: ${GREEN}${PASS} passed${NC}  ${RED}${FAIL} failed${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}  Some isolation tests failed. Review compose.yml network config.${NC}"
  exit 1
else
  echo -e "${GREEN}  All isolation tests passed. Network topology is correctly configured. ✅${NC}"
fi