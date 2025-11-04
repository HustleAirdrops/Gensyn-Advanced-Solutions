#!/bin/bash
# set -e

if [ -t 1 ] && [ -n "$(tput colors)" ] && [ "$(tput colors)" -ge 8 ]; then
    BOLD=$(tput bold)
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    NC=$(tput sgr0)
else
    BOLD=""
    RED=""
    GREEN?!
    YELLOW=""
    CYAN=""
    BLUE=""
    MAGENTA=""
    NC=""
fi

# Paths
SWARM_DIR="$HOME/rl-swarm"
CONFIG_FILE="$SWARM_DIR/.swarm_config"
LOG_FILE="$HOME/swarm_log.txt"
SWAP_FILE="/swapfile"
REPO_URL="https://github.com/gensyn-ai/rl-swarm.git"

# Global Variables
KEEP_TEMP_DATA=true

# Logging
log() {
    local level="$1"
    local msg="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LOG_FILE"
    case "$level" in
        ERROR) echo -e "${RED}$msg${NC}" ;;
        WARN) echo -e "${YELLOW}$msg${NC}" ;;
        INFO) echo -e "${CYAN}$msg${NC}" ;;
    esac
}

# Initialize
init() {
    clear
    touch "$LOG_FILE"
    log "INFO" "=== HUSTLE AIRDROPS RL-SWARM MANAGER STARTED ==="
}

# Display Header
show_header() {
    clear
    echo -e "${BLUE}${BOLD}"
    echo "┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐"
    echo "│  ██╗░░██╗██╗░░░██║░██████╗████████╗██╗░░░░░███████╗  ░█████╗░██╗██████╗░██████╗░██████╗░░█████╗░██████╗░░██████╗  │"
    echo "│  ██║░░██║██║░░░██║██╔════╝╚══██╔══╝██║░░░░░██╔════╝  ██╔══██╗██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝  │"
    echo "│  ███████║██║░░░██║╚█████╗░░░░██║░░░██║░░░░░█████╗░░  ███████║██║██████╔╝██║░░██║██████╔╝██║░░██║██████╔╝╚█████╗░  │"
    echo "│  ██╔══██║██║░░░██║░╚═══██╗░░░██║░░░██║░░░░░██╔══╝░░  ██╔══██║██║██╔══██╗██║░░██║██╔══██╗██║░░██║██╔═══╝░░╚═══██╗  │"
    echo "│  ██║░░██║╚██████╔╝██████╔╝░░░██║░░░███████╗███████╗  ██║░░██║██║██║░░██║██████╔╝██║░░██║╚█████╔╝██║░░░░░██████╔╝  │"
    echo "│  ╚═╝░░╚═╝░╚═════╝░╚═════╝░░░░╚═╝░░░╚══════╝╚══════╝  ╚═╝░░╚═╝╚═╝╚═╝░░╚═╝╚═════╝░╚═╝░░╚═╝░╚════╝░╚═╝░░░░░╚═════╝░  │"
    echo "└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘"
    echo -e "${YELLOW}           🚀 Gensyn RL-Swarm Launcher by Hustle Airdrops 🚀${NC}"
    echo -e "${YELLOW}              GitHub: https://github.com/HustleAirdrops${NC}"
    echo -e "${YELLOW}              Telegram: https://t.me/Hustle_Airdrops${NC}"
    echo -e "${GREEN}===============================================================================${NC}"
}

# Dependencies
install_deps() {
    echo "🔄 Updating package list..."
    sudo apt update -y

    echo "📦 Installing essential packages..."
    sudo apt install -y python3 python3-venv python3-pip curl wget screen git lsof ufw jq perl gnupg

    echo "🟢 Installing Node.js 20..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
    sudo apt install -y nodejs

    echo "🧵 Installing Yarn..."
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/yarn.gpg
    echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
    sudo apt update -y
    sudo apt install -y yarn

    echo "🛡️ Setting up firewall..."
    sudo ufw allow 22
    sudo ufw allow 3000/tcp
    sudo ufw enable

    echo "🌩️ Installing Cloudflared..."
    wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb || sudo apt install -f
    rm -f cloudflared-linux-amd64.deb

    echo "✅ All dependencies installed successfully!"
}

# Swap Management
manage_swap() {
    if [ ! -f "$SWAP_FILE" ]; then
        sudo fallocate -l 16G "$SWAP_FILE" >/dev/null 2>&1
        sudo chmod 600 "$SWAP_FILE" >/dev/null 2>&1
        sudo mkswap "$SWAP_FILE" >/dev/null 2>&1
        sudo swapon "$SWAP_FILE" >/dev/null 2>&1
        echo "$SWAP_FILE none swap sw 0 0" | sudo tee -a /etc/fstab >/dev/null 2>&1
    fi
}


