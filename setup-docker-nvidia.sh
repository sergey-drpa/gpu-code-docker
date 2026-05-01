-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update -qq
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

  info "Docker installed: $(docker --version)"
  info "Docker Compose installed: $(docker compose version)"
}

if command -v docker &>/dev/null && docker compose version &>/dev/null 2>&1; then
  info "Docker and docker-compose-plugin already installed, skipping."
else
  install_docker
fi

# ─── 2. NVIDIA Driver ────────────────────────────────────────────────────────

if ! command -v nvidia-smi &>/dev/null; then
  warn "#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── 1. Docker ───────────────────────────────────────────────────────────────

install_docker() {
  info "Adding Docker's official GPG key and repository..."

  sudo apt-get update -qq
  sudo apt-get install -y -qq ca-certificates curl gnupg

  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --printnvidia-smi not found. Installing NVIDIA drivers..."
  sudo apt-get install -y ubuntu-drivers-common
  sudo ubuntu-drivers autoinstall
  warn "NVIDIA driver installed. A reboot is required before continuing."
  warn "After reboot, re-run this script to complete the setup."
  exit 0
else
  info "NVIDIA driver already present: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -1)"
fi

# ─── 3. NVIDIA Container Toolkit ─────────────────────────────────────────────

install_nvidia_toolkit() {
  info "Installing NVIDIA Container Toolkit..."

  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

  sudo apt-get update -qq
  sudo apt-get install -y nvidia-container-toolkit

  info "Configuring Docker runtime for NVIDIA..."
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker

  info "NVIDIA Container Toolkit installed."
}

if dpkg -l nvidia-container-toolkit &>/dev/null 2>&1; then
  info "NVIDIA Container Toolkit already installed, skipping."
else
  install_nvidia_toolkit
fi

# ─── 4. Clean up conflicting containers ──────────────────────────────────────

info "Removing any stopped/conflicting containers..."
docker container prune -f

# ─── 5. Verify GPU access inside Docker ──────────────────────────────────────

info "Verifying GPU access inside Docker..."
if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi; then
  info "GPU is accessible inside Docker. All good!"
else
  error "GPU test failed. Check your NVIDIA driver and toolkit installation."
fi

# ─── 6. Start the stack ──────────────────────────────────────────────────────

info "Starting docker compose stack..."
docker compose up -d

info "Done! Use 'docker compose logs -f' to follow logs."