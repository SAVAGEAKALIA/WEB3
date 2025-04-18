#!/usr/bin/env bash
set -euo pipefail

# =============================================================
#  One-Click VPS Chromium Setup & Removal Script
# =============================================================
# Features:
# 1. Full root installation support with warnings
# 2. Interactive timezone configuration
# 3. Comprehensive proxy validation
# 4. Complete dependency checks
# 5. Verbose user guidance
# Follow on X: @Daddy_savy
# =============================================================

# ------------------------------
# Constants & Configuration
# ------------------------------
CHROMIUM_IMAGE="lscr.io/linuxserver/chromium:version-114.0.5735.198"
WORKDIR="${HOME}/chromium"
CONFIG_DIR="${WORKDIR}/config"

# ------------------------------
# Banner & Logging
# ------------------------------
info()  { echo -e "\033[1;34m[INFO]\033[0m  $*"; }
step()  { echo -e "\033[1;35m[STEP]\033[0m  $*"; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*" >&2; exit 1; }

show_banner() {
    cat << 'EOF'
__   _____  _   _ ____     ____    _    ____  ______   __
\ \ / / _ \| | | |  _ \   |  _ \  / \  |  _ \|  _ \ \ / /
 \ V / | | | | | | |_) |  | | | |/ _ \ | | | | | | \ V /
  | || |_| | |_| |  _ <   | |_| / ___ \| |_| | |_| || |
  |_| \___/ \___/|_| \_\  |____/_/   \_\____/|____/ |_|  

       Headless Chromium Setup on Your VPS
          Follow on X: @Daddy_savy
EOF
    echo
}

# ------------------------------
# Initial Checks
# ------------------------------
check_root() {
  if [[ $EUID -eq 0 ]]; then
    warn "Running as root user - this is not generally recommended!"
    read -rp "Continue as root? (y/N): " root_confirm
    [[ "${root_confirm:-N}" =~ ^[Yy] ]] || error "Installation aborted by user"
    warn "Docker will run containers as root user. Proceed with caution!"
  elif ! sudo -n true 2>/dev/null; then
    error "User doesn't have sudo privileges. Configure sudo first."
  fi
}

# ------------------------------
# Timezone Handling
# ------------------------------
get_default_timezone() {
  if command -v timedatectl &>/dev/null; then
    timedatectl show --property=Timezone --value
  else
    cat /etc/timezone 2>/dev/null || echo "UTC"
  fi
}

validate_timezone() {
  local tz="$1"
  if [[ -f "/usr/share/zoneinfo/${tz}" ]]; then
    return 0
  fi
  find /usr/share/zoneinfo -type f -print0 | xargs -0 -I {} sh -c \
    'basename "{}"' | grep -qx "$tz" || return 1
}

configure_timezone() {
  DEFAULT_TZ=$(get_default_timezone)
  step "Current system timezone detected: ${DEFAULT_TZ}"
  
  read -rp "Use default timezone? [Y/n]: " use_default
  case "${use_default:-Y}" in
    [Yy]*)
      TZ="$DEFAULT_TZ"
      info "Using default timezone: ${TZ}"
      ;;
    *)
      while :; do
        read -rp "Enter timezone (e.g., America/New_York, Europe/London): " TZ
        if validate_timezone "$TZ"; then
          info "Valid timezone: ${TZ}"
          break
        fi
        warn "Invalid timezone. Check available zones with: timedatectl list-timezones"
      done
      ;;
  esac
}

# ------------------------------
# Port Validation
# ------------------------------
validate_port() {
  local port="$1"
  [[ "$port" =~ ^[0-9]+$ ]] && (( port >= 1 && port <= 65535 )) || return 1
}

check_port() {
  local port="$1"
  while ! validate_port "$port"; do
    warn "Invalid port number: $port"
    read -rp "Enter a valid port (1-65535): " port
  done
  while ss -tuln | awk '{print $4}' | grep -q ":${port}$"; do
    warn "Port $port is already in use."
    read -rp "Enter a different port: " port
    validate_port "$port" || port=0
  done
  echo "$port"
}

