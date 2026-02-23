# End-to-End Example — Full Stack Application

> A complete, runnable project that combines every concept from `basics/` and `advanced/` into one cohesive production-pattern application. Start here if you want to see how everything fits together.

---

## 🏗️ What This Builds

```
                    ┌────────────────────────────────────────────┐
  Browser / curl    │            Docker Host                     │
       │            │                                            │
       │ :80        │  ┌──────────────────────────────────────┐  │
       └───────────►│  │   nginx (reverse proxy + static)     │  │
                    │  │   - Serves React frontend            │  │
                    │  │   - Proxies /api/* → Node.js API     │  │
                    │  └────────────┬─────────────────────────┘  │
                    │               │ frontend network           │
                    │  ┌────────────▼─────────────────────────┐  │
                    │  │   Node.js REST API (:3000)           │  │
                    │  │   - /api/health    liveness check    │  │
                    │  │   - /api/tasks     CRUD endpoints    │  │
                    │  └──────┬──────────────────┬────────────┘  │
                    │         │ backend network (internal)       │
                    │  ┌──────▼──────┐    ┌──────▼──────┐        │
                    │  │  PostgreSQL │    │    Redis     │       │
                    │  │  :5432      │    │    :6379     │       │
                    │  │  tasks DB   │    │  session     │       │
                    │  └─────────────┘    │  cache       │       │
                    │                     └─────────────┘        │
                    └────────────────────────────────────────────┘

Concepts demonstrated:
  ✅ Multi-stage build (API Dockerfile: deps → dev → prod)
  ✅ Frontend build → nginx serve pattern
  ✅ Frontend/backend network isolation (internal: true)
  ✅ Health checks with dependency ordering
  ✅ Named volumes for persistent data
  ✅ Bind mount + dev/prod config split (compose.override.yml)
  ✅ Non-root users in all containers
  ✅ Resource limits on all services
  ✅ .env.example for secrets management
```

---

## 📁 Project Structure

```
example/
├── README.md                ← You are here
├── compose.yml              ← Production stack
├── compose.override.yml     ← Dev overrides (auto-merged locally)
├── .env.example             ← Required environment variables template
├── Makefile                 ← Convenience commands
│
├── app/                     ← Node.js REST API
│   ├── Dockerfile           ← Multi-stage: deps → development → production
│   ├── package.json
│   ├── .dockerignore
│   └── src/
│       └── index.js         ← Express API with tasks CRUD + health check
│
├── nginx/
│   ├── nginx.conf           ← Reverse proxy + static file serving
│   └── frontend/            ← Static frontend (HTML + JS — no build step needed)
│       └── index.html       ← Single-page task manager UI
│
└── postgres/
    ├── init.sql             ← Schema: tasks table
    └── seed.sql             ← Sample tasks data
```

---

## 🚀 Quick Start

```bash
# 1. Clone and navigate
git clone https://github.com/JawherKl/devops-guide.git
cd devops-guide/topics/containers/example

# 2. Set up environment
cp .env.example .env
# Edit .env if needed (default values work for local dev)

# 3. Start the development stack
make dev
# OR: docker compose up -d --build

# 4. Verify everything is healthy
make ps
# All services should show "healthy" status

# 5. Open the app
open http://localhost        # macOS
xdg-open http://localhost    # Linux
# Or just: curl http://localhost/api/health

# 6. Try the API
curl http://localhost/api/health
curl http://localhost/api/tasks
curl -X POST http://localhost/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"My first task","description":"Created via Docker!"}'
```

---

## 🛠️ Available Commands

```bash
make dev          # Start development stack (with source mounting + debug ports)
make up           # Start production stack (compose.yml only)
make down         # Stop and remove containers
make nuke         # Stop and remove everything including volumes (destroys data)
make logs         # Follow logs for all services
make ps           # Show service status
make shell-api    # Open shell in running API container
make shell-db     # Open psql in running postgres container
make test         # Run API health check tests
make clean        # Remove stopped containers and dangling images
```

---

## 🧪 API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Health check — returns status of API, DB, and cache |
| `GET` | `/api/tasks` | List all tasks |
| `POST` | `/api/tasks` | Create a task `{ title, description }` |
| `PUT` | `/api/tasks/:id` | Update a task `{ title?, description?, done? }` |
| `DELETE` | `/api/tasks/:id` | Delete a task |
| `GET` | `/` | Frontend (served by nginx) |

---

## 🔍 What to Observe

### 1. Startup ordering with health checks

```bash
docker compose up -d
docker compose ps
# postgres starts first → becomes healthy → api starts → becomes healthy → nginx starts
# Without health checks, nginx would start before the API is ready
```

### 2. Network isolation

```bash
# API can reach postgres
docker compose exec api sh -c "nc -zv postgres 5432"

# nginx CANNOT reach postgres (frontend network only)
docker compose exec nginx sh -c "nc -zw2 postgres 5432 && echo open || echo blocked"
# blocked ✅
```

### 3. Volume persistence

```bash
# Create some tasks through the UI or API
curl -X POST http://localhost/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Persistent task","description":"I survive restarts"}'

# Restart the postgres container
docker compose restart postgres
sleep 5

# Data is still there
curl http://localhost/api/tasks | jq '.[0].title'
# "Persistent task" ✅
```

### 4. Dev vs prod config

```bash
# See what dev config adds (override merged)
docker compose config | grep -A3 "ports:"

# See prod config only
docker compose -f compose.yml config | grep -A3 "ports:"
# Fewer exposed ports in production
```

---

## 🔗 Concepts This Demonstrates

| Concept | Where to learn more |
|---------|-------------------|
| Multi-stage Dockerfile | [advanced/multi-stage-build](../advanced/multi-stage-build/) |
| Custom networks + isolation | [advanced/custom-networks](../advanced/custom-networks/) |
| Compose + health checks | [advanced/multi-service-app](../advanced/multi-service-app/) |
| Non-root user in Dockerfile | [advanced/security](../advanced/security/) |
| Named volumes + backup | [basics/05-volumes](../basics/05-volumes/) |
| .dockerignore + image size | [basics/04-images](../basics/04-images/) |