# 05 — Volumes & Storage

> Persist data beyond the container lifecycle. Understand when to use named volumes, bind mounts, and tmpfs — and how to back up and restore data.

---

## 📖 Storage Types

| Type | Managed by | Survives `docker rm`? | Use case |
|------|-----------|----------------------|---------|
| **Named volume** | Docker Engine | ✅ Yes | Production DB data, uploads, cache |
| **Bind mount** | Host OS | ✅ Yes (it's a host path) | Dev source code, config files |
| **tmpfs** | Host memory | ❌ No (memory only) | Sensitive temp data (tokens, sessions) |
| **Anonymous volume** | Docker Engine | ❌ Removed with `--rm` | Throw-away scratch space |

---

## 📦 Named Volumes

```bash
# Create a named volume
docker volume create mydata

# List volumes
docker volume ls

# Inspect (see actual host path)
docker volume inspect mydata
# Mountpoint: /var/lib/docker/volumes/mydata/_data

# Use volume in a container
docker run -d \
  --name postgres \
  -v mydata:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  postgres:16-alpine

# The data in mydata persists even when the container is removed:
docker rm -f postgres
docker run -d --name postgres2 -v mydata:/var/lib/postgresql/data postgres:16-alpine
# postgres2 starts with all the data from the previous container ✅

# Remove a volume (only when unused by any container)
docker volume rm mydata

# Remove ALL unused volumes
docker volume prune
```

---

## 📁 Bind Mounts

```bash
# Mount a host directory into a container
docker run -d \
  -v /home/user/app:/app \           # absolute path required
  myapp

# Shorthand with $(pwd) for current directory
docker run -d \
  -v $(pwd)/src:/app/src \           # mount source for live reload
  -v $(pwd)/nginx.conf:/etc/nginx/nginx.conf:ro \  # read-only config
  myapp

# Use --mount syntax (more explicit, same result)
docker run -d \
  --mount type=bind,source=$(pwd)/config,target=/app/config,readonly \
  myapp
```

### Bind mount flags

| Flag | Meaning |
|------|---------|
| `:ro` or `readonly` | Container cannot write — good for config files |
| `:rw` | Read-write (default) |
| `:z` | Relabel for SELinux (shared between containers) |
| `:Z` | Relabel for SELinux (private, single container) |

---

## 💾 tmpfs Mounts

Use for data that must **never touch disk** — session tokens, JWT secrets, temporary processing.

```bash
# tmpfs via --tmpfs flag
docker run -d \
  --tmpfs /tmp:size=100m,mode=1777 \
  --tmpfs /run:size=10m \
  myapp

# tmpfs via --mount (more explicit)
docker run -d \
  --mount type=tmpfs,target=/tmp,tmpfs-size=104857600 \
  myapp
```

In Compose:

```yaml
services:
  api:
    tmpfs:
      - /tmp:size=100m
      - /run:size=10m
```

---

## 🗂️ Compose Volume Patterns

```yaml
services:
  postgres:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data   # named volume — persists
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql:ro  # read-only bind mount

  api:
    volumes:
      - ./src:/app/src:delegated    # bind mount for dev (source reload)
      - /app/node_modules           # anonymous volume — keeps container's node_modules

volumes:
  postgres_data:          # Docker manages this volume
    driver: local
```

---

## 💾 Backup and Restore

### Backup a named volume

```bash
# Backup postgres_data volume to a .tar.gz on the host
docker run --rm \
  -v postgres_data:/data:ro \           # mount the volume read-only
  -v $(pwd)/backups:/backup \           # mount a host backup directory
  alpine \
  tar czf /backup/postgres-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

ls backups/   # verify backup file exists
```

### Restore a backup into a volume

```bash
# Restore from a backup file into a new (or existing) volume
docker run --rm \
  -v postgres_data:/data \
  -v $(pwd)/backups:/backup:ro \
  alpine \
  sh -c "rm -rf /data/* && tar xzf /backup/postgres-20250101-120000.tar.gz -C /data"
```

### Copy a volume between hosts

```bash
# On source host: export to file
docker run --rm \
  -v postgres_data:/data:ro \
  alpine tar czf - -C /data . > postgres_data.tar.gz

# On destination host: import from file
docker volume create postgres_data
cat postgres_data.tar.gz | docker run --rm -i \
  -v postgres_data:/data \
  alpine tar xzf - -C /data
```

---

## 🔒 Volume Permissions

```dockerfile
# In Dockerfile — create and own the volume directory before switching user
RUN mkdir -p /app/data && chown -R 1001:1001 /app/data
VOLUME /app/data
USER 1001
```

```bash
# Fix permissions on an existing volume
docker run --rm \
  -v mydata:/data \
  alpine chown -R 1000:1000 /data
```

---

## 🧪 Labs

### Lab 1: Prove a volume survives container removal

```bash
# Write data to a named volume
docker run --rm -v lab-data:/data alpine sh -c "echo 'still here!' > /data/test.txt"

# The container is gone — the volume persists
# Read the data with a brand new container
docker run --rm -v lab-data:/data alpine cat /data/test.txt
# still here! ✅

# Cleanup
docker volume rm lab-data
```

### Lab 2: Live source reload with bind mount

```bash
mkdir -p /tmp/lab-bind/src
echo "console.log('v1')" > /tmp/lab-bind/src/app.js

docker run -d \
  --name lab-bind \
  -v /tmp/lab-bind/src:/app/src \
  node:20-alpine \
  sh -c "while true; do node /app/src/app.js; sleep 2; done"

docker logs lab-bind

# Edit on host — container sees the change immediately
echo "console.log('v2 - updated!')" > /tmp/lab-bind/src/app.js
sleep 3
docker logs lab-bind

# Cleanup
docker rm -f lab-bind
rm -rf /tmp/lab-bind
echo "✅ Bind mount lab complete"
```

### Lab 3: Backup and restore

```bash
# Start postgres with a named volume and insert data
docker run -d --name lab-pg \
  -v lab-pg-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=testdb \
  postgres:16-alpine

sleep 5  # wait for postgres to initialize

docker exec lab-pg psql -U postgres -d testdb \
  -c "CREATE TABLE items (id serial, name text); INSERT INTO items (name) VALUES ('backed-up data');"

# Backup the volume
mkdir -p /tmp/pg-backups
docker run --rm \
  -v lab-pg-data:/data:ro \
  -v /tmp/pg-backups:/backup \
  alpine tar czf /backup/pg-backup.tar.gz -C /data .

echo "Backup created: $(ls -lh /tmp/pg-backups/)"

# Remove original container and volume
docker rm -f lab-pg
docker volume rm lab-pg-data

# Restore to a new volume
docker volume create lab-pg-data
docker run --rm \
  -v lab-pg-data:/data \
  -v /tmp/pg-backups:/backup:ro \
  alpine tar xzf /backup/pg-backup.tar.gz -C /data

# Start postgres again with restored data
docker run -d --name lab-pg-restored \
  -v lab-pg-data:/var/lib/postgresql/data \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=testdb \
  postgres:16-alpine

sleep 5
docker exec lab-pg-restored psql -U postgres -d testdb -c "SELECT * FROM items;"
# backed-up data ✅ — data survived container deletion and volume recreation

# Cleanup
docker rm -f lab-pg-restored
docker volume rm lab-pg-data
rm -rf /tmp/pg-backups
echo "✅ Backup/restore lab complete"
```

---

## ✅ Volumes Checklist

- [ ] Production state stored in named volumes, not inside containers
- [ ] Never use anonymous volumes for persistent data
- [ ] Bind mounts used only for dev source code and config files
- [ ] Config bind mounts mounted `:ro` (read-only)
- [ ] `tmpfs` used for sensitive in-memory-only temp data
- [ ] Volume ownership set in Dockerfile with `chown` before `USER`
- [ ] Backup strategy implemented for all stateful volumes
- [ ] `docker volume prune` run regularly to clean unused volumes

---

**Next:** [Advanced Topics →](../../advanced/)