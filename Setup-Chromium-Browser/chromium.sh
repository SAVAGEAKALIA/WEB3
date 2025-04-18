#!/usr/bin/env bash
set -euo pipefail

# =============================================================
#  One-Click VPS Chromium Setup & Removal Script
# =============================================================
# Automates Docker installation, headless Chromium deployment using
docker-compose, optional proxy configuration, and full removal.
# Includes port checks, dependency installation, and interactive prompts.
# 
# Follow on X: @Daddy_savy
# =============================================================

# ------------------------------
# Banner & Logging
# ------------------------------
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

show_banner() {
  cat << 'EOF'
   _____ _                      _           _
  / ____| |                    | |         | |
 | |    | |___  _ __ ___   ___ | | ___  ___| |_
 | |    | / __|| '_ ` _ \ / _ \| |/ _ \/ __| __|
 | |____| \__ \| | | | | | (_) | |  __/\__ \ |_
  \_____|_|___/|_| |_| |_|\___/|_|\___||___/\__|

        Headless Chromium Setup on Your VPS
          Follow on X: @Daddy_savy
EOF
}

# ------------------------------
# Port Availability Check
# ------------------------------
check_port() {
  local port=$1
  while ss -tuln | awk '{print $4}' | grep -q ":${port}$"; do
    warn "Port $port is already in use."
    read -rp "Please enter a different port: " port
  done
  echo "$port"
}

# ------------------------------
# Dependency Installation
# ------------------------------
install_dependencies() {
  info "Checking and installing dependencies..."
  local deps=(curl gnupg lsb-release apt-transport-https)
  local miss=()
  for pkg in "${deps[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
      miss+=("$pkg")
    fi
  done
  if [[ ${#miss[@]} -gt 0 ]]; then
    info "Installing missing packages: ${miss[*]}"
    sudo apt-get update -y
    sudo apt-get install -y "${miss[@]}"
  else
    info "All dependencies are satisfied."
  fi
}

# ------------------------------
# Docker Installation
# ------------------------------
install_docker() {
  if command -v docker &>/dev/null; then
    info "Docker is already installed: $(docker --version)"
  else
    info "Installing Docker..."
    sudo apt-get update -y
    sudo apt-get install -y ca-certificates curl gnupg lsb-release
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) \
      signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
    sudo apt-get update -y
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    info "Docker installed: $(docker --version)"
  fi
}

# ------------------------------
# Compose File Generation & Launch
# ------------------------------
deploy_chromium() {
  # Prompt for credentials requirement
  read -rp "Require login creds? (y/N): " REQ_CREDS
  if [[ $REQ_CREDS =~ ^[Yy] ]]; then
    read -rp "Chromium username: " CHR_USER
    read -rsp "Chromium password: " CHR_PASS
    echo
  else
    CHR_USER=""
    CHR_PASS=""
  fi

  # Ports
  local http_port=$(check_port ${HTTP_PORT:-3010})
  local https_port=$(check_port ${HTTPS_PORT:-3011})

  # Proxy
  PROXY_CLI=""
  if [[ $USE_PROXY =~ ^[Yy] ]]; then
    PROXY_CLI="--proxy-server=${PROXY_TYPE}://${AUTH}${PROXY_ADDR}"
  fi

  # Build compose
  mkdir -p "$WORKDIR"
  cat > "$WORKDIR/docker-compose.yaml" <<EOF
version: "3.8"
services:
  chromium:
    image: lscr.io/linuxserver/chromium:latest
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=$CHR_USER
      - PASSWORD=$CHR_PASS
      - PUID=1000
      - PGID=1000
      - TZ=$TZ
      - CHROME_CLI=$PROXY_CLI
    volumes:
      - $WORKDIR/config:/config
    ports:
      - "$http_port:3000"
      - "$https_port:3001"
    shm_size: "1gb"
    restart: unless-stopped
EOF

  info "Launching Chromium container..."
  cd "$WORKDIR"
  docker compose down -v 2>/dev/null || true
  docker compose up -d
  echo
  info "Chromium running at:"  
  echo "  http://$PUBLIC_IP:$http_port/"
  echo "  http://$PUBLIC_IP:$https_port/"
  [[ $REQ_CREDS =~ ^[Yy] ]] && echo -e "Login → user: $CHR_USER | pass: (your password)"
}

# ------------------------------
# Removal Function
# ------------------------------
remove_chromium() {
  warn "This will stop and remove the Chromium container and config."
  read -rp "Proceed? (y/N): " CONF
  if [[ $CONF =~ ^[Yy] ]]; then
    info "Stopping container..."
    docker stop chromium 2>/dev/null || true
    docker rm chromium 2>/dev/null || true
    info "Removing config dir..."
    rm -rf "$WORKDIR"
    info "Chromium has been removed."
  else
    info "Removal cancelled."
  fi
}

# ------------------------------
# Main Menu
# ------------------------------
show_banner
install_dependencies
install_docker

# Detect public IP
echo
info "Detecting public IP..."
PUBLIC_IP=$(curl -fsS https://api.ipify.org || echo "YOUR_VPS_IP")
info "Public IP: $PUBLIC_IP"

echo
cat << EOF
Select an option:
  1) Install/Setup Chromium
  2) Remove Chromium
  3) Exit
EOF
read -rp "Choice [1-3]: " CHOICE
case "$CHOICE" in
  1) deploy_chromium ;;  
  2) remove_chromium ;;  
  3) info "Goodbye!" ; exit 0 ;;  
  *) error "Invalid option." ;;  
esac