install_unzip() {
    if ! command -v unzip &> /dev/null; then
        log "INFO" "⚠️ 'unzip' not found, installing..."
        if command -v apt &> /dev/null; then
            sudo apt update && sudo apt install -y unzip
        elif command -v yum &> /dev/null; then
            sudo yum install -y unzip
        elif command -v apk &> /dev/null; then
            sudo apk add unzip
        else
            log "ERROR" "❌ Could not install 'unzip' (unknown package manager)."
            exit 1
        fi
    fi
}
# Unzip files from HOME (no validation)
unzip_files() {
    ZIP_FILE=$(find "$HOME" -maxdepth 1 -type f -name "*.zip" | head -n 1)
   
    if [ -n "$ZIP_FILE" ]; then
        log "INFO" "📂 Found ZIP file: $ZIP_FILE, unzipping to $HOME ..."
        install_unzip
        unzip -o "$ZIP_FILE" -d "$HOME" >/dev/null 2>&1
     
        [ -f "$HOME/swarm.pem" ] && {
            sudo mv "$HOME/swarm.pem" "$SWARM_DIR/swarm.pem"
            sudo chmod 600 "$SWARM_DIR/swarm.pem"
            JUST_EXTRACTED_PEM=true
            log "INFO" "✅ Moved swarm.pem to $SWARM_DIR"
        }
        [ -f "$HOME/userData.json" ] && {
            sudo mv "$HOME/userData.json" "$TEMP_DATA_DIR/"
            log "INFO" "✅ Moved userData.json to $TEMP_DATA_DIR"
        }
        [ -f "$HOME/userApiKey.json" ] && {
            sudo mv "$HOME/userApiKey.json" "$TEMP_DATA_DIR/"
            log "INFO" "✅ Moved userApiKey.json to $TEMP_DATA_DIR"
        }
        ls -l "$HOME"
        if [ -f "$SWARM_DIR/swarm.pem" ] || [ -f "$TEMP_DATA_DIR/userData.json" ] || [ -f "$TEMP_DATA_DIR/userApiKey.json" ]; then
            log "INFO" "✅ Successfully extracted files from $ZIP_FILE"
        else
            log "WARN" "⚠️ No expected files (swarm.pem, userData.json, userApiKey.json) found in $ZIP_FILE"
        fi
    else
        log "WARN" "⚠️ No ZIP file found in $HOME, proceeding without unzipping"
    fi
}


disable_swap() {
    if [ -f "$SWAP_FILE" ]; then
        sudo swapoff "$SWAP_FILE"
        sudo rm -f "$SWAP_FILE"
        sudo sed -i "\|$SWAP_FILE|d" /etc/fstab
    fi
}

copy_modal_files() {
  local target="$HOME/rl-swarm/modal-login/temp-data"
  mkdir -p "$target"
  cp -n userApiKey.json userData.json "$target" 2>/dev/null || true
  echo "✅ Files copied (if they existed) to $target"
}

