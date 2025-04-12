# Bitz Miner Node Setup on Eclipse

This repository contains a beginner-friendly Bash script that automates the setup of a Bitz Miner Node on Eclipse. The script installs all the necessary dependencies, Rust, Solana CLI, creates (or reuses) a Solana wallet, installs the Bitz Miner CLI via Cargo, and launches the miner in a detached screen session. It also provides useful commands and an uninstall option.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation Instructions](#installation-instructions)
- [Usage](#usage)
- [Features](#features)
- [Troubleshooting](#troubleshooting)
- [Additional Resources](#additional-resources)
- [License](#license)

## Overview

Bitz is the first ePOW commodity token that anyone can mine on Eclipse. This script allows you to quickly set up your mining node using a single command. The process includes:
- Installing system packages (screen, curl, nano)
- Installing Rust and setting up Cargo
- Installing and configuring the Solana CLI (switching the RPC to the Eclipse endpoint)
- Creating a new Solana wallet if one does not exist (with the wallet keyphrase saved to a file for backup)
- Installing the Bitz Miner CLI via Cargo
- Starting the Bitz Miner in a detached `screen` session
- Displaying useful Bitz commands to manage your node
- Providing an option to remove/uninstall the Bitz Miner

## Prerequisites

Before running the script, ensure that:
- You have a VPS or minimal CPU-based Linux Ubuntu system (or WSL if you're on Windows).
- Your Eclipse wallet (e.g., in your .eg Backpack) is funded with ETH.
- You have access to a terminal with `sudo` privileges.

## Installation Instructions

1. **Clone the Repository or Download the Script:**

   You can either clone this repository or copy the script file (`bitz_node_setup.sh`) to your system.

2. **Make the Script Executable:**

   ```bash
   chmod +x bitz_node_setup.sh
3. **Run the Script:**

bash
./bitz_node_setup.sh

Usage
When you run the script, you will be presented with a simple menu offering the following options:

Install/Setup Bitz Miner Node (One-Click Run):

Updates your system and installs system packages.

Installs Rust and the Solana CLI.

Checks for an existing wallet; if none exists, creates a new Solana wallet and saves your keyphrase to ~/wallet-keyphrase.txt.

Installs the Bitz Miner CLI via Cargo.

Starts the Bitz Miner in a detached screen session (you are prompted for how many CPU cores to use).

Display Useful Bitz Commands:

Shows helpful commands to check your account info (bitz account), claim Bitz (bitz claim), and display help (bitz -h).

Remove Bitz Miner Node:

Stops the running Bitz Miner screen session.

Uninstalls the Bitz Miner CLI (via Cargo).

Note: Wallet, Solana CLI, Rust, and other system packages remain installed.

Exit:

Exits the script.

Features
One-Click Setup: Automates the entire installation and setup process.

Wallet Management: Checks for an existing wallet or creates one automatically (with keyphrase extraction and backup).

Detached Screen Session: Runs your Bitz Miner in a background screen session so mining continues even if you disconnect.

Useful Commands: Provides an interactive menu to view handy Bitz CLI commands.

Uninstall Option: Offers a simple way to remove the Bitz Miner without affecting global system components.

Troubleshooting
Solana CLI Not Found:
If the script reports that solana is not found in your PATH, the script appends the Solana CLI directory to your ~/.bashrc and sources it. You can also manually check your PATH by running:

echo $PATH

Wallet Creation Issues:
If the wallet is not created or the keyphrase is not saved, re-run the wallet creation step. Check the output for any errors.

Screen Session Management:
To view all running screen sessions, run:

screen -ls


To reattach to your Bitz Miner session, run:
screen -r bitz


Happy mining!

Follow on X: @Daddy_savy
