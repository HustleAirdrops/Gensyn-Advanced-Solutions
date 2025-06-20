#!/bin/bash

# Styling with tput
BOLD=$(tput bold)
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
CYAN=$(tput setaf 6)
NC=$(tput sgr0)

# Paths
SWARM_DIR="$HOME/rl-swarm"
CONFIG_FILE="$SWARM_DIR/.swarm_config"
TEMP_DATA_PATH="$SWARM_DIR/modal-login/temp-data"
HOME_DIR="$HOME"
LOG_FILE="$HOME/swarm_log.txt"
NODE_PID_FILE="$HOME/.node_pid"
SWAP_FILE="/swapfile"

# Global Variables
STOP_REQUESTED=0
NODE_PID=0

# Logging Function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    case "$level" in
        ERROR) echo -e "${RED}$message${NC}" ;;
        WARN) echo -e "${YELLOW}$message${NC}" ;;
    esac
}

# Initialize log file
mkdir -p "$(dirname "$LOG_FILE")" "$(dirname "$NODE_PID_FILE")"
touch "$LOG_FILE" "$NODE_PID_FILE"
log_message "INFO" "Starting GENSYN RL-SWARM LAUNCHER at $(date)"

# Change to home directory
cd "$HOME" || { log_message "ERROR" "Could not access $HOME. Exiting."; exit 1; }

# Default Config
create_default_config() {
    log_message "INFO" "Creating default config at $CONFIG_FILE"
    mkdir -p "$SWARM_DIR"
    cat <<EOF > "$CONFIG_FILE"
TESTNET=Y
SWARM=A
PARAM=7
PUSH=N
EOF
    chmod 600 "$CONFIG_FILE"
    [ $? -eq 0 ] && log_message "INFO" "Default config created" || log_message "ERROR" "Failed to create default config"
}

[ ! -f "$CONFIG_FILE" ] && create_default_config

# Install and Validate Environment
validate_environment() {
    log_message "INFO" "Validating and installing environment dependencies"
    local missing_deps=()
    if ! command -v git >/dev/null 2>&1; then missing_deps+=("git"); fi
    if ! command -v python3 >/dev/null 2>&1; then missing_deps+=("python3"); fi
    if ! python3 -m venv --help >/dev/null 2>&1; then missing_deps+=("python3-venv"); fi
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message "INFO" "Installing missing dependencies: ${missing_deps[*]}"
        sudo apt update >/dev/null 2>&1
        sudo apt install -y "${missing_deps[@]}" >/dev/null 2>&1
        [ $? -eq 0 ] && log_message "INFO" "Installed dependencies" || { log_message "ERROR" "Failed to install dependencies"; exit 1; }
    fi
    log_message "INFO" "Environment validated"
}

# Swapfile Management
manage_swapfile() {
    if [ ! -f "$SWAP_FILE" ]; then
        sudo fallocate -l 2G "$SWAP_FILE" >/dev/null 2>&1
        sudo chmod 600 "$SWAP_FILE" >/dev/null 2>&1
        sudo mkswap "$SWAP_FILE" >/dev/null 2>&1
        sudo swapon "$SWAP_FILE" >/dev/null 2>&1
        echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null 2>&1
        [ $? -ne 0 ] && log_message "WARN" "Failed to enable swapfile"
    fi
}

# Modify run_rl_swarm.sh if not already modified
modify_run_script() {
    if [ -f "$SWARM_DIR/run_rl_swarm.sh" ]; then
        if ! grep -q 'if \[ "\$KEEP_TEMP_DATA" != "true" \]; then' "$SWARM_DIR/run_rl_swarm.sh"; then
            perl -i -pe 's|rm -r \$ROOT_DIR/modal-login/temp-data/\*.json 2> /dev/null \|\| true|if [ "\$KEEP_TEMP_DATA" != \"true\" ]; then\n    rm -r \$ROOT_DIR/modal-login/temp-data/\*.json 2> /dev/null || true\nfi|' "$SWARM_DIR/run_rl_swarm.sh"
            log_message "INFO" "Modified run_rl_swarm.sh to conditionally delete temp data"
        else
            log_message "INFO" "run_rl_swarm.sh already modified"
        fi
    fi
}

# Copy swarm file
copy_swarm_pem() {
    [ -f "$HOME_DIR/swarm.pem" ] || exit 1
    sudo cp "$HOME_DIR/swarm.pem" "$SWARM_DIR/swarm.pem"
    sudo chmod 600 "$SWARM_DIR/swarm.pem"
    sudo chown "$(whoami):$(whoami)" "$SWARM_DIR/swarm.pem"
}