# Modify run script
modify_run_script() {
    local run_script="$SWARM_DIR/run_rl_swarm.sh"

    if [ -f "$run_script" ]; then
        # 1. Preserve shebang line and remove old KEEP_TEMP_DATA definition
        awk '
        NR==1 && $0 ~ /^#!\/bin\/bash/ { print; next }
        $0 !~ /^\s*: "\$\{KEEP_TEMP_DATA:=.*\}"/ { print }
        ' "$run_script" > "$run_script.tmp" && mv "$run_script.tmp" "$run_script"

        # 2. Inject new KEEP_TEMP_DATA just after #!/bin/bash
        sed -i '1a : "${KEEP_TEMP_DATA:='"$KEEP_TEMP_DATA"'}"' "$run_script"

        # 3. Patch rm logic only if not already patched
        if grep -q 'rm -r \$ROOT_DIR/modal-login/temp-data/\*\.json' "$run_script" && \
           ! grep -q 'if \[ "\$KEEP_TEMP_DATA" != "true" \]; then' "$run_script"; then
            perl -i -pe '
                s#rm -r \$ROOT_DIR/modal-login/temp-data/\*\.json 2> /dev/null \|\| true#
if [ "\$KEEP_TEMP_DATA" != "true" ]; then
    rm -r \$ROOT_DIR/modal-login/temp-data/*.json 2> /dev/null || true
fi#' "$run_script"
        fi
    fi
}

has_error() {
    grep -qP '(current.?batch|UnboundLocalError|Daemon failed to start|FileNotFoundError|DHTNode bootstrap failed|Failed to connect to Gensyn Testnet|Killed|argument of type '\''NoneType'\'' is not iterable|Encountered error during training|cannot unpack non-iterable NoneType object|ConnectionRefusedError|Exception occurred during game run|get_logger\(\)\.exception)' "$LOG_FILE"
}

fix_kill_command() {
    local run_script="$SWARM_DIR/run_rl_swarm.sh"

    if [ -f "$run_script" ]; then
        if grep -q 'kill -- -\$\$ || true' "$run_script"; then
            perl -i -pe 's#kill -- -\$\$ \|\| true#kill -TERM -- -\$\$ 2>/dev/null || true#' "$run_script"
            log "INFO" "✅ Fixed kill command in $run_script to suppress errors"
        else
            log "INFO" "ℹ️ Kill command already updated or not found"
        fi
    else
        log "ERROR" "❌ run_rl_swarm.sh not found at $run_script"
    fi
}

# Clone Repository
clone_repo() {
    sudo rm -rf "$SWARM_DIR" 2>/dev/null
    git clone "$REPO_URL" "$SWARM_DIR" >/dev/null 2>&1
    cd "$SWARM_DIR"
}

create_default_config() {
    log "INFO" "Creating default config at $CONFIG_FILE"
    mkdir -p "$SWARM_DIR"
    cat <<EOF > "$CONFIG_FILE"
PUSH=N
MODEL_NAME=
PARTICIPATE_AI_MARKET=Y
EOF
    chmod 600 "$CONFIG_FILE"
    log "INFO" "Default config created"
}

fix_swarm_pem_permissions() {
    local pem_file="$SWARM_DIR/swarm.pem"
    if [ -f "$pem_file" ]; then
        sudo chown "$(whoami)":"$(whoami)" "$pem_file"
        sudo chmod 600 "$pem_file"
        log "INFO" "✅ swarm.pem permissions fixed"
    else
        log "WARN" "⚠️ swarm.pem not found at $pem_file"
    fi
}

auto_enter_inputs() {
    # Simulate 'N' for pushing to Hugging Face
    HF_TOKEN=${HF_TOKEN:-""}
    if [ -n "${HF_TOKEN}" ]; then
        HUGGINGFACE_ACCESS_TOKEN=${HF_TOKEN}
    else
        HUGGINGFACE_ACCESS_TOKEN="None"
        echo -e "${GREEN}>> Would you like to push models you train in the RL swarm to the Hugging Face Hub? [y/N] N${NC}"
        echo -e "${GREEN}>>> No answer was given, so NO models will be pushed to Hugging Face Hub${NC}"
    fi

    # Handle AI Prediction Market participation
    if [ -n "$PARTICIPATE_AI_MARKET" ]; then
        echo -e "${GREEN}>> Would you like your model to participate in the AI Prediction Market? [Y/n] $PARTICIPATE_AI_MARKET${NC}"
    else
        PARTICIPATE_AI_MARKET="Y"
        echo -e "${GREEN}>> Would you like your model to participate in the AI Prediction Market? [Y/n] Y${NC}"
    fi
}

# Change Configuration
change_config() {
    show_header
    echo -e "${CYAN}${BOLD}⚙️ CHANGE CONFIGURATION${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"

    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "\n${BOLD}${CYAN}⚙️  CURRENT CONFIGURATION${NC}"
        echo -e "${YELLOW}-------------------------------------------------${NC}"
        echo -e "🚀 Push to HF              : ${GREEN}$PUSH${NC}"
        echo -e "🧠 Model Name              : ${GREEN}${MODEL_NAME:-None}${NC}"
        echo -e "📈 Participate AI Market   : ${GREEN}$PARTICIPATE_AI_MARKET${NC}"
        echo -e "${YELLOW}-------------------------------------------------${NC}"
    else
        echo -e "${RED}❗ No config found. Creating default...${NC}"
        create_default_config
        source "$CONFIG_FILE"
    fi

    echo -e "\n${CYAN}${BOLD}🧠 Model Selection:${NC}"
    echo -e "${YELLOW}-------------------------------------------------${NC}"
    printf "${BOLD}%-3s %-40s${NC}\n" "0." "None (default, assigned by hardware)"
    printf "${BOLD}%-3s %-40s${NC}\n" "1." "Gensyn/Qwen2.5-0.5B-Instruct"
    printf "${BOLD}%-3s %-40s${NC}\n" "2." "Qwen/Qwen3-0.6B"
    printf "${BOLD}%-3s %-40s${NC}\n" "3." "nvidia/AceInstruct-1.5B"
    printf "${BOLD}%-3s %-40s${NC}\n" "4." "dnotitia/Smoothie-Qwen3-1.7B"
    printf "${BOLD}%-3s %-40s${NC}\n" "5." "Gensyn/Qwen2.5-1.5B-Instruct"
    printf "${BOLD}%-3s %-40s${NC}\n" "6." "Custom model"
    echo -e "${YELLOW}-------------------------------------------------${NC}"
    read -p "$(echo -e "${BOLD}Choose model [0-6] (Enter = keep current: ${MODEL_NAME:-None}): ${NC}")" model_choice

    if [ -n "$model_choice" ]; then
        case $model_choice in
            0) MODEL_NAME="" ;;
            1) MODEL_NAME="Gensyn/Qwen2.5-0.5B-Instruct" ;;
            2) MODEL_NAME="Qwen/Qwen3-0.6B" ;;
            3) MODEL_NAME="nvidia/AceInstruct-1.5B" ;;
            4) MODEL_NAME="dnotitia/Smoothie-Qwen3-1.7B" ;;
            5) MODEL_NAME="Gensyn/Qwen2.5-1.5B-Instruct" ;;
            6) read -p "Enter custom model (repo/name): " MODEL_NAME ;;
            *) echo -e "${RED}❌ Invalid choice. Keeping current config.${NC}"; MODEL_NAME="${MODEL_NAME:-}" ;;
        esac
        sed -i "s|^MODEL_NAME=.*|MODEL_NAME=$MODEL_NAME|" "$CONFIG_FILE"
        echo -e "${GREEN}✅ Model updated to: ${MODEL_NAME:-None}${NC}"
    else
        echo -e "${CYAN}ℹ️ Model selection unchanged.${NC}"
    fi

    echo -e "\n${CYAN}${BOLD}🚀 Push to Hugging Face:${NC}"
    read -p "${BOLD}Push models to Hugging Face Hub? [y/N]: ${NC}" push_choice
    if [ -n "$push_choice" ]; then
        PUSH=$([[ "$push_choice" =~ ^[Yy]$ ]] && echo "Y" || echo "N")
        sed -i "s/^PUSH=.*/PUSH=$PUSH/" "$CONFIG_FILE"
        echo -e "${GREEN}✅ Push to HF updated to: $PUSH${NC}"
    else
        echo -e "${CYAN}ℹ️ Push setting unchanged.${NC}"
    fi

    echo -e "\n${CYAN}${BOLD}📈 Participate in AI Prediction Market:${NC}"
    read -p "${BOLD}Participate in AI Prediction Market? [Y/n]: ${NC}" market_choice
    if [ -n "$market_choice" ]; then
        PARTICIPATE_AI_MARKET=$([[ "$market_choice" =~ ^[Yy]$ ]] && echo "Y" || echo "N")
        sed -i "s|^PARTICIPATE_AI_MARKET=.*|PARTICIPATE_AI_MARKET=$PARTICIPATE_AI_MARKET|" "$CONFIG_FILE"
        echo -e "${GREEN}✅ AI Prediction Market participation updated to: $PARTICIPATE_AI_MARKET${NC}"
    else
        echo -e "${CYAN}ℹ️ AI Prediction Market setting unchanged.${NC}"
    fi

    echo -e "\n${GREEN}✅ Configuration updated!${NC}"
    echo -e "${YELLOW}${BOLD}👉 Press Enter to return to the menu...${NC}"
    read
    sleep 1
}

