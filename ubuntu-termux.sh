#!/data/data/com.termux/files/usr/bin/bash

# ============================================
# Ubuntu Installation Script for Termux
# Installs full Ubuntu environment via proot
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
UBUNTU_DIR="$HOME/ubuntu-fs"
UBUNTU_VERSION="22.04"

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════╗"
    echo "║   Ubuntu Installer for Termux              ║"
    echo "║   Full Linux Environment (proot)           ║"
    echo "╚════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

check_termux() {
    if [ ! -d "/data/data/com.termux" ]; then
        log_error "This script is designed for Termux on Android"
        exit 1
    fi
}

detect_arch() {
    ARCH=$(uname -m)
    case $ARCH in
        aarch64) UBUNTU_ARCH="arm64" ;;
        armv7l|armv8l) UBUNTU_ARCH="armhf" ;;
        x86_64) UBUNTU_ARCH="amd64" ;;
        i*86) UBUNTU_ARCH="i386" ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    log_info "Detected architecture: $ARCH ($UBUNTU_ARCH)"
}

install_dependencies() {
    log_info "Installing required packages..."
    pkg update -y
    pkg install -y proot proot-distro wget curl tar
    log_success "Dependencies installed!"
}


install_ubuntu_proot_distro() {
    log_info "Installing Ubuntu using proot-distro..."
    
    # Check if already installed
    if proot-distro list | grep -q "ubuntu"; then
        log_warn "Ubuntu already installed via proot-distro"
        read -p "Reinstall? (y/n): " reinstall
        if [ "$reinstall" = "y" ]; then
            proot-distro remove ubuntu
            proot-distro install ubuntu
        fi
    else
        proot-distro install ubuntu
    fi
    
    log_success "Ubuntu installed!"
}

install_ubuntu_manual() {
    log_info "Installing Ubuntu manually..."
    
    mkdir -p "$UBUNTU_DIR"
    cd "$UBUNTU_DIR"
    
    # Download Ubuntu rootfs
    local rootfs_url="https://cdimage.ubuntu.com/ubuntu-base/releases/${UBUNTU_VERSION}/release/ubuntu-base-${UBUNTU_VERSION}-base-${UBUNTU_ARCH}.tar.gz"
    
    if [ ! -f "ubuntu-rootfs.tar.gz" ]; then
        log_info "Downloading Ubuntu ${UBUNTU_VERSION} rootfs..."
        wget -q --show-progress -O ubuntu-rootfs.tar.gz "$rootfs_url"
    fi
    
    log_info "Extracting rootfs..."
    proot --link2symlink tar -xzf ubuntu-rootfs.tar.gz --exclude='dev' 2>/dev/null || \
    tar -xzf ubuntu-rootfs.tar.gz --exclude='dev'
    
    rm -f ubuntu-rootfs.tar.gz
    
    # Setup DNS
    echo "nameserver 8.8.8.8" > "$UBUNTU_DIR/etc/resolv.conf"
    echo "nameserver 8.8.4.4" >> "$UBUNTU_DIR/etc/resolv.conf"
    
    log_success "Ubuntu rootfs extracted!"
}

create_launch_script() {
    log_info "Creating launch script..."
    
    cat > "$HOME/ubuntu" << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash

UBUNTU_DIR="$HOME/ubuntu-fs"

# Kill any existing proot sessions
unset LD_PRELOAD

# Launch Ubuntu
proot \
    --link2symlink \
    -0 \
    -r "$UBUNTU_DIR" \
    -b /dev \
    -b /proc \
    -b /sys \
    -b "$UBUNTU_DIR/root:/dev/shm" \
    -b /data/data/com.termux/files/home:/home/termux \
    -b /sdcard:/sdcard \
    -w /root \
    /usr/bin/env -i \
    HOME=/root \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    TERM=$TERM \
    LANG=C.UTF-8 \
    /bin/bash --login
EOF
    
    chmod +x "$HOME/ubuntu"
    log_success "Launch script created: ~/ubuntu"
}

create_proot_distro_alias() {
    cat >> "$HOME/.bashrc" << 'EOF'

# Ubuntu aliases
alias ubuntu='proot-distro login ubuntu'
alias ubuntu-root='proot-distro login ubuntu --user root'
EOF
    
    log_success "Aliases added to .bashrc"
}

setup_ubuntu_first_run() {
    log_info "Setting up Ubuntu environment..."
    
    # Create first-run setup script
    cat > "$UBUNTU_DIR/root/setup.sh" << 'SETUP'
#!/bin/bash
apt update && apt upgrade -y
apt install -y sudo nano vim curl wget git htop neofetch
echo "Ubuntu setup complete!"
SETUP
    
    chmod +x "$UBUNTU_DIR/root/setup.sh"
}

setup_ubuntu_proot_distro_first_run() {
    log_info "Running first-time Ubuntu setup..."
    
    proot-distro login ubuntu -- bash -c "
        apt update && apt upgrade -y
        apt install -y sudo nano vim curl wget git htop neofetch
        echo 'Setup complete!'
    "
}


