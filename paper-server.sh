#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Minecraft Server Setup (Paper/Purpur) for Termux Ubuntu proot
# Features: Geyser, Floodgate, ngrok, playit.gg, auto-setup
# ═══════════════════════════════════════════════════════════════════

set -e

# ─────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/minecraft-server"

# APIs
PAPER_API="https://api.papermc.io/v2"
PURPUR_API="https://api.purpurmc.org/v2/purpur"
GEYSER_API="https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/spigot"
FLOODGATE_API="https://download.geysermc.org/v2/projects/floodgate/versions/latest/builds/latest/downloads/spigot"

# Defaults
SERVER_TYPE="paper"
SELECTED_VERSION=""
RAM_SETTING="auto"
GAMEMODE="survival"
DIFFICULTY="normal"
JAVA_VERSION="21"
ENABLE_GEYSER=false
ENABLE_NGROK=false
ENABLE_PLAYIT=false
JAVA_PORT=25565
BEDROCK_PORT=19132

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────────────────────────────

print_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         Minecraft Server Setup for Termux                 ║"
    echo "║         Paper • Purpur • Geyser • Floodgate               ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
log_step()    { echo -e "${MAGENTA}[STEP]${NC} $1"; }

separator() {
    echo -e "${CYAN}─────────────────────────────────────────────────${NC}"
}

confirm() {
    read -p "$1 (y/n) [default: $2]: " response
    response=${response:-$2}
    [[ "$response" =~ ^[Yy]$ ]]
}

check_environment() {
    if [ ! -f "/etc/os-release" ]; then
        log_error "Run this inside Ubuntu proot!"
        log_info "First: proot-distro login ubuntu"
        exit 1
    fi
}

check_internet() {
    if ! curl -s --head --connect-timeout 5 https://google.com > /dev/null; then
        log_error "No internet connection!"
        exit 1
    fi
}


# ─────────────────────────────────────────────────────────────────────
# Java Management
# ─────────────────────────────────────────────────────────────────────

check_java() {
    if command -v java &> /dev/null; then
        java -version 2>&1 | head -1 | cut -d'"' -f2 | cut -d'.' -f1
    else
        echo "none"
    fi
}

install_java() {
    local version=${1:-21}
    log_step "Installing Java $version..."
    
    apt update -y &>/dev/null
    
    case $version in
        21)
            apt install -y openjdk-21-jre-headless 2>/dev/null || \
            apt install -y openjdk-21-jdk-headless 2>/dev/null || {
                log_warn "Java 21 unavailable, using Java 17"
                apt install -y openjdk-17-jre-headless
                JAVA_VERSION="17"
            }
            ;;
        17)
            apt install -y openjdk-17-jre-headless
            ;;
        *)
            apt install -y openjdk-17-jre-headless
            ;;
    esac
    log_success "Java installed!"
}

select_java() {
    local current=$(check_java)
    
    echo ""
    echo -e "${CYAN}Java Version:${NC}"
    separator
    
    if [ "$current" = "none" ]; then
        echo -e "  ${RED}Not installed${NC}"
    else
        echo -e "  Current: ${GREEN}Java $current${NC}"
    fi
    
    echo ""
    echo -e "  ${GREEN}1${NC}) Java 17 (MC 1.17-1.20.4)"
    echo -e "  ${GREEN}2${NC}) Java 21 (MC 1.20.5+) ${YELLOW}[recommended]${NC}"
    [ "$current" != "none" ] && echo -e "  ${GREEN}3${NC}) Keep current"
    echo ""
    read -p "Select [default: 2]: " choice
    
    case $choice in
        1) JAVA_VERSION="17"; install_java 17 ;;
        3) [ "$current" != "none" ] && JAVA_VERSION="$current" ;;
        *) JAVA_VERSION="21"; install_java 21 ;;
    esac
}

ensure_java() {
    local current=$(check_java)
    if [ "$current" = "none" ]; then
        log_info "No Java found, installing Java 21..."
        install_java 21
    else
        log_info "Using Java $current"
    fi
}

# ─────────────────────────────────────────────────────────────────────
# Dependencies
# ─────────────────────────────────────────────────────────────────────

install_dependencies() {
    log_step "Installing dependencies..."
    apt update -y &>/dev/null
    apt install -y wget curl jq screen unzip &>/dev/null
    log_success "Dependencies ready!"
}

# ─────────────────────────────────────────────────────────────────────
# Server Download Functions
# ─────────────────────────────────────────────────────────────────────

get_paper_versions() {
    curl -sL "$PAPER_API/projects/paper" | jq -r '.versions[]' 2>/dev/null | tail -10
}

