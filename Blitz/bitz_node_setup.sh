#!/bin/bash
set -euo pipefail

# ============================================================
# Bitz Miner Node Setup Script for Eclipse (Beginner Friendly)
# ============================================================

info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

show_banner() {
cat << 'EOF'
__   _____  _   _ ____     ____    _    ____  ______   __
\ \ / / _ \| | | |  _ \   |  _ \  / \  |  _ \|  _ \ \ / /
 \ V / | | | | | | |_) |  | | | |/ _ \ | | | | | | \ V /
  | || |_| | |_| |  _ <   | |_| / ___ \| |_| | |_| || |
  |_| \___/ \___/|_| \_\  |____/_/   \_\____/|____/ |_|

       Bitz Miner Node Setup on Eclipse
     Follow on X: @Daddy_savy
EOF
}

show_title() {
    clear
    show_banner
    echo ""
}

install_prerequisites() {
    info "Updating system and installing prerequisites..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y screen curl nano jq
}

install_rust() {
    info "Installing Rust..."
    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
}

install_solana() {
    info "Installing Solana CLI..."
    if ! command -v solana &>/dev/null; then
        curl -sSfL https://solana-install.solana.workers.dev | bash
        echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        source "$HOME/.bashrc"
    fi
    solana config set --url https://mainnetbeta-rpc.eclipse.xyz/ > /dev/null
}

check_or_create_wallet() {
    local wallet_file="$HOME/.config/solana/id.json"
    if [ ! -f "$wallet_file" ]; then
        info "Creating new wallet..."
        solana-keygen new --no-bip39-passphrase --force -o "$wallet_file" > /dev/null
    fi

    local pubkey
    pubkey=$(solana address)

    local base58_privkey
    base58_privkey=$(solana-keygen pubkey "$wallet_file" --with-secret-key | grep "Secret:" | awk '{print $2}')

    echo ""
    echo "🔑 === WALLET DETAILS ==="
    echo "📫 Public Address: $pubkey"
    echo "🔐 Private Key (base58): $base58_privkey"
    echo "📁 Backup wallet file: $wallet_file"
    echo ""
    echo "$base58_privkey" > "$HOME/private-key.txt"
    info "🧾 Base58 Private Key saved to: ~/private-key.txt"

    local balance
    balance=$(solana balance || echo "0 SOL")
    info "💰 Wallet Balance: $balance"

    if [[ "$balance" == "0 SOL" || "$balance" == "0.000000000 SOL" ]]; then
        warn "⚠️  Please fund your wallet with at least 0.0005 ETH on Eclipse."
        read -p "Once funded, press Enter to continue..."
    fi
}

install_bitz() {
    info "Installing Bitz Miner CLI..."
    cargo install bitz || true
    source "$HOME/.cargo/env"
}

start_bitz() {
    show_title
    read -p "Enter number of CPU cores to use for mining (default 1): " cores
    cores=${cores:-1}
    info "Starting Bitz Miner with $cores core(s)..."
    screen -S bitz -dm bash -c "bitz collect --cores $cores; exec bash"
    info "✅ Miner started in screen session: bitz"
    echo ""
    info "📺 View Miner: screen -r bitz"
    info "🛑 Exit screen: Ctrl+A then D"
}

display_bitz_commands() {
    show_title
    info "🛠️  Useful Bitz Commands:"
    echo "🔎 Check account info: bitz account"
    echo "🎁 Claim rewards:      bitz claim"
    echo "📘 Help / usage:       bitz -h"
    read -p "Press Enter to return to menu..."
}

remove_node() {
    show_title
    warn "⚠️  This will stop and uninstall Bitz Miner (wallet remains)."
    read -p "Are you sure? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        screen -S bitz -X quit || true
        cargo uninstall bitz || warn "Bitz may not have been installed."
        info "✅ Bitz Miner removed."
    else
        info "Uninstall cancelled."
    fi
    read -p "Press Enter to return to menu..."
}

setup_node() {
    show_title
    install_prerequisites
    install_rust
    install_solana
    check_or_create_wallet
    install_bitz
    start_bitz
    info "🎉 Setup complete! Your Bitz Miner Node is now live."
}

while true; do
    show_title
    echo "Choose an option:"
    echo "1) 🚀 Install/Setup Bitz Miner Node"
    echo "2) 📘 Show Bitz CLI Commands"
    echo "3) ❌ Remove Bitz Miner"
    echo "4) 🔚 Exit"
    echo ""
    read -p "Enter your choice (1-4): " choice
    case $choice in
        1) setup_node ;;
        2) display_bitz_commands ;;
        3) remove_node ;;
        4) info "Goodbye!" && exit 0 ;;
        *) error "Invalid input. Try again." && sleep 2 ;;
    esac
done