# Clone Repository
clone_repository() {
    log_message "INFO" "Cloning rl-swarm to $SWARM_DIR"
    rm -rf "$SWARM_DIR" 2>/dev/null
    git clone https://github.com/gensyn-ai/rl-swarm.git "$SWARM_DIR" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_message "INFO" "Repository cloned"
        chmod -R 700 "$SWARM_DIR"
        modify_run_script
    else
        log_message "ERROR" "Failed to clone repository"
        exit 1
    fi
    create_default_config
}

# Copy swarm to home 
copy_swarm_pem_to_home() {
    [ -f "$SWARM_DIR/swarm.pem" ] || exit 1
    sudo cp "$SWARM_DIR/swarm.pem" "$HOME_DIR/swarm.pem"
    sudo chmod 600 "$HOME_DIR/swarm.pem"
    sudo chown "$(whoami):$(whoami)" "$HOME_DIR/swarm.pem"
}

# Python Environment Setup
setup_python_env() {
    log_message "INFO" "Setting up Python environment"
    cd "$SWARM_DIR" || { log_message "ERROR" "Could not access $SWARM_DIR"; exit 1; }
    if [ ! -d ".venv" ]; then
        python3 -m venv .venv 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "INFO" "Created virtual environment"
        else
            log_message "ERROR" "Failed to create venv"
            exit 1
        fi
    fi
    source .venv/bin/activate
    if [ -f "requirements.txt" ]; then
        pip install -r requirements.txt >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_message "INFO" "Installed dependencies"
        fi
    fi
}

# Remove Swapfile
remove_swapfile() {
    log_message "INFO" "Removing swapfile at $SWAP_FILE"
    if [ -f "$SWAP_FILE" ]; then
        sudo swapoff "$SWAP_FILE" 2>/dev/null && log_message "INFO" "Swapfile disabled" || log_message "WARN" "Failed to disable swapfile"
        sudo rm -f "$SWAP_FILE" 2>/dev/null && log_message "INFO" "Swapfile removed" || log_message "ERROR" "Failed to remove swapfile"
        sudo sed -i "\|$SWAP_FILE|d" /etc/fstab && log_message "INFO" "Removed swapfile entry from /etc/fstab" || log_message "WARN" "Failed to remove swapfile entry from /etc/fstab"
    else
        log_message "INFO" "No swapfile found"
    fi
}

# Venv Check
ensure_venv_installed() {
    [ ! -d ".venv" ] && sudo apt update >/dev/null 2>&1 && sudo apt install python3.12-venv -y >/dev/null 2>&1
}

# Launch Function
launch_rl_swarm() {
    log_message "INFO" "Launching rl-swarm"
    [ ! -f "$SWARM_DIR/run_rl_swarm.sh" ] && { log_message "ERROR" "run_rl_swarm.sh not found"; exit 1; }
    chmod +x "$SWARM_DIR/run_rl_swarm.sh"
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_message "INFO" "Using config: Testnet=$TESTNET, Swarm=$SWARM, Param=$PARAM, Push=$PUSH"
        cd "$SWARM_DIR" && source .venv/bin/activate
        ./run_rl_swarm.sh <<EOF
$TESTNET
$SWARM
$PARAM
$PUSH
EOF
        local exit_code=$?
        return $exit_code
    else
        cd "$SWARM_DIR" && source .venv/bin/activate
        ./run_rl_swarm.sh
        local exit_code=$?
        return $exit_code
    fi
}

# Auto-Fix Function
auto_fix() {
    log_message "INFO" "Running auto-fix"
    [ ! -d "$SWARM_DIR" ] && clone_repository
    [ ! -f "$SWARM_DIR/run_rl_swarm.sh" ] && clone_repository
    modify_run_script
    if [ ! -d "$SWARM_DIR/.venv" ] || [ ! -f "$SWARM_DIR/.venv/bin/activate" ]; then
        rm -rf "$SWARM_DIR/.venv"
        setup_python_env
    fi
    manage_swapfile
    log_message "INFO" "Auto-fix completed"
}

# Run Fixall Function
run_fixall() {
    log_message "INFO" "Running fixall.sh"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/hustleairdrops/Gensyn-Advanced-Solutions/main/fixall.sh)" >/dev/null 2>&1
    [ $? -eq 0 ] && touch "$SWARM_DIR/.fixall_done" && log_message "INFO" "fixall.sh executed successfully" || log_message "ERROR" "Failed to execute fixall.sh"
}

