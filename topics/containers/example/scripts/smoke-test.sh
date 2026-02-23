#!/usr/bin/env bash
# =============================================================================
# scripts/smoke-test.sh — End-to-end smoke test for the example stack
# =============================================================================
# Run AFTER: docker compose up -d  (or make dev)
#
# Tests the full request path:
#   Browser → nginx → API → PostgreSQL / Redis
#
# Exit codes:
#   0 = all tests passed
#   1 = one or more tests failed
# =============================================================================

set -uo pipefail

BASE_URL="${BASE_URL:-http://localhost}"
PASS=0; FAIL=0

# ── Colors ────────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'; RED='\033[0;31m'
BLUE='\033[0;34m';  YELLOW='\033[1;33m'; NC='\033[0m'

pass()  { echo -e "${GREEN}  ✅ PASS${NC} — $1"; ((PASS++)); }
fail()  { echo -e "${RED}  ❌ FAIL${NC} — $1"; ((FAIL++)); }
info()  { echo -e "\n${BLUE}▶ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ⚠ WARN${NC} — $1"; }

# ── Helper ────────────────────────────────────────────────────────────────────
get() {
  curl -sf --max-time 5 "$BASE_URL$1" 2>/dev/null
}

post() {
  local path="$1"; shift
  curl -sf --max-time 5 -X POST \
    -H "Content-Type: application/json" \
    -d "$*" \
    "$BASE_URL$path" 2>/dev/null
}

put_req() {
  local path="$1"; shift
  curl -sf --max-time 5 -X PUT \
    -H "Content-Type: application/json" \
    -d "$*" \
    "$BASE_URL$path" 2>/dev/null
}

delete_req() {
  curl -sf --max-time 5 -X DELETE "$BASE_URL$1" 2>/dev/null
}

http_code() {
  curl -o /dev/null -sw "%{http_code}" --max-time 5 "$BASE_URL$1" 2>/dev/null
}

# ── Wait for stack ────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Task App — Smoke Test"
echo "  BASE_URL: $BASE_URL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

info "Waiting for stack to be ready..."
for i in $(seq 1 20); do
  if curl -sf --max-time 2 "$BASE_URL/api/health" &>/dev/null; then
    echo "  Stack ready after ${i}s ✅"
    break
  fi
  sleep 1
  if [[ $i -eq 20 ]]; then
    echo -e "${RED}  Stack did not become healthy after 20s — is it running?${NC}"
    echo "  Run: docker compose ps"
    exit 1
  fi
done

# ── 1. Static frontend ────────────────────────────────────────────────────────
info "1. Static frontend (nginx serves HTML)"
BODY=$(get "/")
if echo "$BODY" | grep -qi "Task Manager\|DOCTYPE"; then
  pass "GET / returned HTML frontend"
else
  fail "GET / did not return expected HTML (got: ${BODY:0:80})"
fi

# ── 2. Health endpoint — full dependency check ────────────────────────────────
info "2. Health check — API + PostgreSQL + Redis"
HEALTH=$(get "/api/health")
if echo "$HEALTH" | grep -q '"status":"healthy"'; then
  pass "GET /api/health → healthy"
  POSTGRES_STATUS=$(echo "$HEALTH" | grep -o '"postgres":"[^"]*"' | cut -d'"' -f4)
  REDIS_STATUS=$(echo "$HEALTH" | grep -o '"redis":"[^"]*"' | cut -d'"' -f4)
  [[ "$POSTGRES_STATUS" == "ok" ]] && pass "PostgreSQL reachable" || fail "PostgreSQL not ok: $POSTGRES_STATUS"
  [[ "$REDIS_STATUS"    == "ok" ]] && pass "Redis reachable"     || fail "Redis not ok: $REDIS_STATUS"
else
  fail "GET /api/health did not return healthy (got: $HEALTH)"
fi

# ── 3. List tasks (empty or seeded) ───────────────────────────────────────────
info "3. Task listing"
TASKS=$(get "/api/tasks")
if echo "$TASKS" | grep -q '"tasks"'; then
  COUNT=$(echo "$TASKS" | grep -o '"title"' | wc -l)
  pass "GET /api/tasks returned $COUNT task(s)"
