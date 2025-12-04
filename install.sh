#!/data/data/com.termux/files/usr/bin/bash

# ═══════════════════════════════════════════════════════════════════
# MCMS Installer - Minecraft Mobile Server
# https://github.com/mukulx/MCMS
#
# One-line install: curl -sL https://raw.githubusercontent.com/mukulx/MCMS/main/install.sh | bash
# ═══════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

MCMS_REPO="https://github.com/hecker0069/mcms"
MCMS_RAW="https://raw.githubusercontent.com/hecker0069/MCMS/main/mcms.sh"
MCMS_DIR="$HOME/mcms"

echo -e "${CYAN}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              MCMS - Minecraft Mobile Server               ║"
echo "║                      Installer                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running in Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo -e "${RED}[ERROR]${NC} This installer is for Termux on Android!"
    exit 1
fi

echo -e "${CYAN}[1/4]${NC} Updating Termux packages..."
pkg update -y && pkg upgrade -y

echo -e "${CYAN}[2/4]${NC} Installing proot-distro..."
pkg install -y proot-distro wget curl

# Check if Ubuntu is already installed
if proot-distro list | grep -q "ubuntu"; then
    echo -e "${YELLOW}[INFO]${NC} Ubuntu already installed"
else
    echo -e "${CYAN}[3/4]${NC} Installing Ubuntu (this may take a few minutes)..."
    proot-distro install ubuntu
fi

echo -e "${CYAN}[4/4]${NC} Setting up MCMS..."

# Create MCMS directory and download script inside Ubuntu
proot-distro login ubuntu -- bash -c "
    mkdir -p ~/mcms
    cd ~/mcms
    
    echo 'Downloading MCMS...'
    curl -sL '$MCMS_RAW' -o mcms.sh
    chmod +x mcms.sh
    
    echo ''
    echo -e '\033[0;32m════════════════════════════════════════════════\033[0m'
    echo -e '\033[0;32m  MCMS Installation Complete!\033[0m'
    echo -e '\033[0;32m════════════════════════════════════════════════\033[0m'
    echo ''
    echo 'MCMS is installed at: ~/mcms/mcms.sh'
    echo ''
    echo 'Starting MCMS...'
    echo ''
    
    ./mcms.sh
"

echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  To run MCMS again:${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${CYAN}proot-distro login ubuntu${NC}"
echo -e "  ${CYAN}cd ~/mcms && ./mcms.sh${NC}"
echo ""
