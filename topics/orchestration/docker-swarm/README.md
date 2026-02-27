# 🐝 Docker Swarm

<p align="center">
  <img src="https://img.shields.io/badge/Docker_Swarm-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
</p>

> Docker Swarm is Docker's built-in orchestration — no Kubernetes, no extra tools. If you have Docker, you have Swarm. It's ideal for smaller teams, simpler deployments, and anyone who finds Kubernetes overkill for their use case.

---

## 💡 Swarm vs Kubernetes

| | Docker Swarm | Kubernetes |
|--|-------------|------------|
| Setup | `docker swarm init` | Full cluster setup |
| Learning curve | Low | High |
| Config format | Docker Compose YAML | Kubernetes YAML |
| Auto-scaling | Manual only | HPA (automatic) |
| Self-healing | Yes | Yes |
| Service discovery | Built-in DNS | CoreDNS |
| Load balancing | Built-in (ingress routing mesh) | Service + Ingress |
| Best for | Small teams, simple apps | Large scale, complex apps |

---

## 📋 Sections

| Section | What you'll learn |
|---------|-------------------|
| [basics/](./basics/) | `swarm init`, services, stacks, the routing mesh |
| [advanced/secrets/](./advanced/secrets/) | Swarm secrets — encrypted at rest and in transit |
| [advanced/configs/](./advanced/configs/) | Swarm configs for non-secret configuration files |
| [advanced/rolling-update/](./advanced/rolling-update/) | Zero-downtime rolling updates with update_config |
| [example/](./example/) | Full stack: Nginx + Node API + PostgreSQL + Traefik |

---

## 🏗️ Swarm Architecture

```
Manager Nodes (1 or 3+)          Worker Nodes
──────────────────────────        ──────────────
  raft consensus log              service tasks run here
  schedules tasks
  manages service state
        │
        └──── communicates via encrypted overlay network ────┘
```

---

## ⚡ Essential Commands

```bash
# ── Cluster ─────────────────────────────────────────────────────────────────
docker swarm init                                  # create a new swarm
docker swarm init --advertise-addr <manager-ip>    # multi-host setup
docker swarm join --token <token> <manager>:2377   # join as worker
docker swarm join-token manager                    # get manager join token
docker node ls                                     # list all nodes
docker node inspect <node>                         # node details

# ── Services ─────────────────────────────────────────────────────────────────
docker service create --name web -p 80:80 --replicas 3 nginx:alpine
docker service ls                                  # list services
docker service ps web                             # list tasks (pods)
docker service scale web=5                        # scale a service
docker service update --image nginx:1.26 web      # rolling update
docker service rm web                             # remove service

# ── Stacks (Compose-format deployment) ───────────────────────────────────────
docker stack deploy -c docker-stack.yml myapp     # deploy a stack
docker stack ls                                   # list stacks
docker stack ps myapp                             # list tasks in stack
docker stack services myapp                       # list services in stack
docker stack rm myapp                             # remove stack

# ── Secrets ──────────────────────────────────────────────────────────────────
echo "mysecret" | docker secret create db_password -
docker secret ls
docker secret inspect db_password

# ── Overlay network ──────────────────────────────────────────────────────────
docker network create --driver overlay --attachable app-net
docker network ls
```

---

**Start here →** [basics/](./basics/)