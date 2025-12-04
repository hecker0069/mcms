#!/data/data/com.termux/files/usr/bin/bash
# install-mcms.sh
# Installs proot-distro + chosen distro (debian default), ensures noninteractive apt,
# clones mcms repo inside distro and runs mcms.sh

set -euo pipefail

REPO_URL="https://github.com/hecker0069/mcms"
DEFAULT_DISTRO="debian"   # default distro
QUIET=0

echo
echo "=== MCMS Installer ==="
echo

# prompt for distro choice (Debian default)
read -p "Choose distro to install [debian/ubuntu] (default: debian): " DISTRO_CHOICE
DISTRO_CHOICE="${DISTRO_CHOICE:-$DEFAULT_DISTRO}"
DISTRO_CHOICE="$(echo "$DISTRO_CHOICE" | tr '[:upper:]' '[:lower:]')"

if [ "$DISTRO_CHOICE" != "debian" ] && [ "$DISTRO_CHOICE" != "ubuntu" ]; then
  echo "Invalid choice: '$DISTRO_CHOICE'. Falling back to default: $DEFAULT_DISTRO"
  DISTRO_CHOICE="$DEFAULT_DISTRO"
fi

echo "[INSTALLER] Selected distro: $DISTRO_CHOICE"
echo

# ensure running under Termux
if ! command -v pkg >/dev/null 2>&1; then
  echo "[ERROR] This installer is intended for Termux. 'pkg' command not found."
  exit 1
fi

# update termux and install proot-distro + git
echo "[INSTALLER] Updating Termux packages..."
pkg update -y
pkg upgrade -y

echo "[INSTALLER] Installing required packages: proot-distro git"
pkg install proot-distro git -y

# Install chosen distro if not installed
if proot-distro list | grep -iq "^$DISTRO_CHOICE$"; then
  echo "[INSTALLER] $DISTRO_CHOICE already installed. Skipping proot-distro install."
else
  echo "[INSTALLER] Installing $DISTRO_CHOICE via proot-distro (may take several minutes)..."
  proot-distro install "$DISTRO_CHOICE"
fi

# Helper to run commands inside the chosen distro, handling special characters safely
run_in_distro() {
  local CMD="$1"
  proot-distro login "$DISTRO_CHOICE" --shared-tmp -- bash -lc "$CMD"
}

# Prepare non-interactive apt options (keep existing config files by default)
# Change --force-confold -> --force-confnew if you want maintainer's files instead
DEBIAN_FRONTEND=noninteractive
DPKG_OPTS='-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"'
APT_OPTS="-y $DPKG_OPTS"

echo "[INSTALLER] Preparing distro: apt update/upgrade (non-interactive, keep existing config files)..."

# Run inside distro: update, upgrade, install git and try to fix broken dpkg states if any
run_in_distro "
export DEBIAN_FRONTEND=${DEBIAN_FRONTEND};
apt-get update -y || true;
apt-get ${APT_OPTS} upgrade || true;
apt-get ${APT_OPTS} install git || true;
dpkg --configure -a || true;
apt-get -f install -y || true
"

echo "[INSTALLER] Cloning (fresh) MCMS repository inside $DISTRO_CHOICE..."
run_in_distro "
rm -rf mcms;
git clone ${REPO_URL} mcms || { echo 'git clone failed'; exit 1; }
"

echo "[INSTALLER] Running MCMS (mcms.sh) inside $DISTRO_CHOICE..."
# Run mcms.sh. This will be interactive if your mcms.sh expects input.
run_in_distro "
cd mcms;
chmod +x mcms.sh || true;
./mcms.sh
"

echo
echo "=== Done ==="
echo "MCMS was launched inside the $DISTRO_CHOICE distro."
echo "If mcms.sh is interactive, follow prompts inside the distro session."
echo