get_paper_build() {
    local v=$1
    curl -sL "$PAPER_API/projects/paper/versions/$v/builds" | jq -r '.builds[-1].build' 2>/dev/null
}

download_paper() {
    local version=$1 build=$2
    local file="paper-$version-$build.jar"
    local url="$PAPER_API/projects/paper/versions/$version/builds/$build/downloads/$file"
    
    log_step "Downloading Paper $version (build $build)..."
    wget -q --show-progress -O "$SERVER_DIR/server.jar" "$url" || return 1
    log_success "Paper downloaded!"
}

get_purpur_versions() {
    curl -sL "$PURPUR_API" | jq -r '.versions[]' 2>/dev/null | tail -10
}

get_purpur_build() {
    local v=$1
    curl -sL "$PURPUR_API/$v" | jq -r '.builds.latest' 2>/dev/null
}

download_purpur() {
    local version=$1 build=$2
    local url="$PURPUR_API/$version/$build/download"
    
    log_step "Downloading Purpur $version (build $build)..."
    wget -q --show-progress -O "$SERVER_DIR/server.jar" "$url" || return 1
    log_success "Purpur downloaded!"
}

get_versions() {
    [ "$SERVER_TYPE" = "purpur" ] && get_purpur_versions || get_paper_versions
}

get_build() {
    [ "$SERVER_TYPE" = "purpur" ] && get_purpur_build "$1" || get_paper_build "$1"
}

download_server_jar() {
    local version=$1 build=$2
    [ "$SERVER_TYPE" = "purpur" ] && download_purpur "$version" "$build" || download_paper "$version" "$build"
}


# ─────────────────────────────────────────────────────────────────────
# Geyser & Floodgate (Bedrock Support)
# ─────────────────────────────────────────────────────────────────────

download_geyser() {
    log_step "Downloading Geyser (Bedrock support)..."
    mkdir -p "$SERVER_DIR/plugins"
    wget -q --show-progress -O "$SERVER_DIR/plugins/Geyser-Spigot.jar" "$GEYSER_API" || {
        log_error "Geyser download failed!"
        return 1
    }
    log_success "Geyser downloaded!"
}

download_floodgate() {
    log_step "Downloading Floodgate (Bedrock auth)..."
    mkdir -p "$SERVER_DIR/plugins"
    wget -q --show-progress -O "$SERVER_DIR/plugins/floodgate-spigot.jar" "$FLOODGATE_API" || {
        log_error "Floodgate download failed!"
        return 1
    }
    log_success "Floodgate downloaded!"
}

configure_geyser() {
    mkdir -p "$SERVER_DIR/plugins/Geyser-Spigot"
    
    cat > "$SERVER_DIR/plugins/Geyser-Spigot/config.yml" << EOF
bedrock:
  address: 0.0.0.0
  port: $BEDROCK_PORT
  clone-remote-port: false
  motd1: "Mobile Minecraft Server"
  motd2: "Geyser Enabled"
  server-name: "Mobile Server"
remote:
  address: 127.0.0.1
  port: $JAVA_PORT
  auth-type: floodgate
passthrough-motd: true
passthrough-player-counts: true
command-suggestions: true
show-cooldown: title
emote-offhand-workaround: disabled
EOF
    log_success "Geyser configured!"
}

configure_floodgate() {
    mkdir -p "$SERVER_DIR/plugins/floodgate"
    
    cat > "$SERVER_DIR/plugins/floodgate/config.yml" << 'EOF'
username-prefix: "."
replace-spaces: true
disconnect:
  invalid-prefix: "Please remove the prefix from your name!"
  invalid-username: "Invalid username!"
player-link:
  enabled: true
  require-link: false
  allowed-link-type: any
EOF
    log_success "Floodgate configured!"
}

setup_geyser_floodgate() {
    download_geyser
    download_floodgate
    configure_geyser
    configure_floodgate
    ENABLE_GEYSER=true
}

select_geyser() {
    echo ""
    echo -e "${CYAN}Bedrock Support (Geyser + Floodgate):${NC}"
    separator
    echo -e "  Allows Bedrock players (PE, Console, Win10) to join!"
    echo ""
    echo -e "  ${GREEN}1${NC}) Enable Geyser + Floodgate ${YELLOW}[recommended]${NC}"
    echo -e "  ${GREEN}2${NC}) Skip (Java only)"
    echo ""
    read -p "Select [default: 1]: " choice
    
    case $choice in
        2) ENABLE_GEYSER=false ;;
        *) ENABLE_GEYSER=true ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────
# Port Forwarding - ngrok
# ─────────────────────────────────────────────────────────────────────

