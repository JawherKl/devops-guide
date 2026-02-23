#!/usr/bin/env bash
# =============================================================================
# scripts/health-check.sh — Detailed health status for all stack services
# =============================================================================
# Run at any time to see the current health of all containers.
# More detailed than `docker compose ps`.
# =============================================================================

set -uo pipefail

GREEN='\033[0;32m'; RED='\033[0;31m'
YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

SERVICES=(taskapp-nginx taskapp-api taskapp-postgres taskapp-redis)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
printf "  %-24s %-12s %-12s %s\n" "CONTAINER" "STATUS" "HEALTH" "LAST CHECK"
echo "  ────────────────────────────────────────────────────────────────────"

for name in "${SERVICES[@]}"; do
  if ! docker inspect "$name" &>/dev/null; then
    printf "  ${YELLOW}%-24s %-12s${NC}\n" "$name" "not found"
    continue
  fi

  STATUS=$(docker inspect "$name" --format '{{.State.Status}}' 2>/dev/null)
  HEALTH=$(docker inspect "$name" --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' 2>/dev/null)
  LAST_OUTPUT=$(docker inspect "$name" --format '{{if .State.Health}}{{with index .State.Health.Log 0}}{{.Output}}{{end}}{{end}}' 2>/dev/null | tr -d '\n' | cut -c1-60)

  # Color by health
  if [[ "$HEALTH" == "healthy" ]]; then
    COLOR="$GREEN"
  elif [[ "$HEALTH" == "unhealthy" ]]; then
    COLOR="$RED"
  elif [[ "$STATUS" == "running" ]]; then
    COLOR="$YELLOW"
  else
    COLOR="$RED"
  fi

  printf "  ${COLOR}%-24s %-12s %-12s${NC} %s\n" "$name" "$STATUS" "$HEALTH" "$LAST_OUTPUT"
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Resource usage ────────────────────────────────────────────────────────────
echo "  Resource Usage (live):"
echo "  ───────────────────────────────────────────────────────────────────"
docker stats --no-stream --format \
  "  {{printf \"%-24s\" .Name}} CPU: {{printf \"%-8s\" .CPUPerc}}  MEM: {{.MemUsage}}" \
  "${SERVICES[@]}" 2>/dev/null || echo "  (containers not running)"
echo ""

# ── API health endpoint ───────────────────────────────────────────────────────
echo "  API Health Endpoint:"
echo "  ───────────────────────────────────────────────────────────────────"
HEALTH_RESP=$(curl -sf --max-time 3 http://localhost/api/health 2>/dev/null || echo '{"error":"unreachable"}')
echo "  $HEALTH_RESP" | python3 -m json.tool 2>/dev/null || echo "  $HEALTH_RESP"
echo ""