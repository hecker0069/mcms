#!/data/data/com.termux/files/usr/bin/bash
# install-mcms.sh -- patched: prompts work when piped; adds colors; robust apt/dpkg handling
set -euo pipefail

REPO_URL="https://github.com/hecker0069/mcms"
DEFAULT_DISTRO="debian"

# Colors
RESET="\033[0m"
BOLD="\033[1m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"

info(){ printf "${BLUE}%s${RESET}\n" "$*"; }
ok(){ printf "${GREEN}%s${RESET}\n" "$*"; }
warn(){ printf "${YELLOW}%s${RESET}\n" "$*"; }
err(){ printf "${RED}%s${RESET}\n" "$*"; }

# Defaults
CONFFILE_POLICY="confold"    # keep existing config files by default
NONINTERACTIVE=0

usage() {
  cat <<EOF
${BOLD}Usage:${RESET} install-mcms.sh [options]

Options:
  --accept-maintainer    Use package maintainer's version for conflicting config files (force-confnew)
  --keep-config          Keep existing config files on conflict (force-confold) [default]
  --noninteractive       Do not prompt; use defaults (debian + keep-config)
  -h, --help             Show this help
EOF
  exit 1
}

# Parse args (supports being run as: curl ... | bash -s -- [args])
while [ $# -gt 0 ]; do
  case "$1" in
    --accept-maintainer) CONFFILE_POLICY="confnew"; shift ;;
    --keep-config) CONFFILE_POLICY="confold"; shift ;;
    --noninteractive) NONINTERACTIVE=1; shift ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# Map policy to dpkg options
if [ "$CONFFILE_POLICY" = "confnew" ]; then
  DPKG_OPTS='-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confnew"'
else
  DPKG_OPTS='-o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"'
fi

APT_OPTS="-y $DPKG_OPTS"
DEBIAN_FRONTEND_NONINTERACTIVE="DEBIAN_FRONTEND=noninteractive"

echo
printf "${BOLD}MCMS Installer${RESET}\n\n"

# Ensure Termux
if ! command -v pkg >/dev/null 2>&1; then
  err "[ERROR] This installer is intended to run in Termux. 'pkg' not found."
  exit 1
fi

# Choose distro: interactive read should come from /dev/tty if script's stdin is not a TTY
if [ "$NONINTERACTIVE" -eq 0 ]; then
  PROMPT_DEV="/dev/tty"
  if [ ! -r "$PROMPT_DEV" ]; then
    # fallback: if /dev/tty not available, and stdin is a tty, use stdin
    if [ -t 0 ]; then
      PROMPT_DEV="/dev/stdin"
    else
      # no interactive device available — fallback to default
      warn "Interactive prompt not available; falling back to default distro: ${DEFAULT_DISTRO}"
      DISTRO_CHOICE="$DEFAULT_DISTRO"
    fi
  fi

  if [ -z "${DISTRO_CHOICE:-}" ]; then
    if [ -r "$PROMPT_DEV" ]; then
      printf "${BOLD}Choose distro to install [debian/ubuntu] (default: debian): ${RESET}"
      read -r DISTRO_CHOICE < "$PROMPT_DEV" || DISTRO_CHOICE=""
      DISTRO_CHOICE="${DISTRO_CHOICE:-$DEFAULT_DISTRO}"
    fi
  fi
else
  DISTRO_CHOICE="$DEFAULT_DISTRO"
fi

DISTRO_CHOICE="${DISTRO_CHOICE:-$DEFAULT_DISTRO}"
DISTRO_CHOICE="$(echo "$DISTRO_CHOICE" | tr '[:upper:]' '[:lower:]')"

if [ "$DISTRO_CHOICE" != "debian" ] && [ "$DISTRO_CHOICE" != "ubuntu" ]; then
  warn "Invalid choice '$DISTRO_CHOICE' — falling back to '$DEFAULT_DISTRO'."
  DISTRO_CHOICE="$DEFAULT_DISTRO"
fi

info "[INSTALLER] Selected distro: $DISTRO_CHOICE"
info "[INSTALLER] Conffile policy: $CONFFILE_POLICY"
echo

# Termux-side repair function (prevent dpkg conffile prompts)
termux_repair() {
  info "[INSTALLER] Repairing Termux apt/dpkg state (non-interactive) ..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y || true
  apt-get $APT_OPTS upgrade || true
  dpkg --configure -a || true
  apt-get -f install -y || true
  ok "[INSTALLER] Termux apt/dpkg repair completed."
}

termux_repair

# Update Termux packages and install prerequisites
info "[INSTALLER] Updating Termux packages and installing required packages..."
pkg update -y
pkg upgrade -y
pkg install proot-distro git curl -y
ok "[INSTALLER] Required packages installed."

# Install chosen distro if missing
if proot-distro list | grep -iq "^${DISTRO_CHOICE}\$"; then
  ok "[INSTALLER] ${DISTRO_CHOICE} already installed via proot-distro. Skipping install."
else
  info "[INSTALLER] Installing ${DISTRO_CHOICE} via proot-distro (this can take several minutes)..."
  proot-distro install "${DISTRO_CHOICE}"
  ok "[INSTALLER] ${DISTRO_CHOICE} installed."
fi

# Helper to run commands inside the chosen distro
run_in_distro() {
  local cmd="$1"
  proot-distro login "${DISTRO_CHOICE}" --shared-tmp -- bash -lc "$cmd"
}

# Prepare distro (noninteractive apt, install git)
info "[INSTALLER] Preparing ${DISTRO_CHOICE} (apt update/upgrade/install git)..."
run_in_distro "${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get update -y || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get ${APT_OPTS} upgrade || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get ${APT_OPTS} install git || true; dpkg --configure -a || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get -f install -y || true"
ok "[INSTALLER] ${DISTRO_CHOICE} prepared."

# Clone fresh repo and run mcms.sh
info "[INSTALLER] Cloning fresh MCMS repository inside ${DISTRO_CHOICE}..."
run_in_distro "rm -rf mcms; git clone ${REPO_URL} mcms || { echo 'git clone failed'; exit 1; }"
ok "[INSTALLER] Repository cloned."

info "[INSTALLER] Running mcms.sh inside ${DISTRO_CHOICE}..."
run_in_distro "cd mcms; chmod +x mcms.sh || true; ./mcms.sh"
ok "[INSTALLER] mcms.sh executed (follow any prompts it shows)."

echo
ok "=== All done ==="
echo "MCMS launched inside ${DISTRO_CHOICE}. If mcms.sh expects input, follow prompts in that session."
