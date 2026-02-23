#!/usr/bin/env bash
# =============================================================================
# install-docker.sh — Install Docker Engine + Compose on Ubuntu/Debian
# =============================================================================
# Usage: bash install-docker.sh
# Tested on: Ubuntu 22.04, Ubuntu 24.04, Debian 12
# =============================================================================

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

# ── Check OS ──────────────────────────────────────────────────────────────────
if [[ ! -f /etc/os-release ]]; then
  error "Cannot detect OS. This script supports Ubuntu and Debian only."
fi

. /etc/os-release

if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
  error "Unsupported OS: $ID. This script supports Ubuntu and Debian only."
fi

info "Detected OS: $PRETTY_NAME"

# ── Check not running as root (should use sudo internally) ────────────────────
if [[ "$EUID" -eq 0 ]]; then
  warn "Running as root. It's better to run as a regular user with sudo access."
fi

# ── Remove old Docker versions ────────────────────────────────────────────────
info "Removing old Docker versions (if any)..."
sudo apt-get remove -y \
  docker docker-engine docker.io \
  containerd runc \
  docker-ce docker-ce-cli \
  2>/dev/null || true
success "Old versions removed"

# ── Install prerequisites ─────────────────────────────────────────────────────
info "Installing prerequisites..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  gnupg \
  lsb-release
success "Prerequisites installed"

# ── Add Docker GPG key ────────────────────────────────────────────────────────
info "Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL "https://download.docker.com/linux/${ID}/gpg" \
  | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
success "GPG key added"

# ── Add Docker repository ─────────────────────────────────────────────────────
info "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/${ID} \
  ${VERSION_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
success "Repository added"

# ── Install Docker Engine ─────────────────────────────────────────────────────
info "Installing Docker Engine and Compose plugin..."
sudo apt-get update -qq
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
success "Docker Engine installed: $(docker --version)"
success "Docker Compose installed: $(docker compose version)"

# ── Non-root access ───────────────────────────────────────────────────────────
info "Configuring non-root Docker access for user: ${USER}"
sudo groupadd docker 2>/dev/null || true
sudo usermod -aG docker "$USER"
success "User $USER added to docker group"

# ── Enable on boot ────────────────────────────────────────────────────────────
info "Enabling Docker service on boot..."
sudo systemctl enable --now docker
success "Docker service enabled and started"

# ── Configure log rotation ────────────────────────────────────────────────────
info "Configuring log rotation in /etc/docker/daemon.json..."
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
sudo systemctl restart docker
success "Log rotation configured"

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
success "Installation complete!"
echo ""
echo "  Docker:  $(docker --version)"
echo "  Compose: $(docker compose version)"
echo ""
warn "Log out and back in (or run: newgrp docker) for group change to take effect"
echo ""
echo "  Then verify with:"
echo "    docker run --rm hello-world"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"