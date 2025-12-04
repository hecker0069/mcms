#!/data/data/com.termux/files/usr/bin/bash
# install-mcms.sh -- improved: verifies proot-distro + distro, robust login checks + diagnostics
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
DISTRO_CHOICE=""

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

# Parse args
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

printf "${BOLD}MCMS Installer${RESET}\n\n"

# Ensure Termux environment
if ! command -v pkg >/dev/null 2>&1; then
  err "[ERROR] This installer is intended to run in Termux. 'pkg' not found."
  exit 1
fi

# Repair any broken Termux apt/dpkg state (avoids blocking prompts)
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

# Choose distro (interactive if possible)
if [ "$NONINTERACTIVE" -eq 0 ]; then
  PROMPT_DEV="/dev/tty"
  if [ ! -r "$PROMPT_DEV" ]; then
    if [ -t 0 ]; then PROMPT_DEV="/dev/stdin"; else PROMPT_DEV=""; fi
  fi

  if [ -n "$PROMPT_DEV" ]; then
    printf "${BOLD}Choose distro to install [debian/ubuntu] (default: debian): ${RESET}"
    if read -r CHOICE < "$PROMPT_DEV"; then
      CHOICE="${CHOICE:-$DEFAULT_DISTRO}"
      DISTRO_CHOICE="$(echo "$CHOICE" | tr '[:upper:]' '[:lower:]')"
    else
      DISTRO_CHOICE="$DEFAULT_DISTRO"
    fi
  else
    warn "Interactive prompt unavailable; using default distro: ${DEFAULT_DISTRO}"
    DISTRO_CHOICE="$DEFAULT_DISTRO"
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

# Ensure proot-distro exists and install if missing
if ! command -v proot-distro >/dev/null 2>&1; then
  info "[INSTALLER] Installing proot-distro + git + curl..."
  pkg update -y
  pkg upgrade -y
  pkg install proot-distro git curl -y
else
  info "[INSTALLER] proot-distro detected."
  pkg install git curl -y || true
fi

# Ensure distro is installed
if proot-distro list | grep -iq "^${DISTRO_CHOICE}\$"; then
  ok "[INSTALLER] ${DISTRO_CHOICE} is already installed."
else
  info "[INSTALLER] Installing ${DISTRO_CHOICE} (this can take several minutes)..."
  proot-distro install "${DISTRO_CHOICE}"
  ok "[INSTALLER] ${DISTRO_CHOICE} installed."
fi

# Robust run_in_distro: tries common login forms and returns exit code + output
run_in_distro() {
  local CMD="$1"
  local OUT
  local RC

  # Try preferred form: with --shared-tmp
  info "[INSTALLER] Attempting to login to ${DISTRO_CHOICE} (method: --shared-tmp)..."
  if OUT=$(proot-distro login "${DISTRO_CHOICE}" --shared-tmp -- bash -lc "$CMD" 2>&1); then
    RC=0
    printf "%s\n" "$OUT"
    return 0
  else
    RC=$?
    warn "[INSTALLER] Login with --shared-tmp failed (rc=${RC}). Trying fallback..."
    # print little of output for hint
    printf "%s\n" "$OUT" | sed -n '1,40p'
  fi

  # Fallback: without --shared-tmp
  info "[INSTALLER] Attempting login to ${DISTRO_CHOICE} (method: plain login)..."
  if OUT=$(proot-distro login "${DISTRO_CHOICE}" -- bash -lc "$CMD" 2>&1); then
    RC=0
    printf "%s\n" "$OUT"
    return 0
  else
    RC=$?
    warn "[INSTALLER] Login (plain) failed (rc=${RC}). Captured output (first 60 lines):"
    printf "%s\n" "$OUT" | sed -n '1,60p'
  fi

  # final fallback: try interactive login and run a short command (useful for debug)
  warn "[INSTALLER] Final login attempt: interactive login test (will try run 'id' inside distro)..."
  if OUT=$(proot-distro login "${DISTRO_CHOICE}" -- bash -ic "id" 2>&1); then
    ok "[INSTALLER] Interactive login test succeeded; output:"
    printf "%s\n" "$OUT"
    # then run the requested CMD via a separate login to preserve behavior
    proot-distro login "${DISTRO_CHOICE}" -- bash -lc "$CMD"
    return $?
  else
    warn "[INSTALLER] Interactive login test failed. Captured output (first 80 lines):"
    printf "%s\n" "$OUT" | sed -n '1,80p'
  fi

  # If we reach here, login failed repeatedly
  err "[ERROR] proot-distro login failed for '${DISTRO_CHOICE}'."
  cat <<EOF

Suggested manual checks you can run in Termux to diagnose and fix:

1) Check proot-distro version and available distros:
   termux$ proot-distro --version
   termux$ proot-distro list

2) Try an interactive manual login yourself:
   termux$ proot-distro login ${DISTRO_CHOICE}

   If that fails, copy full error output and paste here.

3) If login works manually but fails from script, try running this minimal test:
   termux$ proot-distro login ${DISTRO_CHOICE} -- bash -lc "echo HELLO_FROM_DISTRO; id"

4) If proot-distro binary missing or broken:
   termux$ pkg reinstall proot-distro
   termux$ pkg install proot proot-distro

5) If your device is low on storage or interrupted during install, re-install distro:
   termux$ proot-distro remove ${DISTRO_CHOICE}
   termux$ proot-distro install ${DISTRO_CHOICE}

After running the manual checks above, paste the exact error text here and I'll help you fix it.

EOF
  return 2
}

# Prepare distro (update + install git) using run_in_distro (will exit with helpful diagnostics if login fails)
info "[INSTALLER] Preparing ${DISTRO_CHOICE} environment (apt update/upgrade/install git)..."
run_in_distro "${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get update -y || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get ${APT_OPTS} upgrade || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get ${APT_OPTS} install git || true; dpkg --configure -a || true; ${DEBIAN_FRONTEND_NONINTERACTIVE} apt-get -f install -y || true"
ok "[INSTALLER] ${DISTRO_CHOICE} prepared."

# Clone and run mcms.sh
info "[INSTALLER] Cloning fresh MCMS repository inside ${DISTRO_CHOICE}..."
run_in_distro "rm -rf mcms; git clone ${REPO_URL} mcms || { echo '[ERROR] git clone failed'; exit 1; }"
ok "[INSTALLER] Repository cloned."

info "[INSTALLER] Running mcms.sh inside ${DISTRO_CHOICE}..."
run_in_distro "cd mcms; chmod +x mcms.sh || true; ./mcms.sh"
ok "[INSTALLER] mcms.sh executed (follow any prompts it shows)."

echo
ok "=== All done ==="
echo "MCMS launched inside ${DISTRO_CHOICE}. If mcms.sh expects input, follow the prompts in that session."