install_ngrok() {
    log_step "Installing ngrok..."
    
    local arch=$(uname -m)
    local ngrok_url=""
    
    case $arch in
        aarch64) ngrok_url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm64.tgz" ;;
        armv7l)  ngrok_url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-arm.tgz" ;;
        x86_64)  ngrok_url="https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz" ;;
        *)       log_error "Unsupported arch: $arch"; return 1 ;;
    esac
    
    wget -q --show-progress -O /tmp/ngrok.tgz "$ngrok_url"
    tar -xzf /tmp/ngrok.tgz -C /usr/local/bin
    rm /tmp/ngrok.tgz
    chmod +x /usr/local/bin/ngrok
    
    log_success "ngrok installed!"
}

setup_ngrok() {
    if ! command -v ngrok &>/dev/null; then
        install_ngrok
    fi
    
    # Ensure server directory exists
    mkdir -p "$SERVER_DIR"
    
    echo ""
    echo -e "${CYAN}ngrok Setup:${NC}"
    separator
    echo -e "  1. Go to ${GREEN}https://ngrok.com${NC} and create free account"
    echo -e "  2. Copy your authtoken from dashboard"
    echo ""
    read -p "Enter ngrok authtoken (or press Enter to skip): " authtoken
    
    if [ -n "$authtoken" ]; then
        ngrok config add-authtoken "$authtoken"
        log_success "ngrok authtoken configured!"
    else
        log_warn "No authtoken - you'll need to run 'ngrok config add-authtoken YOUR_TOKEN' later"
    fi
    
    # Always create the ngrok start script
    log_step "Creating ngrok start script..."
    
    cat > "$SERVER_DIR/start-ngrok.sh" << 'NGROKSCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

JAVA_PORT=25565
BEDROCK_PORT=19132

echo "════════════════════════════════════════════"
echo "  Starting ngrok tunnel..."
echo "════════════════════════════════════════════"
echo ""

# Check if ngrok is configured
if ! ngrok config check &>/dev/null; then
    echo "ngrok not configured! Run:"
    echo "  ngrok config add-authtoken YOUR_TOKEN"
    echo ""
    echo "Get your token at: https://dashboard.ngrok.com/get-started/your-authtoken"
    exit 1
fi

# Start Java tunnel
ngrok tcp $JAVA_PORT &
NGROK_PID=$!

sleep 4

# Get tunnel info
TUNNEL_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | grep -o '"public_url":"[^"]*' | head -1 | cut -d'"' -f4)

echo ""
echo -e "\033[0;32m════════════════════════════════════════════\033[0m"
echo -e "\033[0;32m  ngrok Tunnel Active!\033[0m"
echo -e "\033[0;32m════════════════════════════════════════════\033[0m"
echo ""

if [ -n "$TUNNEL_URL" ]; then
    # Remove tcp:// prefix for display
    CONNECT_ADDR="${TUNNEL_URL#tcp://}"
    echo -e "  Java Edition: \033[1;33m$CONNECT_ADDR\033[0m"
else
    echo "  Could not get tunnel URL. Check http://localhost:4040"
fi

echo ""
echo -e "\033[0;33m  Note: Free ngrok = 1 tunnel only\033[0m"
echo -e "\033[0;33m  For Bedrock, use playit.gg instead!\033[0m"
echo ""
echo "Press Ctrl+C to stop"
echo ""

wait $NGROK_PID
NGROKSCRIPT

    chmod +x "$SERVER_DIR/start-ngrok.sh"
    log_success "Created: $SERVER_DIR/start-ngrok.sh"
    ENABLE_NGROK=true
}


# ─────────────────────────────────────────────────────────────────────
# Port Forwarding - playit.gg
# ─────────────────────────────────────────────────────────────────────

install_playit() {
    log_step "Installing playit.gg..."
    
    local arch=$(uname -m)
    local playit_url=""
    
    case $arch in
        aarch64) playit_url="https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-aarch64" ;;
        armv7l)  playit_url="https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-armv7" ;;
        x86_64)  playit_url="https://github.com/playit-cloud/playit-agent/releases/latest/download/playit-linux-amd64" ;;
        *)       log_error "Unsupported arch: $arch"; return 1 ;;
    esac
    
    wget -q --show-progress -O /usr/local/bin/playit "$playit_url"
    chmod +x /usr/local/bin/playit
    
    log_success "playit.gg installed!"
}

