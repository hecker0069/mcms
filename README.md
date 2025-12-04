# Termux Mobile Server Scripts

One-command setup scripts for running servers on Android via Termux.

## Scripts

| Script | Description | README |
|--------|-------------|--------|
| `ubuntu-termux.sh` | Install Ubuntu proot environment | [README-ubuntu.md](README-ubuntu.md) |
| `paper-server.sh` | Minecraft Paper server (runs inside Ubuntu) | [README-paper.md](README-paper.md) |

## Quick Start

```bash
# 1. Install Ubuntu first (in Termux)
chmod +x ubuntu-termux.sh
./ubuntu-termux.sh --quick

# 2. Enter Ubuntu
proot-distro login ubuntu

# 3. Install Minecraft server (inside Ubuntu)
chmod +x paper-server.sh
./paper-server.sh --quick
```

## Requirements

- Android device (aarch64)
- Termux app installed
- ~1.5GB free storage
- 2GB+ RAM recommended
