# Docker Basics

> Everything you need to go from zero to confidently running, building, and managing Docker containers. Work through each sub-section in order — each one builds on the previous.

---

## 📋 Sub-sections

| # | Folder | What you'll learn |
|---|--------|-------------------|
| 01 | [Installation](./01-installation/) | Install Docker Engine on Linux, macOS, Windows |
| 02 | [First Container](./02-first-container/) | Core CLI commands, container lifecycle, cheatsheet |
| 03 | [Dockerfile](./03-dockerfile/) | Writing Dockerfiles for Node.js, Python, and Nginx |
| 04 | [Images](./04-images/) | Build, tag, inspect, push, prune — full image workflow |
| 05 | [Volumes](./05-volumes/) | Named volumes, bind mounts, tmpfs — persistent data |

---

## 🧭 Learning Path

```
01-installation
      ↓
02-first-container  ←  start running things immediately
      ↓
03-dockerfile       ←  build your own images
      ↓
04-images           ←  manage, tag, distribute images
      ↓
05-volumes          ←  persist data correctly
      ↓
../advanced/        ←  networking, multi-service, security
```

---

## ⚡ Prerequisites

| Requirement | Notes |
|-------------|-------|
| Linux, macOS, or Windows | All supported |
| Terminal / shell access | bash, zsh, or PowerShell |
| Internet access | to pull base images |

---

## 🔑 Core Concepts (quick reference)

| Term | Definition |
|------|-----------|
| **Image** | Immutable, layered blueprint — like a class in OOP |
| **Container** | Running instance of an image — like an object instance |
| **Dockerfile** | Recipe to build an image from instructions |
| **Registry** | Server storing and distributing images (Docker Hub, GHCR) |
| **Volume** | Persistent storage that survives container removal |
| **Network** | Virtual network connecting containers |
| **Layer** | Each `RUN`/`COPY`/`ADD` adds a cached, reusable layer |

---

**Start here →** [01 — Installation](./01-installation/)