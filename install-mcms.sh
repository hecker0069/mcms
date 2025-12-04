#!/data/data/com.termux/files/usr/bin/bash
set -e

REPO_URL="https://github.com/hecker0069/mcms"
DISTRO_DEFAULT="debian"   # default distro
TERMUX_PKG="proot-distro"
REQ_PKGS="proot-distro git"

echo
echo "=== MCMS Installer ==="
echo

# prompt for distro choice (Debian default)
read -p "Choose distro to install [debian/ubuntu] (default: debian): " DISTRO_CHOICE
DISTRO_CHOICE="${DISTRO_CHOICE:-$DISTRO_DEFAULT}"
DISTRO_CHOICE="$(echo "$DISTRO_CHOICE" | tr '[:upper:]' '[:lower:]')"

if [ "$DISTRO_CHOICE" != "debian" ] && [ "$DISTRO_CHOICE" != "ubuntu" ]; then
  echo "Invalid choice: '$DISTRO_CHOICE'. Falling back to default: debian"
  DISTRO_CHOICE="$DISTRO_DEFAULT"
fi

echo "[INSTALLER] Selected distro: $DISTRO_CHOICE"
echo

# ensure pkg available
if ! command -v pkg >/dev/null 2>&1; then
  echo "[ERROR] This installer is intended for Termux. 'pkg' command not found."
  exit 1
fi

# update termux and install proot-distro + curl/git if missing
echo "[INSTALLER] Updating Termux packages..."
pkg update -y
pkg upgrade -y

echo "[INSTALLER] Installing required packages: proot-distro, git (if missing)..."
pkg install proot-distro git -y

# Install chosen distro if not installed
if proot-distro list | grep -iq "^$DISTRO_CHOICE$"; then
  echo "[INSTALLER] $DISTRO_CHOICE already installed (proot-distro). Skipping install."
else
  echo "[INSTALLER] Installing $DISTRO_CHOICE via proot-distro. This may take a few minutes..."
  proot-distro install "$DISTRO_CHOICE"
fi

# function to run commands inside distro
run_in_distro() {
  proot-distro login "$DISTRO_CHOICE" --shared-tmp -- bash -c "$1"
}

echo "[INSTALLER] Preparing distro environment (apt update + install git)..."
run_in_distro "apt update -y && apt upgrade -y && apt install git -y"

echo "[INSTALLER] Cloning MCMS repository inside $DISTRO_CHOICE..."
# clone fresh inside distro, then cd & run mcms.sh
run_in_distro "rm -rf mcms && git clone $REPO_URL mcms || (echo 'git clone failed' && exit 1)"

echo "[INSTALLER] Running MCMS (mcms.sh)..."
run_in_distro "cd mcms && chmod +x mcms.sh && ./mcms.sh"

echo
echo "=== Done ==="
echo "If mcms.sh starts an interactive installer, follow its prompts inside the distro."
echo