setup_playit() {
    if ! command -v playit &>/dev/null; then
        install_playit
    fi
    
    # Ensure server directory exists
    mkdir -p "$SERVER_DIR"
    
    echo ""
    echo -e "${CYAN}playit.gg Setup:${NC}"
    separator
    echo -e "  ${GREEN}playit.gg${NC} is FREE and supports both Java & Bedrock!"
    echo ""
    echo -e "  ${YELLOW}How it works:${NC}"
    echo -e "  1. Run the start-playit.sh script"
    echo -e "  2. Open the link shown in browser"
    echo -e "  3. Create account and claim your agent"
    echo -e "  4. Add tunnels in the web dashboard:"
    echo -e "     - Java: TCP port ${GREEN}$JAVA_PORT${NC}"
    [ "$ENABLE_GEYSER" = true ] && echo -e "     - Bedrock: UDP port ${GREEN}$BEDROCK_PORT${NC}"
    echo ""
    
    # Create playit start script
    log_step "Creating playit start script..."
    
    cat > "$SERVER_DIR/start-playit.sh" << 'PLAYITSCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

echo "════════════════════════════════════════════"
echo "  Starting playit.gg tunnel"
echo "════════════════════════════════════════════"
echo ""
echo "If this is your first time:"
echo "  1. A link will appear - open it in browser"
echo "  2. Create account / login"
echo "  3. Claim this agent"
echo "  4. Add tunnels in dashboard:"
echo "     - Minecraft Java: TCP port 25565"
echo "     - Minecraft Bedrock: UDP port 19132"
echo ""
echo "Your public address will show in the dashboard!"
echo ""
echo "Press Ctrl+C to stop"
echo ""

playit
PLAYITSCRIPT

    chmod +x "$SERVER_DIR/start-playit.sh"
    log_success "Created: $SERVER_DIR/start-playit.sh"
    
    ENABLE_PLAYIT=true
    
    read -p "Run playit setup now? (y/n) [default: n]: " run_now
    run_now=${run_now:-n}
    
    if [[ "$run_now" =~ ^[Yy]$ ]]; then
        echo ""
        log_info "Starting playit... Follow the instructions!"
        echo ""
        playit
    else
        echo ""
        log_info "Run './start-playit.sh' later to setup tunnels"
    fi
}

# ─────────────────────────────────────────────────────────────────────
# Port Forwarding Menu
# ─────────────────────────────────────────────────────────────────────

select_port_forwarding() {
    echo ""
    echo -e "${CYAN}Port Forwarding (Play from anywhere):${NC}"
    separator
    echo -e "  ${GREEN}1${NC}) None (LAN only)"
    echo -e "  ${GREEN}2${NC}) ngrok (free, 1 tunnel)"
    echo -e "  ${GREEN}3${NC}) playit.gg (free, unlimited) ${YELLOW}[recommended]${NC}"
    echo -e "  ${GREEN}4${NC}) Both ngrok + playit"
    echo ""
    read -p "Select [default: 1]: " choice
    
    case $choice in
        2) setup_ngrok ;;
        3) setup_playit ;;
        4) setup_ngrok; setup_playit ;;
        *) log_info "Skipping port forwarding (LAN only)" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────
# Server Configuration
# ─────────────────────────────────────────────────────────────────────

setup_server_files() {
    log_step "Creating server directory..."
    mkdir -p "$SERVER_DIR/plugins"
    cd "$SERVER_DIR"
    
    # EULA
    echo "eula=true" > eula.txt
    log_success "EULA accepted"
    
    # server.properties
    cat > server.properties << EOF
# Server Settings
server-port=$JAVA_PORT
gamemode=$GAMEMODE
difficulty=$DIFFICULTY
max-players=10
view-distance=8
simulation-distance=6
spawn-protection=0
online-mode=false
enable-command-block=true
motd=\u00A7b\u00A7lMobile Server \u00A77| \u00A7a${SERVER_TYPE^}
allow-flight=true
white-list=false
pvp=true
enable-status=true
EOF
    log_success "server.properties created"
}

create_start_script() {
    cat > "$SERVER_DIR/start.sh" << 'STARTSCRIPT'
#!/bin/bash
cd "$(dirname "$0")"

# Auto RAM detection
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -gt 4000 ]; then
    XMX="2G"; XMS="1G"
elif [ $TOTAL_MEM -gt 2000 ]; then
    XMX="1G"; XMS="512M"
else
    XMX="512M"; XMS="256M"
fi

echo "════════════════════════════════════════"
echo "  Starting Minecraft Server"
echo "  RAM: ${XMS} - ${XMX}"
echo "════════════════════════════════════════"
echo ""

