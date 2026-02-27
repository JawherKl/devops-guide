#!/usr/bin/env bash
# =============================================================================
# docker-swarm/example/deploy.sh
# =============================================================================
# Automated Swarm deployment script.
# Initializes the swarm, creates secrets, deploys the full stack.
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh             # first-time setup + deploy
#   ./deploy.sh update      # update image tags only
#   ./deploy.sh status      # show stack status
#   ./deploy.sh teardown    # remove stack + leave swarm
# =============================================================================

set -euo pipefail

STACK_NAME="taskapp"
COMPOSE_FILE="docker-stack.yml"
API_IMAGE="taskapp-api"
API_TAG="${API_TAG:-1.0.0}"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Init swarm ────────────────────────────────────────────────────────────────
init_swarm() {
  if docker info --format '{{.Swarm.LocalNodeState}}' | grep -q "active"; then
    warn "Swarm already initialized"
  else
    info "Initializing Docker Swarm..."
    docker swarm init
    success "Swarm initialized"
  fi
}

# ── Create secrets ────────────────────────────────────────────────────────────
create_secrets() {
  info "Creating Swarm secrets..."

  # Check each secret — create only if it doesn't exist
  for secret_name in db_password redis_password; do
    if docker secret ls --format '{{.Name}}' | grep -q "^${secret_name}$"; then
      warn "Secret '${secret_name}' already exists — skipping"
    else
      read -rsp "Enter value for '${secret_name}': " secret_value
      echo
      echo "$secret_value" | docker secret create "$secret_name" -
      success "Created secret: ${secret_name}"
    fi
  done
}

# ── Deploy stack ──────────────────────────────────────────────────────────────
deploy() {
  info "Deploying stack '${STACK_NAME}'..."
  docker stack deploy \
    --compose-file "$COMPOSE_FILE" \
    --with-registry-auth \
    --prune \
    "$STACK_NAME"
  success "Stack deployed"

  info "Waiting for services to stabilize (30s)..."
  sleep 30
  show_status
}

# ── Update image ──────────────────────────────────────────────────────────────
update() {
  info "Updating API to ${API_IMAGE}:${API_TAG}..."
  docker service update \
    --image "${API_IMAGE}:${API_TAG}" \
    --update-parallelism 1 \
    --update-delay 15s \
    --update-order start-first \
    --update-failure-action rollback \
    "${STACK_NAME}_api"
  success "Update initiated — watching rollout..."
  docker service ps "${STACK_NAME}_api" --filter "desired-state=running"
}

# ── Status ────────────────────────────────────────────────────────────────────
show_status() {
  echo ""
  info "=== Stack Services ==="
  docker stack services "$STACK_NAME"
  echo ""
  info "=== Service Tasks ==="
  docker stack ps "$STACK_NAME" --filter "desired-state=running" --no-trunc
  echo ""
  info "=== Node Status ==="
  docker node ls
}

# ── Teardown ──────────────────────────────────────────────────────────────────
teardown() {
  warn "Removing stack '${STACK_NAME}'..."
  docker stack rm "$STACK_NAME"
  warn "Waiting for containers to stop..."
  sleep 15
  warn "Removing secrets..."
  docker secret rm db_password redis_password 2>/dev/null || true
  warn "Leaving swarm..."
  docker swarm leave --force
  success "Teardown complete"
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "${1:-deploy}" in
  init)     init_swarm ;;
  secrets)  create_secrets ;;
  deploy)
    init_swarm
    create_secrets
    deploy
    ;;
  update)   update ;;
  status)   show_status ;;
  teardown) teardown ;;
  *)
    echo "Usage: $0 [init|secrets|deploy|update|status|teardown]"
    exit 1
    ;;
esac