# Install Node
install_node() {
    set +m  

    show_header
    echo -e "${CYAN}${BOLD}INSTALLATION${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"
    
    echo -e "\n${CYAN}Auto-login configuration:${NC}"
    echo "Preserve login data between sessions? (recommended for auto-login)"
    read -p "${BOLD}Enable auto-login? [Y/n]: ${NC}" auto_login

    KEEP_TEMP_DATA=$([[ "$auto_login" =~ ^[Nn]$ ]] && echo "false" || echo "true")
    export KEEP_TEMP_DATA

    # Handle swarm.pem from SWARM_DIR
    if [ -f "$SWARM_DIR/swarm.pem" ]; then
        echo -e "\n${YELLOW}⚠️ Existing swarm.pem detected in SWARM_DIR!${NC}"
        echo "1. Keep and use existing Swarm.pem"
        echo "2. Delete and generate new Swarm.pem"
        echo "3. Cancel installation"
        read -p "${BOLD}➡️ Choose action [1-3]: ${NC}" pem_choice

        case $pem_choice in
            1)
                sudo cp "$SWARM_DIR/swarm.pem" "$HOME/swarm.pem"
                log "INFO" "PEM copied from SWARM_DIR to HOME"
                ;;
            2)
                sudo rm -rf "$HOME/swarm.pem"
                log "INFO" "Old PEM deleted from SWARM_DIR"
                ;;
            3)
                echo -e "${RED}❌ Installation cancelled by user.${NC}"
                sleep 1
                return
                ;;
            *)
                echo -e "${RED}❌ Invalid choice. Continuing with existing PEM.${NC}"
                ;;
        esac
    fi

    echo -e "\n${YELLOW}Starting installation...${NC}"

    spinner() {
        local pid=$1
        local msg="$2"
        local spinstr="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        while kill -0 "$pid" 2>/dev/null; do
            for (( i=0; i<${#spinstr}; i++ )); do
                printf "\r$msg ${spinstr:$i:1} "
                sleep 0.15
            done
        done
        printf "\r$msg ✅ Done"; tput el; echo
    }

    ( install_deps ) & spinner $! "📦 Installing dependencies"
    ( clone_repo ) & spinner $! "📥 Cloning repo"
    ( modify_run_script ) & spinner $! "🧠 Modifying run script"
    ( fix_installation ) & spinner $! "🔧 Fixing installation"

    if [ -f "$HOME/swarm.pem" ]; then
        sudo cp "$HOME/swarm.pem" "$SWARM_DIR/swarm.pem"
        sudo chmod 600 "$SWARM_DIR/swarm.pem"
    fi
    unzip_files

    echo -e "\n${GREEN}✅ Installation completed!${NC}"
    echo -e "Auto-login: ${GREEN}$([ "$KEEP_TEMP_DATA" == "true" ] && echo "ENABLED" || echo "DISABLED")${NC}"
    echo -e "${YELLOW}${BOLD}👉 Press Enter to return to the menu...${NC}"
    read
    sleep 1
}

# Run Node
run_node() {
    show_header
    echo -e "${CYAN}${BOLD}🚀 RUN MODE SELECTION${NC}"
    echo "1. 🔄  Auto-Restart Mode (🟢 Recommended)"
    echo "2. 🎯  Single Run (Normally Run)"
    echo "3. 🧼  Fresh Start (Reinstall + Run)"
    echo -e "${YELLOW}===============================================================================${NC}"
    
    read -p "${BOLD}${YELLOW}➡️ Choose run mode [1-3]: ${NC}" run_choice
    
    if [ ! -f "$SWARM_DIR/swarm.pem" ]; then
        if [ -f "$HOME/swarm.pem" ]; then
            sudo cp "$HOME/swarm.pem" "$SWARM_DIR/swarm.pem"
            sudo chmod 600 "$SWARM_DIR/swarm.pem"
        else
            echo -e "${RED}swarm.pem not found in HOME directory. Proceeding without it...${NC}"
        fi
    fi
    unzip_files

    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "\n${BOLD}${CYAN}⚙️  CURRENT CONFIGURATION${NC}"
        echo -e "${YELLOW}-------------------------------------------------${NC}"
        echo -e "🚀 Push to HF              : ${GREEN}$PUSH${NC}"
        echo -e "🧠 Model Name              : ${GREEN}${MODEL_NAME:-None}${NC}"
        echo -e "📈 Participate AI Market   : ${GREEN}$PARTICIPATE_AI_MARKET${NC}"
        echo -e "${YELLOW}-------------------------------------------------${NC}"
    else
        echo -e "${RED}❗ No config found. Creating default...${NC}"
        create_default_config
        source "$CONFIG_FILE"
    fi
    
    echo -e "${CYAN}${BOLD}🧠 Model Selection:${NC}"
    echo -e "${YELLOW}-------------------------------------------------${NC}"
    printf "${BOLD}%-3s %-40s${NC}\n" "0." "None (default, assigned by hardware)"
    printf "${BOLD}%-3s %-40s${NC}\n" "1." "Gensyn/Qwen2.5-0.5B-Instruct"
    printf "${BOLD}%-3s %-40s${NC}\n" "2." "Qwen/Qwen3-0.6B"
    printf "${BOLD}%-3s %-40s${NC}\n" "3." "nvidia/AceInstruct-1.5B"
    printf "${BOLD}%-3s %-40s${NC}\n" "4." "dnotitia/Smoothie-Qwen3-1.7B"
    printf "${BOLD}%-3s %-40s${NC}\n" "5." "Gensyn/Qwen2.5-1.5B-Instruct"
    printf "${BOLD}%-3s %-40s${NC}\n" "6." "Custom model"
    echo -e "${YELLOW}-------------------------------------------------${NC}"
    read -p "$(echo -e "${BOLD}Choose model [0-6] (Enter = keep current: ${MODEL_NAME:-None}): ${NC}")" model_choice

    if [ -n "$model_choice" ]; then
        case $model_choice in
            0) MODEL_NAME="" ;;
            1) MODEL_NAME="Gensyn/Qwen2.5-0.5B-Instruct" ;;
            2) MODEL_NAME="Qwen/Qwen3-0.6B" ;;
            3) MODEL_NAME="nvidia/AceInstruct-1.5B" ;;
            4) MODEL_NAME="dnotitia/Smoothie-Qwen3-1.7B" ;;
            5) MODEL_NAME="Gensyn/Qwen2.5-1.5B-Instruct" ;;
            6) read -p "Enter custom model (repo/name): " MODEL_NAME ;;
            *) echo -e "${RED}❌ Invalid choice. Using current config.${NC}"; MODEL_NAME="${MODEL_NAME:-}" ;;
        esac
        sed -i "s|^MODEL_NAME=.*|MODEL_NAME=$MODEL_NAME|" "$CONFIG_FILE"
    fi

    if [ -n "$MODEL_NAME" ]; then
        echo -e "${GREEN}>> Using selected model: $MODEL_NAME${NC}"
    else
        echo -e "${GREEN}>> Using default model assignment.${NC}"
    fi

    auto_enter_inputs

    # Ensure KEEP_TEMP_DATA is set
    : "${KEEP_TEMP_DATA:=true}"
    export KEEP_TEMP_DATA
    modify_run_script
    sudo chmod +x "$SWARM_DIR/run_rl_swarm.sh"
    fix_kill_command
    
    case $run_choice in
        1)
            log "INFO" "Starting node in auto-restart mode"
            cd "$SWARM_DIR"
            fix_swarm_pem_permissions
            manage_swap
            python3 -m venv .venv
            source .venv/bin/activate
            install_python_packages
            copy_modal_files
            : "${PARTICIPATE_AI_MARKET:=Y}"
            while true; do
                LOG_FILE="$SWARM_DIR/node.log"
                : > "$LOG_FILE"
                KEEP_TEMP_DATA="$KEEP_TEMP_DATA" ./run_rl_swarm.sh <<EOF | tee "$LOG_FILE"
