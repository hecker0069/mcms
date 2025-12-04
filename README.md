# MCMS - Minecraft Mobile Server

Run a full Minecraft server on your Android phone using Termux.

## Features

- **Paper, Purpur, Folia** - Choose your server software
- **Geyser + Floodgate** - Let Bedrock players join
- **playit.gg** - Free remote access from anywhere
- **Auto Setup** - Java, optimizations, everything handled
- **Mobile Optimized** - Aikar's flags, low RAM configs

## Installation

### 1. Install Ubuntu in Termux

```bash
pkg update && pkg upgrade
pkg install proot-distro curl
proot-distro install ubuntu
```

### 2. Download MCMS

```bash
proot-distro login ubuntu
mkdir -p ~/mcms && cd ~/mcms
curl -sL https://raw.githubusercontent.com/mukulx/MCMS/main/mcms.sh -o mcms.sh
chmod +x mcms.sh
```

### 3. Run

```bash
./mcms.sh
```

## Usage

### Run MCMS

```bash
proot-distro login ubuntu
cd ~/mcms && ./mcms.sh
```

### Update MCMS

```bash
proot-distro login ubuntu
cd ~/mcms
curl -sL https://raw.githubusercontent.com/mukulx/MCMS/main/mcms.sh -o mcms.sh
```

### Start Server Directly

```bash
proot-distro login ubuntu
cd ~/mcms/minecraft-server && ./start.sh
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `./mcms.sh` | Interactive menu |
| `./mcms.sh --quick` | Quick Paper setup |
| `./mcms.sh --purpur` | Quick Purpur setup |
| `./mcms.sh --folia` | Quick Folia setup |
| `./mcms.sh --geyser` | Add Bedrock support |
| `./mcms.sh --playit` | Setup playit.gg |
| `./mcms.sh --start` | Start server |
| `./mcms.sh --background` | Start in background |
| `./mcms.sh --status` | Show status |
| `./mcms.sh --update` | Check for MCMS updates |

## Requirements

- Android (aarch64)
- Termux from [F-Droid](https://f-droid.org/packages/com.termux/)
- ~1.5GB storage
- 2GB+ RAM recommended

## Server Types

| Server | Description |
|--------|-------------|
| Paper | Fast, stable, most plugins work |
| Purpur | Paper fork with extra features |
| Folia | Multi-threaded, needs Folia plugins |

## Ports

| Port | Protocol | Use |
|------|----------|-----|
| 25565 | TCP | Java Edition |
| 19132 | UDP | Bedrock Edition |

## Documentation

See [README-mcms.md](README-mcms.md) for detailed setup guide.

## License

MIT