else
  fail "GET /api/tasks failed (got: ${TASKS:0:120})"
fi

# ── 4. Create a task ──────────────────────────────────────────────────────────
info "4. Task CRUD — Create"
TITLE="Smoke test task $(date +%s)"
CREATE=$(post "/api/tasks" "{\"title\":\"$TITLE\",\"description\":\"Created by smoke-test.sh\"}")
if echo "$CREATE" | grep -q '"id"'; then
  TASK_ID=$(echo "$CREATE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
  pass "POST /api/tasks created task (id: $TASK_ID)"
else
  fail "POST /api/tasks failed (got: ${CREATE:0:120})"
  TASK_ID=""
fi

# ── 5. Read single task ───────────────────────────────────────────────────────
info "5. Task CRUD — Read"
if [[ -n "$TASK_ID" ]]; then
  SINGLE=$(get "/api/tasks/$TASK_ID")
  if echo "$SINGLE" | grep -q "\"id\":\"$TASK_ID\""; then
    pass "GET /api/tasks/$TASK_ID returned correct task"
  else
    fail "GET /api/tasks/$TASK_ID failed or returned wrong task"
  fi
else
  warn "Skipping read test — no task ID from create step"
fi

# ── 6. Update task ────────────────────────────────────────────────────────────
info "6. Task CRUD — Update"
if [[ -n "$TASK_ID" ]]; then
  UPDATE=$(put_req "/api/tasks/$TASK_ID" '{"done":true}')
  if echo "$UPDATE" | grep -q '"done":true'; then
    pass "PUT /api/tasks/$TASK_ID updated done=true"
  else
    fail "PUT /api/tasks/$TASK_ID failed (got: ${UPDATE:0:120})"
  fi
else
  warn "Skipping update test — no task ID"
fi

# ── 7. Cache hit — second request should come from Redis ──────────────────────
info "7. Redis cache — list tasks twice, second should say source:cache"
get "/api/tasks" > /dev/null   # prime the cache
CACHED=$(get "/api/tasks")
if echo "$CACHED" | grep -q '"source":"cache"'; then
  pass "Second GET /api/tasks served from Redis cache"
else
  warn "Cache source not confirmed (response: ${CACHED:0:80})"
fi

# ── 8. Delete task ────────────────────────────────────────────────────────────
info "8. Task CRUD — Delete"
if [[ -n "$TASK_ID" ]]; then
  CODE=$(http_code "/api/tasks/$TASK_ID")
  delete_req "/api/tasks/$TASK_ID" > /dev/null
  CODE_AFTER=$(http_code "/api/tasks/$TASK_ID")
  if [[ "$CODE" == "200" && "$CODE_AFTER" == "404" ]]; then
    pass "DELETE /api/tasks/$TASK_ID removed task (200 → 404)"
  else
    fail "DELETE failed (before: $CODE, after: $CODE_AFTER)"
  fi
else
  warn "Skipping delete test — no task ID"
fi

# ── 9. 404 for unknown routes ─────────────────────────────────────────────────
info "9. 404 handling"
CODE=$(http_code "/api/nonexistent-route-xyz")
if [[ "$CODE" == "404" ]]; then
  pass "Unknown API route returns 404"
else
  fail "Expected 404, got $CODE"
fi

# ── 10. Validation — missing required field ───────────────────────────────────
info "10. Input validation"
CODE=$(curl -o /dev/null -sw "%{http_code}" --max-time 5 \
  -X POST -H "Content-Type: application/json" \
  -d '{}' "$BASE_URL/api/tasks" 2>/dev/null)
if [[ "$CODE" == "400" ]]; then
  pass "POST /api/tasks with empty body returns 400"
else
  fail "Expected 400 for missing title, got $CODE"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  Results: ${GREEN}%d passed${NC}  ${RED}%d failed${NC}\n" "$PASS" "$FAIL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}  Smoke test FAILED. Check: docker compose logs${NC}"
  exit 1
else
  echo -e "${GREEN}  All smoke tests passed ✅${NC}"
fi
echo ""