$PUSH
$MODEL_NAME
$PARTICIPATE_AI_MARKET
EOF
                if has_error; then
                    log "ERROR" "❌ Critical error detected, restarting in 5 seconds..."
                    echo -e "${RED}❌ Critical error detected. Restarting in 5 seconds...${NC}"
                else
                    log "WARN" "⚠️ Node exited without critical error, restarting in 5 seconds..."
                    echo -e "${YELLOW}⚠️ Node exited (non-critical). Restarting in 5 seconds...${NC}"
                fi
                sleep 5
            done
            ;;
        2)
            log "INFO" "Starting node in single-run mode"
            cd "$SWARM_DIR"
            fix_swarm_pem_permissions
            manage_swap
            python3 -m venv .venv
            source .venv/bin/activate
            install_python_packages
            copy_modal_files
            : "${PARTICIPATE_AI_MARKET:=Y}"
            LOG_FILE="$SWARM_DIR/node.log"
            : > "$LOG_FILE"
            KEEP_TEMP_DATA="$KEEP_TEMP_DATA" ./run_rl_swarm.sh <<EOF | tee "$LOG_FILE"
$PUSH
$MODEL_NAME
$PARTICIPATE_AI_MARKET
EOF
            ;;
        3)
            log "INFO" "Starting fresh installation + run"
            install_node && run_node
            ;;
        *)
            echo -e "${RED}❌ Invalid choice!${NC}"
            ;;
    esac
}

