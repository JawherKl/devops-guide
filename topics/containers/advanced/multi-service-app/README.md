# Multi-Service Application with Docker Compose

> A production-grade multi-container application stack demonstrating health checks, dependency ordering, network isolation, resource limits, and the dev/prod configuration split pattern.

---

## 📐 Architecture

```
                         ┌──────────────────────────────────────┐
Internet                 │            Docker Host               │
   │                     │                                      │
   │  :80 / :443         │  ┌──────────┐     frontend network   │
   └────────────────────►│  │  nginx   │                        │
                         │  │  (proxy) │                        │
                         │  └────┬─────┘                        │
                         │       │        ┌──────────────────┐  │
                         │       │        │  backend network │  │
                         │  ┌────▼─────┐  │  (internal=true) │  │
                         │  │   api    ├──┤►┌──────────────┐ │  │
                         │  │ :3000    │  │ │  postgres    │ │  │
                         │  └──────────┘  │ │  :5432       │ │  │
                         │                │ └──────────────┘ │  │
                         │                │ ┌──────────────┐ │  │
                         │                │ │   redis      │ │  │
                         │                │ │  :6379       │ │  │
                         │                │ └──────────────┘ │  │
                         │                └──────────────────┘  │
                         └──────────────────────────────────────┘
```

**Key design decisions:**
- `backend` network is `internal: true` — no external internet access, only the API can reach DB/cache
- Nginx is the only container with published ports — everything else is internal
- Health checks guard all `depends_on` so services only start when dependencies are truly ready

---

## 📁 Files

| File | Purpose |
|------|---------|
| `compose.yml` | Production service definitions |
| `compose.override.yml` | Dev overrides — auto-merged locally, ignored in prod |
| `.env.example` | Template for required environment variables |
| `.env` | Your local secrets — **gitignored, never commit** |

---

## 🚀 Usage

### Development (local)

```bash
# 1. Set up environment
cp .env.example .env
# Edit .env with your values (dev passwords are fine locally)

# 2. Start the full stack
# Docker automatically merges compose.override.yml
docker compose up -d

# 3. Watch logs
docker compose logs -f api

# 4. Access services
# API:      http://localhost:3000
# Adminer:  http://localhost:8080  (DB admin UI)
# Mailhog:  http://localhost:8025  (catch outbound email)
# DB:       localhost:5432         (connect with DBeaver, pgAdmin, etc.)
```

### Production

```bash
# Explicitly specify only compose.yml — override file is NOT loaded
docker compose -f compose.yml up -d

# Or set COMPOSE_FILE in your CI/CD environment
export COMPOSE_FILE=compose.yml
docker compose up -d
```

---

## 🏥 Health Checks — Why They Matter

Without health checks, `depends_on` only waits for the container to *start*, not to be *ready*. This causes race conditions where your API starts before PostgreSQL has finished its initialization.

```yaml
# ❌ Without health check — api may start before postgres is ready
depends_on:
  - postgres

# ✅ With health check — api waits until postgres is actually accepting connections
depends_on:
  postgres:
    condition: service_healthy
```

```bash
# See health status of all services
docker compose ps

# Inspect health check details
docker inspect myapp-postgres | jq '.[0].State.Health'

# Follow health check logs
docker inspect myapp-api | jq '.[0].State.Health.Log'
```

---

## 🌐 Network Isolation

```bash
# Verify backend network is truly internal (no external routing)
docker network inspect myapp_backend | jq '.[0].Internal'
# true ✅

# Verify postgres is NOT reachable from outside the backend network
docker run --rm --network myapp_frontend alpine \
  sh -c "nc -z -w2 postgres 5432 && echo open || echo closed"
# closed ✅ — postgres unreachable from frontend network
```

---

## 📊 Resource Limits

All services in `compose.yml` define CPU and memory limits. This prevents a misbehaving container from starving others on the host.

```bash
# Check live resource usage
docker stats

# Check configured limits
docker inspect myapp-api | jq '.[0].HostConfig.Memory'
docker inspect myapp-api | jq '.[0].HostConfig.NanoCpus'
```

---

## 🧪 Hands-On Labs

### Lab 1: Observe health check dependency ordering

```bash
docker compose up -d
# Watch the startup order — postgres starts first, waits for healthy,
# then api starts, waits for healthy, then proxy starts
docker compose ps
docker compose logs | grep -E "healthy|starting|started"
```

### Lab 2: Dev vs prod config diff

```bash
# See what the merged dev config looks like
docker compose config

# See what the prod-only config looks like (no override)
docker compose -f compose.yml config

# Diff them
diff <(docker compose config) <(docker compose -f compose.yml config)
```

### Lab 3: Simulate a service crash and recovery

```bash
# Kill the API container
docker compose kill api

# Watch it restart automatically (restart: unless-stopped)
watch docker compose ps

# Check restart count
docker inspect myapp-api | jq '.[0].RestartCount'
```

### Lab 4: Scale the API (if behind a load-balancing proxy)

```bash
docker compose up -d --scale api=3
docker compose ps
# 3 api instances running
```

---

## ✅ Checklist

- [ ] `depends_on` uses `condition: service_healthy` everywhere
- [ ] Backend network set to `internal: true`
- [ ] No database or cache ports published externally in `compose.yml`
- [ ] Resource limits (`deploy.resources.limits`) defined for all services
- [ ] `restart: unless-stopped` on all production services
- [ ] `.env.example` committed, `.env` gitignored
- [ ] `compose.override.yml` used for all dev-only config (ports, volumes, tools)
- [ ] Named volumes used for all persistent data