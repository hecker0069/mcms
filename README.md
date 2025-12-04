# MCMS - Minecraft Mobile Server

Run a Minecraft server on your Android phone.

## Installation

### Step 1: Setup Termux

```bash
pkg install proot-distro curl
proot-distro install ubuntu
```

### Step 2: Download MCMS

```bash
proot-distro login ubuntu
mkdir -p ~/mcms && cd ~/mcms
curl -sL https://raw.githubusercontent.com/mukulx/MCMS/main/mcms.sh -o mcms.sh
chmod +x mcms.sh
```

### Step 3: Run MCMS

```bash
./mcms.sh
```

## Run Again

```bash
proot-distro login ubuntu
cd ~/mcms && ./mcms.sh
```

## Update MCMS

```bash
proot-distro login ubuntu
cd ~/mcms
curl -sL https://raw.githubusercontent.com/mukulx/MCMS/main/mcms.sh -o mcms.sh
```

## Features

- **Server Software:** Paper, Purpur, Folia
- **Bedrock Support:** Geyser + Floodgate
- **Remote Access:** playit.gg (free)
- **Auto Setup:** Java, dependencies, optimizations

## Commands

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
- Termux from F-Droid
- ~1.5GB storage
- 2GB+ RAM recommended

## Documentation

See [README-mcms.md](README-mcms.md) for detailed documentation.