update_node() {
    set +m  

    show_header
    echo -e "${CYAN}${BOLD}INSTALLATION${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"

    echo -e "${GREEN}${BOLD}Updating node files from Git repository...${NC}"
    
    if [ -d "$SWARM_DIR/.git" ]; then
        cd "$SWARM_DIR" || { echo -e "${RED}Failed to change directory to $SWARM_DIR${NC}"; return; }

        # Remove old virtual environment
        if [ -d ".venv" ]; then
            echo -e "${YELLOW}Removing old virtual environment (.venv)...${NC}"
            rm -rf .venv
        fi

        # Pull latest changes
        echo -e "${YELLOW}Pulling latest updates from Git...${NC}"
        git pull
        echo -e "${GREEN}Repository successfully updated!${NC}"
    else
        echo -e "${RED}$SWARM_DIR is not a git repository.${NC}"
    fi

    echo -e "${YELLOW}${BOLD}👉 Press Enter to return to the menu...${NC}"
    read
    sleep 1
}

fix_installation() {
    show_header
    echo -e "${CYAN}${BOLD}FIX NODE (HustleAirdrops Optimized Files)${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"

    local RUN_SCRIPT_URL="https://raw.githubusercontent.com/HustleAirdrops/Gensyn-Advanced-Solutions/main/run_rl_swarm.sh"
    local MANAGER_PY_URL="https://raw.githubusercontent.com/HustleAirdrops/Gensyn-Advanced-Solutions/main/manager.py"
    local RUN_SCRIPT_PATH="$SWARM_DIR/run_rl_swarm.sh"
    local MANAGER_PY_PATH="$SWARM_DIR/rgym_exp/src/manager.py"
    local MANAGER_DIR="$SWARM_DIR/rgym_exp/src"

    # === STEP 1: Ensure SWARM_DIR exists ===
    if [ ! -d "$SWARM_DIR" ]; then
        echo -e "${RED}SWARM_DIR not found! Run 'Install Node' first.${NC}"
        sleep 3
        return 1
    fi

    # === STEP 2: Create missing directories ===
    mkdir -p "$MANAGER_DIR"
    sudo chown -R "$(whoami):$(whoami)" "$SWARM_DIR" 2>/dev/null || true

    # === STEP 3: Backup old files (if exist) ===
    [ -f "$RUN_SCRIPT_PATH" ] && cp "$RUN_SCRIPT_PATH" "$RUN_SCRIPT_PATH.bak.$(date +%s)" && log "INFO" "Backed up run_rl_swarm.sh"
    [ -f "$MANAGER_PY_PATH" ] && cp "$MANAGER_PY_PATH" "$MANAGER_PY_PATH.bak.$(date +%s)" && log "INFO" "Backed up manager.py"

    # === STEP 4: Download with retry + force write ===
    echo -e "${YELLOW}Downloading run_rl_swarm.sh...${NC}"
    if curl -fsSL "$RUN_SCRIPT_URL" --output "$RUN_SCRIPT_PATH" --create-dirs; then
        chmod +x "$RUN_SCRIPT_PATH"
        log "INFO" "run_rl_swarm.sh updated"
        echo -e "${GREEN}run_rl_swarm.sh updated!${NC}"
    else
        log "ERROR" "Failed to download run_rl_swarm.sh"
        echo -e "${RED}Failed to download run_rl_swarm.sh${NC}"
    fi

    echo -e "${YELLOW}Downloading manager.py...${NC}"
    if curl -fsSL "$MANAGER_PY_URL" --output "$MANAGER_PY_PATH" --create-dirs; then
        log "INFO" "manager.py updated"
        echo -e "${GREEN}manager.py updated!${NC}"
    else
        log "ERROR" "Failed to download manager.py"
        echo -e "${RED}Failed to download manager.py${NC}"
    fi

    # === STEP 5: Fix permissions ===
    sudo chown -R "$(whoami):$(whoami)" "$SWARM_DIR" 2>/dev/null || true
    [ -f "$SWARM_DIR/swarm.pem" ] && chmod 600 "$SWARM_DIR/swarm.pem"

    echo -e "\n${GREEN}Node fixed!${NC}"
}

