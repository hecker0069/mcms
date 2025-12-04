# Minecraft Paper Server for Termux (Ubuntu proot)

Run a Minecraft Paper server on your Android device inside Ubuntu proot.

## Prerequisites

1. Install Termux on Android
2. Install Ubuntu using `ubuntu-termux.sh` first
3. Enter Ubuntu environment

## Quick Start

```bash
# Step 1: Enter Ubuntu (in Termux)
proot-distro login ubuntu

# Step 2: Download and run (inside Ubuntu)
chmod +x paper-server.sh
./paper-server.sh
```

## Installation Options

| Command | Description |
|---------|-------------|
| `./paper-server.sh` | Interactive menu |
| `./paper-server.sh --quick` | Quick setup with defaults |
| `./paper-server.sh --start` | Start existing server |
| `./paper-server.sh --background` | Start in background |

## Interactive Menu Options

1. **Quick Setup** - Latest Paper version, auto RAM, survival mode
2. **Custom Setup** - Choose version, RAM, gamemode, difficulty
3. **Update Server** - Download newer Paper version
4. **Uninstall** - Remove server files

## After Setup

### Start Server
```bash
cd ~/minecraft-server
./start.sh
```

### Background Mode (keeps running after closing terminal)
```bash
cd ~/minecraft-server
./run-background.sh
```

### Manage Background Server
```bash
# Attach to server console
screen -r minecraft

# Detach (keep running): Press Ctrl+A then D

# Stop server (in console)
stop
```

## Connect to Server

### From Same Device
- Address: `localhost`
- Port: `25565`

### From Other Devices (same WiFi)
1. Find your IP: `ip addr` or check Android WiFi settings
2. Connect to: `YOUR_IP:25565`

### Minecraft Settings
- Online mode: OFF (for cracked/Bedrock clients)
- Default port: 25565

## Server Configuration

Server files location: `~/minecraft-server/`

| File | Purpose |
|------|---------|
| `server.properties` | Main server config |
| `paper.jar` | Server executable |
| `start.sh` | Start script with optimized flags |
| `eula.txt` | EULA acceptance |

### Edit Server Properties
```bash
nano ~/minecraft-server/server.properties
```

Common settings:
```properties
max-players=10
difficulty=normal
gamemode=survival
view-distance=8
motd=My Mobile Server
```

## RAM Allocation

The script auto-detects optimal RAM based on your device:
- 4GB+ device → 2GB for server
- 2-4GB device → 1GB for server
- <2GB device → 512MB for server

## Requirements

- Ubuntu proot installed in Termux
- ~500MB storage for server
- 2GB+ RAM recommended
- Java 17 (auto-installed)

## Troubleshooting

**"Java not found"**
```bash
apt update && apt install -y openjdk-17-jre-headless
```

**Server crashes immediately**
- Reduce RAM in `start.sh`
- Lower `view-distance` in server.properties

**Can't connect from other devices**
- Check firewall/hotspot settings
- Ensure same WiFi network
- Try disabling mobile data

**Lag/Low TPS**
- Reduce `max-players`
- Lower `view-distance` to 6
- Lower `simulation-distance` to 4

## Uninstall

```bash
./paper-server.sh
# Select option 4 (Uninstall)
```

Or manually:
```bash
rm -rf ~/minecraft-server
```