java -Xmx${XMX} -Xms${XMS} \
    -XX:+UseG1GC \
    -XX:+ParallelRefProcEnabled \
    -XX:MaxGCPauseMillis=200 \
    -XX:+UnlockExperimentalVMOptions \
    -XX:+DisableExplicitGC \
    -XX:G1NewSizePercent=30 \
    -XX:G1MaxNewSizePercent=40 \
    -XX:G1HeapRegionSize=8M \
    -XX:G1ReservePercent=20 \
    -XX:G1HeapWastePercent=5 \
    -XX:G1MixedGCCountTarget=4 \
    -XX:InitiatingHeapOccupancyPercent=15 \
    -XX:G1MixedGCLiveThresholdPercent=90 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -jar server.jar nogui
STARTSCRIPT
    chmod +x "$SERVER_DIR/start.sh"
    
    # Background script
    cat > "$SERVER_DIR/start-background.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
screen -dmS minecraft ./start.sh
echo ""
echo "Server started in background!"
echo ""
echo "Commands:"
echo "  Attach:  screen -r minecraft"
echo "  Detach:  Ctrl+A then D"
echo "  Stop:    Type 'stop' in console"
echo ""
EOF
    chmod +x "$SERVER_DIR/start-background.sh"
    
    log_success "Start scripts created"
}

optimize_mobile() {
    mkdir -p "$SERVER_DIR/config"
    
    cat > "$SERVER_DIR/config/paper-global.yml" << 'EOF'
chunk-loading-basic:
  autoconfig-send-distance: true
  player-max-chunk-load-rate: 50.0
  player-max-concurrent-chunk-loads: 4.0
chunk-system:
  gen-parallelism: default
  io-threads: 2
  worker-threads: 2
EOF
    log_success "Mobile optimizations applied"
}


# ─────────────────────────────────────────────────────────────────────
# Selection Menus
# ─────────────────────────────────────────────────────────────────────

select_server_type() {
    echo ""
    echo -e "${CYAN}Server Software:${NC}"
    separator
    echo -e "  ${GREEN}1${NC}) Paper - Fast & optimized"
    echo -e "  ${GREEN}2${NC}) Purpur - More features & customization"
    echo ""
    read -p "Select [default: 1]: " choice
    
    case $choice in
        2) SERVER_TYPE="purpur" ;;
        *) SERVER_TYPE="paper" ;;
    esac
    log_info "Selected: ${SERVER_TYPE^}"
}

select_version() {
    echo ""
    log_info "Fetching ${SERVER_TYPE^} versions..."
    
    local versions_list=$(get_versions)
    [ -z "$versions_list" ] && { log_error "Failed to fetch versions"; exit 1; }
    
    readarray -t versions <<< "$versions_list"
    local count=${#versions[@]}
    
    echo ""
    echo -e "${CYAN}Minecraft Version:${NC}"
    separator
    
    for i in "${!versions[@]}"; do
        local num=$((count - i))
        local ver="${versions[$i]}"
        [ $num -eq 1 ] && echo -e "  ${GREEN}${num}${NC}) $ver ${YELLOW}[latest]${NC}" || echo -e "  ${GREEN}${num}${NC}) $ver"
    done
    
    echo ""
    read -p "Select (1-$count) [default: 1]: " choice
    
    [ -z "$choice" ] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ] && choice=1
    
    local idx=$((count - choice))
    SELECTED_VERSION="${versions[$idx]}"
    log_info "Selected: $SELECTED_VERSION"
}

select_ram() {
    echo ""
    echo -e "${CYAN}RAM Allocation:${NC}"
    separator
    echo -e "  ${GREEN}1${NC}) Auto-detect ${YELLOW}[recommended]${NC}"
    echo -e "  ${GREEN}2${NC}) 512MB (low-end)"
    echo -e "  ${GREEN}3${NC}) 1GB (mid-range)"
    echo -e "  ${GREEN}4${NC}) 2GB (high-end)"
    echo ""
    read -p "Select [default: 1]: " choice
    
    case $choice in
        2) RAM_SETTING="512M" ;;
        3) RAM_SETTING="1G" ;;
        4) RAM_SETTING="2G" ;;
        *) RAM_SETTING="auto" ;;
    esac
}

select_gamemode() {
    echo ""
    echo -e "${CYAN}Default Gamemode:${NC}"
    separator
    echo -e "  ${GREEN}1${NC}) Survival"
    echo -e "  ${GREEN}2${NC}) Creative"
    echo -e "  ${GREEN}3${NC}) Adventure"
    echo -e "  ${GREEN}4${NC}) Spectator"
    echo ""
    read -p "Select [default: 1]: " choice
    
    case $choice in
        2) GAMEMODE="creative" ;;
        3) GAMEMODE="adventure" ;;
        4) GAMEMODE="spectator" ;;
        *) GAMEMODE="survival" ;;
    esac
}