fix_node() {
    show_header
    echo -e "${CYAN}${BOLD}FIX NODE${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"

    local RUN_SCRIPT_URL="https://raw.githubusercontent.com/HustleAirdrops/Gensyn-Advanced-Solutions/main/run_rl_swarm.sh"
    local MANAGER_PY_URL="https://raw.githubusercontent.com/HustleAirdrops/Gensyn-Advanced-Solutions/main/manager.py"
    local RUN_SCRIPT_PATH="$SWARM_DIR/run_rl_swarm.sh"
    local MANAGER_PY_PATH="$SWARM_DIR/rgym_exp/src/manager.py"
    local MANAGER_DIR="$SWARM_DIR/rgym_exp/src"

    # === STEP 1: Ensure SWARM_DIR exists ===
    if [ ! -d "$SWARM_DIR" ]; then
        echo -e "${RED}SWARM_DIR not found! Run 'Install Node' first.${NC}"
        sleep 3
        return 1
    fi

    # === STEP 2: Create missing directories ===
    mkdir -p "$MANAGER_DIR"
    sudo chown -R "$(whoami):$(whoami)" "$SWARM_DIR" 2>/dev/null || true

    # === STEP 3: Backup old files (if exist) ===
    [ -f "$RUN_SCRIPT_PATH" ] && cp "$RUN_SCRIPT_PATH" "$RUN_SCRIPT_PATH.bak.$(date +%s)" && log "INFO" "Backed up run_rl_swarm.sh"
    [ -f "$MANAGER_PY_PATH" ] && cp "$MANAGER_PY_PATH" "$MANAGER_PY_PATH.bak.$(date +%s)" && log "INFO" "Backed up manager.py"

    # === STEP 4: Download with retry + force write ===
    echo -e "${YELLOW}Downloading run_rl_swarm.sh...${NC}"
    if curl -fsSL "$RUN_SCRIPT_URL" --output "$RUN_SCRIPT_PATH" --create-dirs; then
        chmod +x "$RUN_SCRIPT_PATH"
        log "INFO" "run_rl_swarm.sh updated"
        echo -e "${GREEN}run_rl_swarm.sh updated!${NC}"
    else
        log "ERROR" "Failed to download run_rl_swarm.sh"
        echo -e "${RED}Failed to download run_rl_swarm.sh${NC}"
    fi

    echo -e "${YELLOW}Downloading manager.py...${NC}"
    if curl -fsSL "$MANAGER_PY_URL" --output "$MANAGER_PY_PATH" --create-dirs; then
        log "INFO" "manager.py updated"
        echo -e "${GREEN}manager.py updated!${NC}"
    else
        log "ERROR" "Failed to download manager.py"
        echo -e "${RED}Failed to download manager.py${NC}"
    fi

    # === STEP 5: Fix permissions ===
    sudo chown -R "$(whoami):$(whoami)" "$SWARM_DIR" 2>/dev/null || true
    [ -f "$SWARM_DIR/swarm.pem" ] && chmod 600 "$SWARM_DIR/swarm.pem"

    echo -e "\n${GREEN}Node fixed!${NC}"
    echo -e "${YELLOW}${BOLD}Press Enter to return to menu...${NC}"
    read
}


