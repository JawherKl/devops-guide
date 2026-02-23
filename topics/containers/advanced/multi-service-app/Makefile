# =============================================================================
# Makefile — Multi-service app shortcuts
# =============================================================================
# Usage: make <target>
# Run `make help` to see all available targets.
# =============================================================================

.PHONY: help up down dev logs ps shell-api shell-db migrate seed clean nuke

# ── Default ───────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  Multi-Service App — Available commands"
	@echo "  ──────────────────────────────────────"
	@echo "  make up          Start production stack (compose.yml only)"
	@echo "  make dev         Start development stack (auto-merges override)"
	@echo "  make down        Stop and remove containers + networks"
	@echo "  make nuke        Stop + remove containers, networks, AND volumes"
	@echo "  make logs        Follow logs for all services"
	@echo "  make ps          Show service status and health"
	@echo "  make shell-api   Open shell in running API container"
	@echo "  make shell-db    Open psql in running postgres container"
	@echo "  make seed        Run seed SQL against the database"
	@echo "  make clean       Remove stopped containers + unused images"
	@echo ""

# ── Stack management ──────────────────────────────────────────────────────────

## Start production stack (compose.yml only — no dev overrides)
up:
	@[ -f .env ] || (echo "❌ .env not found. Run: cp .env.example .env" && exit 1)
	docker compose -f compose.yml up -d --build
	@echo "✅ Production stack started"
	@make ps

## Start development stack (auto-merges compose.override.yml)
dev:
	@[ -f .env ] || (echo "❌ .env not found. Run: cp .env.example .env" && exit 1)
	docker compose up -d --build
	@echo "✅ Development stack started"
	@make ps
	@echo ""
	@echo "  Services:"
	@echo "  API:      http://localhost:3000"
	@echo "  Adminer:  http://localhost:8080"
	@echo "  Mailhog:  http://localhost:8025"

## Stop and remove containers + networks (preserve volumes)
down:
	docker compose down

## Stop and remove EVERYTHING including volumes — destroys all data
nuke:
	@echo "⚠  This will DELETE all database data. Press Ctrl+C to cancel..."
	@sleep 3
	docker compose down -v --remove-orphans
	@echo "🗑  All containers, networks, and volumes removed"

# ── Observability ─────────────────────────────────────────────────────────────

## Follow logs for all services
logs:
	docker compose logs -f

## Show service status + health
ps:
	docker compose ps

# ── Debugging ─────────────────────────────────────────────────────────────────

## Open a shell in the running API container
shell-api:
	docker compose exec api sh

## Open psql in the running postgres container
shell-db:
	docker compose exec postgres psql -U appuser -d $${POSTGRES_DB:-appdb}

## Run seed SQL (idempotent — safe to run multiple times)
seed:
	docker compose exec postgres psql -U appuser -d $${POSTGRES_DB:-appdb} -f /docker-entrypoint-initdb.d/02-seed.sql
	@echo "✅ Seed data applied"

# ── Maintenance ───────────────────────────────────────────────────────────────

## Remove stopped containers and unused images
clean:
	docker container prune -f
	docker image prune -f
	@echo "✅ Pruned stopped containers and dangling images"

## Show disk usage by containers, images, and volumes
disk:
	docker system df