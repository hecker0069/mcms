#!/data/data/com.termux/files/usr/bin/bash

# ═══════════════════════════════════════════════════════════════════
# MCMS Installer - Minecraft Mobile Server
# https://github.com/mukulx/MCMS
#
# Install: curl -sL https://raw.githubusercontent.com/mukulx/MCMS/main/install.sh | bash
# ═══════════════════════════════════════════════════════════════════

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

MCMS_RAW="https://raw.githubusercontent.com/hecker0069/MCMS/main/mcms.sh"

clear
echo -e "${CYAN}${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              MCMS - Minecraft Mobile Server               ║"
echo "║                      Installer                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Check if running in Termux
if [ ! -d "/data/data/com.termux" ]; then
    echo -e "${RED}[ERROR]${NC} This installer is for Termux on Android!"
    echo "Download Termux from F-Droid: https://f-droid.org/packages/com.termux/"
    exit 1
fi

echo -e "${CYAN}[1/4]${NC} Installing required packages..."
pkg install -y proot-distro curl 2>/dev/null || {
    # If pkg fails, try updating first
    yes n | pkg update 2>/dev/null || true
    pkg install -y proot-distro curl
}

echo ""

# Check if Ubuntu is already installed
if proot-distro list 2>/dev/null | grep -q "ubuntu"; then
    echo -e "${CYAN}[2/4]${NC} Ubuntu already installed ${GREEN}✓${NC}"
else
    echo -e "${CYAN}[2/4]${NC} Installing Ubuntu proot (this takes a few minutes)..."
    proot-distro install ubuntu
fi

echo ""
echo -e "${CYAN}[3/4]${NC} Downloading MCMS..."

# Download MCMS inside Ubuntu
proot-distro login ubuntu -- bash -c "
    mkdir -p ~/mcms
    cd ~/mcms
    curl -sL '$MCMS_RAW' -o mcms.sh
    chmod +x mcms.sh
"

echo -e "${GREEN}[4/4]${NC} Installation complete!"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  MCMS Installed Successfully!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════${NC}"
echo ""
echo -e "  Location: ${CYAN}~/mcms/mcms.sh${NC} (inside Ubuntu)"
echo ""
echo -e "  ${YELLOW}Starting MCMS now...${NC}"
echo ""

# Run MCMS
proot-distro login ubuntu -- bash -c "cd ~/mcms && ./mcms.sh"
