#!/bin/bash
set -euo pipefail

# ============================================================
# Bitz Miner Node Setup Script for Eclipse (One-Click Run)
# ============================================================
# This script automates the setup of a Bitz Miner Node on Eclipse.
# It installs system packages, Rust, and the Solana CLI, then either
# uses an existing Solana wallet or creates one (saving its seed phrase
# to ~/wallet-keyphrase.txt). It also installs Bitz Miner CLI via Cargo
# and starts the miner in a detached screen session.
#
# Additional options include displaying useful Bitz commands and a
# removal option to stop the miner and uninstall Bitz Miner.
#
# Prequisites:
# - Your Eclipse wallet (.eg Backpack) should be funded with ETH.
# - For Windows users: run this via the Linux Ubuntu Terminal (WSL).
#
# Guide: https://eclipsescan.xyz/token/64mggk2nXg6vHC1qCdsZdEFzd5QGN4id54Vbho4PswCF
#
# Follow on X: @Daddy_savy
# ============================================================

# ------------------------------
# Utility Functions
# ------------------------------

# Print messages with color codes
info() { echo -e "\033[1;34m[INFO]\033[0m $1"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $1"; }

# Display the custom ASCII art banner
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

# Clear the screen and show the banner
show_title() {
    clear
    show_banner
    echo ""
}

# ------------------------------
# Prerequisites Installation
# ------------------------------

install_prerequisites() {
    info "Updating system packages and installing prerequisites (screen, curl, nano)..."
    sudo apt-get update && sudo apt-get upgrade -y
    sudo apt-get install -y screen curl nano
}

# ------------------------------
# Rust Installation
# ------------------------------

install_rust() {
    info "Installing Rust (if not already installed)..."
    if ! command -v rustc &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        set +u; source "$HOME/.cargo/env"; set -u
        info "Rust installed successfully. (Check with: rustc --version)"
    else
        info "Rust is already installed."
    fi
}

# ------------------------------
# Solana CLI Installation and Setup
# ------------------------------

install_solana() {
    info "Installing Solana CLI (if not already installed)..."
    if ! command -v solana &>/dev/null; then
        curl --proto '=https' --tlsv1.2 -sSfL https://solana-install.solana.workers.dev | bash
        info "Solana CLI installed. Please close and reopen your terminal, then return to the script."
        read -p "Press Enter once you have reopened your terminal..."
        if ! command -v solana &>/dev/null; then
            warn "Solana not found in PATH. Adding it to ~/.bashrc..."
            echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"' >> "$HOME/.bashrc"
            set +u; source "$HOME/.bashrc"; set -u
            export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"
        fi
    else
        info "Solana CLI is already installed."
    fi

    info "Switching RPC endpoint to Eclipse..."
    solana config set --url https://mainnetbeta-rpc.eclipse.xyz/ >/dev/null || {
        error "Failed to switch RPC endpoint. Please verify Solana CLI installation."
        exit 1
    }
}

# ------------------------------
# Wallet Setup (Create or Use Existing)
# ------------------------------

check_or_create_wallet() {
    local wallet_path="$HOME/.config/solana/id.json"
    if [ -f "$wallet_path" ]; then
        info "A Solana wallet already exists at $wallet_path. Skipping wallet creation."
    else
        info "No wallet found. Creating a new wallet..."
        key_output=$(solana-keygen new --no-bip39-passphrase --force -o "$wallet_path")
        info "New wallet created and saved to $wallet_path."
        # Extract the seed phrase (keyphrase) from the wallet creation output.
        mnemonic=$(echo "$key_output" | awk '/Your new keypair seed phrase is:/,/^$/' | sed '1d;$d')
        if [ -n "$mnemonic" ]; then
            echo "$mnemonic" > "$HOME/wallet-keyphrase.txt"
            info "Your wallet keyphrase has been saved to: ~/wallet-keyphrase.txt"
            info "IMPORTANT: Back up this file securely. You will need it to recover your wallet."
            info "To view it later, run: cat ~/wallet-keyphrase.txt"
        else
            warn "Could not extract the seed phrase automatically. Please note the wallet creation output."
        fi
    fi
}

# ------------------------------
# Install Bitz Miner CLI
# ------------------------------

install_bitz() {
    info "Installing Bitz Miner CLI using Cargo..."
    cargo install bitz || true
    set +u; source "$HOME/.cargo/env"; set -u
    info "Bitz Miner CLI installation complete."
}

# ------------------------------
# Start Bitz Miner Node in a Screen Session
# ------------------------------

start_bitz() {
    show_title
    local cores
    read -p "Enter the number of CPU cores to use for mining (default is 1): " cores
    cores=${cores:-1}
    info "Starting Bitz Miner using $cores core(s) in a detached screen session named 'bitz'..."
    screen -S bitz -dm bash -c "bitz collect --cores $cores; exec bash"
    info "Bitz Miner started successfully."
    info "To view the miner session, run: screen -r bitz"
    info "To detach from the session, press: Ctrl+A then D"
}

# ------------------------------
# Display Useful Bitz Commands
# ------------------------------

display_bitz_commands() {
    show_title
    info "Useful Bitz Commands (run these outside the miner screen session):"
    echo " - Check account info:  bitz account"
    echo " - Claim Bitz:          bitz claim"
    echo " - Display help/usage:  bitz -h"
    echo ""
    info "These commands help you manage and review your mining node."
    read -p "Press Enter to return to the main menu..."
}

# ------------------------------
# Remove Node / Uninstall Option
# ------------------------------

remove_node() {
    show_title
    warn "This will stop the Bitz Miner process and remove the Bitz Miner CLI from your system."
    read -p "Are you sure you want to continue? [y/N]: " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        info "Stopping Bitz Miner screen session (if running)..."
        if screen -list | grep -q "bitz"; then
            screen -XS bitz quit
            info "Bitz Miner session terminated."
        else
            warn "No active Bitz Miner session found."
        fi

        info "Uninstalling Bitz Miner CLI..."
        cargo uninstall bitz || warn "Bitz Miner CLI may not have been installed via Cargo."
        
        info "Removal completed."
        info "Note: The wallet, Solana CLI, Rust, and system packages are not removed."
    else
        info "Removal cancelled."
    fi
    read -p "Press Enter to return to the main menu..."
}

# ------------------------------
# Main Setup Function
# ------------------------------

setup_node() {
    show_title
    install_prerequisites
    install_rust
    install_solana
    check_or_create_wallet
    install_bitz
    start_bitz
    info "Node setup is complete! Your Bitz Miner Node is now running in the background."
    info "To check running sessions, run: screen -ls"
}

# ------------------------------
# Main Menu (Beginner-Friendly)
# ------------------------------

while true; do
    show_title
    echo "Select an option:"
    echo "1) Install/Setup Bitz Miner Node (One-Click Run)"
    echo "2) Display Useful Bitz Commands"
    echo "3) Remove Bitz Miner Node"
    echo "4) Exit"
    echo ""
    read -p "Enter your choice (1-4): " choice

    case $choice in
        1)
            setup_node
            read -p "Press Enter to return to the menu..."
            ;;
        2)
            display_bitz_commands
            ;;
        3)
            remove_node
            ;;
        4)
            info "Exiting. Thank you!"
            exit 0
            ;;
        *)
            error "Invalid option. Please try again."
            sleep 2
            ;;
    esac
done