# ------------------------------
# Dependency Management
# ------------------------------
install_dependencies() {
  step "Starting system dependency check..."
  info "Required packages: curl, gnupg, lsb-release, apt-transport-https"
  
  local deps=(curl gnupg lsb-release apt-transport-https)
  local missing=()
  
  for pkg in "${deps[@]}"; do
    dpkg -s "$pkg" &>/dev/null || missing+=("$pkg")
  done

  if (( ${#missing[@]} > 0 )); then
    warn "Missing packages detected: ${missing[*]}"
    step "Installing system dependencies..."
    sudo apt-get update -y
    sudo apt-get install -y "${missing[@]}" || error "Dependency installation failed"
    info "Dependencies installed successfully"
  else
    info "All required packages already installed"
  fi
}

# ------------------------------
# Docker Management
# ------------------------------
install_docker() {
  step "Checking Docker installation..."
  if command -v docker &>/dev/null; then
    info "Docker already installed: $(docker --version)"
    return
  fi

  warn "Docker not found - starting installation..."
  info "Adding Docker's official GPG key and repository..."
  
  sudo apt-get update -y
  sudo apt-get install -y ca-certificates curl gnupg

  local arch=$(dpkg --print-architecture)
  local distro=$(lsb_release -cs)
  local keyring="/etc/apt/keyrings/docker.gpg"
  
  sudo mkdir -p /etc/apt/keyrings
  if [[ ! -f "$keyring" ]]; then
    step "Downloading and installing Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
      sudo gpg --dearmor -o "$keyring"
    sudo chmod a+r "$keyring"
  fi

  step "Adding Docker repository to sources..."
  echo "deb [arch=$arch signed-by=$keyring] \
    https://download.docker.com/linux/ubuntu $distro stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

  step "Installing Docker packages..."
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin || error "Docker installation failed"

  info "Docker successfully installed: $(docker --version)"
}

# ------------------------------
# User ID Handling
# ------------------------------
get_user_ids() {
  if [[ $EUID -eq 0 ]]; then
    echo "1000"
  else
    echo "1000"
  fi
}

get_group_ids() {
  if [[ $EUID -eq 0 ]]; then
    echo "1000"
  else
    echo "1000"
  fi
}

# ------------------------------
# Proxy Validation
# ------------------------------
validate_proxy() {
  local proxy="$1"
  [[ "$proxy" =~ ^[^:]+:[0-9]{1,5}$ ]] || return 1
}

# ------------------------------
# Configuration Handling
# ------------------------------
sanitize_input() {
  echo "$1" | tr -d '[:space:]' | sed "s/'//g"
}

gather_config() {
  echo
  info "Chromium Configuration"
  local pass_check=1
  while (( pass_check )); do
    read -rp "Require login credentials? (y/N): " REQ_CREDS
    case "${REQ_CREDS:-N}" in
      [Yy]*)
        read -rp "Username: " CHR_USER
        CHR_USER=$(sanitize_input "$CHR_USER")
        while [[ -z "$CHR_USER" ]]; do
          warn "Username cannot be empty"
          read -rp "Username: " CHR_USER
          CHR_USER=$(sanitize_input "$CHR_USER")
        done
        
        read -rsp "Password: " CHR_PASS
        echo
        read -rsp "Confirm password: " CHR_PASS_CONFIRM
        echo
        [[ "$CHR_PASS" == "$CHR_PASS_CONFIRM" ]] && pass_check=0 || warn "Passwords don't match"
        ;;
      *) 
        CHR_USER=""
        CHR_PASS=""
        pass_check=0
        ;;
    esac
  done

  # Port configuration
  step "Configuring network ports..."
  read -rp "Enter HTTP port [3010]: " HTTP_PORT
  HTTP_PORT=${HTTP_PORT:-3010}
  HTTP_PORT=$(check_port "$HTTP_PORT")
  read -rp "Enter HTTPS/WebSocket port [3011]: " HTTPS_PORT
  HTTPS_PORT=${HTTPS_PORT:-3011}
  HTTPS_PORT=$(check_port "$HTTPS_PORT")

  # Timezone configuration
  step "Configuring timezone..."
  configure_timezone

  # Proxy configuration
  PROXY_CLI=""
  read -rp "Do you want to use a proxy? (y/N): " USE_PROXY
  if [[ "${USE_PROXY:-N}" =~ ^[Yy] ]]; then
    step "Configuring proxy settings..."
    while :; do
      read -rp "Proxy type (http/socks5) [http]: " PROXY_TYPE
      PROXY_TYPE=${PROXY_TYPE:-http}
      [[ "$PROXY_TYPE" =~ ^(http|socks5)$ ]] && break
      warn "Invalid proxy type. Choose http or socks5"
    done

    while :; do
      read -rp "Proxy host:port (example: proxy.com:3128): " PROXY_ADDR
      validate_proxy "$PROXY_ADDR" && break
      warn "Invalid format. Use host:port"
    done

    read -rp "Proxy username (optional): " PROXY_USER
    if [[ -n "$PROXY_USER" ]]; then
      read -rsp "Proxy password: " PROXY_PASS
      echo
      AUTH="${PROXY_USER}:${PROXY_PASS}@"
    else
      AUTH=""
    fi
    
    PROXY_CLI="--proxy-server=${PROXY_TYPE}://${AUTH}${PROXY_ADDR}"
    info "Proxy configured: ${PROXY_TYPE}://${PROXY_ADDR}"
  fi
}

# ------------------------------
# Docker Compose Management
# ------------------------------
create_compose_file() {
  info "Creating Docker compose configuration..."
  mkdir -p "$CONFIG_DIR"
  chmod 700 "$WORKDIR"

  cat > "${WORKDIR}/docker-compose.yaml" <<EOF
version: "3.8"
services:
  chromium:
    image: ${CHROMIUM_IMAGE}
    container_name: chromium
    security_opt:
      - seccomp:unconfined
    environment:
      - CUSTOM_USER=${CHR_USER}
      - PASSWORD=${CHR_PASS}
      - PUID=$(get_user_ids)
      - PGID=$(get_group_ids)
      - TZ=${TZ}
      - CHROME_CLI=${PROXY_CLI}
    volumes:
      - ${CONFIG_DIR}:/config
    ports:
      - "${HTTP_PORT}:3000"
      - "${HTTPS_PORT}:3001"
    shm_size: "1gb"
    restart: unless-stopped
EOF

  chmod 600 "${WORKDIR}/docker-compose.yaml"
}

# ------------------------------
# Deployment Functions
# ------------------------------
deploy_chromium() {
  step "Starting Chromium deployment..."
  create_compose_file

  cd "$WORKDIR"
  step "Stopping any existing containers..."
  docker compose down -v --remove-orphans >/dev/null 2>&1 || true

  step "Starting new container..."
  docker compose up -d || error "Failed to start container"

  # Verify container status
  sleep 5
  if ! docker compose ps --filter status=running | grep -q chromium; then
    error "Container failed to start. Check logs with: docker compose logs"
  fi

  show_access_info
}

show_access_info() {
  local PUBLIC_IP
  PUBLIC_IP=$(curl -fsS4 https://ifconfig.co || \
    curl -fsS6 https://ifconfig.co || \
    echo "your-server-ip")

  cat <<EOF

\033[1;32m[SUCCESS]\033[0m Chromium is running!

Access URLs:
  • HTTP  → http://${PUBLIC_IP}:${HTTP_PORT}/
  • HTTPS → https://${PUBLIC_IP}:${HTTPS_PORT}/ (SSL may take ~1 minute to initialize)

EOF

  [[ -n "$CHR_USER" ]] && echo "Credentials: ${CHR_USER} / $(sed 's/./*/g' <<< "${CHR_PASS}")"
  [[ -n "$PROXY_CLI" ]] && echo "Proxy Configuration: ${PROXY_TYPE}://${PROXY_ADDR}"
  echo -e "\nConfig directory: ${CONFIG_DIR}"
  echo -e "Management commands:"
  echo -e "  Stop:    cd ${WORKDIR} && docker compose stop"
  echo -e "  Start:   cd ${WORKDIR} && docker compose start"
  echo -e "  Restart: cd ${WORKDIR} && docker compose restart"
}

# ------------------------------
# Cleanup Functions
# ------------------------------
remove_chromium() {
  warn "This will PERMANENTLY remove Chromium and all its data!"
  read -rp "Confirm removal? (y/N): " CONF
  [[ "${CONF:-N}" =~ ^[Yy] ]] || { info "Removal cancelled"; return; }

  if [[ -d "$WORKDIR" ]]; then
    cd "$WORKDIR"
    step "Stopping containers..."
    docker compose down -v --remove-orphans >/dev/null 2>&1 || true
    
    step "Removing configuration files..."
    sudo rm -rf "$WORKDIR"
    
    info "Chromium successfully removed"
  else
    warn "Chromium directory not found. Manual cleanup may be required."
  fi
}

# ------------------------------
# Main Execution
# ------------------------------
main() {
  check_root
  show_banner
  install_dependencies
  install_docker

  cat <<EOF

\033[1mMain Menu:\033[0m
  1) Install Chromium
  2) Remove Chromium
  3) Exit

EOF

  read -rp "Select option [1-3]: " CHOICE
  case "${CHOICE:-3}" in
    1) 
      gather_config
      deploy_chromium
      ;;
    2) remove_chromium ;;
    3) info "Exiting..."; exit 0 ;;
    *) error "Invalid selection" ;;
  esac
}

main
