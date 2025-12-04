# MCMS - Minecraft Mobile Server

One-command Minecraft server setup for Android via Termux.

**Repository:** https://github.com/mukulx/MCMS

## Features

- **Server Software:** Paper, Purpur, Folia
- **Bedrock Support:** Geyser + Floodgate
- **Remote Access:** playit.gg integration
- **Auto Setup:** Java, dependencies, optimizations
- **Mobile Optimized:** Aikar's flags, low RAM configs

## Quick Start

```bash
# 1. Install Ubuntu in Termux
chmod +x ubuntu-termux.sh
./ubuntu-termux.sh --quick

# 2. Enter Ubuntu
proot-distro login ubuntu

# 3. Run MCMS
chmod +x mcms.sh
./mcms.sh
```

## Scripts

| Script | Description |
|--------|-------------|
| `ubuntu-termux.sh` | Install Ubuntu proot in Termux |
| `mcms.sh` | Minecraft server setup (run inside Ubuntu) |

## MCMS Commands

```bash
./mcms.sh              # Interactive menu
./mcms.sh --quick      # Quick Paper setup
./mcms.sh --purpur     # Quick Purpur setup
./mcms.sh --folia      # Quick Folia setup
./mcms.sh --geyser     # Add Bedrock support
./mcms.sh --playit     # Setup remote access
./mcms.sh --start      # Start server
./mcms.sh --update     # Check for updates
```

## Requirements

- Android device (aarch64)
- Termux app
- ~1.5GB storage
- 2GB+ RAM recommended

## Documentation

- [Ubuntu Setup Guide](README-ubuntu.md)
- [Server Setup Guide](README-mcms.md)
