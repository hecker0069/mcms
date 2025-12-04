#!/data/data/com.termux/files/usr/bin/bash
# install-mcms.sh
# Robust installer: fixes Termux apt conffile prompts, installs chosen distro (debian default),
# runs non-interactive apt inside the distro, clones mcms and runs mcms.sh.
set -euo pipefail

REPO_URL="https://github.com/hecker0069/mcms"
DEFAULT_DISTRO="debian"

# Defaults
CONFFILE_POLICY="confold"    # keep existing config files by default
NONINTERACTIVE=0
DISTRO_CHOICE=""
QUIET=0

usage() {
  cat <<EOF
Usage: install-mcms.sh [options]

Options:
  --accept-maintainer    Use package maintainer's version for conflicting config files (force-confnew)
  --keep-config          Keep existing config files on conflict (force-confold) [default]
  --noninteractive       Do not prompt; use defaults (debian + keep-config)
  -h, --help             Show this help
EOF
  exit 1
}

# parse args
while [ $# -gt 0 ]; do
  case "$1" in
    --accept-maintainer) CONFFILE_POLICY="confnew"; shift ;;
    --keep-config) CONFFILE_POLICY="confold"; shift ;;
    --noninteractive) NONINTERACTIVE=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# map policy to dpkg options
if [ "$CONFFILE_POLICY" = "confnew" ]; then
  DPKG_OPTS='-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew"'
else
  DPKG_OPTS='-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"'
fi

APT_OPTS="-y $DPKG_OPTS"
DEBIAN_FRONTEND_NONINTERACTIVE="DEBIAN_FRONTEND=noninteractive"

echo
echo "=== MCMS Installer ==="
echo

# ensure running under Termux (pkg present)
if ! command -v pkg >/dev/null 2>&1; then
  echo "[ERROR] This installer is intended to run in Termux. 'pkg' not found."
  exit 1
fi

# If noninteractive, choose defaults
if [ "$NONINTERACTIVE" -eq 1 ]; then
  DISTRO_CHOICE="$DEFAULT_DISTRO"
else
  # prompt user for distro (default = debian)
  read -p "Choose distro to install [debian/ubuntu] (default: debian): " DISTRO_CHOICE
  DISTRO_CHOICE="${DISTRO_CHOICE:-$DEFAULT_DISTRO}"
  DISTRO_CHOICE="$(echo "$DISTRO_CHOICE" | tr '[:upper:]' '[:lower:]')"
fi

if [ "$DISTRO_CHOICE" != "debian" ] && [ "$DISTRO_CHOICE" != "ubuntu" ]; then
  echo "[WARN] Invalid choice '$DISTRO_CHOICE' — falling back to '$DEFAULT_DISTRO'."
  DISTRO_CHOICE="$DEFAULT_DISTRO"
fi

echo "[INSTALLER] Selected distro: $DISTRO_CHOICE"
echo "[INSTALLER] Conffile policy: $CONFFILE_POLICY"
echo

# 1) Fix Termux-side dpkg/apt state first (prevent blocking conffile prompt)
termux_repair() {
  echo "[INSTALLER] Repairing Termux apt/dpkg state (non-interactive) ..."
  # Export DEBIAN_FRONTEND noninteractive for apt-get commands that run under Termux's environment.
  # Use apt-get instead of apt to allow -o options reliably.
  # keep / replace behavior controlled by DPKG_OPTS variable above.
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y || true
  apt-get $APT_OPTS upgrade || true
  dpkg --configure -a || true
  apt-get -f install -y || true
  echo "[INSTALLER] Termux apt/dpkg repair step completed."
}

termux_repair

# 2) Update Termux packages and ensure proot-distro + git installed
echo "[INSTALLER] Updating Termux packages and installing required packages..."
pkg update -y
pkg upgrade -y
pkg install proot-distro git curl -y

# 3) Install chosen distro via proot-distro if not already installed
if proot-distro list | grep -iq "^${DISTRO_CHOICE}\$"; then
  echo "[INSTALLER] ${DISTRO_CHOICE} already installed via proot-distro. Skipping install."
else
  echo "[INSTALLER] Installing ${DISTRO_CHOICE} via proot-distro. This can take several minutes..."
  proot-distro install "${DISTRO_CHOICE}"
fi

# helper to run commands inside distro (safe quoting)
run_in_distro() {
  local cmd="$1"
  # Use bash -lc to allow ; and && style commands; use --shared-tmp for better compatibility
  proot-distro login "${DISTRO_CHOICE}" --shared-tmp -- bash -lc "$cmd"
}

# 4) Prepare distro: update + upgrade + install git (non-interactive)
echo "[INSTALLER] Preparing ${DISTRO_CHOICE} environment (apt update/upgrade/install git)..."
run_in_distro "${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get update -y || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get ${APT_OPTS} upgrade || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get ${APT_OPTS} install git || true; dpkg --configure -a || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get -f install -y || true"

# 5) Clone the repo fresh inside distro and run mcms.sh
echo "[INSTALLER] Cloning fresh copy of MCMS inside ${DISTRO_CHOICE}..."
run_in_distro "rm -rf mcms; git clone ${REPO_URL} mcms || { echo '[ERROR] git clone failed'; exit 1; }"

echo "[INSTALLER] Running mcms.sh inside ${DISTRO_CHOICE}..."
run_in_distro "cd mcms; chmod +x mcms.sh || true; ./mcms.sh"

echo
echo "=== Done ==="
echo "MCMS launched inside ${DISTRO_CHOICE}."
echo "If mcms.sh prompts for input, follow the prompts in the distro session."
echo

# End of script