select_difficulty() {
    echo ""
    echo -e "${CYAN}Difficulty:${NC}"
    separator
    echo -e "  ${GREEN}1${NC}) Peaceful"
    echo -e "  ${GREEN}2${NC}) Easy"
    echo -e "  ${GREEN}3${NC}) Normal"
    echo -e "  ${GREEN}4${NC}) Hard"
    echo ""
    read -p "Select [default: 3]: " choice
    
    case $choice in
        1) DIFFICULTY="peaceful" ;;
        2) DIFFICULTY="easy" ;;
        4) DIFFICULTY="hard" ;;
        *) DIFFICULTY="normal" ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────
# Setup Flows
# ─────────────────────────────────────────────────────────────────────

show_completion() {
    # Change to server directory
    cd "$SERVER_DIR"
    
    echo ""
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}                  Setup Complete!${NC}"
    echo -e "${GREEN}${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Server Info:${NC}"
    echo -e "  Type:      ${GREEN}${SERVER_TYPE^}${NC}"
    echo -e "  Version:   ${GREEN}$SELECTED_VERSION${NC}"
    echo -e "  Location:  ${GREEN}$SERVER_DIR${NC}"
    echo -e "  Gamemode:  ${GREEN}$GAMEMODE${NC}"
    echo -e "  Difficulty:${GREEN}$DIFFICULTY${NC}"
    
    if [ "$ENABLE_GEYSER" = true ]; then
        echo ""
        echo -e "${CYAN}Bedrock Support:${NC} ${GREEN}Enabled${NC}"
        echo -e "  Java Port:    ${GREEN}$JAVA_PORT${NC}"
        echo -e "  Bedrock Port: ${GREEN}$BEDROCK_PORT${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Commands (run from this directory):${NC}"
    echo -e "  Start:        ${GREEN}./start.sh${NC}"
    echo -e "  Background:   ${GREEN}./start-background.sh${NC}"
    echo -e "  Attach:       ${GREEN}screen -r minecraft${NC}"
    
    if [ "$ENABLE_NGROK" = true ]; then
        echo -e "  ngrok:        ${GREEN}./start-ngrok.sh${NC}"
    fi
    if [ "$ENABLE_PLAYIT" = true ]; then
        echo -e "  playit:       ${GREEN}./start-playit.sh${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}Connect:${NC}"
    echo -e "  Java:    ${GREEN}localhost:$JAVA_PORT${NC}"
    [ "$ENABLE_GEYSER" = true ] && echo -e "  Bedrock: ${GREEN}localhost:$BEDROCK_PORT${NC}"
    echo ""
    echo -e "${CYAN}Current directory:${NC} ${GREEN}$(pwd)${NC}"
    echo ""
}

quick_setup() {
    print_banner
    log_step "Quick Setup - Paper with defaults"
    separator
    
    check_internet
    ensure_java
    
    SERVER_TYPE="paper"
    GAMEMODE="survival"
    DIFFICULTY="normal"
    
    log_info "Fetching latest Paper version..."
    local versions=$(get_versions)
    SELECTED_VERSION=$(echo "$versions" | tail -1)
    [ -z "$SELECTED_VERSION" ] && { log_error "Failed to get version"; exit 1; }
    
    log_info "Version: $SELECTED_VERSION"
    
    local build=$(get_build "$SELECTED_VERSION")
    [ -z "$build" ] || [ "$build" = "null" ] && { log_error "Failed to get build"; exit 1; }
    log_info "Build: $build"
    
    setup_server_files
    download_server_jar "$SELECTED_VERSION" "$build"
    create_start_script
    optimize_mobile
    
    show_completion
    
    echo -e "${CYAN}Starting server...${NC}"
    echo ""
    ./start.sh
}

custom_setup() {
    print_banner
    log_step "Custom Setup"
    separator
    
    check_internet
    select_java
    select_server_type
    select_version
    select_ram
    select_gamemode
    select_difficulty
    select_geyser
    select_port_forwarding
    
    echo ""
    log_step "Downloading and configuring..."
    separator
    
    local build=$(get_build "$SELECTED_VERSION")
    [ -z "$build" ] || [ "$build" = "null" ] && { log_error "Failed to get build"; exit 1; }
    
    setup_server_files
    download_server_jar "$SELECTED_VERSION" "$build"
    create_start_script
    optimize_mobile
    
    [ "$ENABLE_GEYSER" = true ] && setup_geyser_floodgate
    
    # Update RAM if not auto
    [ "$RAM_SETTING" != "auto" ] && sed -i "s/XMX=.*/XMX=\"$RAM_SETTING\"/" "$SERVER_DIR/start.sh"
    
    show_completion
    
    echo -e "${CYAN}Starting server...${NC}"
    echo ""
    ./start.sh
}


