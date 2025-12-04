#!/bin/bash

# ============================================
# Minecraft Paper Server Setup
# For Ubuntu proot on Termux (aarch64)
# One-command automatic setup
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config
SERVER_DIR="$HOME/minecraft-server"
PAPER_API="https://api.papermc.io/v2"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   Minecraft Paper Server                   ║"
    echo "║   Ubuntu proot on Termux (aarch64)         ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_environment() {
    # Check if running in Linux environment (Ubuntu proot or native)
    if [ ! -f "/etc/os-release" ]; then
        log_error "This script should run inside Ubuntu proot"
        log_info "First run: proot-distro login ubuntu"
        exit 1
    fi
}

install_dependencies() {
    log_info "Updating packages..."
    apt update -y && apt upgrade -y
    
    log_info "Installing required packages..."
    apt install -y openjdk-17-jre-headless wget curl jq screen
    
    log_success "Dependencies installed!"
}

get_paper_versions() {
    log_info "Fetching available Minecraft versions..."
    curl -s "$PAPER_API/projects/paper" | jq -r '.versions[]' | tail -10
}

get_latest_build() {
    local version=$1
    curl -s "$PAPER_API/projects/paper/versions/$version" | jq -r '.builds[-1]'
}

download_paper() {
    local version=$1
    local build=$2
    local filename="paper-$version-$build.jar"
    local url="$PAPER_API/projects/paper/versions/$version/builds/$build/downloads/$filename"
    
    log_info "Downloading Paper $version (build $build)..."
    wget -q --show-progress -O "$SERVER_DIR/paper.jar" "$url"
    log_success "Paper server downloaded!"
}


setup_server() {
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR"
    
    # Accept EULA
    echo "eula=true" > eula.txt
    log_success "EULA accepted"
    
    # Create server.properties
    cat > server.properties << 'EOF'
server-port=25565
gamemode=survival
difficulty=normal
max-players=10
view-distance=8
simulation-distance=6
spawn-protection=0
online-mode=false
enable-command-block=true
motd=\u00A7bMobile Paper Server \u00A77- \u00A7aTermux
EOF
    log_success "Server properties configured"
}

create_start_script() {
    cat > "$SERVER_DIR/start.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

# Memory settings based on device
TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2}')
if [ $TOTAL_MEM -gt 4000 ]; then
    XMX="2G"
    XMS="1G"
elif [ $TOTAL_MEM -gt 2000 ]; then
    XMX="1G"
    XMS="512M"
else
    XMX="512M"
    XMS="256M"
fi

echo "Starting server with ${XMX} max memory..."
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
    -XX:G1RSetUpdatingPauseTimePercent=5 \
    -XX:SurvivorRatio=32 \
    -XX:+PerfDisableSharedMem \
    -XX:MaxTenuringThreshold=1 \
    -Dusing.aikars.flags=https://mcflags.emc.gs \
    -Daikars.new.flags=true \
    -jar paper.jar nogui
EOF
    chmod +x "$SERVER_DIR/start.sh"
    log_success "Start script created"
}

create_screen_script() {
    cat > "$SERVER_DIR/run-background.sh" << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
screen -dmS minecraft ./start.sh
echo "Server started in background!"
echo "Use 'screen -r minecraft' to attach"
echo "Press Ctrl+A then D to detach"
EOF
    chmod +x "$SERVER_DIR/run-background.sh"
}

optimize_for_mobile() {
    mkdir -p "$SERVER_DIR/config"
    
    # Paper global config for mobile optimization
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


select_version() {
    echo ""
    echo -e "${CYAN}Available Minecraft Versions:${NC}"
    echo "─────────────────────────────"
    
    versions=($(get_paper_versions))
    
    for i in "${!versions[@]}"; do
        echo -e "  ${GREEN}$((i+1))${NC}) ${versions[$i]}"
    done
    
    echo ""
    read -p "Select version (1-${#versions[@]}) [default: 1 - ${versions[-1]}]: " choice
    
    if [ -z "$choice" ]; then
        choice=1
    fi
    
    # Reverse index since we want latest first
    idx=$((${#versions[@]} - choice))
    SELECTED_VERSION="${versions[$idx]}"
    
    log_info "Selected version: $SELECTED_VERSION"
}

select_ram() {
    echo ""
    echo -e "${CYAN}RAM Allocation:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) Auto-detect (recommended)"
    echo -e "  ${GREEN}2${NC}) 512MB (low-end device)"
    echo -e "  ${GREEN}3${NC}) 1GB (mid-range device)"
    echo -e "  ${GREEN}4${NC}) 2GB (high-end device)"
    echo ""
    read -p "Select option [default: 1]: " ram_choice
    
    case $ram_choice in
        2) RAM_SETTING="512M" ;;
        3) RAM_SETTING="1G" ;;
        4) RAM_SETTING="2G" ;;
        *) RAM_SETTING="auto" ;;
    esac
}

select_gamemode() {
    echo ""
    echo -e "${CYAN}Default Gamemode:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) Survival"
    echo -e "  ${GREEN}2${NC}) Creative"
    echo -e "  ${GREEN}3${NC}) Adventure"
    echo -e "  ${GREEN}4${NC}) Spectator"
    echo ""
    read -p "Select gamemode [default: 1]: " gm_choice
    
    case $gm_choice in
        2) GAMEMODE="creative" ;;
        3) GAMEMODE="adventure" ;;
        4) GAMEMODE="spectator" ;;
        *) GAMEMODE="survival" ;;
    esac
}

