# Custom Docker Networks

> Understand Docker's network drivers, implement proper frontend/backend isolation, and use DNS-based service discovery — the foundation of secure multi-container communication.

---

## 💡 Why Custom Networks?

The **default bridge network** is convenient but insecure: it lets all containers on the host communicate freely, and containers can only find each other by IP address (no DNS).

**User-defined networks** give you:

| Feature | Default Bridge | User-Defined Bridge |
|---------|---------------|---------------------|
| Automatic DNS by container name | ❌ | ✅ |
| Network isolation between stacks | ❌ | ✅ |
| `internal: true` (no internet) | ❌ | ✅ |
| Alias-based discovery | ❌ | ✅ |
| Inspect/manage independently | Limited | ✅ |

---

## 🌐 Network Drivers

| Driver | Scope | Use case |
|--------|-------|----------|
| `bridge` | Single host | Default — isolated containers on one machine |
| `overlay` | Multi-host | Docker Swarm — containers across multiple nodes |
| `host` | Single host | No isolation — container uses host network directly |
| `none` | Single host | Complete isolation — no networking at all |
| `macvlan` | Single host | Container gets its own MAC/IP on physical network |

---

## 📐 Architecture: Frontend / Backend Isolation

This is the **correct production network topology** for a multi-tier application.

```
                    ╔═════════════════════════════════════════════╗
                    ║              Docker Host                    ║
                    ║                                             ║
  Internet          ║   ┌─────────────────────────────────────┐   ║
──────────►:80/443──╫──►│           frontend network          │   ║
                    ║   │    (bridge, external access)        │   ║
                    ║   │  ┌──────────────────────────────┐   │   ║
                    ║   │  │         nginx (proxy)         │  │   ║
                    ║   │  │         :80, :443             │  │   ║
                    ║   │  └───────────────┬──────────────┘   │   ║
                    ║   └──────────────────┼──────────────────┘   ║
                    ║                      │ nginx → api          ║
                    ║   ┌──────────────────┼──────────────────┐   ║
                    ║   │           api    │                  │   ║
                    ║   │    ┌─────────────▼────────────┐     │   ║
                    ║   │    │          api              │    │   ║
                    ║   │    │          :3000            │    │   ║
                    ║   │    └──────┬────────────┬───────┘    │   ║
                    ║   │          │            │             │   ║
                    ║   │  ┌───────▼───┐  ┌────▼──────┐       │   ║
                    ║   │  │ postgres  │  │   redis   │       │   ║
                    ║   │  │  :5432    │  │   :6379   │       │   ║
                    ║   │  └───────────┘  └───────────┘       │   ║
                    ║   │     backend network                 │   ║
                    ║   │   (internal: true — no internet)    │   ║
                    ║   └─────────────────────────────────────┘   ║
                    ║                                             ║
                    ╚═════════════════════════════════════════════╝

Access rules:
  ✅ Internet → nginx (port 80/443 published)
  ✅ nginx → api (same frontend network)
  ✅ api → postgres (same backend network)
  ✅ api → redis (same backend network)
  ❌ Internet → postgres (no published port, backend is internal)
  ❌ Internet → redis (same)
  ❌ nginx → postgres (nginx is not on backend network)
```

---

## 📁 Files

| File | Purpose |
|------|---------|
| `compose.yml` | Full stack with frontend/backend network isolation |
| `README.md` | This guide |

---

## 🔧 Network Configuration in Compose

```yaml
# compose.yml
services:
  proxy:
    image: nginx:1.25-alpine
    ports:
      - "80:80"
    networks:
      - frontend          # only on frontend — no access to backend

  api:
    build: ./api
    networks:
      - frontend          # reachable from proxy
      - backend           # can reach postgres and redis
    # No ports: published — only proxy talks to api

  postgres:
    image: postgres:16-alpine
    networks:
      - backend           # only on backend — unreachable from internet or proxy
    # No ports: — never expose database externally

  redis:
    image: redis:7-alpine
    networks:
      - backend

networks:
  frontend:
    driver: bridge

  backend:
    driver: bridge
    internal: true        # ← key: no routing to/from the internet
```

