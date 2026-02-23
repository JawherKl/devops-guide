#!/usr/bin/env bash
# =============================================================================
# scripts/logs.sh — Structured log viewer for the example stack
# =============================================================================
#
# Usage:
#   ./scripts/logs.sh              # follow all services
#   ./scripts/logs.sh api          # follow api only
#   ./scripts/logs.sh api postgres # follow multiple services
#   ./scripts/logs.sh --errors     # show only ERROR/WARN lines
#   ./scripts/logs.sh --tail 100   # last 100 lines then follow
# =============================================================================

set -uo pipefail

TAIL_LINES=50
ERRORS_ONLY=false
SERVICES=()

# ── Parse args ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --errors)    ERRORS_ONLY=true; shift ;;
    --tail)      TAIL_LINES="$2"; shift 2 ;;
    --tail=*)    TAIL_LINES="${1#*=}"; shift ;;
    -*)          echo "Unknown flag: $1"; exit 1 ;;
    *)           SERVICES+=("$1"); shift ;;
  esac
done

# ── Colors for service names ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

# ── Build compose logs command ────────────────────────────────────────────────
COMPOSE_CMD=(docker compose logs -f --tail "$TAIL_LINES")
[[ ${#SERVICES[@]} -gt 0 ]] && COMPOSE_CMD+=("${SERVICES[@]}")

if $ERRORS_ONLY; then
  "${COMPOSE_CMD[@]}" 2>&1 | grep -iE "error|warn|fatal|critical|exception" \
    | while IFS= read -r line; do
        if   echo "$line" | grep -qiE "fatal|critical"; then echo -e "${RED}${line}${NC}"
        elif echo "$line" | grep -qiE "error|exception"; then echo -e "${RED}${line}${NC}"
        elif echo "$line" | grep -qiE "warn"; then echo -e "${YELLOW}${line}${NC}"
        else echo "$line"
        fi
      done
else
  "${COMPOSE_CMD[@]}"
fi