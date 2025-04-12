#!/bin/bash
set -euo pipefail

# ============================================================
# Bitz Miner Node Setup Script for Eclipse (One-Click Run)
# ============================================================
# This script automates the setup of a Bitz Miner Node on Eclipse.
# It installs system packages, Rust, Solana CLI, and Python3 (if not
# already installed). It then either uses an existing Solana wallet 
# or creates one (displaying its private key in hex format and saving 
# it to ~/wallet-private-key.txt) so that you can import it into your 
# Backpack wallet. The script also installs Bitz Miner CLI via Cargo and 
# starts the miner in a detached screen session.
#
# Additional options include displaying useful Bitz commands and a
# removal option to stop the miner and uninstall Bitz Miner.
#
# Prerequisites:
# - Your Eclipse wallet (e.g., Backpack) must be funded with at least
#   0.0005 ETH on the Eclipse network.
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
# Ensure Python3 is installed
# ------------------------------

install_python() {
    if ! command -v python3 &>/dev/null; then
        info "Python3 is not installed. Installing Python3..."
        sudo apt-get install -y python3
        if command -v python3 &>/dev/null; then
            info "Python3 installed successfully."
        else
            error "Failed to install Python3. Please install it manually and re-run the script."
            exit 1
        fi
    else
        info "Python3 is already installed."
    fi
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
        info "A Solana wallet already exists at $wallet_path. Reusing the existing wallet."
    else
        info "No wallet found. Creating a new wallet..."
        solana-keygen new --no-bip39-passphrase --force -o "$wallet_path"
        info "New wallet created and saved to $wallet_path."
    fi

    # Convert the JSON array private key into a hexadecimal string using Python3.
    local private_hex
    private_hex=$(python3 -c "import sys, json; arr=json.load(sys.stdin); print(''.join(['{:02x}'.format(x) for x in arr]))" < "$wallet_path")
    echo "$private_hex" > "$HOME/wallet-private-key.txt"
    info "Your wallet PRIVATE KEY (in hex format) has been saved to: ~/wallet-private-key.txt"
    echo -e "\033[1;32mYour wallet PRIVATE KEY (hex format):\033[0m"
    echo "$private_hex"

    # Display the wallet public address.
    local public_key
    public_key=$(solana address -k "$wallet_path")
    info "Your wallet public address is: $public_key"

    # Display wallet balance.
    local balance_raw
    balance_raw=$(solana balance -k "$wallet_path")
    info "Current wallet balance: $balance_raw"

    # Check if bc is available to compare balance numerically.
    if command -v bc &>/dev/null; then
        # Extract the numeric value assuming the balance is the first token.
        local balance_number
        balance_number=$(echo "$balance_raw" | awk '{print $1}')
        if [ -z "$balance_number" ]; then
            warn "Could not determine numeric balance from: $balance_raw"
        else
            # Compare balance with the minimum required threshold (0.0005).
            if (( $(echo "$balance_number < 0.0005" | bc -l) )); then
                warn "Your wallet balance is below the recommended minimum of 0.0005 ETH (or equivalent)."
                warn "Please fund your wallet (using at least 0.0005 ETH on the Eclipse network) before proceeding."
                read -p "Press Enter after funding your wallet to continue: "
            else
                info "Your wallet balance meets the minimum requirement."
            fi
        fi
    else
        warn "bc is not installed, so we cannot automatically verify your wallet balance."
        warn "Please ensure your wallet is funded with at least 0.0005 ETH on the Eclipse network."
        read -p "Press Enter to continue: "
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
    install_python
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