# ─────────────────────────────────────────────────────────────────────
# Additional Setup Functions
# ─────────────────────────────────────────────────────────────────────

update_server() {
    print_banner
    
    [ ! -d "$SERVER_DIR" ] && { log_error "No server at $SERVER_DIR"; exit 1; }
    
    log_step "Update Server"
    separator
    
    select_server_type
    select_version
    
    local build=$(get_build "$SELECTED_VERSION")
    [ -z "$build" ] || [ "$build" = "null" ] && { log_error "Failed to get build"; exit 1; }
    
    # Backup
    [ -f "$SERVER_DIR/server.jar" ] && mv "$SERVER_DIR/server.jar" "$SERVER_DIR/server.jar.backup"
    
    download_server_jar "$SELECTED_VERSION" "$build"
    log_success "Updated to ${SERVER_TYPE^} $SELECTED_VERSION (build $build)"
}

add_geyser() {
    print_banner
    
    [ ! -d "$SERVER_DIR" ] && { log_error "No server at $SERVER_DIR"; exit 1; }
    
    log_step "Adding Geyser + Floodgate"
    separator
    
    setup_geyser_floodgate
    log_success "Geyser & Floodgate installed!"
    echo ""
    echo -e "${YELLOW}Restart your server to activate!${NC}"
}

setup_tunnels() {
    print_banner
    log_step "Port Forwarding Setup"
    separator
    
    # Ensure server directory exists
    mkdir -p "$SERVER_DIR"
    
    # Check if geyser is enabled
    [ -f "$SERVER_DIR/plugins/Geyser-Spigot.jar" ] && ENABLE_GEYSER=true
    
    echo -e "${CYAN}Scripts will be created in:${NC} $SERVER_DIR"
    echo ""
    
    select_port_forwarding
    
    echo ""
    if [ "$ENABLE_NGROK" = true ] || [ "$ENABLE_PLAYIT" = true ]; then
        echo -e "${GREEN}Scripts created:${NC}"
        [ -f "$SERVER_DIR/start-ngrok.sh" ] && echo -e "  - ${GREEN}$SERVER_DIR/start-ngrok.sh${NC}"
        [ -f "$SERVER_DIR/start-playit.sh" ] && echo -e "  - ${GREEN}$SERVER_DIR/start-playit.sh${NC}"
        echo ""
    fi
}

show_status() {
    print_banner
    
    local java_ver=$(check_java)
    
    echo -e "${CYAN}System Status:${NC}"
    separator
    
    if [ "$java_ver" = "none" ]; then
        echo -e "  Java:     ${RED}Not installed${NC}"
    else
        echo -e "  Java:     ${GREEN}Version $java_ver${NC}"
    fi
    
    if [ -d "$SERVER_DIR" ]; then
        echo -e "  Server:   ${GREEN}Installed${NC}"
        echo -e "  Location: ${GREEN}$SERVER_DIR${NC}"
        
        [ -f "$SERVER_DIR/plugins/Geyser-Spigot.jar" ] && echo -e "  Geyser:   ${GREEN}Installed${NC}" || echo -e "  Geyser:   ${YELLOW}Not installed${NC}"
        [ -f "$SERVER_DIR/plugins/floodgate-spigot.jar" ] && echo -e "  Floodgate:${GREEN}Installed${NC}" || echo -e "  Floodgate:${YELLOW}Not installed${NC}"
    else
        echo -e "  Server:   ${RED}Not installed${NC}"
    fi
    
    command -v ngrok &>/dev/null && echo -e "  ngrok:    ${GREEN}Installed${NC}" || echo -e "  ngrok:    ${YELLOW}Not installed${NC}"
    command -v playit &>/dev/null && echo -e "  playit:   ${GREEN}Installed${NC}" || echo -e "  playit:   ${YELLOW}Not installed${NC}"
    
    echo ""
}

# ─────────────────────────────────────────────────────────────────────
# Main Menu
# ─────────────────────────────────────────────────────────────────────