# Menu Options
option_1() {
    log_message "INFO" "Option 1: Auto-restart with existing files"
    export KEEP_TEMP_DATA=true
    copy_swarm_pem
    modify_run_script
    pkill -f swarm.pem 2>/dev/null
    auto_fix
    run_fixall
    ensure_venv_installed
    setup_python_env
    while [ $STOP_REQUESTED -eq 0 ]; do
        pkill -f swarm.pem 2>/dev/null
        launch_rl_swarm
        log_message "WARN" "rl-swarm exited. Restarting in 1s..."
        auto_fix
        setup_python_env
        sleep 1
    done
}

option_2() {
    log_message "INFO" "Option 2: Run once with existing files"
    export KEEP_TEMP_DATA=true
    copy_swarm_pem
    modify_run_script
    auto_fix
    ensure_venv_installed
    setup_python_env
    run_fixall
    pkill -f swarm.pem 2>/dev/null
    launch_rl_swarm
}

option_3() {
    log_message "INFO" "Option 3: Delete and start fresh"
    echo -e "${YELLOW}⚠️ Do you want to delete swarm.pem? (y/n): ${NC}"
    read -p "" delete_pem
    if [[ "$delete_pem" =~ ^[Yy]$ ]]; then
        log_message "INFO" "User chose to delete swarm.pem"
        rm -rf "$SWARM_DIR"
        rm -f ~/swarm.pem ~/userData.json ~/userApiKey.json
    else
        log_message "INFO" "User chose to keep swarm.pem, copying to home"
        copy_swarm_pem_to_home
        rm -rf "$SWARM_DIR"
        rm -f ~/userData.json ~/userApiKey.json
    fi
    clone_repository
    modify_run_script
    ensure_venv_installed
    setup_python_env
    run_fixall
    if [ -f "$HOME_DIR/swarm.pem" ]; then
        copy_swarm_pem
        log_message "INFO" "Fresh installation completed with swarm.pem"
        echo -e "${GREEN}✅ Successfully installed rl-swarm with swarm.pem copied to $SWARM_DIR!${NC}"
    else
        log_message "INFO" "Fresh installation completed without swarm.pem"
        echo -e "${GREEN}✅ Successfully installed rl-swarm! Please place swarm.pem in $HOME_DIR to proceed with launching.${NC}"
    fi
}

option_4() {
    log_message "INFO" "Option 4: Update configuration"
    echo -e "${CYAN}⚙️ Updating Configuration...${NC}"
    source "$CONFIG_FILE"
    echo -e "${GREEN}✅ Testnet: Y (Fixed)${NC}"
    echo -e "${GREEN}✅ Push to HF: N (Fixed)${NC}"
    read -p "${YELLOW}➡️ Swarm type (A=Math, B=Math Hard) [$SWARM]: ${NC}" swarm
    swarm=${swarm:-$SWARM}
    read -p "${YELLOW}➡️ Parameter count (0.5, 1.5, 7, 32, 72) [$PARAM]: ${NC}" param
    param=${param:-$PARAM}
    cat <<EOF > "$CONFIG_FILE"
TESTNET=Y
SWARM=$swarm
PARAM=$param
PUSH=N
EOF
    chmod 600 "$CONFIG_FILE"
    [ $? -eq 0 ] && log_message "INFO" "Config saved" && echo -e "${GREEN}✅ Config Updated!${NC}" || log_message "ERROR" "Failed to save config"
    exit 0
}

option_5() {
    log_message "INFO" "Option 5: Fix all errors"
    echo -e "${CYAN}🛠️ Fixing Errors...${NC}"
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/hustleairdrops/Gensyn-Advanced-Solutions/main/fixall.sh)" >/dev/null 2>&1
    [ $? -eq 0 ] && echo -e "${GREEN}✅ Errors Fixed!${NC}" || echo -e "${RED}❌ Fix Failed. Check Logs.${NC}"
}

option_6() {
    log_message "INFO" "Option 6: Reset all files to fix peer ID issues"
    echo -e "${CYAN}🛠️ Deleting all key files to resolve peer ID issues...${NC}"
    sudo rm -rf ~/swarm.pem ~/userData.json ~/userApiKey.json ~/rl-swarm/swarm.pem ~/rl-swarm/modal-login/temp-data/userData.json ~/rl-swarm/modal-login/temp-data/userApiKey.json 2>/dev/null
    if [ $? -eq 0 ]; then
        log_message "INFO" "Deleted swarm.pem, userData.json, and userApiKey.json"
        echo -e "${GREEN}✅ All files deleted successfully.${NC}"
    else
        log_message "ERROR" "Failed to delete some files"
        echo -e "${RED}❌ Failed to delete some files. Check logs.${NC}"
    fi
    echo -e "${YELLOW}⚠️ Please import swarm.pem into $HOME_DIR${NC}"
    echo -e "${YELLOW}➡️ Then restart the node.${NC}"
    exit 0
}