select_difficulty() {
    echo ""
    echo -e "${CYAN}Difficulty:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) Peaceful"
    echo -e "  ${GREEN}2${NC}) Easy"
    echo -e "  ${GREEN}3${NC}) Normal"
    echo -e "  ${GREEN}4${NC}) Hard"
    echo ""
    read -p "Select difficulty [default: 3]: " diff_choice
    
    case $diff_choice in
        1) DIFFICULTY="peaceful" ;;
        2) DIFFICULTY="easy" ;;
        4) DIFFICULTY="hard" ;;
        *) DIFFICULTY="normal" ;;
    esac
}

update_server_properties() {
    sed -i "s/gamemode=.*/gamemode=$GAMEMODE/" "$SERVER_DIR/server.properties"
    sed -i "s/difficulty=.*/difficulty=$DIFFICULTY/" "$SERVER_DIR/server.properties"
    
    if [ "$RAM_SETTING" != "auto" ]; then
        sed -i "s/XMX=.*/XMX=\"$RAM_SETTING\"/" "$SERVER_DIR/start.sh"
        sed -i "s/XMS=.*/XMS=\"${RAM_SETTING%G}00M\"/" "$SERVER_DIR/start.sh" 2>/dev/null || true
    fi
}

show_final_info() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Setup Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Server Location:${NC} $SERVER_DIR"
    echo -e "${CYAN}Minecraft Version:${NC} $SELECTED_VERSION"
    echo -e "${CYAN}Gamemode:${NC} $GAMEMODE"
    echo -e "${CYAN}Difficulty:${NC} $DIFFICULTY"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  Start server:      ${GREEN}cd $SERVER_DIR && ./start.sh${NC}"
    echo -e "  Background mode:   ${GREEN}cd $SERVER_DIR && ./run-background.sh${NC}"
    echo -e "  Attach to server:  ${GREEN}screen -r minecraft${NC}"
    echo -e "  Detach:            ${GREEN}Ctrl+A then D${NC}"
    echo ""
    echo -e "${YELLOW}Connect from Minecraft:${NC}"
    echo -e "  Address: ${GREEN}localhost${NC} or your device IP"
    echo -e "  Port: ${GREEN}25565${NC}"
    echo ""
    
    read -p "Start server now? (y/n) [default: y]: " start_now
    if [ "$start_now" != "n" ] && [ "$start_now" != "N" ]; then
        cd "$SERVER_DIR"
        ./start.sh
    fi
}


quick_setup() {
    log_info "Quick setup - using recommended defaults..."
    SELECTED_VERSION=$(get_paper_versions | tail -1)
    RAM_SETTING="auto"
    GAMEMODE="survival"
    DIFFICULTY="normal"
    
    local build=$(get_latest_build "$SELECTED_VERSION")
    
    setup_server
    download_paper "$SELECTED_VERSION" "$build"
    create_start_script
    create_screen_script
    optimize_for_mobile
    
    show_final_info
}

custom_setup() {
    select_version
    select_ram
    select_gamemode
    select_difficulty
    
    local build=$(get_latest_build "$SELECTED_VERSION")
    
    setup_server
    download_paper "$SELECTED_VERSION" "$build"
    create_start_script
    create_screen_script
    optimize_for_mobile
    update_server_properties
    
    show_final_info
}

main_menu() {
    print_banner
    
    echo -e "${CYAN}Setup Options:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) Quick Setup (recommended defaults)"
    echo -e "  ${GREEN}2${NC}) Custom Setup (choose options)"
    echo -e "  ${GREEN}3${NC}) Update existing server"
    echo -e "  ${GREEN}4${NC}) Uninstall"
    echo -e "  ${GREEN}5${NC}) Exit"
    echo ""
    read -p "Select option: " main_choice
    
    case $main_choice in
        1)
            check_environment
            install_dependencies
            quick_setup
            ;;
        2)
            check_environment
            install_dependencies
            custom_setup
            ;;
        3)
            if [ -d "$SERVER_DIR" ]; then
                select_version
                local build=$(get_latest_build "$SELECTED_VERSION")
                download_paper "$SELECTED_VERSION" "$build"
                log_success "Server updated to $SELECTED_VERSION!"
            else
                log_error "No existing server found. Run setup first."
            fi
            ;;
        4)
            read -p "Are you sure? This will delete all server data! (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                rm -rf "$SERVER_DIR"
                log_success "Server uninstalled"
            fi
            ;;
        5)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            log_error "Invalid option"
            main_menu
            ;;
    esac
}

# Handle command line arguments
case "$1" in
    --quick|-q)
        check_environment
        install_dependencies
        quick_setup
        ;;
    --start|-s)
        if [ -f "$SERVER_DIR/start.sh" ]; then
            cd "$SERVER_DIR" && ./start.sh
        else
            log_error "Server not installed. Run setup first."
        fi
        ;;
    --background|-b)
        if [ -f "$SERVER_DIR/run-background.sh" ]; then
            cd "$SERVER_DIR" && ./run-background.sh
        else
            log_error "Server not installed. Run setup first."
        fi
        ;;
    --help|-h)
        echo "Minecraft Paper Server Setup for Termux"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  --quick, -q      Quick setup with defaults"
        echo "  --start, -s      Start the server"
        echo "  --background, -b Start server in background"
        echo "  --help, -h       Show this help"
        echo ""
        echo "Run without arguments for interactive menu"
        ;;
    *)
        main_menu
        ;;
esac