main_menu() {
    print_banner
    show_status
    
    echo -e "${CYAN}Options:${NC}"
    separator
    echo -e "  ${GREEN}1${NC}) Quick Setup (Paper, latest, defaults)"
    echo -e "  ${GREEN}2${NC}) Custom Setup (choose everything)"
    echo -e "  ${GREEN}3${NC}) Add Geyser + Floodgate"
    echo -e "  ${GREEN}4${NC}) Setup Port Forwarding"
    echo -e "  ${GREEN}5${NC}) Install/Change Java"
    echo -e "  ${GREEN}6${NC}) Update Server"
    echo -e "  ${GREEN}7${NC}) Start Server"
    echo -e "  ${GREEN}8${NC}) Uninstall"
    echo -e "  ${GREEN}0${NC}) Exit"
    echo ""
    read -p "Select: " choice
    
    case $choice in
        1) check_environment; install_dependencies; quick_setup ;;
        2) check_environment; install_dependencies; custom_setup ;;
        3) check_environment; add_geyser ;;
        4) check_environment; install_dependencies; setup_tunnels ;;
        5) check_environment; apt update -y; select_java; main_menu ;;
        6) check_environment; update_server ;;
        7)
            if [ -f "$SERVER_DIR/start.sh" ]; then
                cd "$SERVER_DIR" && ./start.sh
            else
                log_error "Server not installed!"
                sleep 2
                main_menu
            fi
            ;;
        8)
            echo ""
            read -p "Delete ALL server data? (type 'yes'): " confirm
            [ "$confirm" = "yes" ] && { rm -rf "$SERVER_DIR"; log_success "Uninstalled"; } || log_info "Cancelled"
            sleep 2
            main_menu
            ;;
        0) echo "Goodbye!"; exit 0 ;;
        *) main_menu ;;
    esac
}

# ─────────────────────────────────────────────────────────────────────
# Command Line Interface
# ─────────────────────────────────────────────────────────────────────

show_help() {
    echo "Minecraft Server Setup for Termux"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  --quick, -q        Quick setup (Paper, latest)"
    echo "  --purpur, -p       Quick setup with Purpur"
    echo "  --geyser, -g       Add Geyser + Floodgate"
    echo "  --ngrok            Setup ngrok tunneling"
    echo "  --playit           Setup playit.gg tunneling"
    echo "  --java [17|21]     Install Java version"
    echo "  --start, -s        Start server"
    echo "  --background, -b   Start in background"
    echo "  --status           Show status"
    echo "  --help, -h         Show this help"
    echo ""
    echo "Run without arguments for interactive menu"
}

quick_purpur() {
    print_banner
    log_step "Quick Setup - Purpur"
    separator
    
    check_internet
    ensure_java
    
    SERVER_TYPE="purpur"
    GAMEMODE="survival"
    DIFFICULTY="normal"
    
    log_info "Fetching latest Purpur version..."
    local versions=$(get_purpur_versions)
    SELECTED_VERSION=$(echo "$versions" | tail -1)
    [ -z "$SELECTED_VERSION" ] && { log_error "Failed to get version"; exit 1; }
    
    local build=$(get_purpur_build "$SELECTED_VERSION")
    [ -z "$build" ] || [ "$build" = "null" ] && { log_error "Failed to get build"; exit 1; }
    
    setup_server_files
    download_purpur "$SELECTED_VERSION" "$build"
    create_start_script
    optimize_mobile
    
    show_completion
    
    echo -e "${CYAN}Starting server...${NC}"
    echo ""
    ./start.sh
}

# ─────────────────────────────────────────────────────────────────────
# Entry Point
# ─────────────────────────────────────────────────────────────────────

case "$1" in
    --quick|-q)
        check_environment
        install_dependencies
        quick_setup
        ;;
    --purpur|-p)
        check_environment
        install_dependencies
        quick_purpur
        ;;
    --geyser|-g)
        check_environment
        add_geyser
        ;;
    --ngrok)
        check_environment
        install_dependencies
        [ -f "$SERVER_DIR/plugins/Geyser-Spigot.jar" ] && ENABLE_GEYSER=true
        setup_ngrok
        ;;
    --playit)
        check_environment
        install_dependencies
        [ -f "$SERVER_DIR/plugins/Geyser-Spigot.jar" ] && ENABLE_GEYSER=true
        setup_playit
        ;;
    --java)
        check_environment
        apt update -y &>/dev/null
        [ -n "$2" ] && install_java "$2" || select_java
        ;;
    --start|-s)
        [ -f "$SERVER_DIR/start.sh" ] && { cd "$SERVER_DIR"; ./start.sh; } || log_error "Server not installed!"
        ;;
    --background|-b)
        [ -f "$SERVER_DIR/start-background.sh" ] && { cd "$SERVER_DIR"; ./start-background.sh; } || log_error "Server not installed!"
        ;;
    --status)
        show_status
        ;;
    --help|-h)
        show_help
        ;;
    "")
        main_menu
        ;;
    *)
        log_error "Unknown: $1"
        show_help
        exit 1
        ;;
esac