# Display Logo
display_logo() {
    echo -e "${CYAN}${BOLD}"
    echo "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│  ██╗░░██╗██╗░░░██║░██████╗████████╗██╗░░░░░███████╗  ░█████╗░██╗██████╗░██████░██╗██████╗░░█████╗░██████╗░░██████╗  │"
    echo "│  ██║░░██║██║░░░██║██╔════╝╚══██╔══╝██║░░░░░██╔════╝  ██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝  │"
    echo "│  ███████║██║░░░██║╚█████╗░░░░██║░░░██║░░░░░█████╗░░  ███████║██║██╔══██╗██║░░██║██████╔╝██║░░██║██████╔╝╚█████╗░  │"
    echo "│  ██╔══██║██║░░░██║░╚═══██╗░░░██║░░░██║░░░░░██╔══╝░░  ██╔══██║██║██╔══██╗██║░░██║██╔══██╗██║░░██║██╔═══╝░░╚═══██╗  │"
    echo "│  ██║░░██║╚██████╔╝██████╔╝░░░██║░░░███████╗███████╗  ██║░░██║██║██║░░██║██████╔╝██║░░██║╚█████╔╝██║░░░░░██████╔╝  │"
    echo "│  ╚═╝░░╚═╝░╚═════╝░╚═════╝░░░░╚═╝░░░╚══════╝╚══════╝  ╚═╝░░╚═╝╚═╝╚═╝░░╚═╝╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░░░░╚═════╝░  │"
    echo "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${YELLOW}           🚀 Gensyn RL-Swarm Launcher by Hustle Airdrops 🚀${NC}"
    echo -e "${YELLOW}              GitHub: https://github.com/HustleAirdrops${NC}"
    echo -e "${NC}"
}

# Stop Handler (Ctrl+X)
stop_script() {
    log_message "INFO" "Stopping script (Ctrl+X)"
    STOP_REQUESTED=1
    [ $NODE_PID -ne 0 ] && kill $NODE_PID 2>/dev/null && log_message "INFO" "Terminated node (PID: $NODE_PID)"
    echo -e "${GREEN}✅ Stopped Gracefully${NC}"
    remove_swapfile
    exit 0
}

stty intr ^X
trap stop_script INT

# Main Menu
while true; do
    clear
    display_logo
    echo -e "${BOLD}${CYAN}🎉 GENSYN RL-SWARM LAUNCHER MENU 🎉${NC}\n"
    log_message "INFO" "Displaying menu"
    validate_environment
    manage_swapfile

    if [ -d "$SWARM_DIR" ] || [ -f "$HOME_DIR/swarm.pem" ] || [ -f "$HOME_DIR/userData.json" ] || [ -f "$HOME_DIR/userApiKey.json" ]; then
        echo -e "${YELLOW}${BOLD}⚠️ Existing Setup Detected!${NC}"
        echo -e "${GREEN}-------------------------------------------------${NC}"
        echo "  ||   ${BOLD}${CYAN}1️⃣️ Auto-Restart Mode${NC} - Run with existing files, restarts on crash"
        echo "  ||   ${BOLD}${CYAN}2️⃣ Single Run${NC} - Run once with existing files"
        echo "  ||   ${BOLD}${CYAN}3️⃣ Fresh Start${NC} - Delete everything and start anew"
        echo "  ||   ${BOLD}${CYAN}4️⃣ Update Config${NC} - Change Swarm type and Parameter count"
        echo "  ||   ${BOLD}${CYAN}5️⃣ Fix Errors${NC} - Resolve BF16/Login/DHTNode issues"
        echo "  ||   ${BOLD}${CYAN}6️⃣ Fix Peer ID Issues${NC} - Delete all key files and start fresh with new keys"
        echo -e "${GREEN}-------------------------------------------------${NC}"
        echo -e "${CYAN}ℹ️ Press Ctrl+X to stop anytime${NC}"
    else
        log_message "INFO" "No setup found. Starting fresh"
        echo -e "${GREEN}✅ No Setup Found. Starting Fresh...${NC}"
        clone_repository
        modify_run_script
        setup_python_env
        run_fixall
        launch_rl_swarm
        exit 0
    fi

    read -p "${BOLD}${YELLOW}➡️ Select Option (1-6): ${NC}" choice
    case "$choice" in
        1) option_1; break ;;
        2) option_2; break ;;
        3) option_3; break ;;
        4) option_4; break ;;
        5) option_5; break ;;
        6) option_6; break ;;
        *) log_message "ERROR" "Invalid choice: $choice"; echo -e "${RED}❌ Invalid Option!${NC}" ;;
    esac
done
