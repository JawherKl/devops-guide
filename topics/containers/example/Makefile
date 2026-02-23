# =============================================================================
# Makefile — Task App convenience commands
# Run `make help` to see all targets
# =============================================================================

.PHONY: help dev up down nuke logs logs-errors ps build \
        shell-api shell-db seed test smoke health \
        backup restore backup-list clean disk

# ── Default target ────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  Task App — Available commands"
	@echo "  ─────────────────────────────────────────────────────"
	@echo "  make dev          Start development stack (live reload, debug ports)"
	@echo "  make up           Start production stack (compose.yml only)"
	@echo "  make down         Stop and remove containers + networks"
	@echo "  make nuke         Stop + remove containers, networks, AND volumes"
	@echo "  make build        Rebuild all images without cache"
	@echo "  make logs         Follow all service logs"
	@echo "  make logs-errors  Follow logs, show only ERROR/WARN lines"
	@echo "  make ps           Show service status and health"
	@echo "  make health       Detailed health check + resource usage per service"
	@echo "  make shell-api    Open shell inside the running API container"
	@echo "  make shell-db     Open psql inside the running postgres container"
	@echo "  make seed         Re-apply seed data to the database"
	@echo "  make smoke        Full end-to-end smoke test (10 checks)"
	@echo "  make test         Quick inline API smoke tests"
	@echo "  make backup       Backup PostgreSQL to ./backups/"
	@echo "  make backup-list  List available backups"
	@echo "  make clean        Remove stopped containers + dangling images"
	@echo "  make disk         Show Docker disk usage"
	@echo ""

# ── Guards ────────────────────────────────────────────────────────────────────
.env:
	@echo "❌  .env not found. Run: cp .env.example .env"; exit 1

# ── Stack management ──────────────────────────────────────────────────────────
dev: .env
	docker compose up -d --build
	@echo ""
	@echo "  ✅ Development stack started"
	@echo "  ──────────────────────────────────────────"
	@echo "  App:      http://localhost"
	@echo "  API:      http://localhost:3000/api/health"
	@echo "  Adminer:  http://localhost:8080"
	@echo "  DB:       localhost:5432"
	@echo "  Redis:    localhost:6379"
	@echo ""
	@make ps

up: .env
	docker compose -f compose.yml up -d --build
	@echo "✅ Production stack started"
	@make ps

down:
	docker compose down

nuke:
	@echo "⚠  Deleting ALL data including volumes. Press Ctrl+C to cancel..."
	@sleep 3
	docker compose down -v --remove-orphans
	@echo "🗑  Stack and all volumes removed"

build:
	docker compose build --no-cache

# ── Observability ─────────────────────────────────────────────────────────────
logs:
	docker compose logs -f

logs-errors:
	@chmod +x scripts/logs.sh && ./scripts/logs.sh --errors

ps:
	@docker compose ps

health:
	@chmod +x scripts/health-check.sh && ./scripts/health-check.sh

# ── Debugging ─────────────────────────────────────────────────────────────────
shell-api:
	docker compose exec api sh

shell-db:
	@PGPASSWORD=$$(grep POSTGRES_PASSWORD .env | cut -d= -f2) \
	docker compose exec postgres psql -U appuser -d $$(grep POSTGRES_DB .env | cut -d= -f2)

seed:
	docker compose exec postgres psql -U appuser \
	  -d $$(grep POSTGRES_DB .env | cut -d= -f2) \
	  -f /docker-entrypoint-initdb.d/02-seed.sql
	@echo "✅ Seed data applied"

# ── Testing ───────────────────────────────────────────────────────────────────
test:
	@echo "Running API smoke tests..."
	@echo ""

	@echo -n "  GET /api/health ... "
	@curl -sf http://localhost/api/health | grep -q '"status":"healthy"' \
	  && echo "✅ PASS" || echo "❌ FAIL"

	@echo -n "  GET /api/tasks ... "
	@curl -sf http://localhost/api/tasks | grep -q '\[' \
	  && echo "✅ PASS" || echo "❌ FAIL"

	@echo -n "  POST /api/tasks ... "
	@TASK_ID=$$(curl -sf -X POST http://localhost/api/tasks \
	  -H "Content-Type: application/json" \
	  -d '{"title":"Smoke test task","description":"Auto-created by make test"}' \
	  | grep -o '"id":"[^"]*"' | cut -d'"' -f4) && \
	  [ -n "$$TASK_ID" ] && echo "✅ PASS (id=$$TASK_ID)" || echo "❌ FAIL"

	@echo -n "  Frontend / ... "
	@curl -sf http://localhost/ | grep -q "Task Manager" \
	  && echo "✅ PASS" || echo "❌ FAIL"

	@echo ""

smoke:
	@chmod +x scripts/smoke-test.sh && ./scripts/smoke-test.sh

backup:
	@chmod +x scripts/backup-db.sh && ./scripts/backup-db.sh backup

backup-list:
	@chmod +x scripts/backup-db.sh && ./scripts/backup-db.sh list

# ── Maintenance ───────────────────────────────────────────────────────────────
clean:
	docker container prune -f
	docker image prune -f

disk:
	docker system df