# Reset Peer ID
reset_peer() {
    echo -e "${RED}${BOLD}⚠️ WARNING: This will delete ALL node keys and data!${NC}"
    read -p "${BOLD}Are you sure? [y/N]: ${NC}" confirm
    
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        sudo rm -f ~/swarm.pem ~/userData.json ~/userApiKey.json
        sudo rm -f "$SWARM_DIR"/{swarm.pem,modal-login/temp-data/{userData.json,userApiKey.json}}
        echo -e "${GREEN}✅ All keys and data deleted!${NC}"
        echo -e "${YELLOW}⚠️ Reinstall node to generate new keys${NC}"
    else
        echo -e "${YELLOW}⚠️ Operation canceled${NC}"
    fi
    sleep 5
}

install_python_packages() {
    TRANSFORMERS_VERSION=$(pip show transformers 2>/dev/null | grep ^Version: | awk '{print $2}')
    TRL_VERSION=$(pip show trl 2>/dev/null | grep ^Version: | awk '{print $2}')

    if [ "$TRANSFORMERS_VERSION" != "4.51.3" ] || [ "$TRL_VERSION" != "0.19.1" ]; then
        pip install --force-reinstall transformers==4.51.3 trl==0.19.1
    fi
    pip freeze | grep -E '^(transformers|trl)=='
}

# Main Menu
main_menu() {
    while true; do
        show_header
        echo -e "${BOLD}${MAGENTA}==================== 🧠 GENSYN MAIN MENU ====================${NC}"
        echo "1. 🛠  Install/Reinstall Node"
        echo "2. 🚀  Run Node"
        echo "3. ⚙️  Update Node"
        echo '4. 🔥  Change Configuration'
        echo "5. ♻️  Reset Peer ID"
        echo "6. 🗑️  Delete Everything & Start New"
        echo "7. 🔧  Fix Node"
        echo "8. ❌ Exit"
        echo -e "${GREEN}===============================================================================${NC}"
        
        read -p "${BOLD}${YELLOW}➡️ Select option [1-7]: ${NC}" choice
        
        case $choice in
            1) install_node ;;
            2) run_node ;;
            3) update_node ;;
            4) change_config ;;
            5) reset_peer ;;
            6)
                echo -e "\n${RED}${BOLD}⚠️ WARNING: This will delete ALL node data!${NC}"
                read -p "${BOLD}Are you sure you want to continue? [y/N]: ${NC}" confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    sudo rm -rf "$SWARM_DIR"
                    sudo rm -f ~/swarm.pem ~/userData.json ~/userApiKey.json
                    echo -e "${GREEN}✅ All node data deleted!${NC}"

                    echo -e "\n${YELLOW}➕ Do you want to reinstall the node now?${NC}"
                    read -p "${BOLD}Proceed with fresh install? [Y/n]: ${NC}" reinstall_choice
                    if [[ ! "$reinstall_choice" =~ ^[Nn]$ ]]; then
                        install_node
                    else
                        echo -e "${CYAN}❗ Fresh install skipped.${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️ Operation canceled${NC}"
                fi
                ;;
            7) fix_node ;;
            8)
                echo -e "\n${GREEN}✅ Exiting... Thank you for using Hustle Manager!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Invalid option!${NC}"
                sleep 1
                ;;
        esac
    done
}

init
trap "echo -e '\n${GREEN}✅ Stopped gracefully${NC}'; disable_swap; exit 0" SIGINT
main_menu
