#!/bin/bash

# ============================================
# Minecraft Server Setup (Paper/Purpur)
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

# Config - Use current directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVER_DIR="$SCRIPT_DIR/minecraft-server"

# APIs
PAPER_API="https://api.papermc.io/v2"
PURPUR_API="https://api.purpurmc.org/v2/purpur"

# Defaults
SERVER_TYPE="paper"
SELECTED_VERSION=""
RAM_SETTING="auto"
GAMEMODE="survival"
DIFFICULTY="normal"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   Minecraft Server Setup (Paper/Purpur)    ║"
    echo "║   Ubuntu proot on Termux (aarch64)         ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_environment() {
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


# ============================================
# Paper API Functions
# ============================================

get_paper_versions() {
    local versions=$(curl -sL "$PAPER_API/projects/paper" | jq -r '.versions[]' 2>/dev/null)
    if [ -z "$versions" ]; then
        log_error "Failed to fetch Paper versions"
        return 1
    fi
    echo "$versions" | tail -10
}

get_paper_latest_build() {
    local version=$1
    local build=$(curl -sL "$PAPER_API/projects/paper/versions/$version/builds" | jq -r '.builds[-1].build' 2>/dev/null)
    if [ -z "$build" ] || [ "$build" = "null" ]; then
        log_error "Failed to get build for Paper $version"
        return 1
    fi
    echo "$build"
}

download_paper() {
    local version=$1
    local build=$2
    local filename="paper-$version-$build.jar"
    local url="$PAPER_API/projects/paper/versions/$version/builds/$build/downloads/$filename"
    
    log_info "Downloading Paper $version (build $build)..."
    log_info "URL: $url"
    
    if ! wget -q --show-progress -O "$SERVER_DIR/server.jar" "$url"; then
        log_error "Download failed!"
        return 1
    fi
    log_success "Paper server downloaded!"
}

# ============================================
# Purpur API Functions
# ============================================

get_purpur_versions() {
    local versions=$(curl -sL "$PURPUR_API" | jq -r '.versions[]' 2>/dev/null)
    if [ -z "$versions" ]; then
        log_error "Failed to fetch Purpur versions"
        return 1
    fi
    echo "$versions" | tail -10
}

get_purpur_latest_build() {
    local version=$1
    local build=$(curl -sL "$PURPUR_API/$version" | jq -r '.builds.latest' 2>/dev/null)
    if [ -z "$build" ] || [ "$build" = "null" ]; then
        log_error "Failed to get build for Purpur $version"
        return 1
    fi
    echo "$build"
}

download_purpur() {
    local version=$1
    local build=$2
    local url="$PURPUR_API/$version/$build/download"
    
    log_info "Downloading Purpur $version (build $build)..."
    log_info "URL: $url"
    
    if ! wget -q --show-progress -O "$SERVER_DIR/server.jar" "$url"; then
        log_error "Download failed!"
        return 1
    fi
    log_success "Purpur server downloaded!"
}

# ============================================
# Generic Functions
# ============================================

get_versions() {
    if [ "$SERVER_TYPE" = "purpur" ]; then
        get_purpur_versions
    else
        get_paper_versions
    fi
}

get_latest_build() {
    local version=$1
    if [ "$SERVER_TYPE" = "purpur" ]; then
        get_purpur_latest_build "$version"
    else
        get_paper_latest_build "$version"
    fi
}

download_server() {
    local version=$1
    local build=$2
    if [ "$SERVER_TYPE" = "purpur" ]; then
        download_purpur "$version" "$build"
    else
        download_paper "$version" "$build"
    fi
}


# ============================================
# Server Setup Functions
# ============================================

setup_server() {
    log_info "Creating server directory: $SERVER_DIR"
    mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR"
    
    # Accept EULA
    echo "eula=true" > eula.txt
    log_success "EULA accepted"
    
    # Create server.properties
    cat > server.properties << EOF
server-port=25565
gamemode=$GAMEMODE
difficulty=$DIFFICULTY
max-players=10
view-distance=8
simulation-distance=6
spawn-protection=0
online-mode=false
enable-command-block=true
motd=\u00A7bMobile ${SERVER_TYPE^} Server \u00A77- \u00A7aTermux
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
    -jar server.jar nogui
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
    log_success "Background script created"
}