install_gui_support() {
    log_info "Installing GUI support (VNC)..."
    
    proot-distro login ubuntu -- bash -c "
        apt update
        apt install -y tigervnc-standalone-server dbus-x11 xfce4 xfce4-terminal
        
        # Setup VNC
        mkdir -p ~/.vnc
        echo '#!/bin/bash
export XDG_RUNTIME_DIR=/tmp/runtime-root
xrdb \$HOME/.Xresources
startxfce4 &' > ~/.vnc/xstartup
        chmod +x ~/.vnc/xstartup
    "
    
    # Install VNC viewer in Termux
    pkg install -y x11-repo
    pkg install -y tigervnc
    
    log_success "GUI support installed!"
    echo ""
    echo -e "${YELLOW}To start GUI:${NC}"
    echo "1. Enter Ubuntu: proot-distro login ubuntu"
    echo "2. Start VNC: vncserver :1"
    echo "3. Connect with VNC viewer to localhost:5901"
}

select_version() {
    echo ""
    echo -e "${CYAN}Ubuntu Version:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) Ubuntu 22.04 LTS (Jammy) - Recommended"
    echo -e "  ${GREEN}2${NC}) Ubuntu 20.04 LTS (Focal)"
    echo -e "  ${GREEN}3${NC}) Ubuntu 24.04 LTS (Noble)"
    echo ""
    read -p "Select version [default: 1]: " ver_choice
    
    case $ver_choice in
        2) UBUNTU_VERSION="20.04" ;;
        3) UBUNTU_VERSION="24.04" ;;
        *) UBUNTU_VERSION="22.04" ;;
    esac
}

select_install_method() {
    echo ""
    echo -e "${CYAN}Installation Method:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) proot-distro (Recommended - easier)"
    echo -e "  ${GREEN}2${NC}) Manual install (more control)"
    echo ""
    read -p "Select method [default: 1]: " method_choice
    
    case $method_choice in
        2) INSTALL_METHOD="manual" ;;
        *) INSTALL_METHOD="proot-distro" ;;
    esac
}

show_final_info() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo -e "${GREEN}   Ubuntu Installation Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════${NC}"
    echo ""
    
    if [ "$INSTALL_METHOD" = "proot-distro" ]; then
        echo -e "${YELLOW}Commands:${NC}"
        echo -e "  Start Ubuntu:     ${GREEN}proot-distro login ubuntu${NC}"
        echo -e "  Or use alias:     ${GREEN}ubuntu${NC}"
        echo -e "  As root:          ${GREEN}ubuntu-root${NC}"
    else
        echo -e "${YELLOW}Commands:${NC}"
        echo -e "  Start Ubuntu:     ${GREEN}~/ubuntu${NC}"
        echo -e "  First run setup:  ${GREEN}/root/setup.sh${NC} (inside Ubuntu)"
    fi
    
    echo ""
    echo -e "${YELLOW}Tips:${NC}"
    echo -e "  Exit Ubuntu:      ${GREEN}exit${NC}"
    echo -e "  Access Termux:    ${GREEN}/home/termux${NC} (inside Ubuntu)"
    echo -e "  Access SD card:   ${GREEN}/sdcard${NC} (inside Ubuntu)"
    echo ""
}

main_menu() {
    print_banner
    detect_arch
    
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo "─────────────────────────────"
    echo -e "  ${GREEN}1${NC}) Install Ubuntu"
    echo -e "  ${GREEN}2${NC}) Install Ubuntu + GUI (XFCE)"
    echo -e "  ${GREEN}3${NC}) Remove Ubuntu"
    echo -e "  ${GREEN}4${NC}) Exit"
    echo ""
    read -p "Select option: " main_choice
    
    case $main_choice in
        1)
            check_termux
            install_dependencies
            select_install_method
            
            if [ "$INSTALL_METHOD" = "proot-distro" ]; then
                install_ubuntu_proot_distro
                create_proot_distro_alias
                setup_ubuntu_proot_distro_first_run
            else
                select_version
                install_ubuntu_manual
                create_launch_script
                setup_ubuntu_first_run
            fi
            
            show_final_info
            ;;
        2)
            check_termux
            install_dependencies
            install_ubuntu_proot_distro
            create_proot_distro_alias
            setup_ubuntu_proot_distro_first_run
            install_gui_support
            show_final_info
            ;;
        3)
            echo ""
            read -p "Remove Ubuntu? This deletes all data! (yes/no): " confirm
            if [ "$confirm" = "yes" ]; then
                proot-distro remove ubuntu 2>/dev/null || true
                rm -rf "$UBUNTU_DIR" 2>/dev/null || true
                rm -f "$HOME/ubuntu" 2>/dev/null || true
                log_success "Ubuntu removed"
            fi
            ;;
        4)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            log_error "Invalid option"
            main_menu
            ;;
    esac
}

# Handle arguments
case "$1" in
    --quick|-q)
        check_termux
        install_dependencies
        install_ubuntu_proot_distro
        create_proot_distro_alias
        setup_ubuntu_proot_distro_first_run
        show_final_info
        ;;
    --gui|-g)
        check_termux
        install_dependencies
        install_ubuntu_proot_distro
        create_proot_distro_alias
        setup_ubuntu_proot_distro_first_run
        install_gui_support
        show_final_info
        ;;
    --help|-h)
        echo "Ubuntu Installer for Termux"
        echo ""
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  --quick, -q   Quick install with defaults"
        echo "  --gui, -g     Install with GUI support"
        echo "  --help, -h    Show this help"
        echo ""
        echo "Run without arguments for interactive menu"
        ;;
    *)
        main_menu
        ;;
esac
