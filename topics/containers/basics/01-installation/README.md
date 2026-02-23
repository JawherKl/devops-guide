# 01 — Installation

> Install Docker Engine and Docker Compose on Linux, macOS, or Windows. Verify everything works before proceeding.

---

## 🐧 Linux (Ubuntu / Debian — recommended for DevOps)

```bash
# 1. Remove old versions (safe to run even on fresh system)
sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

# 2. Install prerequisites
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# 3. Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 5. Install Docker Engine + Compose plugin
sudo apt-get update
sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# 6. Manage Docker as non-root user (avoids sudo on every command)
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker $USER

# ⚠️  Log out and back in (or run: newgrp docker) for group change to take effect

# 7. Enable Docker to start on boot
sudo systemctl enable docker
sudo systemctl start docker
```

### Quick install (convenience script — not for production servers)

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
```

---

## 🍎 macOS

**Option A — Docker Desktop (easiest, GUI included)**

1. Download from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/)
2. Open the `.dmg` and drag Docker to Applications
3. Launch Docker Desktop from Applications
4. Wait for the whale icon in the menu bar to stop animating

**Option B — Colima (lightweight, no GUI, recommended for power users)**

```bash
# Install via Homebrew
brew install colima docker docker-compose

# Start the Linux VM (adjust --cpu and --memory as needed)
colima start --cpu 4 --memory 8 --disk 60

# Verify
docker --version
docker compose version
```

---

## 🪟 Windows

**Windows 10/11 with WSL2 (recommended)**

```powershell
# 1. Enable WSL2 (run in PowerShell as Administrator)
wsl --install

# 2. Download and install Docker Desktop for Windows
# https://www.docker.com/products/docker-desktop/

# 3. In Docker Desktop settings:
#    General → Use the WSL 2 based engine ✅
#    Resources → WSL Integration → Enable for your distro ✅
```

---

## ✅ Verification

Run these after installation. All should succeed before moving to the next section.

```bash
# Docker Engine version
docker --version
# Expected: Docker version 25.x.x, build xxxxxxx

# Compose version (must be v2 — note: no hyphen, it's a plugin now)
docker compose version
# Expected: Docker Compose version v2.x.x

# Daemon is running
docker info | head -5

# Run hello-world — pulls image, runs container, prints confirmation, removes itself
docker run --rm hello-world
# Expected: "Hello from Docker!"

# Non-root access (should work WITHOUT sudo after group change)
docker ps
# Expected: empty table, no permission error
```

---

## 🐧 Linux post-install script

```bash
# install-docker.sh — save and run: bash install-docker.sh
#!/usr/bin/env bash
set -euo pipefail

echo "Installing Docker Engine..."
curl -fsSL https://get.docker.com | sh

echo "Adding $USER to docker group..."
sudo usermod -aG docker "$USER"

echo "Enabling Docker service..."
sudo systemctl enable --now docker

echo ""
echo "✅ Docker installed. Log out and back in, then run: docker run --rm hello-world"
docker --version
```

---

## 🔧 Useful Configuration

```bash
# /etc/docker/daemon.json — system-wide Docker daemon config
# Create or edit this file, then: sudo systemctl restart docker
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",    # rotate logs — prevents disk fill on long-running containers
    "max-file": "3"
  },
  "default-ulimits": {
    "nofile": {
      "Name": "nofile",
      "Hard": 64000,
      "Soft": 64000
    }
  }
}
```

---

**Next:** [02 — Your First Container →](../02-first-container/)