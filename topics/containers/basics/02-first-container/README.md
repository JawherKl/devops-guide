# 02 — Your First Container

> Learn the complete Docker CLI — run, inspect, exec, logs, copy, stop, remove. These are the commands you'll use every single day.

---

## 🧠 Container Lifecycle

```
docker pull        docker run          docker stop        docker rm
     │                  │                   │                  │
     ▼                  ▼                   ▼                  ▼
 [image on disk] → [running container] → [stopped container] → [removed]
                        │
                   docker exec     ← attach and run commands
                   docker logs     ← read stdout/stderr
                   docker cp       ← copy files in/out
                   docker inspect  ← full metadata JSON
```

---

## 🚀 Running Containers

```bash
# Pull an image without running it
docker pull nginx:1.25-alpine

# Run a container in the foreground (CTRL+C to stop)
docker run nginx:1.25-alpine

# Run detached (background), give it a name, map a port
docker run -d --name my-nginx -p 8080:80 nginx:1.25-alpine

# Verify it's running
curl http://localhost:8080

# Run interactively — get a shell inside
docker run -it --rm ubuntu:22.04 bash
# ↑ --rm removes the container automatically when you exit

# Run a one-off command and exit
docker run --rm alpine echo "Hello from inside a container"

# Run with environment variables
docker run -d \
  --name my-postgres \
  -e POSTGRES_PASSWORD=secret \
  -e POSTGRES_DB=mydb \
  -p 5432:5432 \
  postgres:16-alpine
```

### `docker run` flags you need to know

| Flag | What it does |
|------|-------------|
| `-d` | Detached — run in background |
| `-it` | Interactive + TTY — for shell sessions |
| `--rm` | Remove container automatically on exit |
| `--name` | Give the container a memorable name |
| `-p host:container` | Publish a port |
| `-e KEY=VALUE` | Set an environment variable |
| `-v name:/path` | Mount a named volume |
| `-v /host:/container` | Bind mount a host path |
| `--network name` | Connect to a specific network |
| `--restart unless-stopped` | Auto-restart policy |
| `--memory 512m` | Memory limit |
| `--cpus 1.0` | CPU limit |

---

## 🔍 Inspecting Running Containers

```bash
# List running containers
docker ps

# List ALL containers (running + stopped)
docker ps -a

# Compact format — just names and status
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Full JSON metadata (everything Docker knows about a container)
docker inspect my-nginx

# Extract specific fields with Go templates
docker inspect -f '{{.NetworkSettings.IPAddress}}' my-nginx
docker inspect -f '{{.State.Status}}' my-nginx
docker inspect -f '{{.HostConfig.Memory}}' my-nginx

# Live resource usage — CPU, memory, network, block I/O
docker stats

# Watch a specific container
docker stats my-nginx

# Running processes inside the container
docker top my-nginx

# Filesystem changes since container start
docker diff my-nginx
# A = Added, C = Changed, D = Deleted
```

---

## 📋 Logs

```bash
# All logs since container started
docker logs my-nginx

# Follow live (like tail -f)
docker logs -f my-nginx

# Last 50 lines with timestamps
docker logs --tail 50 -t my-nginx

# Logs since a specific time
docker logs --since 2024-01-01T00:00:00 my-nginx

# Logs between two times
docker logs --since 1h --until 30m my-nginx
```

---

## 💻 Exec — Run Commands Inside a Running Container

```bash
# Open an interactive shell (bash or sh for alpine)
docker exec -it my-nginx bash       # bash (debian/ubuntu)
docker exec -it my-nginx sh         # sh (alpine — no bash by default)

# Run a single command and exit
docker exec my-nginx nginx -t              # test nginx config
docker exec my-nginx cat /etc/nginx/nginx.conf

# Run as a specific user
docker exec -u root my-nginx whoami        # run as root even if container uses non-root

# Set environment variables for the exec session
docker exec -e DEBUG=true my-nginx env | grep DEBUG
```

---

## 📂 Copying Files

```bash
# Copy FROM container TO host
docker cp my-nginx:/etc/nginx/nginx.conf ./nginx.conf

# Copy FROM host TO container
docker cp ./nginx.conf my-nginx:/etc/nginx/nginx.conf

# Copy a whole directory
docker cp my-nginx:/var/log/nginx ./nginx-logs/

# Reload nginx config after copying (without restart)
docker exec my-nginx nginx -s reload
```

---

## 🛑 Stopping and Removing

```bash
# Graceful stop (SIGTERM, waits 10s, then SIGKILL)
docker stop my-nginx

# Immediate kill (SIGKILL — no cleanup)
docker kill my-nginx

# Stop then remove
docker stop my-nginx && docker rm my-nginx

# Force remove a running container
docker rm -f my-nginx

# Remove all stopped containers
docker container prune

# Stop and remove everything running (useful for clean slate)
docker rm -f $(docker ps -aq) 2>/dev/null || true
```

---

## 🧹 System Cleanup

```bash
# Show disk usage broken down by type
docker system df

# Remove unused images, stopped containers, and unused networks
docker system prune

# Also remove unused volumes (WARNING: destroys persistent data)
docker system prune --volumes

# Remove everything including all images not used by a container
docker system prune -a

# Remove only dangling (untagged) images
docker image prune

# Remove only stopped containers
docker container prune

# Remove unused volumes
docker volume prune

# Remove unused networks
docker network prune
```

---

## 🧪 Lab: Container lifecycle in 10 commands

```bash
# 1. Run nginx in background
docker run -d --name lab-nginx -p 8081:80 nginx:alpine

# 2. Verify it responds
curl -s http://localhost:8081 | grep -o "<title>.*</title>"

# 3. Check logs
docker logs lab-nginx

# 4. See resource usage
docker stats lab-nginx --no-stream

# 5. Run a command inside
docker exec lab-nginx nginx -v

# 6. Copy its config out
docker cp lab-nginx:/etc/nginx/nginx.conf /tmp/lab-nginx.conf
cat /tmp/lab-nginx.conf | head -5

# 7. Inspect its IP
docker inspect -f '{{.NetworkSettings.IPAddress}}' lab-nginx

# 8. See what changed in its filesystem
docker diff lab-nginx

# 9. Stop gracefully
docker stop lab-nginx

# 10. Confirm it stopped, then remove
docker ps -a | grep lab-nginx
docker rm lab-nginx

echo "✅ Lab complete — container lifecycle demonstrated"
```

---

## 📄 Cheatsheet

```bash
# ── Run ──────────────────────────────────────────────────────────────────────
docker run -d --name NAME -p HOST:CTR IMAGE      # detached with port
docker run -it --rm IMAGE bash                    # interactive, auto-remove
docker run --rm IMAGE CMD                         # one-off command

# ── Inspect ──────────────────────────────────────────────────────────────────
docker ps                                         # running containers
docker ps -a                                      # all containers
docker stats --no-stream                          # resource snapshot
docker inspect NAME                               # full JSON metadata
docker logs -f NAME                               # follow logs
docker top NAME                                   # processes inside

# ── Interact ─────────────────────────────────────────────────────────────────
docker exec -it NAME sh                           # open shell
docker exec NAME CMD                              # run one command
docker cp NAME:/path ./local                      # copy out
docker cp ./local NAME:/path                      # copy in

# ── Stop / Remove ─────────────────────────────────────────────────────────────
docker stop NAME                                  # graceful stop
docker rm NAME                                    # remove stopped
docker rm -f NAME                                 # force remove running
docker system prune                               # clean up unused resources
```

---

**Next:** [03 — Writing Dockerfiles →](../03-dockerfile/)