---

## 🔍 DNS Resolution in Practice

```bash
# Start the stack
docker compose up -d

# From inside the API container, resolve service names
docker compose exec api sh -c "nslookup postgres"
# Server: 127.0.0.11          ← Docker's embedded DNS
# Address: 127.0.0.11:53
# Name: postgres
# Address: 172.20.0.3         ← internal IP, auto-assigned

# Connect to postgres by name (no need to know the IP)
docker compose exec api sh -c "nc -zv postgres 5432"
# Connection to postgres 5432 port [tcp/postgresql] succeeded! ✅

# Try to reach postgres from a container NOT on the backend network
docker run --rm --network containers_frontend alpine \
  sh -c "nc -zw2 postgres 5432 && echo open || echo 'blocked ✅'"
# blocked ✅
```

---

## 📡 Network Aliases

Aliases give a service an additional DNS name within a specific network:

```yaml
services:
  api:
    networks:
      backend:
        aliases:
          - app-internal    # reachable as 'api' OR 'app-internal' on backend

  # Useful for blue/green deployments:
  api-blue:
    networks:
      backend:
        aliases:
          - api-active      # point alias to blue
  api-green:
    networks:
      backend:
        aliases:
          - api-active      # switch alias to green during deploy
```

---

## 🛠️ Network CLI Commands

```bash
# List all networks
docker network ls

# Inspect a network (see connected containers, subnet, config)
docker network inspect containers_backend

# Verify internal flag
docker network inspect containers_backend | jq '.[0].Internal'
# true ✅

# See which networks a container belongs to
docker inspect myapp-api | jq '.[0].NetworkSettings.Networks | keys'

# Temporarily connect a container to another network
docker network connect containers_backend debug-container

# Disconnect
docker network disconnect containers_backend debug-container

# Remove unused networks
docker network prune
```

---

## 🧪 Labs

### Lab 1: Verify network isolation

```bash
docker compose up -d

# ✅ Should succeed — api can reach postgres (same backend network)
docker compose exec api sh -c "nc -zv postgres 5432"

# ✅ Should succeed — proxy can reach api (same frontend network)
docker compose exec proxy sh -c "nc -zv api 3000"

# ❌ Should FAIL — proxy cannot reach postgres (different network, backend is internal)
docker compose exec proxy sh -c "nc -zw2 postgres 5432 && echo 'open' || echo 'blocked ✅'"

# ❌ Should FAIL — no container can reach the internet from backend
docker compose exec postgres sh -c "nc -zw2 8.8.8.8 53 && echo 'open' || echo 'blocked ✅'"
```

### Lab 2: Observe DNS from inside containers

```bash
# See Docker's DNS server from inside the api container
docker compose exec api cat /etc/resolv.conf
# nameserver 127.0.0.11   ← Docker's embedded DNS

# Resolve all services by name
docker compose exec api sh -c "
  for svc in proxy postgres redis; do
    echo -n \"\$svc → \"; nslookup \$svc 2>/dev/null | grep Address | tail -1
  done
"
```

### Lab 3: Manual network creation and test

```bash
# Create isolated networks manually
docker network create --driver bridge lab-frontend
docker network create --driver bridge --internal lab-backend

# Verify internal flag
docker network inspect lab-backend | jq '.[0].Internal'

# Cleanup
docker network rm lab-frontend lab-backend
```

---

## ✅ Checklist

- [ ] User-defined bridge networks used (not the default bridge)
- [ ] Database and cache services on an `internal: true` backend network
- [ ] No database or cache ports published externally
- [ ] Only the reverse proxy/load balancer has published ports
- [ ] Services connect to only the networks they need (least privilege)
- [ ] `docker network prune` run regularly on CI runners
- [ ] Network aliases used instead of hardcoded IPs for service discovery