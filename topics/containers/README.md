# 🐳 Containers

<p align="center">
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/Docker_Compose-2496ED?style=for-the-badge&logo=docker&logoColor=white"/>
  <img src="https://img.shields.io/badge/status-in%20progress-yellow?style=for-the-badge"/>
</p>

> A complete, hands-on guide to Docker — from first principles to production-grade security, multi-stage builds, networking, and orchestration. Every section contains runnable examples you can execute locally.

---

## 📋 Table of Contents

| Section | What you'll learn |
|---------|-------------------|
| [Basics](./basics/) | Docker architecture, installation, core CLI commands |
| [Advanced → Custom Networks](./advanced/custom-networks/) | Bridge, overlay, host drivers · DNS · network isolation |
| [Advanced → Multi-Service App](./advanced/multi-service-app/) | Compose deep dive · health checks · dev/prod config split |
| [Advanced → Multi-Stage Build](./advanced/multi-stage-build/) | Lean images · build targets · size comparison across languages |
| [Advanced → Security](./advanced/security/) | Non-root user · capabilities · Trivy scanning · hardened Dockerfile |

---

## 🗺️ Learning Path

If you're new to Docker, follow this order. If you're experienced, jump directly to what you need — every section is self-contained.

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   1. basics/          →   2. custom-networks/                   │
│   What is a container     How containers talk to each other     │
│   Docker CLI basics       Bridge, overlay, DNS resolution       │
│                                    ↓                            │
│   4. security/         ←  3. multi-service-app/                 │
│   Non-root, cap_drop       Compose full stack                   │
│   Trivy scanning           Health checks, dev/prod split        │
│          ↓                                                      │
│   5. multi-stage-build/                                         │
│   Lean production images                                        │
│   Node.js, Python, Go → scratch                                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ⚡ Quick Start

```bash
# 1. Verify your Docker installation
docker --version        # Docker Engine 24.x+
docker compose version  # Docker Compose v2.x+

# 2. Clone the repository
git clone https://github.com/JawherKl/devops-guide.git
cd devops-guide/topics/containers

# 3. Run your first container
docker run --rm hello-world

# 4. Explore the example full-stack app
cd advanced/multi-service-app
cp .env.example .env
docker compose up -d
docker compose ps
```

---

## 🛠️ Prerequisites

| Tool | Minimum Version | How to check |
|------|----------------|--------------|
| Docker Engine | 24.x | `docker --version` |
| Docker Compose | v2.x | `docker compose version` |
| Git | any | `git --version` |

---

## 📦 What You'll Build

By working through all sections, you will have:

- A solid understanding of Linux namespaces, cgroups, and how containers work under the hood
- A full multi-service application stack (API + PostgreSQL + Redis + Nginx) with Compose
- Multi-stage Dockerfiles in Node.js, Python, and Go that produce minimal, secure images
- A hardened, rootless container that passes a Trivy scan with zero critical CVEs
- A correctly isolated Docker network topology (frontend / backend separation)

---

## 📐 Folder Structure

```
containers/
├── README.md                        ← You are here
├── basics/                          ← Start here if new to Docker
│   └── README.md
├── advanced/
│   ├── custom-networks/             ← Network drivers, DNS, isolation
│   │   ├── README.md
│   │   └── docker-compose.yml
│   ├── multi-service-app/           ← Full Compose stack, dev/prod split
│   │   ├── README.md
│   │   ├── docker-compose.yml
│   │   ├── docker-compose.override.yml
│   │   └── .env.example
│   ├── multi-stage-build/           ← Lean images across multiple languages
│   │   ├── README.md
│   │   ├── node.dockerfile
│   │   ├── python.dockerfile
│   │   └── go.dockerfile
│   └── security/                    ← Hardening, CVE scanning, secrets
│       ├── README.md
│       ├── hardened.dockerfile
│       ├── trivy-scan.sh
│       └── .trivyignore
└── example/                         ← End-to-end runnable project
    └── README.md
```

---

## 🔗 Related Topics in This Guide

- [Orchestration (Kubernetes)](../orchestration/) — next step after mastering containers
- [CI/CD](../ci-cd/) — building and pushing images in automated pipelines
- [DevSecOps](../devsecops/) — advanced scanning, SBOM generation, policy enforcement
- [Monitoring](../monitoring/) — container metrics with Prometheus and cAdvisor

---

## 📖 Key Concepts at a Glance

| Concept | One-liner |
|---------|-----------|
| **Image** | Immutable, layered blueprint for a container |
| **Container** | Running instance of an image — an isolated process |
| **Dockerfile** | Recipe to build an image |
| **Compose** | Tool to define and run multi-container applications |
| **Volume** | Persistent storage that survives container removal |
| **Network** | Virtual network connecting containers |
| **Registry** | Storage and distribution server for images |
| **Layer** | Each `RUN`/`COPY`/`ADD` creates a cacheable layer |
| **Multi-stage** | Build with tools, ship only the runtime artifact |