optimize_for_mobile() {
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

update_ram_setting() {
    if [ "$RAM_SETTING" != "auto" ]; then
        sed -i "s/XMX=.*/XMX=\"$RAM_SETTING\"/" "$SERVER_DIR/start.sh"
    fi
}


# ============================================
# Selection Menus
# ============================================

select_server_type() {
    echo ""
    echo -e "${CYAN}Server Type:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) Paper - Optimized Minecraft server"
    echo -e "  ${GREEN}2${NC}) Purpur - Paper fork with more features"
    echo ""
    read -p "Select server type [default: 1]: " type_choice
    
    case $type_choice in
        2) SERVER_TYPE="purpur" ;;
        *) SERVER_TYPE="paper" ;;
    esac
    log_info "Selected: ${SERVER_TYPE^}"
}

select_version() {
    echo ""
    echo -e "${CYAN}Fetching ${SERVER_TYPE^} versions...${NC}"
    
    local versions_list=$(get_versions)
    if [ -z "$versions_list" ]; then
        log_error "Could not fetch versions"
        exit 1
    fi
    
    # Convert to array
    readarray -t versions <<< "$versions_list"
    
    echo ""
    echo -e "${CYAN}Available Minecraft Versions:${NC}"
    echo "─────────────────────────────"
    
    local count=${#versions[@]}
    for i in "${!versions[@]}"; do
        local num=$((count - i))
        echo -e "  ${GREEN}${num}${NC}) ${versions[$i]}"
    done
    
    echo ""
    read -p "Select version (1-$count) [default: 1 = ${versions[-1]}]: " choice
    
    if [ -z "$choice" ] || [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
        choice=1
    fi
    
    # Get version (1 = latest)
    local idx=$((count - choice))
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


# ============================================
# Setup Flows
# ============================================

show_info_and_start() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Setup Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}Server Type:${NC} ${SERVER_TYPE^}"
    echo -e "${CYAN}Version:${NC} $SELECTED_VERSION"
    echo -e "${CYAN}Location:${NC} $SERVER_DIR"
    echo -e "${CYAN}Gamemode:${NC} $GAMEMODE"
    echo -e "${CYAN}Difficulty:${NC} $DIFFICULTY"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  Start:       ${GREEN}cd $SERVER_DIR && ./start.sh${NC}"
    echo -e "  Background:  ${GREEN}cd $SERVER_DIR && ./run-background.sh${NC}"
    echo -e "  Attach:      ${GREEN}screen -r minecraft${NC}"
    echo ""
    echo -e "${YELLOW}Connect:${NC} localhost:25565"
    echo ""
    echo -e "${CYAN}Starting server now...${NC}"
    echo ""
    
    cd "$SERVER_DIR"
    ./start.sh
}

quick_setup() {
    log_info "Quick setup with defaults..."
    
    # Default to Paper
    SERVER_TYPE="paper"
    
    # Get latest version
    log_info "Fetching latest ${SERVER_TYPE^} version..."
    local versions=$(get_versions)
    SELECTED_VERSION=$(echo "$versions" | tail -1)
    
    if [ -z "$SELECTED_VERSION" ]; then
        log_error "Failed to get version"
        exit 1
    fi
    log_info "Using version: $SELECTED_VERSION"
    
    # Get latest build
    log_info "Getting latest build..."
    local build=$(get_latest_build "$SELECTED_VERSION")
    
    if [ -z "$build" ] || [ "$build" = "null" ]; then
        log_error "Failed to get build number"
        exit 1
    fi
    log_info "Build: $build"
    
    # Setup
    setup_server
    download_server "$SELECTED_VERSION" "$build"
    create_start_script
    create_screen_script
    optimize_for_mobile
    
    show_info_and_start
}

custom_setup() {
    select_server_type
    select_version
    select_ram
    select_gamemode
    select_difficulty
    
    # Get build
    log_info "Getting latest build for $SELECTED_VERSION..."
    local build=$(get_latest_build "$SELECTED_VERSION")
    
    if [ -z "$build" ] || [ "$build" = "null" ]; then
        log_error "Failed to get build number for $SELECTED_VERSION"
        exit 1
    fi
    log_info "Build: $build"
    
    # Setup
    setup_server
    download_server "$SELECTED_VERSION" "$build"
    create_start_script
    create_screen_script
    optimize_for_mobile
    update_ram_setting
    
    show_info_and_start
}

update_server() {
    if [ ! -d "$SERVER_DIR" ]; then
        log_error "No server found at $SERVER_DIR"
        exit 1
    fi
    
    select_server_type
    select_version
    
    local build=$(get_latest_build "$SELECTED_VERSION")
    if [ -z "$build" ] || [ "$build" = "null" ]; then
        log_error "Failed to get build"
        exit 1
    fi
    
    # Backup old jar
    if [ -f "$SERVER_DIR/server.jar" ]; then
        mv "$SERVER_DIR/server.jar" "$SERVER_DIR/server.jar.backup"
    fi
    
    download_server "$SELECTED_VERSION" "$build"
    log_success "Server updated to ${SERVER_TYPE^} $SELECTED_VERSION (build $build)"
}


# ============================================
# Main Menu
# ============================================

main_menu() {
    print_banner
    
    echo -e "${CYAN}Server will be installed in:${NC} $SERVER_DIR"
    echo ""
    echo -e "${CYAN}Setup Options:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) Quick Setup (Paper, latest, defaults)"
    echo -e "  ${GREEN}2${NC}) Custom Setup (choose everything)"
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
            update_server
            ;;
        4)
            read -p "Delete all server data? (yes/no): " confirm
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

# ============================================
# Command Line Arguments
# ============================================

show_help() {
    echo "Minecraft Server Setup (Paper/Purpur)"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  --quick, -q       Quick setup (Paper, latest version)"
    echo "  --purpur, -p      Quick setup with Purpur"
    echo "  --start, -s       Start existing server"
    echo "  --background, -b  Start in background"
    echo "  --help, -h        Show this help"
    echo ""
    echo "Run without arguments for interactive menu"
}

quick_purpur_setup() {
    log_info "Quick Purpur setup..."
    SERVER_TYPE="purpur"
    
    log_info "Fetching latest Purpur version..."
    local versions=$(get_purpur_versions)
    SELECTED_VERSION=$(echo "$versions" | tail -1)
    
    if [ -z "$SELECTED_VERSION" ]; then
        log_error "Failed to get version"
        exit 1
    fi
    log_info "Using version: $SELECTED_VERSION"
    
    local build=$(get_purpur_latest_build "$SELECTED_VERSION")
    if [ -z "$build" ] || [ "$build" = "null" ]; then
        log_error "Failed to get build"
        exit 1
    fi
    log_info "Build: $build"
    
    setup_server
    download_purpur "$SELECTED_VERSION" "$build"
    create_start_script
    create_screen_script
    optimize_for_mobile
    
    show_info_and_start
}

case "$1" in
    --quick|-q)
        check_environment
        install_dependencies
        quick_setup
        ;;
    --purpur|-p)
        check_environment
        install_dependencies
        quick_purpur_setup
        ;;
    --start|-s)
        if [ -f "$SERVER_DIR/start.sh" ]; then
            cd "$SERVER_DIR" && ./start.sh
        else
            log_error "Server not found. Run setup first."
        fi
        ;;
    --background|-b)
        if [ -f "$SERVER_DIR/run-background.sh" ]; then
            cd "$SERVER_DIR" && ./run-background.sh
        else
            log_error "Server not found. Run setup first."
        fi
        ;;
    --help|-h)
        show_help
        ;;
    "")
        main_menu
        ;;
    *)
        log_error "Unknown option: $1"
        show_help
        exit 1
        ;;
esac
